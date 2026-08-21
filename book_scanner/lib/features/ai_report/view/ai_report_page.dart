import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/route_names.dart';
import '../../../data/models/braille_record.dart';
import '../../home/providers/home_provider.dart';
import '../providers/ai_report_provider.dart';

/// AI 盲文报告页：输入主题 → AI 生成结构化长文 → 打印到盲文
/// 生成状态保存在全局 provider，切 tab 再回来仍显示工作现场
class AiReportPage extends ConsumerStatefulWidget {
  const AiReportPage({super.key});

  @override
  ConsumerState<AiReportPage> createState() => _AiReportPageState();
}

class _AiReportPageState extends ConsumerState<AiReportPage> {
  static const _suggestions = ['本月科技发展', '本月国内外大事', '儿童交通安全知识', '小学数学常识'];

  late final TextEditingController _topicController;
  late final TextEditingController _extraController;

  @override
  void initState() {
    super.initState();
    final s = ref.read(aiReportProvider);
    _topicController = TextEditingController(text: s.topic);
    _extraController = TextEditingController(text: s.extra);
    ref.read(aiReportProvider.notifier).enter();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  void _pickSuggestion(String s) {
    _topicController.text = s;
    ref.read(aiReportProvider.notifier).setTopic(s);
    ref.read(aiReportProvider.notifier).generate();
  }

  Future<void> _sendToBraille() async {
    final ai = ref.read(aiReportProvider);
    final text = [
      if (ai.title != null) '【${ai.title}】',
      ai.content,
    ].join('\n\n');

    final record = BrailleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'AI报告_${(ai.title ?? '报告').length > 20 ? (ai.title ?? '报告').substring(0, 20) : (ai.title ?? '报告')}',
      sourceType: 'AI 报告',
      dotMatrixWidth: 0,
      dotMatrixHeight: 0,
      dotMatrixData: [],
      createdAt: DateTime.now(),
      pageCount: 1,
      textContent: text,
    );

    final homeNotifier = ref.read(homeProvider.notifier);
    homeNotifier.setMode(PrintMode.localFile);
    homeNotifier.selectRecord(record);
    context.go(RouteNames.home);
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: ref.read(aiReportProvider).content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('报告内容已复制'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ai = ref.watch(aiReportProvider);
    final generating = ai.status == AiReportStatus.generating;
    final hasContent = ai.content.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 盲文报告'),
        centerTitle: false,
        leading: IconButton(
          tooltip: '退出',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.read(aiReportProvider.notifier).exit();
            context.pop();
          },
        ),
        actions: [
          if (hasContent)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: '复制内容',
                onPressed: _copyContent,
                icon: const Icon(Icons.copy_rounded),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text('输入主题，AI 为你汇总生成一份完整报告，可直接打印为盲文书。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _topicController,
                    enabled: !generating,
                    textInputAction: TextInputAction.done,
                    onChanged: (v) => ref.read(aiReportProvider.notifier).setTopic(v),
                    decoration: InputDecoration(
                      labelText: '报告主题',
                      hintText: '例如：本月科技发展 / 小学数学知识',
                      prefixIcon: const Icon(Icons.auto_awesome_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onSubmitted: (_) => ref.read(aiReportProvider.notifier).generate(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _extraController,
                    enabled: !generating,
                    textInputAction: TextInputAction.done,
                    onChanged: (v) => ref.read(aiReportProvider.notifier).setExtra(v),
                    decoration: InputDecoration(
                      labelText: '补充要求（可选）',
                      hintText: '例如：重点讲人工智能、语言通俗适合朗读',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onSubmitted: (_) => ref.read(aiReportProvider.notifier).generate(),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(
                          label: Text(s),
                          onPressed: generating ? null : () => _pickSuggestion(s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: generating ? null : () => ref.read(aiReportProvider.notifier).generate(),
                    icon: generating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(generating ? '正在生成，请稍候…' : '生成报告'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                  const SizedBox(height: 8),
                  if (generating)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'AI 正在撰写多章节长文，通常需要 30~90 秒，切换页面不影响生成',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                  if (ai.error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                        const SizedBox(width: 10),
                        Expanded(child: Text(ai.error!)),
                      ]),
                    ),
                  ],
                  if (ai.title != null && hasContent) ...[
                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 12),
                    Text(ai.title!, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.4)),
                    const SizedBox(height: 12),
                    Text(
                      ai.content,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.9, fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
            if (hasContent)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _sendToBraille,
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('打印到盲文'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
