import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'comm_interface.dart';
import 'comm_protocol.dart';
import '../../../core/constants/hardware_config.dart';
import '../../../core/utils/logger.dart';

class MqttCommService implements IHardwareComm {
  MqttServerClient? _client;
  bool _connected = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  final StreamController<HardwareMessage> _statusController =
      StreamController<HardwareMessage>.broadcast();

  @override
  Stream<HardwareMessage> get deviceStatusStream => _statusController.stream;

  @override
  Future<bool> connect(String brokerAddress) async {
    _disposed = false;
    _client?.disconnect();
    _client = null;

    final host = brokerAddress.isNotEmpty ? brokerAddress : HardwareConfig.mqttBrokerHost;

    if (HardwareConfig.mqttUseWebSocket) {
      _client = MqttServerClient.withPort(host, HardwareConfig.mqttClientId, HardwareConfig.mqttPort)
        ..useWebSocket = true
        ..websocketProtocols = ['mqtt'];
    } else {
      _client = MqttServerClient.withPort(host, HardwareConfig.mqttClientId, HardwareConfig.mqttPort);
    }

    _client!.logging(on: false);
    _client!.keepAlivePeriod = HardwareConfig.keepAlivePeriod;
    _client!.autoReconnect = false;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;

    final connMsg = MqttConnectMessage()
        .withClientIdentifier(HardwareConfig.mqttClientId)
        .startClean()
        .keepAliveFor(HardwareConfig.keepAlivePeriod);

    if (HardwareConfig.mqttUsername != null && HardwareConfig.mqttUsername!.isNotEmpty) {
      connMsg.withUsername(HardwareConfig.mqttUsername!);
    }
    if (HardwareConfig.mqttPassword != null && HardwareConfig.mqttPassword!.isNotEmpty) {
      connMsg.withPassword(HardwareConfig.mqttPassword!);
    }

    _client!.connectionMessage = connMsg;

    try {
      Logger.info('[MQTT] 正在连接 $host:${HardwareConfig.mqttPort}');
      await _client!.connect();
    } catch (e) {
      Logger.error('[MQTT] 连接失败: $e');
      _connected = false;
      return false;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      _connected = true;
      _reconnectAttempts = 0;
      _subscribeTopics();
      _listenMessages();
      _statusController.add(
        const HardwareMessage(type: HardwareConfig.statusConnected, payload: {}),
      );
      Logger.info('[MQTT] 已连接 EMQX broker');
      return true;
    }

    Logger.error('[MQTT] 连接未就绪: ${_client!.connectionStatus!.state}');
    _connected = false;
    return false;
  }

  void _subscribeTopics() {
    if (_client == null) return;
    _client!.subscribe(HardwareConfig.topicDeviceToApp, MqttQos.atLeastOnce);
    Logger.info('[MQTT] 已订阅 ${HardwareConfig.topicDeviceToApp}');
  }

  void _listenMessages() {
    _client!.updates?.listen(_onMessage);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic = msg.topic;
      final payloadStr = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
      Logger.debug('[MQTT] 收到 ← [$topic] $payloadStr');

      if (topic == HardwareConfig.topicDeviceToApp) {
        try {
          final hwMsg = HardwareMessage.fromJsonString(payloadStr);
          _statusController.add(hwMsg);
        } catch (e) {
          Logger.error('[MQTT] 消息解析失败: $e, raw=$payloadStr');
        }
      }
    }
  }

  void _onConnected() {
    Logger.info('[MQTT] onConnected 回调');
    _connected = true;
    _reconnectAttempts = 0;
  }

  void _onDisconnected() {
    Logger.warn('[MQTT] 连接断开');
    _connected = false;
    if (!_disposed) {
      _scheduleReconnect();
    }
  }

  void _onSubscribed(String topic) {
    Logger.info('[MQTT] onSubscribed → $topic');
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= HardwareConfig.maxReconnectAttempts) {
      Logger.error('[MQTT] 重连次数已达上限 (${HardwareConfig.maxReconnectAttempts})，停止重连');
      return;
    }
    _reconnectAttempts++;
    final delay = HardwareConfig.reconnectDelayMs * _reconnectAttempts;
    Logger.info('[MQTT] 将在 ${delay}ms 后尝试第 $_reconnectAttempts 次重连');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      if (!_disposed && !_connected) {
        _attemptReconnect();
      }
    });
  }

  Future<void> _attemptReconnect() async {
    if (_client == null || _disposed) return;
    try {
      Logger.info('[MQTT] 尝试重连...');
      await _client!.connect();
      if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
        _connected = true;
        _reconnectAttempts = 0;
        _subscribeTopics();
        Logger.info('[MQTT] 重连成功');
      }
    } catch (e) {
      Logger.error('[MQTT] 重连失败: $e');
      _scheduleReconnect();
    }
  }

  @override
  Future<void> disconnect() async {
    Logger.info('[MQTT] 断开连接');
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _client?.disconnect();
    _client = null;
    _connected = false;
  }

  @override
  Future<bool> initialize() async {
    Logger.info('[MQTT] 发送设备初始化指令...');
    _publish({'type': 'CMD_INIT', 'payload': {}});
    await Future.delayed(const Duration(seconds: 1));
    Logger.info('[MQTT] 初始化完成');
    return true;
  }

  @override
  Future<void> startPrint() async {
    Logger.info('[MQTT] 开始打印');
    _publish(CmdStartPrint().toJson());
  }

  @override
  Future<void> stopPrint() async {
    Logger.info('[MQTT] 停止打印');
    _publish(CmdStopPrint().toJson());
  }

  @override
  Future<void> emergencyStop() async {
    Logger.info('[MQTT] 紧急停止');
    _publish(CmdEmergencyStop().toJson());
  }

  void _publish(Map<String, dynamic> message) {
    if (!_connected || _client == null) {
      Logger.warn('[MQTT] 未连接，无法发布消息');
      return;
    }
    final jsonStr = jsonEncode(message);
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonStr);
    _client!.publishMessage(
      HardwareConfig.topicAppToDevice,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
    Logger.debug('[MQTT] 发布 → [${HardwareConfig.topicAppToDevice}] $jsonStr');
  }
}
