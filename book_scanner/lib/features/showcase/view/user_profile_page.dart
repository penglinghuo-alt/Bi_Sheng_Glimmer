import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/post_comment.dart';
import '../../../data/models/showcase_post.dart';
import '../../../data/services/api_client.dart';
import '../providers/user_profile_provider.dart';

class UserProfilePage extends ConsumerStatefulWidget {
  final String userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).load(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('个人主页'), centerTitle: false),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.user == null
                ? Center(child: Text(state.error ?? '加载失败', style: theme.textTheme.bodyMedium))
                : RefreshIndicator(
                    onRefresh: () => ref.read(userProfileProvider.notifier).load(widget.userId),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        _profileHeader(theme, state.user!),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('TA 的帖子 (${state.user!.postCount})', style: theme.textTheme.titleMedium),
                        ),
                        const SizedBox(height: 12),
                        if (state.posts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: Text('还没有发布帖子', style: theme.textTheme.bodySmall)),
                          )
                        else
                          ...state.posts.map((p) => _postCard(theme, p, context)),
                      ]),
                    ),
                  ),
      ),
    );
  }

  Widget _profileHeader(ThemeData theme, ShowcaseUser user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(children: [
        _avatar(user.avatar, size: 72),
        const SizedBox(height: 12),
        Text(user.username, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          user.bio == null || user.bio!.trim().isEmpty ? 'TA 还没有填写签名' : user.bio!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 12),
        Text(
          '加入时间：${user.createdAt == null ? '未知' : _formatDate(user.createdAt!)}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
        ),
      ]),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(post.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(post.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.favorite_border_rounded, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 4),
            Text('${post.likeCount}', style: theme.textTheme.bodySmall),
            const SizedBox(width: 12),
            Icon(Icons.chat_bubble_outline_rounded, size: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 4),
            Text('${post.commentCount}', style: theme.textTheme.bodySmall),
            const Spacer(),
            Text(_formatDate(post.createdAt), style: theme.textTheme.bodySmall),
          ]),
        ]),
      ),
    );
  }

  Widget _avatar(String? avatar, {required double size}) {
    if (avatar == null || avatar.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
        alignment: Alignment.center,
        child: Icon(Icons.person_rounded, size: size * 0.55, color: Colors.white),
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
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
          alignment: Alignment.center,
          child: Icon(Icons.person_rounded, size: size * 0.55, color: Colors.white),
        ),
      ),
    );
  }

  String _formatDate(DateTime t) {
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
