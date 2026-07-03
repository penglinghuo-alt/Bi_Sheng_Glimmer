import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_enums.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/local_db/database_helper.dart';

// ════════════════════════════════════════════════════════
//  HomeState
// ════════════════════════════════════════════════════════
class HomeState {
  final PrintMode selectedMode;
  final PrintStep currentStep;
  final bool showPaperDialog;
  final double progress;
  final bool isInitializing;
  final bool isWorking;
  final List<String> logs;
  final bool showReadyDialog;

  const HomeState({
    this.selectedMode = PrintMode.scanAndPrint,
    this.currentStep = PrintStep.idle,
    this.showPaperDialog = false,
    this.progress = 0.0,
    this.isInitializing = false,
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
      isWorking: isWorking ?? this.isWorking,
      logs: logs ?? this.logs,
      showReadyDialog: showReadyDialog ?? this.showReadyDialog,
    );
  }
}

// ════════════════════════════════════════════════════════
//  LogEntry
// ════════════════════════════════════════════════════════
class _LogEntry {
  final String message;
  final int delayMs;
  final bool autoTimestamp;
  const _LogEntry(this.message, this.delayMs, {this.autoTimestamp = false});
}

// ════════════════════════════════════════════════════════
//  HomeNotifier
// ════════════════════════════════════════════════════════
class HomeNotifier extends StateNotifier<HomeState> {
  final DatabaseHelper _db = DatabaseHelper();
  final Random _rnd = Random();
  Timer? _timer;
  int _jobCounter = 0;
  int _totalPages = 0;
  int _currentPage = 0;

  // ── 日志辅助 ──────────────────────────────────────
  void _log(String msg) {
    state = state.copyWith(logs: [...state.logs, msg]);
  }

  String _ts() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
  }

  String _rndDec(double base, double spread) {
    return (base + (_rnd.nextDouble() - 0.5) * spread).toStringAsFixed(3);
  }

  void _playEntries(List<_LogEntry> entries, {void Function()? onDone}) {
    int delay = 0;
    for (final entry in entries) {
      delay += entry.delayMs;
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        if (entry.message.isNotEmpty) {
          final text = entry.autoTimestamp ? '[${_ts()}]${entry.message}' : entry.message;
          _log(text);
        }
      });
    }
    if (onDone != null) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) onDone();
      });
    }
  }

  // ════════════════════════════════════════════════════
  //  初始化阶段 (~19s, 实时时间戳)
  // ════════════════════════════════════════════════════
  List<_LogEntry> _buildInitLogs() {
    final y1Time = _rndDec(4.8, 0.4);
    final y2Wait = _rndDec(3.1, 0.3);
    final x1Time = _rndDec(4.8, 0.4);
    final x2Wait = _rndDec(3.1, 0.3);
    final yTotal = _rndDec(8.0, 0.8);
    final xTotal = _rndDec(8.0, 0.8);
    return [
      _LogEntry('[INFO][logger] 日志管理器初始化完成', 300, autoTimestamp: true),
      _LogEntry('[INFO][main] 系统启动中...', 300, autoTimestamp: true),
      _LogEntry('[INFO][main] 已启用 mock 串口模式', 300, autoTimestamp: true),
      _LogEntry('[INFO][init] 系统初始化开始：自动回零', 300, autoTimestamp: true),
      _LogEntry('[INFO][init] [MOTOR-HOME] 开始Y1/Y2同步回零，目标最小时长=${yTotal}s', 5000, autoTimestamp: true),
      _LogEntry('[INFO][init] [MOTOR-HOME] 回零实际执行${y1Time}s，小于配置${yTotal}s，补足等待${y2Wait}s', 3000, autoTimestamp: true),
      _LogEntry('[INFO][init] [MOTOR-HOME] 回零完成: axis=Y1 total=${yTotal}s', 300, autoTimestamp: true),
      _LogEntry('[INFO][init] [MOTOR-HOME] 回零完成: axis=Y2 total=${yTotal}s', 300, autoTimestamp: true),
      _LogEntry('[INFO][init] [MOTOR-HOME] 开始X轴回零，目标最小时长=${xTotal}s', 5000, autoTimestamp: true),
      _LogEntry('[INFO][init] [MOTOR-HOME] 回零实际执行${x1Time}s，小于配置${xTotal}s，补足等待${x2Wait}s', 3000, autoTimestamp: true),
      _LogEntry('[INFO][init] [MOTOR-HOME] 回零完成: axis=X total=${xTotal}s', 300, autoTimestamp: true),
      _LogEntry('[INFO][init] 系统初始化完成', 300, autoTimestamp: true),
      _LogEntry('[INFO][main] 系统初始化（回零）完成', 400, autoTimestamp: true),
      _LogEntry('--- 机器已准备完毕，等待打印任务 ---', 800),
    ];
  }

  // ════════════════════════════════════════════════════
  //  分页工作阶段 (每页约 6-7 分钟)
  // ════════════════════════════════════════════════════
  void _startPageCycle() {
    _currentPage++;
    if (_currentPage == 1) {
      _phasePaperDetect();
    } else {
      _phaseTurnPage();
    }
  }

  // ── 纸张检测 ──────────────────────────────────────
  void _phasePaperDetect() {
    final thickness = _rndDec(0.12, 0.03);
    state = state.copyWith(currentStep: PrintStep.turningPage);
    final entries = [
      _LogEntry('[INFO][scanner] 纸张传感器触发，检测到纸张', 800, autoTimestamp: true),
      _LogEntry('[INFO][scanner] 纸张厚度: ${thickness}mm, 材质: 盲文专用纸', 500, autoTimestamp: true),
    ];
    _playEntries(entries, onDone: () => _phaseTurnPage());
  }

  // ── 翻页 (~10s) ─────────────────────────────────
  void _phaseTurnPage() {
    state = state.copyWith(currentStep: PrintStep.turningPage);
    final turnTime = _rndDec(1.8, 0.4);
    final entries = [
      _LogEntry('[INFO][scanner] 开始翻页 (第 $_currentPage/$_totalPages 页)...', 2000, autoTimestamp: true),
      _LogEntry('[INFO][scanner] 翻页完成，步进电机到位，耗时 ${turnTime}s', 8000, autoTimestamp: true),
    ];
    _playEntries(entries, onDone: () => _phaseCapture());
  }

  // ── 拍摄 (~20s) ─────────────────────────────────
  void _phaseCapture() {
    state = state.copyWith(currentStep: PrintStep.capturing);
    final res = '${2000 + _rnd.nextInt(200)}x${1400 + _rnd.nextInt(200)}';
    final entries = [
      _LogEntry('[INFO][camera] 摄像头初始化...', 2000, autoTimestamp: true),
      _LogEntry('[INFO][camera] 正在拍摄第 $_currentPage 页图像...', 5000, autoTimestamp: true),
      _LogEntry('[INFO][camera] 图像采集完成，分辨率 $res, 300DPI', 2000, autoTimestamp: true),
      _LogEntry('[INFO][camera] 图像预处理：去噪、二值化、倾斜校正', 6000, autoTimestamp: true),
      _LogEntry('[INFO][camera] 预处理完成', 2000, autoTimestamp: true),
      _LogEntry('', 3000),
    ];
    _playEntries(entries, onDone: () => _phaseOCR());
  }

  // ── OCR (~50s) ──────────────────────────────────
  void _phaseOCR() {
    state = state.copyWith(currentStep: PrintStep.recognizing);
    final charCount = 200 + _rnd.nextInt(300);
    final regions = 10 + _rnd.nextInt(12);
    final entries = [
      _LogEntry('[INFO][ocr] 开始第 $_currentPage 页 OCR 文字识别...', 2000, autoTimestamp: true),
      _LogEntry('[INFO][ocr] 加载识别模型: chinese_ocr_v3.pth', 6000, autoTimestamp: true),
      _LogEntry('[INFO][ocr] 模型加载完成，推理引擎: ONNX Runtime', 2000, autoTimestamp: true),
      _LogEntry('[INFO][ocr] 文字区域检测中...', 5000, autoTimestamp: true),
      _LogEntry('[INFO][ocr] 检测到 $regions 个文字区域', 2000, autoTimestamp: true),
      _LogEntry('[INFO][ocr] 逐区域字符识别中...', 8000, autoTimestamp: true),
      _LogEntry('[INFO][ocr] 区域 1-${regions ~/ 3} 识别完成', 5000, autoTimestamp: true),
      _LogEntry('[INFO][ocr] 区域 ${regions ~/ 3 + 1}-${regions * 2 ~/ 3} 识别完成', 5000, autoTimestamp: true),
      _LogEntry('[INFO][ocr] 区域 ${regions * 2 ~/ 3 + 1}-$regions 识别完成', 4000, autoTimestamp: true),
      _LogEntry('[INFO][ocr] 第 $_currentPage 页 OCR 识别完成，共检测 $charCount 个字符', 3000, autoTimestamp: true),
      _LogEntry('', 8000),
    ];
    _playEntries(entries, onDone: () => _phaseConvert());
  }

  // ── 盲文转换 (~35s) ─────────────────────────────
  void _phaseConvert() {
    state = state.copyWith(currentStep: PrintStep.converting);
    final w = 40 + _rnd.nextInt(10);
    final h = 30 + _rnd.nextInt(5);
    final c1 = 40 + _rnd.nextInt(60);
    final c2 = 80 + _rnd.nextInt(60);
    final c3 = 100 + _rnd.nextInt(80);
    final entries = [
      _LogEntry('[INFO][converter] 开始盲文点阵转换 (第 $_currentPage 页)...', 2000, autoTimestamp: true),
      _LogEntry('[INFO][converter] 加载盲文对照表: braille_table_v2.json', 5000, autoTimestamp: true),
      _LogEntry('[INFO][converter] 文本分段处理中...', 3000, autoTimestamp: true),
      _LogEntry('[INFO][converter] 共 3 个段落，逐段转换', 2000, autoTimestamp: true),
      _LogEntry('[INFO][converter] 第 1 段落转换完成 ($c1 字符)', 5000, autoTimestamp: true),
      _LogEntry('[INFO][converter] 第 2 段落转换完成 ($c2 字符)', 5000, autoTimestamp: true),
      _LogEntry('[INFO][converter] 第 3 段落转换完成 ($c3 字符)', 5000, autoTimestamp: true),
      _LogEntry('[INFO][converter] 点阵映射完成: ${w}x$h', 3000, autoTimestamp: true),
      _LogEntry('[INFO][converter] 盲文转换完成，开始传输数据', 3000, autoTimestamp: true),
      _LogEntry('', 4000),
    ];
    _playEntries(entries, onDone: () => _phasePrint());
  }

  // ── 打印 (~200s = 3分20秒) ─────────────────────
  void _phasePrint() {
    state = state.copyWith(currentStep: PrintStep.printing);
    final totalRows = 25 + _rnd.nextInt(15);

    // 每批打印约 38s，5 批 + 首尾 ≈ 200s
    final batchMs = 36000 + _rnd.nextInt(8000);

    final entries = [
      _LogEntry('[INFO][printer] 打印头就绪，开始打印第 $_currentPage 页，总行数: $totalRows', 3000, autoTimestamp: true),
      _LogEntry('[INFO][printer] 打印行 1-${totalRows ~/ 5}', batchMs, autoTimestamp: true),
      _LogEntry('[INFO][printer] 打印行 ${totalRows ~/ 5 + 1}-${totalRows * 2 ~/ 5}', batchMs, autoTimestamp: true),
      _LogEntry('[INFO][printer] 打印行 ${totalRows * 2 ~/ 5 + 1}-${totalRows * 3 ~/ 5}', batchMs, autoTimestamp: true),
      _LogEntry('[INFO][printer] 打印行 ${totalRows * 3 ~/ 5 + 1}-${totalRows * 4 ~/ 5}', batchMs, autoTimestamp: true),
      _LogEntry('[INFO][printer] 打印行 ${totalRows * 4 ~/ 5 + 1}-$totalRows', batchMs, autoTimestamp: true),
      _LogEntry('[INFO][printer] 第 $_currentPage 页打印完成', 3000, autoTimestamp: true),
    ];
    _playEntries(entries, onDone: () {
      if (_currentPage >= _totalPages) {
        _phaseFinished();
      } else {
        _phasePaperAdvance();
      }
    });
  }

  // ── 纸张推进 (~20s) ─────────────────────────────
  void _phasePaperAdvance() {
    state = state.copyWith(currentStep: PrintStep.turningPage);
    final entries = [
      _LogEntry('[INFO][scanner] 纸张传送中...', 3000, autoTimestamp: true),
      _LogEntry('[INFO][scanner] 机械臂归位', 3000, autoTimestamp: true),
    ];
    _playEntries(entries, onDone: () {
      int delay = 8000 + _rnd.nextInt(12000);
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        _startPageCycle();
      });
    });
  }

  // ── 全部完成 ──────────────────────────────────────
  void _phaseFinished() {
    final entries = [
      _LogEntry('[INFO][scanner] 机械臂归位', 3000, autoTimestamp: true),
      _LogEntry('[INFO][main] --- 本次打印任务全部完成，共 $_totalPages 页 ---', 3000, autoTimestamp: true),
    ];
    _playEntries(entries, onDone: () {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) showPaperDialog();
      });
    });
  }

  // ════════════════════════════════════════════════════
  //  公开方法
  // ════════════════════════════════════════════════════
  HomeNotifier() : super(const HomeState());

  void setMode(PrintMode mode) {
    state = state.copyWith(selectedMode: mode);
  }

  void startWorking() {
    _totalPages = 3 + _rnd.nextInt(2);
    _currentPage = 0;
    _timer?.cancel();
    state = state.copyWith(isInitializing: true, showReadyDialog: false, logs: []);

    final initEntries = _buildInitLogs();
    final initTotalMs = initEntries.fold<int>(0, (sum, e) => sum + e.delayMs);
    _playEntries(initEntries);
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: initTotalMs), () {
      if (mounted) {
        state = state.copyWith(isInitializing: false, showReadyDialog: true);
      }
    });
  }

  void confirmReady() {
    state = state.copyWith(
      showReadyDialog: false,
      isWorking: true,
      currentStep: PrintStep.turningPage,
    );
    _startPageCycle();
  }

  void updateStep(PrintStep step, double progress) {
    state = state.copyWith(currentStep: step);
  }

  void showPaperDialog() {
    _timer?.cancel();
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
      pageCount: _totalPages,
    );
    _db.addRecord(record);
    _timer?.cancel();
    state = state.copyWith(
      showPaperDialog: false,
      isWorking: false,
      currentStep: PrintStep.idle,
      progress: 0.0,
    );
  }

  void reset() {
    _timer?.cancel();
    state = const HomeState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) => HomeNotifier());
