import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/route_names.dart';
import '../../features/auth/view/login_page.dart';
import '../../features/auth/view/register_page.dart';
import '../../features/home/view/home_page.dart';
import '../../features/repository/view/repo_list_page.dart';
import '../../features/repository/view/preview_page.dart';
import '../../features/profile/view/profile_page.dart';
import '../../features/profile/view/device_manage_page.dart';
import '../../features/showcase/view/showcase_page.dart';
import '../../features/showcase/view/post_detail_page.dart';
import '../../features/showcase/view/user_profile_page.dart';
import '../../features/showcase/view/publish_page.dart';
import '../../features/showcase/view/favorites_page.dart';
import '../../features/news/view/news_page.dart';
import '../../features/voice/view/voice_page.dart';

final authRedirectNotifier = ValueNotifier<bool>(false);

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    refreshListenable: authRedirectNotifier,
    redirect: (context, state) {
      final isAuth = authRedirectNotifier.value;
      final loc = state.uri.toString();

      if (loc == '/') {
        return isAuth ? RouteNames.home : RouteNames.login;
      }

      final isAuthRoute = loc == RouteNames.login || loc == RouteNames.register;

      if (!isAuth && !isAuthRoute) return RouteNames.login;
      if (isAuth && isAuthRoute) return RouteNames.home;
      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.login,
        builder: (_, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (_, state) => const RegisterPage(),
      ),
      ShellRoute(
        builder: (_, s, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.home,
            builder: (_, state) => const HomePage(),
          ),
          GoRoute(
            path: RouteNames.repository,
            builder: (_, state) => const RepoListPage(),
          ),
          GoRoute(
            path: RouteNames.showcase,
            builder: (_, state) => const ShowcasePage(),
          ),
          GoRoute(
            path: RouteNames.news,
            builder: (_, state) => const NewsPage(),
          ),
          GoRoute(
            path: RouteNames.voice,
            builder: (_, state) => const VoicePage(),
          ),
          GoRoute(
            path: RouteNames.profile,
            builder: (_, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/preview',
            builder: (_, state) {
              final recordId = state.uri.queryParameters['id'] ?? '';
              return PreviewPage(recordId: recordId);
            },
          ),
          GoRoute(
            path: RouteNames.deviceManage,
            builder: (_, state) => const DeviceManagePage(),
          ),
          GoRoute(
            path: RouteNames.postDetail,
            builder: (_, state) {
              final id = state.uri.queryParameters['id'] ?? '';
              return PostDetailPage(postId: id);
            },
          ),
          GoRoute(
            path: RouteNames.userProfile,
            builder: (_, state) {
              final id = state.uri.queryParameters['id'] ?? '';
              return UserProfilePage(userId: id);
            },
          ),
          GoRoute(
            path: RouteNames.publish,
            builder: (_, state) {
              final id = state.uri.queryParameters['id'] ?? '';
              return PublishPage(initialRecordId: id);
            },
          ),
          GoRoute(
            path: RouteNames.favorites,
            builder: (_, state) => const FavoritesPage(),
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
    final loc = GoRouterState.of(context).uri.toString();

    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: Row(children: [
            Expanded(child: _navItem(Icons.home_rounded, Icons.home_outlined, '首页', RouteNames.showcase, loc, context)),
            Expanded(child: _navItem(Icons.article_rounded, Icons.article_outlined, '新闻', RouteNames.news, loc, context)),
            Expanded(child: _navItem(Icons.print_rounded, Icons.print_outlined, '打印', RouteNames.home, loc, context)),
            Expanded(child: _navItem(Icons.storage_rounded, Icons.storage_outlined, '存储库', RouteNames.repository, loc, context)),
            Expanded(child: _navItem(Icons.person_rounded, Icons.person_outlined, '我的', RouteNames.profile, loc, context)),
          ]),
        ),
      ),
    );
  }

  Widget _navItem(IconData filled, IconData outlined, String label, String route, String currentLoc, BuildContext context) {
    final isActive = currentLoc == route;
    final color = isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Semantics(
      button: true, label: label,
      child: InkWell(
        onTap: isActive ? null : () => context.go(route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Semantics(label: label, child: Icon(isActive ? filled : outlined, size: 26, color: color)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(top: isActive ? 4 : 6),
              child: Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: color)),
            ),
          ]),
        ),
      ),
    );
  }
}
