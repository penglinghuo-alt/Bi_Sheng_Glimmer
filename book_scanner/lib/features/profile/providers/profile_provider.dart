import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_model.dart';
import '../../../core/utils/logger.dart';

class ProfileState {
  final UserModel? user;
  final bool isLogUploading;

  const ProfileState({this.user, this.isLogUploading = false});

  ProfileState copyWith({UserModel? user, bool? isLogUploading}) {
    return ProfileState(user: user ?? this.user, isLogUploading: isLogUploading ?? this.isLogUploading);
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(const ProfileState());

  void loadUser(UserModel user) {
    state = state.copyWith(user: user);
  }

  void updateAvatar(String avatar) {
    if (state.user != null) {
      state = state.copyWith(user: state.user!.copyWith(avatar: avatar));
    }
  }

  void updateBio(String bio) {
    if (state.user != null) {
      state = state.copyWith(user: state.user!.copyWith(bio: bio));
    }
  }

  Future<void> uploadLogs() async {
    state = state.copyWith(isLogUploading: true);
    await Future.delayed(const Duration(seconds: 2));
    state = state.copyWith(isLogUploading: false);
  }

  List<String> getLogs() => Logger.getAllLogs();
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) => ProfileNotifier());
