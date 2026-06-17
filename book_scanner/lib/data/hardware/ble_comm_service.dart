import 'dart:async';
import 'dart:convert';
import 'comm_interface.dart';
import '../../../core/utils/logger.dart';

class BleCommService implements IHardwareComm {
  String? _deviceId;
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  @override
  Stream<String> get deviceStatusStream => _statusController.stream;

  @override
  Future<bool> connect(String deviceIdOrIp) async {
    _deviceId = deviceIdOrIp;
    Logger.info('[BLE] Connecting to device: $deviceIdOrIp');
    await Future.delayed(const Duration(seconds: 1));
    _statusController.add(jsonEncode({'status': 'connected', 'device': _deviceId}));
    Logger.info('[BLE] Connected successfully');
    return true;
  }

  @override
  Future<void> disconnect() async {
    Logger.info('[BLE] Disconnecting');
    await Future.delayed(const Duration(milliseconds: 300));
    _statusController.add(jsonEncode({'status': 'disconnected'}));
    _deviceId = null;
  }

  @override
  Future<bool> initialize() async {
    Logger.info('[BLE] Initializing device...');
    _statusController.add(jsonEncode({'status': 'initializing'}));
    await Future.delayed(const Duration(seconds: 2));
    _statusController.add(jsonEncode({'status': 'initialized'}));
    Logger.info('[BLE] Device initialized successfully');
    return true;
  }

  @override
  Future<void> startScanAndPrint() async {
    Logger.info('[BLE] Starting scan and print');
    _statusController.add(jsonEncode({'status': 'working', 'step': 'capturing'}));
  }

  @override
  Future<void> stopAll() async {
    Logger.info('[BLE] Emergency stop');
    _statusController.add(jsonEncode({'status': 'stopped'}));
  }

  @override
  Future<void> nextPaperReady() async {
    Logger.info('[BLE] Next paper ready');
    _statusController.add(jsonEncode({'status': 'working', 'step': 'printing'}));
  }

  @override
  Future<void> sendCommand(String command, {Map<String, dynamic>? params}) async {
    Logger.info('[BLE] Sending command: $command');
    _statusController.add(jsonEncode({'command': command, 'params': params}));
  }
}
