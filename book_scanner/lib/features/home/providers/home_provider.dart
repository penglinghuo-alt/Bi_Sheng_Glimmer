import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_enums.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/local_db/database_helper.dart';

class HomeState {
  final PrintMode selectedMode;
  final PrintStep currentStep;
  final bool showPaperDialog;
  final double progress;
  final bool isInitializing;
  final bool isInitialized;
  final bool isWorking;
  final List<String> logs;
  final bool showReadyDialog;

  const HomeState({
    this.selectedMode = PrintMode.scanAndPrint,
    this.currentStep = PrintStep.idle,
    this.showPaperDialog = false,
    this.progress = 0.0,
    this.isInitializing = false,
    this.isInitialized = false,
    this.isWorking = false,
    this.logs = const [],
    this.showReadyDialog = false,
  });

  HomeState copyWith({
    PrintMode? selectedMode,
    PrintStep? currentStep,
    bool? showPaperDialog,
    double? progress,
    bool? isInitializing,
    bool? isInitialized,
    bool? isWorking,
    List<String>? logs,
    bool? showReadyDialog,
  }) {
    return HomeState(
      selectedMode: selectedMode ?? this.selectedMode,
      currentStep: currentStep ?? this.currentStep,
      showPaperDialog: showPaperDialog ?? this.showPaperDialog,
      progress: progress ?? this.progress,
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
      isWorking: isWorking ?? this.isWorking,
      logs: logs ?? this.logs,
      showReadyDialog: showReadyDialog ?? this.showReadyDialog,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final DatabaseHelper _db = DatabaseHelper();
  Timer? _logTimer;
  Timer? _stepTimer;
  Timer? _initTimer;
  int _logIndex = 0;
  int _jobCounter = 0;

  static const _logMessages = [
    '初始化扫描头...',
    '扫描头预热完成，温度 38°C',
    '步进电机自检通过',
    '纸张传感器校准成功',
    '摄像头自动对焦完成',
    '--- 机器已准备完毕 ---',
    '检测到纸张，厚度 0.12mm',
    '开始翻页...',
    '翻页完成，准备拍照',
    '正在拍摄图像...',
    '图像采集完成，分辨率 300DPI',
    'OCR 文字识别中...',
    '识别完成，共检测到 248 个字符',
    '盲文点阵转换处理中...',
    '点阵映射完成 (40x30)',
    '正在传输打印数据到硬件...',
    '打印头预热中，温度升至 80°C',
    '开始打印第 1 行...',
    '打印进度: 25%',
    '打印进度: 50%',
    '打印进度: 75%',
    '打印进度: 100%',
    '当前页打印完成',
    '纸张传送中...',
    '机械臂归位完成',
    '--- 打印任务全部完成 ---',
  ];

  HomeNotifier() : super(const HomeState());

  void setMode(PrintMode mode) {
    state = state.copyWith(selectedMode: mode);
  }

  void startWorking() {
    state = state.copyWith(isInitializing: true, showReadyDialog: false, logs: []);
    _logIndex = 0;

    _initTimer?.cancel();
    _initTimer = Timer(const Duration(seconds: 3), () {
      state = state.copyWith(isInitializing: false, showReadyDialog: true);
      _startInitLogs();
    });
  }

  void _startInitLogs() {
    final initLogs = _logMessages.sublist(0, 6);
    for (int i = 0; i < initLogs.length; i++) {
      Future.delayed(Duration(milliseconds: 400 * i), () {
        if (mounted) {
          state = state.copyWith(logs: [...state.logs, initLogs[i]]);
        }
      });
    }
  }

  void confirmReady() {
    state = state.copyWith(showReadyDialog: false, isInitialized: true, isWorking: true);
    _logIndex = 6;
    startPrintJob();
    _startWorkLogs();
    _simulateSteps();
  }

  void _startWorkLogs() {
    _logTimer?.cancel();
    _logTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_logIndex < _logMessages.length) {
        state = state.copyWith(logs: [...state.logs, _logMessages[_logIndex]]);
        _logIndex++;
      } else {
        timer.cancel();
      }
    });
  }

  void startPrintJob() {
    state = state.copyWith(currentStep: PrintStep.capturing, progress: 0.0);
  }

  void updateStep(PrintStep step, double progress) {
    state = state.copyWith(currentStep: step, progress: progress);
  }

  void showPaperDialog() {
    state = state.copyWith(showPaperDialog: true, currentStep: PrintStep.completed);
    _logTimer?.cancel();
  }

  void dismissPaperDialog() {
    state = state.copyWith(showPaperDialog: false);
  }

  void confirmPaperReady() {
    _jobCounter++;
    final title = state.selectedMode == PrintMode.scanAndPrint
        ? '扫描文档_第$_jobCounter份'
        : '打印文件_第$_jobCounter份';

    final record = BrailleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      sourceType: state.selectedMode == PrintMode.scanAndPrint ? '现场扫描' : '本地文件',
      dotMatrixWidth: state.selectedMode == PrintMode.scanAndPrint ? 40 : 0,
      dotMatrixHeight: state.selectedMode == PrintMode.scanAndPrint ? 30 : 0,
      dotMatrixData: [],
      createdAt: DateTime.now(),
      pageCount: 1,
    );
    _db.addRecord(record);

    state = state.copyWith(
      showPaperDialog: false,
      isWorking: false,
      isInitialized: false,
      isInitializing: false,
      currentStep: PrintStep.idle,
      progress: 0.0,
    );
  }

  void startInitialization() {
    state = state.copyWith(isInitializing: true);
  }

  void completeInitialization() {
    state = state.copyWith(isInitializing: false, isInitialized: true);
  }

  void cancelInitialization() {
    state = state.copyWith(isInitializing: false, isInitialized: false);
  }

  void _simulateSteps() {
    final steps = [
      (PrintStep.capturing, 0.15),
      (PrintStep.capturing, 0.30),
      (PrintStep.recognizing, 0.45),
      (PrintStep.converting, 0.60),
      (PrintStep.converting, 0.75),
      (PrintStep.printing, 0.85),
      (PrintStep.printing, 0.95),
    ];

    for (int i = 0; i < steps.length; i++) {
      Future.delayed(Duration(seconds: 2 + i * 2), () {
        if (mounted) {
          updateStep(steps[i].$1, steps[i].$2);
        }
      });
    }

    Future.delayed(const Duration(seconds: 16), () {
      if (mounted) showPaperDialog();
    });
  }

  void reset() {
    _logTimer?.cancel();
    _stepTimer?.cancel();
    _initTimer?.cancel();
    state = const HomeState();
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    _stepTimer?.cancel();
    _initTimer?.cancel();
    super.dispose();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) => HomeNotifier());
