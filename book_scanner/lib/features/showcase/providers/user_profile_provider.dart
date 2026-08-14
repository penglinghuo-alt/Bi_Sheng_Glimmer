import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/post_comment.dart';
import '../../../data/models/showcase_post.dart';
import '../../../data/services/api_client.dart';

class UserProfileState {
  final ShowcaseUser? user;
  final List<ShowcasePost> posts;
  final bool loading;
  final String? error;

  const UserProfileState({this.user, this.posts = const [], this.loading = false, this.error});

  UserProfileState copyWith({
    ShowcaseUser? user,
    List<ShowcasePost>? posts,
    bool? loading,
    String? error,
  }) {
    return UserProfileState(
      user: user ?? this.user,
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final ApiClient _api = ApiClient();

  UserProfileNotifier() : super(const UserProfileState());

  Future<void> load(String userId) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final userJson = await _api.getShowcaseUser(userId);
      final postsJson = await _api.getUserPosts(userId);
      state = state.copyWith(
        user: ShowcaseUser.fromJson(userJson),
        posts: ShowcasePostList.fromJson(postsJson).posts,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: '加载失败，请稍后重试');
    }
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) => UserProfileNotifier());
