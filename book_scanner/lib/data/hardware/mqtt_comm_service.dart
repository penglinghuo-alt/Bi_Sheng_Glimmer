import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mqtt_client/mqtt_client.dart';

import 'comm_interface.dart';
import 'comm_protocol.dart';
import '../../../core/constants/hardware_config.dart';
import '../../../core/utils/logger.dart';
import 'mqtt_client_factory_io.dart'
    if (dart.library.html) 'mqtt_client_factory_web.dart';

class MqttCommService implements IHardwareComm {
  MqttClient? _client;
  bool _connected = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  final StreamController<HardwareMessage> _statusController =
      StreamController<HardwareMessage>.broadcast();

  static const _qos = MqttQos.atMostOnce;

  @override
  Stream<HardwareMessage> get deviceStatusStream => _statusController.stream;

  int get _port => kIsWeb ? 8083 : HardwareConfig.mqttPort;

  @override
  Future<bool> connect(String brokerAddress) async {
    _disposed = false;
    _client?.disconnect();
    _client = null;

    final host = brokerAddress.isNotEmpty ? brokerAddress : HardwareConfig.mqttBrokerHost;

    _client = createMqttClient(host, HardwareConfig.mqttClientId, _port);

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

    _client!.connectionMessage = connMsg;

    try {
      Logger.info('[MQTT] 正在连接 $host:$_port ${kIsWeb ? "(WebSocket)" : "(TCP)"}');
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
      Logger.info('[MQTT] 已连接 EMQX broker');
      return true;
    }

    Logger.error('[MQTT] 连接未就绪: ${_client!.connectionStatus!.state}');
    _connected = false;
    return false;
  }

  void _subscribeTopics() {
    if (_client == null) return;
    _client!.subscribe(HardwareConfig.topicStatusState, _qos);
    _client!.subscribe(HardwareConfig.topicStatusPosition, _qos);
    _client!.subscribe(HardwareConfig.topicStatusError, _qos);
    _client!.subscribe(HardwareConfig.topicStatusOcr, _qos);
    _client!.subscribe(HardwareConfig.topicStatusOnline, MqttQos.atLeastOnce);
    Logger.info('[MQTT] 已订阅 5 个状态 Topic (含 online)');
  }

  void _listenMessages() {
    _client!.updates?.listen(_onMessage);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final msg in messages) {
      final topic = msg.topic;
      final publishMsg = msg.payload as MqttPublishMessage;
      final payloadStr = MqttPublishPayload.bytesToStringAsString(publishMsg.payload.message);
      Logger.debug('[MQTT] 收到 ← [$topic] $payloadStr');

      try {
        final hwMsg = _parseMessage(topic, payloadStr);
        _statusController.add(hwMsg);
      } catch (e) {
        Logger.error('[MQTT] 消息解析失败: $e, raw=$payloadStr');
      }
    }
  }

  /// 统一解析入口: online 主题为扁平 JSON (event/message_id/...),
  /// 其余主题为通用信封 (type/payload)。
  HardwareMessage _parseMessage(String topic, String payloadStr) {
    final map = jsonDecode(payloadStr) as Map<String, dynamic>;

    if (topic == HardwareConfig.topicStatusOnline) {
      final online = StatusOnline.fromRawJson(map);
      return HardwareMessage(
        type: HardwareConfig.statusOnline,
        payload: {
          'event': online.event,
          'message_id': online.messageId,
          'timestamp': online.timestamp,
          'client_id': online.clientId,
          'config_version': online.configVersion,
          'services': online.services,
          'health': {
            'status': online.healthStatus,
            'checks': online.healthChecks,
          },
          'uptime_ms': online.uptimeMs,
        },
      );
    }

    return HardwareMessage.fromJsonString(payloadStr);
  }

  void _onConnected() {
    Logger.info('[MQTT] onConnected');
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
    Logger.info('[MQTT] 初始化设备...');
    _publishCmd(CmdReset().toJson());
    await Future.delayed(const Duration(milliseconds: 500));
    _publishCmd(CmdHome().toJson());
    return true;
  }

  @override
  Future<void> sendText(String text) async {
    _publishSingle(HardwareConfig.topicCmdPrint, TextBatch(text: text).toJson());
  }

  @override
  Future<void> startPrint() async {
    _publishCmd(CmdStartPrint().toJson());
  }

  @override
  Future<void> stopPrint() async {
    _publishCmd(CmdStopPrint().toJson());
  }

  @override
  Future<void> emergencyStop() async {
    _publishCmd(CmdEmergencyStop().toJson());
  }

  void _publishSingle(String topic, Map<String, dynamic> message) {
    if (!_connected || _client == null) return;
    final jsonStr = jsonEncode(message);
    final bytes = utf8.encode(jsonStr);
    final builder = MqttClientPayloadBuilder();
    for (final b in bytes) {
      builder.addByte(b);
    }
    _client!.publishMessage(topic, _qos, builder.payload!);
    Logger.debug('[MQTT] 发布 → ${message['type']} → $topic');
  }

  void _publishCmd(Map<String, dynamic> message) {
    if (!_connected || _client == null) {
      Logger.warn('[MQTT] 未连接，无法发布');
      return;
    }
    final jsonStr = jsonEncode(message);
    final bytes = utf8.encode(jsonStr);
    final builder = MqttClientPayloadBuilder();
    for (final b in bytes) {
      builder.addByte(b);
    }
    _client!.publishMessage(HardwareConfig.topicCmdControl, _qos, builder.payload!);
    Logger.debug('[MQTT] 发布 → [${HardwareConfig.topicCmdControl}] ${message['type']}');
  }

  void publishMessage(String topic, Map<String, dynamic> message) {
    if (!_connected || _client == null) return;
    final jsonStr = jsonEncode(message);
    final bytes = utf8.encode(jsonStr);
    final builder = MqttClientPayloadBuilder();
    for (final b in bytes) {
      builder.addByte(b);
    }
    _client!.publishMessage(topic, _qos, builder.payload!);
    Logger.debug('[MQTT] 发布 → [$topic] $jsonStr');
  }
}
