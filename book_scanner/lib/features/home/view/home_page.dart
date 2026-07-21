import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/providers/device_provider.dart';
import '../../../../shared/widgets/device_status_bar.dart';
import '../../../../data/local_db/database_helper.dart';
import '../../../../data/models/braille_record.dart';
import '../providers/home_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _logScrollCtrl = ScrollController();
  String? _lastBoardState;
  int _lastProgressCurrent = -1;
  int _lastProgressTotal = -1;

  @override
  void dispose() {
    _logScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeState = ref.watch(homeProvider);
    final deviceState = ref.watch(deviceProvider);

    final isConnected = deviceState.status == DeviceStatus.connected ||
        deviceState.status == DeviceStatus.initialized ||
        deviceState.status == DeviceStatus.working ||
        deviceState.status == DeviceStatus.printing ||
        deviceState.status == DeviceStatus.paused;

    final isBusy = deviceState.status == DeviceStatus.connecting ||
        deviceState.status == DeviceStatus.initializing;
    final isWorking = deviceState.status == DeviceStatus.working ||
        deviceState.status == DeviceStatus.printing;

    ref.listen(homeProvider.select((s) => s.logs.length), (_, __) {
      _scrollToBottom();
    });

    ref.listen(homeProvider.select((s) => s.showPaperDialog), (_, show) {
      if (show) _showPaperDialog();
    });

    ref.listen(deviceProvider, (prev, next) {
      if (prev == next) return;
      final notifier = ref.read(homeProvider.notifier);

      if (next.boardState != null && next.boardState != _lastBoardState) {
        _lastBoardState = next.boardState;
        notifier.onDeviceStateChanged(next.boardState!);
      }

      if (next.progressCurrent != _lastProgressCurrent ||
          next.progressTotal != _lastProgressTotal) {
        _lastProgressCurrent = next.progressCurrent;
        _lastProgressTotal = next.progressTotal;
        if (next.progressTotal > 0) {
          notifier.onProgressUpdate(next.progressCurrent, next.progressTotal);
        }
      }

      if (prev.motorX != next.motorX ||
          prev.motorY1 != next.motorY1 ||
          prev.motorY2 != next.motorY2) {
        if (next.motorX != 0 || next.motorY1 != 0 || next.motorY2 != 0) {
          notifier.onMotorPosition(
            next.motorX.toDouble(),
            next.motorY1.toDouble(),
            next.motorY2.toDouble(),
          );
        }
      }

      if (next.ocrText != null && next.ocrText != prev.ocrText) {
        notifier.onOcrResult(next.ocrText!, next.ocrTotalChars);
      }

      if (next.status == DeviceStatus.error &&
          prev.status != DeviceStatus.error) {
        notifier.onDeviceError('DEVICE', next.statusMessage);
      }

      if (next.currentStep == PrintStep.completed &&
          prev.currentStep != PrintStep.completed) {
        notifier.onPrintComplete();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('毕昇微光'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DeviceStatusBar(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _greeting(theme),
                const SizedBox(height: 24),
                _modeSelector(theme, homeState, isBusy || isWorking),
                if (homeState.selectedMode == PrintMode.localFile && !isBusy && !isWorking) ...[
                  const SizedBox(height: 16),
                  _filePicker(theme, homeState),
                ],
                const SizedBox(height: 24),
                if (isBusy) _busyIndicator(theme, deviceState),
                if (isConnected) ...[
                  const SizedBox(height: 12),
                  _deviceInfoCard(theme, deviceState),
                ],
                const SizedBox(height: 16),
                _actionArea(theme, homeState, deviceState, isConnected, isBusy, isWorking),
              ]),
            ),
          ),
          if (isWorking || deviceState.currentStep != PrintStep.idle)
            _logPanel(theme, homeState, isWorking),
        ]),
      ),
    );
  }

  Widget _greeting(ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('下午好', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      const SizedBox(height: 4),
      Text('今天想打印什么？', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _modeSelector(ThemeData theme, HomeState homeState, bool disabled) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(child: _modeTab(theme, homeState, '现场扫描', Icons.document_scanner_rounded, PrintMode.scanAndPrint, disabled)),
        Expanded(child: _modeTab(theme, homeState, '本地文件', Icons.folder_open_rounded, PrintMode.localFile, disabled)),
      ]),
    );
  }

  Widget _modeTab(ThemeData theme, HomeState state, String label, IconData icon, PrintMode mode, bool disabled) {
    final selected = state.selectedMode == mode;
    return Semantics(
      button: true, label: label,
      child: GestureDetector(
        onTap: disabled ? null : () => ref.read(homeProvider.notifier).setMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: selected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: selected ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      ),
    );
  }

  Widget _filePicker(ThemeData theme, HomeState homeState) {
    final selected = homeState.selectedRecord;
    if (selected != null) {
      return _selectedFileCard(theme, selected);
    }
    final records = DatabaseHelper().getRecords(orderByDate: true);
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(Icons.inbox_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 12),
          Text('存储库中暂无文件', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('选择存储库文件', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ),
        ...records.map((r) {
          final timeStr = '${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.day.toString().padLeft(2, '0')} '
              '${r.createdAt.hour.toString().padLeft(2, '0')}:${r.createdAt.minute.toString().padLeft(2, '0')}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => ref.read(homeProvider.notifier).selectRecord(r),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Icon(r.sourceType == '现场扫描' ? Icons.document_scanner_rounded : Icons.description_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('$timeStr · ${r.pageCount}面 · ${r.sourceType}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }),
      ]),
    );
  }

  Widget _selectedFileCard(ThemeData theme, BrailleRecord record) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.description_rounded, color: theme.colorScheme.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(record.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${record.pageCount}面 · ${record.sourceType}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18),
          onPressed: () => ref.read(homeProvider.notifier).selectRecord(null),
        ),
      ]),
    );
  }

  Widget _busyIndicator(ThemeData theme, DeviceState deviceState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        SizedBox(
          width: 28, height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary)),
        ),
        const SizedBox(height: 16),
        Text(deviceState.statusMessage, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _deviceInfoCard(ThemeData theme, DeviceState d) {
    final items = <Widget>[];

    if (d.boardState != null && d.boardState!.isNotEmpty) {
      items.add(_infoRow(theme, '板子状态', d.boardState!, Icons.memory_rounded));
    }
    if (d.progressTotal > 0) {
      items.add(_infoRow(theme, '打印进度', '${d.progressCurrent}/${d.progressTotal} (${(d.progressPercentage * 100).toStringAsFixed(0)}%)', Icons.speed_rounded));
      items.add(const SizedBox(height: 4));
      items.add(ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: d.progressPercentage,
          minHeight: 6,
        ),
      ));
    }
    if (d.motorX != 0 || d.motorY1 != 0 || d.motorY2 != 0) {
      items.add(const SizedBox(height: 8));
      items.add(_infoRow(theme, '电机位置', 'X:${d.motorX}  Y1:${d.motorY1}  Y2:${d.motorY2}', Icons.settings_rounded));
    }
    if (d.ocrText != null && d.ocrText!.isNotEmpty) {
      items.add(const SizedBox(height: 8));
      items.add(_infoRow(theme, 'OCR 识别', '${d.ocrTotalChars} 字符', Icons.text_fields_rounded));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('设备状态', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 10),
          ...items,
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _actionArea(ThemeData theme, HomeState homeState, DeviceState deviceState,
      bool isConnected, bool isBusy, bool isWorking) {
    final canStart = (homeState.selectedMode == PrintMode.scanAndPrint || homeState.selectedRecord != null) && isConnected;

    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: canStart
              ? () {
                  ref.read(homeProvider.notifier).startWorking();
                  ref.read(deviceProvider.notifier).startPrintJob();
                }
              : null,
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: Text(isWorking ? '工作中...' : '开始工作', style: const TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      if (isWorking) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => ref.read(deviceProvider.notifier).emergencyStop(),
          icon: const Icon(Icons.stop_rounded, size: 18, color: Colors.red),
          label: const Text('紧急停止', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    ]);
  }

  void _scrollToBottom() {
    if (_logScrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logScrollCtrl.animateTo(
          _logScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Widget _logPanel(ThemeData theme, HomeState state, bool isWorking) {
    final logs = state.logs;
    if (logs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border(top: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.black26,
          child: Row(children: [
            const Icon(Icons.terminal_rounded, size: 14, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Text('系统日志', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
            const Spacer(),
            if (isWorking) ...[
              SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent))),
            ] else ...[
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
            ],
          ]),
        ),
        Expanded(
          child: ListView.builder(
            controller: _logScrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: logs.length,
            itemBuilder: (_, i) {
              final log = logs[i];
              final isHeader = log.startsWith('---') && log.endsWith('---');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  log,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isHeader ? Colors.yellowAccent : Colors.greenAccent.withValues(alpha: 0.75),
                    fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showPaperDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(homeProvider.notifier).dismissPaperDialog();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.note_add_rounded, color: AppColors.primary, size: 32),
          ),
          title: const Text('打印完成', style: TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          content: const Text('当前任务已完成\n已保存至存储库', textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(homeProvider.notifier).confirmPaperReady();
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('确定'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
