import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/accessible_button.dart';
import '../providers/repo_provider.dart';

class PreviewPage extends ConsumerWidget {
  final String recordId;

  const PreviewPage({super.key, required this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final record = ref.read(repoProvider.notifier).getRecord(recordId);

    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('预览')),
        body: const Center(child: Text('记录不存在')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(record.title), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _infoCard(theme, record),
            const SizedBox(height: 20),
            Text('盲文点阵预览', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _dotMatrixPreview(theme, record),
            const SizedBox(height: 24),
            AccessibleButton(
              label: '直接打印',
              icon: Icons.print_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('已发送打印指令'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                );
              },
              fullWidth: true,
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _infoCard(ThemeData theme, dynamic record) {
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

  Widget _dotMatrixPreview(ThemeData theme, dynamic record) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Semantics(
        label: '盲文点阵图形预览',
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: List.generate(
              record.dotMatrixHeight > 20 ? 20 : record.dotMatrixHeight,
              (y) => Row(
                children: List.generate(
                  record.dotMatrixWidth > 30 ? 30 : record.dotMatrixWidth,
                  (x) {
                    final isDot = (record.dotMatrixData[y][x]) == 1;
                    return Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: isDot ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
