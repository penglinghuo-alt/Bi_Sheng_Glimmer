import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/showcase_post.dart';
import '../../../data/services/api_client.dart';
import '../providers/favorites_provider.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(favoritesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏'), centerTitle: false),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.posts.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.bookmark_border_rounded, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text('暂无收藏', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                      const SizedBox(height: 4),
                      Text('去展示区逛逛吧', style: theme.textTheme.bodySmall),
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: () => ref.read(favoritesProvider.notifier).load(),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.all(16),
                      itemCount: state.posts.length,
                      itemBuilder: (_, i) => _postCard(theme, state.posts[i], context),
                    ),
                  ),
      ),
    );
  }

  Widget _postCard(ThemeData theme, ShowcasePost post, BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('${RouteNames.postDetail}?id=${post.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(post.author.avatar, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(post.author.username, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(post.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.favorite_border_rounded, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text('${post.likeCount}', style: theme.textTheme.bodySmall),
                const SizedBox(width: 12),
                Icon(Icons.chat_bubble_outline_rounded, size: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text('${post.commentCount}', style: theme.textTheme.bodySmall),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _avatar(String? avatar, {required double size}) {
    if (avatar == null || avatar.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, size: size * 0.6, color: AppColors.primary),
      );
    }
    final url = avatar.startsWith('http') ? avatar : '${ApiClient.baseUrl}$avatar';
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(Icons.person_rounded, size: size * 0.6, color: AppColors.primary),
        ),
      ),
    );
  }
}
