import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/route_names.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/view/login_page.dart';
import '../../features/auth/view/register_page.dart';
import '../../features/home/view/home_page.dart';
import '../../features/repository/view/repo_list_page.dart';
import '../../features/repository/view/preview_page.dart';
import '../../features/profile/view/profile_page.dart';
import '../../features/profile/view/device_manage_page.dart';

final _authRedirect = ValueNotifier<bool>(false);

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final isAuth = authState.status == AuthStatus.authenticated;
  _authRedirect.value = isAuth;

  return GoRouter(
    refreshListenable: _authRedirect,
    initialLocation: RouteNames.login,
    redirect: (context, state) {
      final auth = _authRedirect.value;
      final loc = state.uri.toString();
      final isAuthRoute = loc == RouteNames.login || loc == RouteNames.register;

      if (!auth && !isAuthRoute) return RouteNames.login;
      if (auth && isAuthRoute) return RouteNames.home;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.login,
        pageBuilder: (_, s) => CustomTransitionPage(
          child: const LoginPage(),
          transitionsBuilder: (ctx, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: RouteNames.register,
        pageBuilder: (_, s) => CustomTransitionPage(
          child: const RegisterPage(),
          transitionsBuilder: (ctx, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
        ),
      ),
      ShellRoute(
        builder: (_, s, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.home,
            pageBuilder: (_, s) => const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: RouteNames.repository,
            pageBuilder: (_, s) => const NoTransitionPage(child: RepoListPage()),
          ),
          GoRoute(
            path: RouteNames.profile,
            pageBuilder: (_, s) => const NoTransitionPage(child: ProfilePage()),
          ),
          GoRoute(
            path: '/preview',
            pageBuilder: (_, state) {
              final recordId = state.uri.queryParameters['id'] ?? '';
              return CustomTransitionPage(
                child: PreviewPage(recordId: recordId),
                transitionsBuilder: (ctx, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
              );
            },
          ),
          GoRoute(
            path: RouteNames.deviceManage,
            pageBuilder: (_, s) => CustomTransitionPage(
              child: const DeviceManagePage(),
              transitionsBuilder: (ctx, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
            ),
          ),
        ],
      ),
    ],
  );
});

class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, boxShadow: [BoxShadow(color: theme.shadowColor.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4))]),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _NavItem(icon: Icons.home_rounded, label: '首页', selected: location == RouteNames.home, onTap: () => context.go(RouteNames.home)),
              _NavItem(icon: Icons.inventory_2_rounded, label: '存储库', selected: location == RouteNames.repository || location.startsWith('/preview'), onTap: () => context.go(RouteNames.repository)),
              _NavItem(icon: Icons.person_rounded, label: '我的', selected: location == RouteNames.profile || location == RouteNames.deviceManage, onTap: () => context.go(RouteNames.profile)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true, label: label, selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200), curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 24, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ]),
        ),
      ),
    );
  }
}
