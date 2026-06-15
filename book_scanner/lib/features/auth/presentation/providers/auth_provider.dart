import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { unauthenticated, authenticated, loading }

class AuthState {
  final AuthStatus status;
  final String? email;
  final String? username;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.email,
    this.username,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? username,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      username: username ?? this.username,
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
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Please fill in all fields',
      );
      return;
    }

    if (email == 'test@test.com' && password == '123456') {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        email: email,
        username: email.split('@').first,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Invalid email or password',
      );
    }
  }

  Future<void> register(String username, String email, String password, String confirmPassword) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    await Future.delayed(const Duration(seconds: 1));

    if (username.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Please fill in all fields',
      );
      return;
    }

    if (password != confirmPassword) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Passwords do not match',
      );
      return;
    }

    if (password.length < 6) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: 'Password must be at least 6 characters',
      );
      return;
    }

    state = state.copyWith(
      status: AuthStatus.authenticated,
      email: email,
      username: username,
    );
  }

  void logout() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
