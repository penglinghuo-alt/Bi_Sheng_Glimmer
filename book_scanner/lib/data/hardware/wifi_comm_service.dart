import 'dart:async';
import 'dart:convert';
import 'comm_interface.dart';
import '../../../core/utils/logger.dart';

class WifiCommService implements IHardwareComm {
  String? _ip;
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  @override
  Stream<String> get deviceStatusStream => _statusController.stream;

  @override
  Future<bool> connect(String deviceIdOrIp) async {
    _ip = deviceIdOrIp;
    Logger.info('[WiFi] Connecting to: $deviceIdOrIp');
    await Future.delayed(const Duration(seconds: 1));
    _statusController.add(jsonEncode({'status': 'connected', 'ip': _ip}));
    Logger.info('[WiFi] Connected successfully');
    return true;
  }

  @override
  Future<void> disconnect() async {
    Logger.info('[WiFi] Disconnecting');
    await Future.delayed(const Duration(milliseconds: 300));
    _statusController.add(jsonEncode({'status': 'disconnected'}));
    _ip = null;
  }

  @override
  Future<void> startScanAndPrint() async {
    Logger.info('[WiFi] Starting scan and print');
    _statusController.add(jsonEncode({'status': 'working', 'step': 'capturing'}));
  }

  @override
  Future<void> stopAll() async {
    Logger.info('[WiFi] Emergency stop');
    _statusController.add(jsonEncode({'status': 'stopped'}));
  }

  @override
  Future<void> nextPaperReady() async {
    Logger.info('[WiFi] Next paper ready');
    _statusController.add(jsonEncode({'status': 'working', 'step': 'printing'}));
  }

  @override
  Future<void> sendCommand(String command, {Map<String, dynamic>? params}) async {
    Logger.info('[WiFi] Sending command: $command');
    _statusController.add(jsonEncode({'command': command, 'params': params}));
  }
}
