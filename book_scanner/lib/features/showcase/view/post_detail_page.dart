import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/post_comment.dart';
import '../../../data/models/showcase_post.dart';
import '../../../data/services/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/post_detail_provider.dart';
import '../providers/showcase_provider.dart';

class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(postDetailProvider.notifier).load(widget.postId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(postDetailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('帖子详情'), centerTitle: false),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.post == null
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(state.error ?? '帖子不存在或已删除', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        child: const Text('返回'),
                      ),
                    ]),
                  )
                : Column(children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _authorCard(theme, state.post!.author),
                          const SizedBox(height: 16),
                          Text(state.post!.displayTitle, style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          _metaRow(theme, state.post!),
                          const SizedBox(height: 16),
                          _sectionCard(theme, '描述', Icons.notes_rounded,
                              state.post!.description?.isNotEmpty == true ? state.post!.description! : '该用户未填写描述'),
                          if (state.post!.textContent?.isNotEmpty == true) ...[
                            const SizedBox(height: 12),
                            _sectionCard(theme, '文字内容', Icons.article_outlined, state.post!.textContent!),
                          ],
                          const SizedBox(height: 12),
                          _interactionBar(theme, state.post!),
                          const SizedBox(height: 20),
                          Text('评论 (${state.post!.commentCount})', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (state.comments.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: Text('还没有评论，来说两句吧', style: theme.textTheme.bodySmall)),
                            )
                          else
                            ...state.comments.map((c) => _commentTile(theme, c, ref)),
                          const SizedBox(height: 80),
                        ]),
                      ),
                    ),
                    _commentInputBar(theme, ref),
                  ]),
      ),
    );
  }

  Widget _authorCard(ThemeData theme, ShowcaseAuthor author) {
    return GestureDetector(
      onTap: () => context.push('${RouteNames.userProfile}?id=${author.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          _avatar(author.avatar, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(author.username, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text('查看个人主页', style: theme.textTheme.bodySmall),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
        ]),
      ),
    );
  }

  Widget _metaRow(ThemeData theme, ShowcasePost post) {
    return Wrap(spacing: 12, runSpacing: 8, children: [
      _metaChip(theme, Icons.label_outline_rounded, post.sourceType),
      _metaChip(theme, Icons.pages_outlined, '${post.pageCount} 页'),
      _metaChip(theme, Icons.schedule_rounded, _formatTime(post.createdAt)),
    ]);
  }

  Widget _metaChip(ThemeData theme, IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
      const SizedBox(width: 4),
      Text(text, style: theme.textTheme.bodySmall),
    ]);
  }

  Widget _sectionCard(ThemeData theme, String title, IconData icon, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(title, style: theme.textTheme.titleSmall),
        ]),
        const SizedBox(height: 10),
        Text(content, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
      ]),
    );
  }

  Widget _interactionBar(ThemeData theme, ShowcasePost post) {
    final currentUserId = ref.watch(authProvider).user?.id;
    final isMine = post.author.id == currentUserId;
    return Row(children: [
      Expanded(
        child: _actionButton(
          theme,
          post.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          '${post.likeCount}',
          post.liked,
          AppColors.error,
          () => ref.read(postDetailProvider.notifier).toggleLike(),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _actionButton(
          theme,
          post.favorited ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          post.favorited ? '已收藏' : '收藏',
          post.favorited,
          theme.colorScheme.primary,
          () => ref.read(postDetailProvider.notifier).toggleFavorite(),
        ),
      ),
      if (isMine) ...[
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            theme,
            Icons.delete_outline_rounded,
            '删除',
            false,
            AppColors.error,
            () => _confirmDeletePost(theme),
          ),
        ),
      ],
    ]);
  }

  Widget _actionButton(
    ThemeData theme,
    IconData icon,
    String label,
    bool active,
    Color activeColor,
    VoidCallback onTap,
  ) {
    final color = active ? activeColor : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _commentTile(ThemeData theme, PostComment comment, WidgetRef ref) {
    final isMine = comment.isMine;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _avatar(comment.author.avatar, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(comment.author.username, style: theme.textTheme.titleSmall),
                ),
                Text(_formatTime(comment.createdAt), style: theme.textTheme.bodySmall),
              ]),
              const SizedBox(height: 6),
              Text(comment.content, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
            ]),
          ),
        ),
        if (isMine)
          IconButton(
            tooltip: '删除评论',
            onPressed: () => ref.read(postDetailProvider.notifier).deleteComment(comment.id),
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ),
      ]),
    );
  }

  Widget _commentInputBar(ThemeData theme, WidgetRef ref) {
    final state = ref.watch(postDetailProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2))),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            maxLength: 200,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submitComment(ref),
            decoration: const InputDecoration(
              hintText: '说点什么...',
              counterText: '',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: state.toggling ? null : () => _submitComment(ref),
          style: ElevatedButton.styleFrom(minimumSize: const Size(64, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
          child: const Text('发送'),
        ),
      ]),
    );
  }

  Future<void> _submitComment(WidgetRef ref) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评论不能为空')));
      return;
    }
    final ok = await ref.read(postDetailProvider.notifier).addComment(text);
    if (ok) {
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('评论发送失败，请稍后重试')));
    }
  }

  Future<void> _confirmDeletePost(ThemeData theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除帖子'),
        content: const Text('确定删除这条帖子吗？删除后不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(postDetailProvider.notifier).deletePost();
    if (ok && mounted) {
      final post = ref.read(postDetailProvider).post;
      if (post == null) {
        ref.read(showcaseProvider.notifier).removePost(widget.postId);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('帖子已删除')));
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败，请稍后重试')));
    }
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
          color: AppColors.primary.withValues(alpha: 0.15),
          alignment: Alignment.center,
          child: Icon(Icons.person_rounded, size: size * 0.6, color: AppColors.primary),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 30) return '${diff.inDays} 天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
