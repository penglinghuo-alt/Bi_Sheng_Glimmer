import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_enums.dart';
import '../../../core/constants/route_names.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/services/api_client.dart';
import '../../home/providers/home_provider.dart';

/// 新闻原文阅读页（内置查看，正文由后端抓取）
class NewsDetailPage extends ConsumerStatefulWidget {
  const NewsDetailPage({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  ConsumerState<NewsDetailPage> createState() => _NewsDetailPageState();
}

class _NewsDetailPageState extends ConsumerState<NewsDetailPage> {
  final ApiClient _api = ApiClient();
  bool _loading = true;
  String? _error;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchNewsDetail(widget.url);
      if (!mounted) return;
      setState(() {
        _content = (data['content'] as String?) ?? '';
        if (_content.isEmpty) _error = '原文内容为空';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '原文加载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: widget.url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('原文链接已复制'), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _sendToBraille() async {
    final text = [
      '【${widget.title}】',
      if (_content.isNotEmpty) _content,
    ].join('\n\n');

    final record = BrailleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '新闻_${widget.title.length > 20 ? widget.title.substring(0, 20) : widget.title}',
      sourceType: 'AI 新闻',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('新闻原文'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: '复制链接',
              onPressed: _copyUrl,
              icon: const Icon(Icons.link_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildBody(theme),
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

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.article_rounded, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(widget.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.4)),
        const SizedBox(height: 16),
        Text(
          _content,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.9, fontSize: 16),
        ),
      ],
    );
  }
}
