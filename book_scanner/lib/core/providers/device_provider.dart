import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_enums.dart';
import '../../data/hardware/hardware_manager.dart';

class DeviceState {
  final DeviceStatus status;
  final String statusMessage;
  final PrintStep currentStep;
  final String? connectedDeviceId;
  final bool useWifi;

  const DeviceState({
    this.status = DeviceStatus.disconnected,
    this.statusMessage = '未连接',
    this.currentStep = PrintStep.idle,
    this.connectedDeviceId,
    this.useWifi = false,
  });

  DeviceState copyWith({
    DeviceStatus? status,
    String? statusMessage,
    PrintStep? currentStep,
    String? connectedDeviceId,
    bool? useWifi,
  }) {
    return DeviceState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      currentStep: currentStep ?? this.currentStep,
      connectedDeviceId: connectedDeviceId ?? this.connectedDeviceId,
      useWifi: useWifi ?? this.useWifi,
    );
  }
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  final HardwareManager _hardwareManager = HardwareManager();
  StreamSubscription<String>? _statusSub;

  DeviceNotifier() : super(const DeviceState());

  void _listenToHardware() {
    _statusSub?.cancel();
    _statusSub = _hardwareManager.deviceStatusStream?.listen((data) {
      // Parse JSON status from hardware
      // In production, parse real status data here
    });
  }

  Future<void> connect(String deviceId, {bool useWifi = false}) async {
    _hardwareManager.switchMode(useWifi);
    state = state.copyWith(
      status: DeviceStatus.connecting,
      statusMessage: '连接中...',
    );

    await _hardwareManager.connect(deviceId);

    state = state.copyWith(
      status: DeviceStatus.connected,
      statusMessage: '已连接',
      connectedDeviceId: deviceId,
      useWifi: useWifi,
    );
    _listenToHardware();
  }

  Future<void> disconnect() async {
    _statusSub?.cancel();
    await _hardwareManager.disconnect();
    state = const DeviceState();
  }

  Future<void> startPrintJob() async {
    await _hardwareManager.startScanAndPrint();
    state = state.copyWith(status: DeviceStatus.working, currentStep: PrintStep.turningPage);
  }

  Future<void> emergencyStop() async {
    await _hardwareManager.emergencyStop();
    state = state.copyWith(
      status: DeviceStatus.connected,
      currentStep: PrintStep.stopped,
      statusMessage: '已终止',
    );
  }

  void setSimulatedStep(PrintStep step) {
    state = state.copyWith(currentStep: step);
  }

  void simulatePaperDone() {
    state = state.copyWith(
      status: DeviceStatus.connected,
      currentStep: PrintStep.completed,
      statusMessage: '请更换盲文纸',
    );
  }

  Future<void> confirmPaperReady() async {
    await _hardwareManager.nextPaperReady();
    state = state.copyWith(
      status: DeviceStatus.working,
      currentStep: PrintStep.printing,
      statusMessage: '打印中...',
    );
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }
}

final deviceProvider = StateNotifierProvider<DeviceNotifier, DeviceState>((ref) {
  return DeviceNotifier();
});
