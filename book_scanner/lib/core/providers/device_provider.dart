import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_enums.dart';
import '../../data/services/api_client.dart';
import '../../data/hardware/comm_protocol.dart';
import '../../data/hardware/hardware_manager.dart';
import '../../core/utils/logger.dart';

class DeviceState {
  final DeviceStatus status;
  final String statusMessage;
  final PrintStep currentStep;
  final String? connectedDeviceId;
  final bool useWifi;
  final int progressCurrent;
  final int progressTotal;
  final double progressPercentage;

  final String? boardState;
  final int motorX;
  final int motorY1;
  final int motorY2;
  final String? ocrText;
  final int ocrTotalChars;

  const DeviceState({
    this.status = DeviceStatus.disconnected,
    this.statusMessage = '未连接',
    this.currentStep = PrintStep.idle,
    this.connectedDeviceId,
    this.useWifi = false,
    this.progressCurrent = 0,
    this.progressTotal = 0,
    this.progressPercentage = 0,
    this.boardState,
    this.motorX = 0,
    this.motorY1 = 0,
    this.motorY2 = 0,
    this.ocrText,
    this.ocrTotalChars = 0,
  });

  DeviceState copyWith({
    DeviceStatus? status,
    String? statusMessage,
    PrintStep? currentStep,
    String? connectedDeviceId,
    bool? useWifi,
    int? progressCurrent,
    int? progressTotal,
    double? progressPercentage,
    String? boardState,
    bool clearBoardState = false,
    int? motorX,
    int? motorY1,
    int? motorY2,
    String? ocrText,
    bool clearOcrText = false,
    int? ocrTotalChars,
  }) {
    return DeviceState(
      status: status ?? this.status,
      statusMessage: statusMessage ?? this.statusMessage,
      currentStep: currentStep ?? this.currentStep,
      connectedDeviceId: connectedDeviceId ?? this.connectedDeviceId,
      useWifi: useWifi ?? this.useWifi,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      progressTotal: progressTotal ?? this.progressTotal,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      boardState: clearBoardState ? null : (boardState ?? this.boardState),
      motorX: motorX ?? this.motorX,
      motorY1: motorY1 ?? this.motorY1,
      motorY2: motorY2 ?? this.motorY2,
      ocrText: clearOcrText ? null : (ocrText ?? this.ocrText),
      ocrTotalChars: ocrTotalChars ?? this.ocrTotalChars,
    );
  }

  DeviceState applyProgress(StatusProgress p) {
    return copyWith(
      progressCurrent: p.current,
      progressTotal: p.total,
      progressPercentage: p.percentage,
      currentStep: PrintStep.printing,
      status: DeviceStatus.printing,
      statusMessage: '${p.current}/${p.total}',
    );
  }
}

class DeviceNotifier extends StateNotifier<DeviceState> {
  final ApiClient _api = ApiClient();
  final HardwareManager _hwManager = HardwareManager();
  StreamSubscription<HardwareMessage>? _statusSub;

  DeviceNotifier() : super(const DeviceState());

  void bindStatusStream(Stream<HardwareMessage> stream) {
    _statusSub?.cancel();
    _statusSub = stream.listen((msg) {
      switch (msg.type) {
        case StatusState.type:
          final s = StatusState.fromPayload(msg.payload);
          state = state.copyWith(
            boardState: s.newState,
            statusMessage: '设备: ${s.newState} ${s.reason ?? ""}'.trimRight(),
            status: _boardStateToDeviceStatus(s.newState),
          );
        case StatusProgress.type:
          final p = StatusProgress.fromPayload(msg.payload);
          state = state.applyProgress(p);
        case StatusPosition.type:
          final p = StatusPosition.fromPayload(msg.payload);
          state = state.copyWith(motorX: p.x, motorY1: p.y1, motorY2: p.y2);
        case StatusError.type:
          final e = StatusError.fromPayload(msg.payload);
          state = state.copyWith(
            status: DeviceStatus.error,
            statusMessage: '${e.code}: ${e.msg}',
          );
        case StatusOcrResult.type:
          final r = StatusOcrResult.fromPayload(msg.payload);
          state = state.copyWith(
            ocrText: r.text,
            ocrTotalChars: r.totalChars,
          );
          Logger.info('[Device] OCR 识别结果: ${r.totalChars} 字符');
      }
    });
  }

  DeviceStatus _boardStateToDeviceStatus(String boardState) {
    switch (boardState) {
      case 'PRINTING':
        return DeviceStatus.printing;
      case 'ERROR':
        return DeviceStatus.error;
      case 'PAGE_COMPLETE':
        return DeviceStatus.stopped;
      case 'IDLE':
      default:
        return DeviceStatus.connected;
    }
  }

  Future<void> connect(String deviceId, {bool useWifi = false, bool useMqtt = false}) async {
    state = state.copyWith(status: DeviceStatus.connecting, statusMessage: '连接中...');

    if (useMqtt) {
      try {
        final ok = await _hwManager.connect(deviceId);
        if (ok) {
          final stream = _hwManager.deviceStatusStream;
          if (stream != null) {
            bindStatusStream(stream);
          }
          state = state.copyWith(
            status: DeviceStatus.connected,
            statusMessage: '已连接到 Broker',
            connectedDeviceId: deviceId,
            clearBoardState: true,
            clearOcrText: true,
            motorX: 0,
            motorY1: 0,
            motorY2: 0,
          );
          Logger.info('[Device] MQTT 连接成功，已绑定状态流');
        } else {
          state = state.copyWith(status: DeviceStatus.error, statusMessage: 'MQTT 连接失败');
        }
      } catch (e) {
        Logger.error('[Device] MQTT 连接异常: $e');
        state = state.copyWith(status: DeviceStatus.error, statusMessage: '连接失败: $e');
      }
      return;
    }

    try {
      await _api.connectDevice(deviceId, useWifi: useWifi);
      state = state.copyWith(
        status: DeviceStatus.connected,
        statusMessage: '已连接',
        connectedDeviceId: deviceId,
        useWifi: useWifi,
      );
    } catch (e) {
      state = state.copyWith(status: DeviceStatus.error, statusMessage: '连接失败');
    }
  }

  Future<void> disconnect() async {
    try {
      await _api.disconnectDevice();
    } catch (_) {}
    _statusSub?.cancel();
    _hwManager.disconnect();
    state = const DeviceState();
  }

  Future<void> initialize() async {
    state = state.copyWith(status: DeviceStatus.initializing, statusMessage: '正在初始化设备...');
    try {
      await _hwManager.initialize();
      try {
        final res = await _api.initializeDevice();
        if (res['success'] == true) {
          state = state.copyWith(status: DeviceStatus.initialized, statusMessage: '设备就绪，可以开始打印');
        } else {
          state = state.copyWith(status: DeviceStatus.error, statusMessage: '初始化失败');
        }
      } catch (_) {
        state = state.copyWith(status: DeviceStatus.initialized, statusMessage: '设备就绪，可以开始打印');
      }
    } catch (e) {
      state = state.copyWith(status: DeviceStatus.error, statusMessage: '初始化失败，请检查网络');
    }
  }

  Future<void> startPrintJob() async {
    try {
      await _api.startPrint();
    } catch (_) {}
    _hwManager.startPrint();
    state = state.copyWith(
      status: DeviceStatus.working,
      currentStep: PrintStep.turningPage,
      progressCurrent: 0,
      progressTotal: 0,
      progressPercentage: 0,
    );
  }

  /// 仅更新本地 UI 状态——板端 CMD_PAUSE_PRINT 有 bug，不应通过硬件层发送
  Future<void> pausePrint() async {
    state = state.copyWith(status: DeviceStatus.paused, currentStep: PrintStep.paused, statusMessage: '已暂停');
  }

  /// 仅更新本地 UI 状态——板端 CMD_RESUME_PRINT 有 bug，不应通过硬件层发送
  Future<void> resumePrint() async {
    state = state.copyWith(status: DeviceStatus.printing, currentStep: PrintStep.printing, statusMessage: '打印中...');
  }

  Future<void> emergencyStop() async {
    try {
      await _api.stopPrint();
    } catch (_) {}
    _hwManager.emergencyStop();
    state = state.copyWith(status: DeviceStatus.connected, currentStep: PrintStep.stopped, statusMessage: '已终止');
  }

  void setSimulatedStep(PrintStep step) {
    state = state.copyWith(currentStep: step);
  }

  void simulatePaperDone() {
    state = state.copyWith(status: DeviceStatus.connected, currentStep: PrintStep.completed, statusMessage: '请更换盲文纸');
  }

  Future<void> confirmPaperReady() async {
    try {
      await _api.paperReady();
    } catch (_) {}
    state = state.copyWith(status: DeviceStatus.working, currentStep: PrintStep.printing, statusMessage: '打印中...');
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
