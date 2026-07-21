import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_enums.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/local_db/database_helper.dart';

class HomeState {
  final PrintMode selectedMode;
  final PrintStep currentStep;
  final bool showPaperDialog;
  final double progress;
  final List<String> logs;
  final BrailleRecord? selectedRecord;

  const HomeState({
    this.selectedMode = PrintMode.scanAndPrint,
    this.currentStep = PrintStep.idle,
    this.showPaperDialog = false,
    this.progress = 0.0,
    this.logs = const [],
    this.selectedRecord,
  });

  HomeState copyWith({
    PrintMode? selectedMode,
    PrintStep? currentStep,
    bool? showPaperDialog,
    double? progress,
    List<String>? logs,
    BrailleRecord? selectedRecord,
  }) {
    return HomeState(
      selectedMode: selectedMode ?? this.selectedMode,
      currentStep: currentStep ?? this.currentStep,
      showPaperDialog: showPaperDialog ?? this.showPaperDialog,
      progress: progress ?? this.progress,
      logs: logs ?? this.logs,
      selectedRecord: selectedRecord ?? this.selectedRecord,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final DatabaseHelper _db = DatabaseHelper();
  int _jobCounter = 0;
  int _totalPages = 0;

  HomeNotifier() : super(const HomeState());

  void _log(String msg) {
    final ts = DateTime.now();
    final t = '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}';
    state = state.copyWith(logs: [...state.logs, '[$t] $msg']);
  }

  void setMode(PrintMode mode) {
    state = state.copyWith(selectedMode: mode, selectedRecord: null);
  }

  void selectRecord(BrailleRecord? record) {
    state = state.copyWith(selectedRecord: record);
  }

  void startWorking() {
    state = state.copyWith(logs: [], currentStep: PrintStep.idle, progress: 0.0);
    _log('等待设备就绪...');
  }

  void onDeviceStateChanged(String boardState) {
    switch (boardState) {
      case 'PRINTING':
        state = state.copyWith(currentStep: PrintStep.printing);
        _log('设备进入打印模式');
      case 'IDLE':
        if (state.currentStep != PrintStep.idle) {
          state = state.copyWith(currentStep: PrintStep.idle, progress: 1.0);
          _log('设备进入空闲状态');
        }
      case 'ERROR':
        _log('设备报错');
      case 'PAGE_COMPLETE':
        _log('当前页面打印完成');
      default:
    }
  }

  void onProgressUpdate(int current, int total) {
    if (total > 0) {
      final pct = current / total;
      state = state.copyWith(progress: pct);
      _log('打印进度: $current/$total (${(pct * 100).toStringAsFixed(0)}%)');
    }
  }

  void onMotorPosition(double x, double y1, double y2) {
    _log('电机位置 - X: ${x.toStringAsFixed(0)}, Y1: ${y1.toStringAsFixed(0)}, Y2: ${y2.toStringAsFixed(0)}');
  }

  void onOcrResult(String text, int totalChars) {
    _log('OCR 识别完成: $totalChars 字符');
  }

  void onDeviceError(String code, String msg) {
    _log('设备错误 [$code]: $msg');
  }

  void onPrintComplete() {
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
    state = state.copyWith(showPaperDialog: true, currentStep: PrintStep.completed, progress: 1.0);
    _log('打印任务完成');
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
      pageCount: _totalPages,
    );
    _db.addRecord(record);
    state = state.copyWith(
      showPaperDialog: false,
      currentStep: PrintStep.idle,
      progress: 0.0,
    );
  }

  void reset() {
    state = const HomeState();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) => HomeNotifier());
