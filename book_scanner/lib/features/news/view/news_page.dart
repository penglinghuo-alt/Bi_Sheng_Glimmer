import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/braille_record.dart';
import '../../../data/models/news_item.dart';
import '../../home/providers/home_provider.dart';
import '../providers/news_provider.dart';

class NewsPage extends ConsumerStatefulWidget {
  const NewsPage({super.key});

  @override
  ConsumerState<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends ConsumerState<NewsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(newsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 新闻摘要'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  state.source == 'cctv' ? '央视新闻' : (state.source == 'fallback' ? '本地新闻' : '新闻'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.primary),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: state.loading && state.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => ref.read(newsProvider.notifier).load(),
                child: state.items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        children: [
                          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                          _emptyState(theme, state.error),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            _newsCard(theme, state.items[i]),
                      ),
              ),
      ),
    );
  }

  Widget _newsCard(ThemeData theme, NewsItem item) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.article_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.3),
            ),
          ),
        ]),
        if (item.brief.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            item.brief,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              height: 1.5,
            ),
          ),
        ],
        if (item.keywords.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: item.keywords
                .split(RegExp(r'[\s,，、]+'))
                .where((k) => k.isNotEmpty)
                .take(5)
                .map((k) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        k,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSecondaryContainer),
                      ),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          if (item.focusDate != null && item.focusDate!.isNotEmpty)
            Text(
              item.focusDate!,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ),
          const Spacer(),
          _cardAction(theme, Icons.print_rounded, '打印', () => _sendToBraille(item)),
          const SizedBox(width: 6),
          _cardAction(theme, Icons.open_in_new_rounded, '原文', () => _openOriginal(item)),
        ]),
      ]),
    );
  }

  Widget _cardAction(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
        ]),
      ),
    );
  }

  Future<void> _sendToBraille(NewsItem item) async {
    final text = [
      '【${item.title}】',
      if (item.brief.isNotEmpty) item.brief,
      if (item.keywords.isNotEmpty) '关键词: ${item.keywords}',
    ].join('\n\n');

    final record = BrailleRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '新闻_${item.title.length > 20 ? item.title.substring(0, 20) : item.title}',
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

  void _openOriginal(NewsItem item) {
    if (item.url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: item.url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('原文链接已复制: ${item.url}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _emptyState(ThemeData theme, String? error) {
    return Column(
      children: [
        Icon(Icons.article_rounded, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
        const SizedBox(height: 12),
        Text(
          error ?? '暂无新闻',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => ref.read(newsProvider.notifier).load(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重新加载'),
        ),
      ],
    );
  }
}
