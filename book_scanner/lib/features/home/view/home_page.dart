import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/providers/device_provider.dart';
import '../../../../shared/widgets/device_status_bar.dart';
import '../providers/home_provider.dart';
import '../widgets/print_progress.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final homeState = ref.watch(homeProvider);
    final deviceState = ref.watch(deviceProvider);
    final isInitializing = homeState.isInitializing;
    final isWorking = homeState.isWorking;

    ref.listen(homeProvider.select((s) => s.showReadyDialog), (_, show) {
      if (show) _showReadyDialog();
    });

    ref.listen(homeProvider.select((s) => s.showPaperDialog), (_, show) {
      if (show) _showPaperDialog();
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
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _greeting(theme),
                const SizedBox(height: 24),
                _modeSelector(theme, homeState, isWorking || isInitializing),
                const SizedBox(height: 24),
                if (isInitializing) _initLoadingCard(theme),
                if (isWorking || homeState.currentStep != PrintStep.idle) ...[
                  _workingArea(theme, homeState),
                  const SizedBox(height: 24),
                ],
                if (!isInitializing) _actionArea(theme, homeState),
                const SizedBox(height: 32),
              ]),
            ),
          ),
          if (isWorking || homeState.currentStep != PrintStep.idle)
            _logPanel(theme, homeState),
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

  Widget _initLoadingCard(ThemeData theme) {
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
        Text('正在准备机器...', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('扫描头校准、纸张检测、机械臂归零', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      ]),
    );
  }

  Widget _workingArea(ThemeData theme, HomeState state) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('打印进度', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      PrintProgressWidget(step: state.currentStep, progress: state.progress),
    ]);
  }

  Widget _actionArea(ThemeData theme, HomeState homeState) {
    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => ref.read(homeProvider.notifier).startWorking(),
          icon: const Icon(Icons.play_arrow_rounded, size: 20),
          label: const Text('开始工作', style: TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }

  Widget _logPanel(ThemeData theme, HomeState state) {
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
            if (state.isWorking) ...[
              SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent))),
            ] else ...[
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
            ],
          ]),
        ),
        Expanded(
          child: ListView.builder(
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

  void _showReadyDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
            child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 36),
          ),
          title: const Text('机器已准备完毕', style: TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          content: const Text('设备初始化完成\n请放入纸张后点击确定开始打印', textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(homeProvider.notifier).confirmReady();
                  ref.read(deviceProvider.notifier).startPrintJob();
                },
                icon: const Icon(Icons.print_rounded),
                label: const Text('确定开始打印'),
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
