import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/user_model.dart';

enum AuthStatus { unauthenticated, authenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({this.status = AuthStatus.unauthenticated, this.user, this.error});

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error, bool clearError = false}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (email.isEmpty || password.isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: '请填写所有字段');
      return;
    }

    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: UserModel(id: '1', username: email, email: email, bio: '毕昇微光用户'),
    );
  }

  Future<void> register(String username, String email, String password, String confirm) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    await Future.delayed(const Duration(milliseconds: 600));

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: '请填写所有字段');
      return;
    }
    if (password != confirm) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: '两次密码不一致');
      return;
    }
    if (password.length < 6) {
      state = state.copyWith(status: AuthStatus.unauthenticated, error: '密码至少6位');
      return;
    }

    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: UserModel(id: DateTime.now().millisecondsSinceEpoch.toString(), username: username, email: email, bio: '毕昇微光用户'),
    );
  }

  void logout() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
