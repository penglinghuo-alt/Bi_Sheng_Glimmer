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

class _LogEntry {
  final String message;
  final int delayMs;
  const _LogEntry(this.message, this.delayMs);
}

class HomeNotifier extends StateNotifier<HomeState> {
  final DatabaseHelper _db = DatabaseHelper();
  Timer? _logTimer;
  int _jobCounter = 0;

  // 初始化日志 — 延迟根据实际时间戳差值计算
  // 同日戳 15s→15s: 300ms
  // 15s→20s 实际5s: 2500ms (Y 归零总耗时 8s, 超过 5s 砍半)
  // 20s→23s 实际3s: 1500ms
  // 23s→28s 实际5s: 2500ms (X 归零总耗时 8s, 超过 5s 砍半)
  // 28s→31s 实际3s: 1500ms
  static const _initLogs = [
    _LogEntry('[2026-07-03 19:46:15][INFO][logger] 日志管理器初始化完成', 300),
    _LogEntry('[2026-07-03 19:46:15][INFO][main] 系统启动中...', 300),
    _LogEntry('[2026-07-03 19:46:15][INFO][main] 已启用 mock 串口模式', 300),
    _LogEntry('[2026-07-03 19:46:15][INFO][init] 系统初始化开始：自动回零', 300),
    _LogEntry('[2026-07-03 19:46:15][INFO][init] [MOTOR-HOME] 开始Y1/Y2同步回零，目标最小时长=8.0s', 2500),
    _LogEntry('[2026-07-03 19:46:20][INFO][init] [MOTOR-HOME] 回零实际执行4.891s，补足等待3.109s', 1500),
    _LogEntry('[2026-07-03 19:46:23][INFO][init] [MOTOR-HOME] 回零完成: axis=Y1 total=8.000s', 300),
    _LogEntry('[2026-07-03 19:46:23][INFO][init] [MOTOR-HOME] 回零完成: axis=Y2 total=8.000s', 300),
    _LogEntry('[2026-07-03 19:46:23][INFO][init] [MOTOR-HOME] 开始X轴回零，目标最小时长=8.0s', 2500),
    _LogEntry('[2026-07-03 19:46:28][INFO][init] [MOTOR-HOME] 回零实际执行4.897s，补足等待3.103s', 1500),
    _LogEntry('[2026-07-03 19:46:31][INFO][init] [MOTOR-HOME] 回零完成: axis=X total=8.000s', 300),
    _LogEntry('[2026-07-03 19:46:31][INFO][init] 系统初始化完成', 300),
    _LogEntry('[2026-07-03 19:46:31][INFO][main] 系统初始化（回零）完成', 400),
    _LogEntry('--- 机器已准备完毕，等待打印任务 ---', 800),
  ];

  // 工作日志 — 延迟根据实际流程耗时砍半
  static const _workLogs = [
    _LogEntry('[19:46:35][INFO][scanner] 纸张传感器触发，检测到纸张', 600),
    _LogEntry('[19:46:36][INFO][scanner] 纸张厚度: 0.12mm, 材质: 盲文专用纸', 400),
    _LogEntry('[19:46:37][INFO][scanner] 开始翻页...', 1000),
    _LogEntry('[19:46:38][INFO][scanner] 翻页完成，步进电机到位', 600),
    _LogEntry('[19:46:38][INFO][camera] 摄像头初始化...', 400),
    _LogEntry('[19:46:39][INFO][camera] 正在拍摄图像...', 1200),
    _LogEntry('[19:46:40][INFO][camera] 图像采集完成，分辨率 2048x1536, 300DPI', 600),
    _LogEntry('[19:46:41][INFO][camera] 图像预处理：去噪、二值化、倾斜校正', 1200),
    _LogEntry('[19:46:42][INFO][camera] 预处理完成', 400),
    _LogEntry('', 1500),
    _LogEntry('[19:46:43][INFO][ocr] 开始 OCR 文字识别...', 500),
    _LogEntry('[19:46:44][INFO][ocr] 加载识别模型: chinese_ocr_v3.pth', 1000),
    _LogEntry('[19:46:45][INFO][ocr] 模型加载完成，推理引擎: ONNX Runtime', 400),
    _LogEntry('[19:46:45][INFO][ocr] 文字区域检测中...', 1000),
    _LogEntry('[19:46:46][INFO][ocr] 检测到 12 个文字区域', 400),
    _LogEntry('[19:46:46][INFO][ocr] 逐区域字符识别中...', 1500),
    _LogEntry('[19:46:48][INFO][ocr] 区域 1-4 识别完成 (进度: 33%)', 1000),
    _LogEntry('[19:46:49][INFO][ocr] 区域 5-8 识别完成 (进度: 67%)', 1000),
    _LogEntry('[19:46:50][INFO][ocr] 区域 9-12 识别完成 (进度: 100%)', 600),
    _LogEntry('[19:46:50][INFO][ocr] OCR 识别完成，共检测 248 个字符', 600),
    _LogEntry('[19:46:50][INFO][ocr] 识别置信度: 97.3%', 400),
    _LogEntry('', 2000),
    _LogEntry('[19:46:52][INFO][converter] 开始盲文点阵转换...', 500),
    _LogEntry('[19:46:52][INFO][converter] 加载盲文对照表: braille_table_v2.json', 1000),
    _LogEntry('[19:46:53][INFO][converter] 文本分段处理中...', 500),
    _LogEntry('[19:46:53][INFO][converter] 共 3 个段落，逐段转换', 300),
    _LogEntry('[19:46:54][INFO][converter] 第 1 段转换完成 (40 字符)', 1000),
    _LogEntry('[19:46:55][INFO][converter] 第 2 段转换完成 (82 字符)', 1000),
    _LogEntry('[19:46:56][INFO][converter] 第 3 段转换完成 (126 字符)', 1000),
    _LogEntry('[19:46:57][INFO][converter] 点阵映射完成: 40x30', 500),
    _LogEntry('[19:46:57][INFO][converter] 盲文转换完成，开始传输数据', 800),
    _LogEntry('', 1500),
    _LogEntry('[19:46:58][INFO][printer] 打印头预热中...', 500),
    _LogEntry('[19:46:59][INFO][printer] 打印头温度: 45°C / 目标 80°C', 1000),
    _LogEntry('[19:47:00][INFO][printer] 打印头温度: 62°C / 目标 80°C', 1000),
    _LogEntry('[19:47:01][INFO][printer] 打印头温度: 78°C，预热完成', 800),
    _LogEntry('[19:47:01][INFO][printer] 开始打印，总行数: 30', 500),
    _LogEntry('[19:47:02][INFO][printer] 打印行 1-5 (进度: 17%)', 800),
    _LogEntry('[19:47:03][INFO][printer] 打印行 6-10 (进度: 33%)', 800),
    _LogEntry('[19:47:04][INFO][printer] 打印行 11-15 (进度: 50%)', 800),
    _LogEntry('[19:47:05][INFO][printer] 打印行 16-20 (进度: 67%)', 800),
    _LogEntry('[19:47:05][INFO][printer] 打印行 21-25 (进度: 83%)', 800),
    _LogEntry('[19:47:06][INFO][printer] 打印行 26-30 (进度: 100%)', 800),
    _LogEntry('[19:47:07][INFO][printer] 打印完成', 600),
    _LogEntry('[19:47:07][INFO][scanner] 纸张传送中...', 1000),
    _LogEntry('[19:47:08][INFO][scanner] 机械臂归位', 800),
    _LogEntry('[19:47:09][INFO][main] --- 打印任务全部完成 ---', 600),
  ];

  HomeNotifier() : super(const HomeState());

  void setMode(PrintMode mode) {
    state = state.copyWith(selectedMode: mode);
  }

  void startWorking() {
    state = state.copyWith(isInitializing: true, showReadyDialog: false, logs: []);

    _playInitLogs();

    final initTotalMs = _initLogs.fold<int>(0, (sum, e) => sum + e.delayMs);
    _logTimer?.cancel();
    _logTimer = Timer(Duration(milliseconds: initTotalMs), () {
      if (mounted) {
        state = state.copyWith(isInitializing: false, showReadyDialog: true);
      }
    });
  }

  void _playInitLogs() {
    int delay = 0;
    for (final entry in _initLogs) {
      delay += entry.delayMs;
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted && entry.message.isNotEmpty) {
          state = state.copyWith(logs: [...state.logs, entry.message]);
        }
      });
    }
  }

  void confirmReady() {
    state = state.copyWith(
      showReadyDialog: false,
      isInitialized: true,
      isWorking: true,
      currentStep: PrintStep.idle,
      progress: 0.0,
    );
    _playWorkLogs();
  }

  void _playWorkLogs() {
    int delay = 0;
    for (final entry in _workLogs) {
      delay += entry.delayMs;
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        if (entry.message.isNotEmpty) {
          state = state.copyWith(logs: [...state.logs, entry.message]);
        }
        switch (entry.message) {
          case '正在拍摄图像...':
            updateStep(PrintStep.capturing, 0.12);
          case '图像采集完成，分辨率 2048x1536, 300DPI':
            updateStep(PrintStep.capturing, 0.20);
          case '开始 OCR 文字识别...':
            updateStep(PrintStep.recognizing, 0.32);
          case 'OCR 识别完成，共检测 248 个字符':
            updateStep(PrintStep.recognizing, 0.50);
          case '开始盲文点阵转换...':
            updateStep(PrintStep.converting, 0.58);
          case '点阵映射完成: 40x30':
            updateStep(PrintStep.converting, 0.72);
          case '打印头预热中...':
            updateStep(PrintStep.printing, 0.77);
          case '打印行 11-15 (进度: 50%)':
            updateStep(PrintStep.printing, 0.87);
          case '打印完成':
            updateStep(PrintStep.printing, 0.96);
        }
      });
    }

    final totalWorkMs = _workLogs.fold<int>(0, (sum, e) => sum + e.delayMs) + 1000;
    Future.delayed(Duration(milliseconds: totalWorkMs), () {
      if (mounted) showPaperDialog();
    });
  }

  void startPrintJob() {
    state = state.copyWith(currentStep: PrintStep.capturing, progress: 0.0);
  }

  void updateStep(PrintStep step, double progress) {
    state = state.copyWith(currentStep: step, progress: progress);
  }

  void showPaperDialog() {
    state = state.copyWith(showPaperDialog: true, currentStep: PrintStep.completed, progress: 1.0);
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

    _logTimer?.cancel();
    state = state.copyWith(
      showPaperDialog: false,
      isWorking: false,
      isInitialized: false,
      isInitializing: false,
      currentStep: PrintStep.idle,
      progress: 0.0,
    );
  }

  void reset() {
    _logTimer?.cancel();
    state = const HomeState();
  }

  @override
  void dispose() {
    _logTimer?.cancel();
    super.dispose();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) => HomeNotifier());
