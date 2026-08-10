import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../data/models/braille_record.dart';
import '../../../../shared/widgets/accessible_button.dart';
import '../../../../core/providers/hardware_provider.dart';
import '../providers/repo_provider.dart';

class PreviewPage extends ConsumerStatefulWidget {
  final String recordId;

  const PreviewPage({super.key, required this.recordId});

  @override
  ConsumerState<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends ConsumerState<PreviewPage> {
  BrailleRecord? _record;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final record = await ref.read(repoProvider.notifier).getRecord(widget.recordId);
    if (mounted) {
      setState(() {
        _record = record;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('预览')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('预览')),
        body: const Center(child: Text('记录不存在')),
      );
    }

    final record = _record!;

    return Scaffold(
      appBar: AppBar(title: Text(record.title), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _infoCard(theme, record),
            const SizedBox(height: 20),
            if (record.dotMatrixData.isNotEmpty) ...[
              Text('盲文点阵', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _dotMatrixCard(theme, record),
              const SizedBox(height: 24),
            ],
            if (record.textContent != null && record.textContent!.isNotEmpty) ...[
              Text('文字内容', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              _textContentCard(theme, record.textContent!),
              const SizedBox(height: 24),
            ],
            AccessibleButton(
              label: '直接打印',
              icon: Icons.print_rounded,
              onPressed: () async {
                final text = record.textContent;
                if (text != null && text.isNotEmpty) {
                  await ref.read(hardwareManagerProvider).sendText(text);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('已发送文字数据到 MQTT Broker'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  );
                }
              },
              fullWidth: true,
            ),
            const SizedBox(height: 12),
            AccessibleButton(
              label: '删除记录',
              icon: Icons.delete_outline_rounded,
              color: AppColors.error,
              onPressed: () => _confirmDelete(record),
              fullWidth: true,
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _infoCard(ThemeData theme, BrailleRecord record) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(record.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          _infoChip(theme, Icons.source_rounded, record.sourceType),
          const SizedBox(width: 10),
          _infoChip(theme, Icons.grid_on_rounded, '${record.dotMatrixWidth}x${record.dotMatrixHeight}'),
          const SizedBox(width: 10),
          _infoChip(theme, Icons.pages_rounded, '${record.pageCount}页'),
        ]),
      ]),
    );
  }

  Widget _infoChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _textContentCard(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.8, letterSpacing: 1),
      ),
    );
  }

  Widget _dotMatrixCard(ThemeData theme, BrailleRecord record) {
    final cells = <Widget>[];
    for (final row in record.dotMatrixData) {
      for (final v in row) {
        final isDot = v == 1;
        cells.add(Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDot
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ));
      }
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        runSpacing: 0,
        children: cells,
      ),
    );
  }

  void _confirmDelete(BrailleRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('删除记录'),
        content: Text('确定删除「${record.title}」吗？删除后本地与云端数据将一并清除。', style: const TextStyle(fontSize: 15)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(repoProvider.notifier).deleteRecord(record.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('记录已删除'), behavior: SnackBarBehavior.floating),
                );
                context.go(RouteNames.repository);
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
