import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/route_names.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/services/api_client.dart';
import '../../home/providers/home_provider.dart';

/// AI 盲文报告页：输入主题 → AI 生成结构化长文 → 打印到盲文
class AiReportPage extends ConsumerStatefulWidget {
  const AiReportPage({super.key});

  @override
  ConsumerState<AiReportPage> createState() => _AiReportPageState();
}

class _AiReportPageState extends ConsumerState<AiReportPage> {
  final ApiClient _api = ApiClient();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _extraController = TextEditingController();

  static const _suggestions = ['本月科技发展', '本月国内外大事', '儿童交通安全知识', '小学数学常识'];

  bool _generating = false;
  String? _error;
  String? _title;
  String _content = '';

  @override
  void dispose() {
    _topicController.dispose();
    _extraController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      setState(() => _error = '请输入报告主题');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _error = null;
      _title = null;
      _content = '';
    });
    try {
      final data = await _api.fetchAiReport(topic, extra: _extraController.text.trim());
      if (!mounted) return;
      setState(() {
        _title = (data['title'] as String?)?.trim().isNotEmpty == true
            ? (data['title'] as String).trim()
            : topic;
        _content = (data['content'] as String?) ?? '';
        if (_content.isEmpty) _error = '报告内容为空';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '报告生成失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _sendToBraille() async {
    final text = [
      if (_title != null) '【$_title】',
      _content,
    ].join('\n\n');

    final record = BrailleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'AI报告_${(_title ?? '报告').length > 20 ? (_title ?? '报告').substring(0, 20) : (_title ?? '报告')}',
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
    Clipboard.setData(ClipboardData(text: _content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('报告内容已复制'), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 盲文报告'),
        centerTitle: false,
        actions: [
          if (_content.isNotEmpty)
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
                    enabled: !_generating,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: '报告主题',
                      hintText: '例如：本月科技发展 / 小学数学知识',
                      prefixIcon: const Icon(Icons.auto_awesome_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _extraController,
                    enabled: !_generating,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: '补充要求（可选）',
                      hintText: '例如：重点讲人工智能、语言通俗适合朗读',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onSubmitted: (_) => _generate(),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _suggestions)
                        ActionChip(
                          label: Text(s),
                          onPressed: _generating
                              ? null
                              : () {
                                  _topicController.text = s;
                                  _generate();
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _generating ? null : _generate,
                    icon: _generating
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_generating ? '正在生成，请稍候…' : '生成报告'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  ),
                  const SizedBox(height: 8),
                  if (_generating)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'AI 正在撰写多章节长文，通常需要 30~90 秒',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ),
                  if (_error != null) ...[
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
                        Expanded(child: Text(_error!)),
                      ]),
                    ),
                  ],
                  if (_title != null && _content.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Divider(color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 12),
                    Text(_title!, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.4)),
                    const SizedBox(height: 12),
                    Text(
                      _content,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.9, fontSize: 16),
                    ),
                  ],
                ],
              ),
            ),
            if (_content.isNotEmpty)
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
