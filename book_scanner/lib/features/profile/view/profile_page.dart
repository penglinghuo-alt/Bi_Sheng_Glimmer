import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('我的'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            _profileHeader(theme, ref, user),
            const SizedBox(height: 28),
            _sectionTitle(theme, '设备'),
            const SizedBox(height: 10),
            _menuTile(theme, Icons.bluetooth_rounded, '设备管理', '配对与管理硬件', () => context.go('/device-manage')),
            const SizedBox(height: 20),
            _sectionTitle(theme, '系统'),
            const SizedBox(height: 10),
            _menuTile(theme, Icons.bug_report_rounded, '上传错误日志', '将本地日志打包发送', () => _handleLogUpload(context, ref)),
            const SizedBox(height: 10),
            _menuTile(theme, Icons.settings_rounded, '设置', '退出登录等', () => _showSettings(context, ref)),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _profileHeader(ThemeData theme, WidgetRef ref, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFFFF6B35)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () {}, // Future: image picker for avatar
          child: Semantics(
            label: '头像',
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user?.username ?? '用户', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(user?.bio ?? '毕昇微光用户', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
        ])),
      ]),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: theme.colorScheme.primary, letterSpacing: 0.5)),
    );
  }

  Widget _menuTile(ThemeData theme, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ])),
            Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ]),
        ),
      ),
    );
  }

  void _handleLogUpload(BuildContext context, WidgetRef ref) async {
    final state = ref.read(profileProvider.notifier);
    await state.uploadLogs();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('日志已上传'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      );
    }
  }

  void _showSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Semantics(button: true, label: '退出登录', child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(authProvider.notifier).logout();
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('退出登录'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              )),
            ]),
          ),
        );
      },
    );
  }
}
