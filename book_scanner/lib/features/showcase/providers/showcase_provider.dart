import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/showcase_post.dart';
import '../../../data/services/api_client.dart';

class ShowcaseState {
  final List<ShowcasePost> posts;
  final int total;
  final bool loading;
  final bool loadingMore;
  final String? error;

  const ShowcaseState({
    this.posts = const [],
    this.total = 0,
    this.loading = false,
    this.loadingMore = false,
    this.error,
  });

  ShowcaseState copyWith({
    List<ShowcasePost>? posts,
    int? total,
    bool? loading,
    bool? loadingMore,
    String? error,
  }) {
    return ShowcaseState(
      posts: posts ?? this.posts,
      total: total ?? this.total,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error ?? this.error,
    );
  }
}

class ShowcaseNotifier extends StateNotifier<ShowcaseState> {
  final ApiClient _api = ApiClient();
  int _page = 1;

  ShowcaseNotifier() : super(const ShowcaseState());

  Future<void> loadFirstPage() async {
    _page = 1;
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _api.getShowcasePosts(page: _page);
      final list = ShowcasePostList.fromJson(data);
      state = state.copyWith(posts: list.posts, total: list.total, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '首页加载失败，请稍后重试');
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore) return;
    if (state.posts.length >= state.total) return;
    state = state.copyWith(loadingMore: true);
    try {
      final data = await _api.getShowcasePosts(page: _page + 1);
      final list = ShowcasePostList.fromJson(data);
      _page += 1;
      state = state.copyWith(
        posts: [...state.posts, ...list.posts],
        total: list.total,
        loadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false);
    }
  }

  void refreshPost(ShowcasePost post) {
    final idx = state.posts.indexWhere((p) => p.id == post.id);
    if (idx < 0) return;
    final updated = [...state.posts];
    updated[idx] = post;
    state = state.copyWith(posts: updated);
  }

  void removePost(String id) {
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != id).toList(),
      total: state.total > 0 ? state.total - 1 : 0,
    );
  }
}

final showcaseProvider = StateNotifierProvider<ShowcaseNotifier, ShowcaseState>((ref) => ShowcaseNotifier());
