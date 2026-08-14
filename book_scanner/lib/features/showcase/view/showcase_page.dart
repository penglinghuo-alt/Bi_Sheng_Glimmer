import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/showcase_post.dart';
import '../../../data/services/api_client.dart';
import '../providers/showcase_provider.dart';

class ShowcasePage extends ConsumerStatefulWidget {
  const ShowcasePage({super.key});

  @override
  ConsumerState<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends ConsumerState<ShowcasePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(showcaseProvider.notifier).loadFirstPage();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(showcaseProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(showcaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '发布',
            onPressed: () => context.push(RouteNames.publish),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: state.loading && state.posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.posts.isEmpty
                ? _emptyState(theme)
                : RefreshIndicator(
                    onRefresh: () => ref.read(showcaseProvider.notifier).loadFirstPage(),
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          sliver: SliverList.builder(
                            itemCount: state.posts.length,
                            itemBuilder: (_, i) => _postCard(theme, state.posts[i], context),
                          ),
                        ),
                        if (state.loadingMore)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.explore_outlined, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text('还没有内容，快来发布第一条吧', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text('点击右上角按钮发布你的记录', style: theme.textTheme.bodySmall),
      ]),
    );
  }

  Widget _postCard(ThemeData theme, ShowcasePost post, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    return Semantics(
      label: '帖子，${post.displayTitle}',
      button: true,
      child: GestureDetector(
        onTap: () => context.push('${RouteNames.postDetail}?id=${post.id}'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _authorRow(theme, post.author),
            const SizedBox(height: 12),
            Text(post.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(post.excerpt,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
            const SizedBox(height: 12),
            Row(children: [
              _badge(theme, Icons.description_outlined, post.sourceType),
              const SizedBox(width: 8),
              _badge(theme, Icons.pages_outlined, '${post.pageCount} 页'),
              const Spacer(),
              Icon(Icons.favorite_border_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text('${post.likeCount}', style: theme.textTheme.bodySmall),
              const SizedBox(width: 12),
              Icon(Icons.chat_bubble_outline_rounded, size: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 4),
              Text('${post.commentCount}', style: theme.textTheme.bodySmall),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _authorRow(ThemeData theme, ShowcaseAuthor author) {
    return Row(children: [
      ClipOval(
        child: _avatarImage(author.avatar, size: 30),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(author.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      ),
    ]);
  }

  Widget _badge(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: theme.colorScheme.primary),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
      ]),
    );
  }

  Widget _avatarImage(String? avatar, {required double size}) {
    if (avatar == null || avatar.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: AppColors.primary.withValues(alpha: 0.15),
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, size: size * 0.6, color: AppColors.primary),
      );
    }
    final url = avatar.startsWith('http') ? avatar : '${ApiClient.baseUrl}$avatar';
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        color: AppColors.primary.withValues(alpha: 0.15),
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, size: size * 0.6, color: AppColors.primary),
      ),
    );
  }
}
