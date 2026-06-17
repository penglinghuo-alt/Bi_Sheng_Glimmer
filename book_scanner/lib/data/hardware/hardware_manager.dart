import 'dart:async';
import 'comm_interface.dart';
import 'ble_comm_service.dart';
import 'wifi_comm_service.dart';
import '../../../core/utils/logger.dart';

class HardwareManager {
  static final HardwareManager _instance = HardwareManager._();
  factory HardwareManager() => _instance;
  HardwareManager._();

  IHardwareComm? _currentComm;
  bool _useWifi = false;

  IHardwareComm? get currentComm => _currentComm;
  bool get useWifi => _useWifi;
  Stream<String>? get deviceStatusStream => _currentComm?.deviceStatusStream;

  void switchMode(bool useWifi) {
    if (_useWifi == useWifi && _currentComm != null) return;
    _useWifi = useWifi;
    _currentComm?.disconnect();
    _currentComm = useWifi ? WifiCommService() : BleCommService();
    Logger.info('[HardwareManager] Switched to ${useWifi ? "WiFi" : "BLE"} mode');
  }

  Future<bool> connect(String deviceIdOrIp) async {
    switchMode(_useWifi);
    return await _currentComm!.connect(deviceIdOrIp);
  }

  Future<void> disconnect() async {
    await _currentComm?.disconnect();
    _currentComm = null;
  }

  Future<void> emergencyStop() async {
    await _currentComm?.stopAll();
  }

  Future<void> startScanAndPrint() async {
    await _currentComm?.startScanAndPrint();
  }

  Future<void> nextPaperReady() async {
    await _currentComm?.nextPaperReady();
  }
}
