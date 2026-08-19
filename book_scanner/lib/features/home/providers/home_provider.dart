import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/constants/hardware_config.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/local_db/database_helper.dart';

class HomeState {
  final PrintMode selectedMode;
  final PrintStep currentStep;
  final bool showPaperDialog;
  final double progress;
  final List<String> logs;
  final BrailleRecord? selectedRecord;
  final Set<int> litDots;
  final double paperUsedRatio;

  const HomeState({
    this.selectedMode = PrintMode.scanAndPrint,
    this.currentStep = PrintStep.idle,
    this.showPaperDialog = false,
    this.progress = 0.0,
    this.logs = const [],
    this.selectedRecord,
    this.litDots = const {},
    this.paperUsedRatio = 0.0,
  });

  HomeState copyWith({
    PrintMode? selectedMode,
    PrintStep? currentStep,
    bool? showPaperDialog,
    double? progress,
    List<String>? logs,
    BrailleRecord? selectedRecord,
    Set<int>? litDots,
    double? paperUsedRatio,
  }) {
    return HomeState(
      selectedMode: selectedMode ?? this.selectedMode,
      currentStep: currentStep ?? this.currentStep,
      showPaperDialog: showPaperDialog ?? this.showPaperDialog,
      progress: progress ?? this.progress,
      logs: logs ?? this.logs,
      selectedRecord: selectedRecord ?? this.selectedRecord,
      litDots: litDots ?? this.litDots,
      paperUsedRatio: paperUsedRatio ?? this.paperUsedRatio,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final DatabaseHelper _db = DatabaseHelper();
  int _jobCounter = 0;
  int _pageCount = 0;
  String _accumulatedOcr = '';
  String? _lastSavedRecordId;
  double _maxPaperRatio = 0.0;
  bool _paperWarningLogged = false;

  HomeNotifier() : super(const HomeState());

  void _log(String msg) {
    final ts = DateTime.now();
    final t = '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}';
    state = state.copyWith(logs: [...state.logs, '[$t] $msg']);
  }

  Future<String?> _saveRecord(BrailleRecord record) async {
    final serverId = await _db.saveToBackend(record);
    if (serverId != null) {
      _log('已上传至腾讯云 (ID: $serverId)');
      _db.addRecord(record.copyWith(id: serverId));
      _lastSavedRecordId = serverId;
      if (_accumulatedOcr.isNotEmpty && _accumulatedOcr != record.textContent) {
        _db.updateRecordText(serverId, _accumulatedOcr);
      }
      return serverId;
    }
    _log('云端同步失败，记录仅保存在本地');
    _db.addRecord(record);
    _lastSavedRecordId = record.id;
    if (_accumulatedOcr.isNotEmpty && _accumulatedOcr != record.textContent) {
      _db.updateRecordText(record.id, _accumulatedOcr);
    }
    return record.id;
  }

  void setMode(PrintMode mode) {
    state = state.copyWith(selectedMode: mode, selectedRecord: null);
  }

  void selectRecord(BrailleRecord? record) {
    state = state.copyWith(selectedRecord: record);
  }

  void startWorking() {
    state = state.copyWith(logs: [], currentStep: PrintStep.idle, progress: 0.0);
    _pageCount = 0;
    _accumulatedOcr = '';
    _lastSavedRecordId = null;
    _maxPaperRatio = 0.0;
    _paperWarningLogged = false;
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
        _pageCount++;
        _log('第 $_pageCount 页打印完成');
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

    final maxY = HardwareConfig.motorMaxYPulse.toDouble();
    if (maxY <= 0) return;

    // 纸张使用比例: 以竖向推进为准
    final yAvg = (y1 + y2) / 2;
    final ratio = (yAvg / maxY).clamp(0.0, 1.0);
    if (ratio > _maxPaperRatio) _maxPaperRatio = ratio;

    state = state.copyWith(
      paperUsedRatio: _maxPaperRatio,
    );

    // 接近底部提示快换纸 (一次只提示一次)
    if (_maxPaperRatio >= 0.85 && !_paperWarningLogged) {
      _paperWarningLogged = true;
      _log('注意: 盲文纸已使用 ${(_maxPaperRatio * 100).toStringAsFixed(0)}%，请准备更换新纸');
    }
  }

  void onOcrResult(String text, int totalChars) {
    if (text.trim().isEmpty) return;
    if (_accumulatedOcr.isNotEmpty) {
      _accumulatedOcr += '\n';
    }
    _accumulatedOcr += text;
    _log('OCR 识别完成: $totalChars 字符 (累计 ${_accumulatedOcr.length} 字符)');

    // 若打印已完成但 OCR 结果晚到，回写最近一次已保存记录，确保文字不丢
    final savedId = _lastSavedRecordId;
    if (savedId != null) {
      _db.updateRecordText(savedId, _accumulatedOcr);
    }
  }

  void onDeviceError(String code, String msg) {
    _log('设备错误 [$code]: $msg');
  }

  void clearLogs() {
    state = state.copyWith(logs: []);
  }

  void onPrintComplete({bool stopped = false}) {
    _jobCounter++;
    if (state.selectedMode == PrintMode.scanAndPrint) {
      final record = BrailleRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '扫描文档_第$_jobCounter份',
        sourceType: '现场扫描',
        dotMatrixWidth: 40,
        dotMatrixHeight: 30,
        dotMatrixData: [],
        createdAt: DateTime.now(),
        pageCount: _pageCount > 0 ? _pageCount : 1,
        textContent: _accumulatedOcr.isNotEmpty ? _accumulatedOcr : null,
      );
      _lastSavedRecordId = record.id;
      _saveRecord(record);
    }
    if (stopped) {
      _log('打印已紧急停止，共 $_pageCount 页');
    } else {
      _log('打印任务完成，共 $_pageCount 页');
    }
    state = state.copyWith(
      showPaperDialog: true,
      currentStep: stopped ? PrintStep.stopped : PrintStep.completed,
      progress: 1.0,
    );
  }

  /// 打印完成对话框点"确定"后调用，自动退出本次任务
  void confirmPrintDone() {
    _autoExit();
  }

  void _autoExit() {
    _accumulatedOcr = '';
    _lastSavedRecordId = null;
    _pageCount = 0;
    _maxPaperRatio = 0.0;
    _paperWarningLogged = false;
    state = state.copyWith(
      showPaperDialog: false,
      currentStep: PrintStep.idle,
      progress: 0.0,
      litDots: const {},
      paperUsedRatio: 0.0,
    );
  }

  void reset() {
    _accumulatedOcr = '';
    _lastSavedRecordId = null;
    _maxPaperRatio = 0.0;
    _paperWarningLogged = false;
    state = const HomeState();
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) => HomeNotifier());
