import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_enums.dart';
import '../../../../core/providers/device_provider.dart';
import '../../../../shared/widgets/device_status_bar.dart';
import '../../../../shared/widgets/custom_dialog.dart';
import '../providers/home_provider.dart';
import '../widgets/print_progress.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final homeState = ref.watch(homeProvider);
    final deviceState = ref.watch(deviceProvider);
    final isWorking = deviceState.status == DeviceStatus.working || deviceState.status == DeviceStatus.printing;
    final isInitializing = deviceState.status == DeviceStatus.initializing || homeState.isInitializing;

    if (homeState.showPaperDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPaperDialog(context, ref);
      });
    }

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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _greeting(theme),
            const SizedBox(height: 24),
            _modeSelector(theme, ref, homeState, isWorking || isInitializing),
            const SizedBox(height: 24),
            if (isWorking || homeState.currentStep != PrintStep.idle) ...[
              _workingArea(theme, ref, homeState),
              const SizedBox(height: 24),
            ],
            _actionArea(theme, ref, homeState, deviceState, context),
            const SizedBox(height: 32),
          ]),
        ),
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

  Widget _modeSelector(ThemeData theme, WidgetRef ref, HomeState homeState, bool disabled) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Expanded(child: _modeTab(theme, ref, homeState, '现场扫描', Icons.document_scanner_rounded, PrintMode.scanAndPrint, disabled)),
        Expanded(child: _modeTab(theme, ref, homeState, '本地文件', Icons.folder_open_rounded, PrintMode.localFile, disabled)),
      ]),
    );
  }

  Widget _modeTab(ThemeData theme, WidgetRef ref, HomeState state, String label, IconData icon, PrintMode mode, bool disabled) {
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

  Widget _workingArea(ThemeData theme, WidgetRef ref, HomeState state) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('打印进度', style: theme.textTheme.titleMedium),
      const SizedBox(height: 12),
      PrintProgressWidget(step: state.currentStep, progress: state.progress),
    ]);
  }

  Widget _actionArea(ThemeData theme, WidgetRef ref, HomeState homeState, DeviceState deviceState, BuildContext context) {
    final isWorking = deviceState.status == DeviceStatus.working || deviceState.status == DeviceStatus.printing;
    final isInitializing = deviceState.status == DeviceStatus.initializing || homeState.isInitializing;
    final isInitialized = deviceState.status == DeviceStatus.initialized || homeState.isInitialized;
    final isConnected = deviceState.status == DeviceStatus.connected;
    final isDisconnected = deviceState.status == DeviceStatus.disconnected;

    if (isInitializing) {
      return _initProgressCard(theme);
    }

    if (isInitialized && !isWorking) {
      return _readyCard(theme, ref, homeState, context);
    }

    return Column(children: [
      if (!isWorking && !isInitialized) ...[
        _initButton(theme, ref, deviceState, isConnected, isDisconnected, context),
        const SizedBox(height: 16),
        _startButton(theme, ref, homeState, deviceState, isConnected, isInitialized, context),
      ],
      if (isWorking) ...[
        _workingCard(theme, ref, context),
      ],
    ]);
  }

  Widget _initButton(ThemeData theme, WidgetRef ref, DeviceState deviceState, bool isConnected, bool isDisconnected, BuildContext context) {
    return Semantics(
      button: true, label: '设备初始化',
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isDisconnected
              ? null
              : () async {
                  ref.read(homeProvider.notifier).startInitialization();
                  try {
                    await ref.read(deviceProvider.notifier).initialize();
                    ref.read(homeProvider.notifier).completeInitialization();
                  } catch (e) {
                    ref.read(homeProvider.notifier).cancelInitialization();
                    if (context.mounted) {
                      CustomDialog.showInfo(context: context, title: '初始化失败', message: '请检查设备连接后重试');
                    }
                  }
                },
          icon: const Icon(Icons.memory_rounded, size: 20),
          label: const Text('设备初始化', style: TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _initProgressCard(ThemeData theme) {
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
        Text('正在初始化设备...', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('正在进行扫描头校准、纸张检测、机械臂归零', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
      ]),
    );
  }

  Widget _startButton(ThemeData theme, WidgetRef ref, HomeState homeState, DeviceState deviceState, bool isConnected, bool isInitialized, BuildContext context) {
    final label = homeState.selectedMode == PrintMode.scanAndPrint ? '开始扫描打印' : '选择文件打印';
    final icon = homeState.selectedMode == PrintMode.scanAndPrint ? Icons.play_arrow_rounded : Icons.folder_open_rounded;

    return Semantics(
      button: true, label: label,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: (!isConnected && !isInitialized) ? null : () {
            if (deviceState.status == DeviceStatus.disconnected) {
              CustomDialog.showInfo(context: context, title: '设备未连接', message: '请先在「我的 -> 设备管理」中连接硬件设备');
              return;
            }
            ref.read(homeProvider.notifier).startPrintJob();
            ref.read(deviceProvider.notifier).startPrintJob();
            _simulateSteps(ref);
          },
          icon: Icon(icon, size: 20),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _readyCard(ThemeData theme, WidgetRef ref, HomeState homeState, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Semantics(label: '设备就绪', child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 28),
        )),
        const SizedBox(height: 14),
        Text('设备已就绪', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
        const SizedBox(height: 4),
        Text('设备初始化完成，可以开始打印', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: Semantics(
              button: true, label: '取消',
              child: OutlinedButton(
                onPressed: () {
                  ref.read(homeProvider.notifier).cancelInitialization();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('取消'),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Semantics(
              button: true, label: '确定开始打印',
              child: FilledButton.icon(
                onPressed: () {
                  ref.read(homeProvider.notifier).startPrintJob();
                  ref.read(deviceProvider.notifier).startPrintJob();
                  _simulateSteps(ref);
                },
                icon: const Icon(Icons.print_rounded, size: 20),
                label: const Text('确定开始打印', style: TextStyle(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _workingCard(ThemeData theme, WidgetRef ref, BuildContext context) {
    return Semantics(
      button: true, label: '终止打印',
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () async {
            final confirm = await CustomDialog.showConfirm(context: context, title: '确认终止', message: '确定要立即终止所有操作吗？', confirmText: '终止');
            if (confirm == true) {
              ref.read(homeProvider.notifier).reset();
              ref.read(deviceProvider.notifier).emergencyStop();
            }
          },
          icon: const Icon(Icons.stop_rounded),
          label: const Text('终止打印', style: TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  void _simulateSteps(WidgetRef ref) {
    Future.delayed(const Duration(seconds: 2), () => ref.read(homeProvider.notifier).updateStep(PrintStep.capturing, 0.2));
    Future.delayed(const Duration(seconds: 4), () => ref.read(homeProvider.notifier).updateStep(PrintStep.recognizing, 0.4));
    Future.delayed(const Duration(seconds: 6), () => ref.read(homeProvider.notifier).updateStep(PrintStep.converting, 0.6));
    Future.delayed(const Duration(seconds: 8), () => ref.read(homeProvider.notifier).updateStep(PrintStep.printing, 0.8));
    Future.delayed(const Duration(seconds: 10), () {
      ref.read(homeProvider.notifier).showPaperDialog();
    });
  }

  void _showPaperDialog(BuildContext context, WidgetRef ref) {
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
        title: const Text('请更换盲文纸', style: TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        content: const Text('当前纸张打印完成\n请放入新的盲文纸后点击确定', textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(homeProvider.notifier).confirmPaperReady();
                ref.read(deviceProvider.notifier).confirmPaperReady();
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('已放好纸张'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
