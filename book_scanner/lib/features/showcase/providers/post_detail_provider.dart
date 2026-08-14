import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/post_comment.dart';
import '../../../data/models/showcase_post.dart';
import '../../../data/services/api_client.dart';

class PostDetailState {
  final ShowcasePost? post;
  final List<PostComment> comments;
  final bool loading;
  final bool toggling;
  final String? error;

  const PostDetailState({
    this.post,
    this.comments = const [],
    this.loading = false,
    this.toggling = false,
    this.error,
  });

  PostDetailState copyWith({
    ShowcasePost? post,
    List<PostComment>? comments,
    bool? loading,
    bool? toggling,
    String? error,
  }) {
    return PostDetailState(
      post: post ?? this.post,
      comments: comments ?? this.comments,
      loading: loading ?? this.loading,
      toggling: toggling ?? this.toggling,
      error: error ?? this.error,
    );
  }
}

class PostDetailNotifier extends StateNotifier<PostDetailState> {
  final ApiClient _api = ApiClient();

  PostDetailNotifier() : super(const PostDetailState());

  Future<void> load(String postId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final postJson = await _api.getShowcasePost(postId);
      final commentsJson = await _api.getPostComments(postId);
      state = state.copyWith(
        post: ShowcasePost.fromJson(postJson),
        comments: commentsJson.map((e) => PostComment.fromJson(e)).toList(),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请稍后重试');
    }
  }

  Future<void> toggleLike() async {
    final post = state.post;
    if (post == null || state.toggling) return;
    state = state.copyWith(toggling: true);
    try {
      if (post.liked) {
        await _api.unlikeShowcasePost(post.id);
        state = state.copyWith(
          post: post.copyWith(liked: false, likeCount: post.likeCount > 0 ? post.likeCount - 1 : 0),
          toggling: false,
        );
      } else {
        await _api.likeShowcasePost(post.id);
        state = state.copyWith(
          post: post.copyWith(liked: true, likeCount: post.likeCount + 1),
          toggling: false,
        );
      }
    } catch (e) {
      state = state.copyWith(toggling: false);
    }
  }

  Future<void> toggleFavorite() async {
    final post = state.post;
    if (post == null || state.toggling) return;
    state = state.copyWith(toggling: true);
    try {
      if (post.favorited) {
        await _api.unfavoriteShowcasePost(post.id);
        state = state.copyWith(post: post.copyWith(favorited: false), toggling: false);
      } else {
        await _api.favoriteShowcasePost(post.id);
        state = state.copyWith(post: post.copyWith(favorited: true), toggling: false);
      }
    } catch (e) {
      state = state.copyWith(toggling: false);
    }
  }

  Future<bool> addComment(String content) async {
    final post = state.post;
    if (post == null) return false;
    try {
      final commentJson = await _api.addPostComment(post.id, content);
      final comment = PostComment.fromJson(commentJson);
      state = state.copyWith(
        comments: [...state.comments, comment],
        post: post.copyWith(commentCount: post.commentCount + 1),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteComment(int commentId) async {
    try {
      await _api.deletePostComment(commentId);
      final post = state.post;
      state = state.copyWith(
        comments: state.comments.where((c) => c.id != commentId).toList(),
        post: post == null ? null : post.copyWith(commentCount: post.commentCount > 0 ? post.commentCount - 1 : 0),
      );
    } catch (e) {
      // 忽略失败
    }
  }

  Future<bool> deletePost() async {
    final post = state.post;
    if (post == null) return false;
    try {
      await _api.deleteShowcasePost(post.id);
      state = state.copyWith(post: null);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final postDetailProvider = StateNotifierProvider<PostDetailNotifier, PostDetailState>((ref) => PostDetailNotifier());
