import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/showcase_post.dart';
import '../../../data/services/api_client.dart';

class FavoritesState {
  final List<ShowcasePost> posts;
  final bool loading;
  final String? error;

  const FavoritesState({this.posts = const [], this.loading = false, this.error});

  FavoritesState copyWith({
    List<ShowcasePost>? posts,
    bool? loading,
    String? error,
  }) {
    return FavoritesState(
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final ApiClient _api = ApiClient();

  FavoritesNotifier() : super(const FavoritesState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final data = await _api.getMyFavorites();
      state = state.copyWith(posts: ShowcasePostList.fromJson(data).posts, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请稍后重试');
    }
  }

  void removePost(String id) {
    state = state.copyWith(posts: state.posts.where((p) => p.id != id).toList());
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) => FavoritesNotifier());
