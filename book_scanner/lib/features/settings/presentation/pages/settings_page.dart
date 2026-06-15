import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = false;
  bool _autoSave = true;
  bool _highQuality = false;
  String _defaultPaperSize = 'A4';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildProfileCard(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildSectionLabel(context, 'Appearance')),
            SliverToBoxAdapter(child: _buildAppearanceSection(context)),
            SliverToBoxAdapter(child: _buildSectionLabel(context, 'Scanning')),
            SliverToBoxAdapter(child: _buildScanningSection(context)),
            SliverToBoxAdapter(child: _buildSectionLabel(context, 'Printing')),
            SliverToBoxAdapter(child: _buildPrintingSection(context)),
            SliverToBoxAdapter(child: _buildSectionLabel(context, 'General')),
            SliverToBoxAdapter(child: _buildGeneralSection(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ).createShader(bounds),
            child: Text(
              'Settings',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Customize your experience',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student User',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Free Plan',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            _SwitchTile(
              icon: Icons.dark_mode_rounded,
              title: 'Dark Mode',
              subtitle: 'Switch between light and dark themes',
              value: _isDarkMode,
              onChanged: (v) => setState(() => _isDarkMode = v),
            ),
            _SettingsDivider(theme),
            _SettingsTile(
              icon: Icons.color_lens_rounded,
              title: 'Accent Color',
              value: 'Indigo',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningSection(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            _SwitchTile(
              icon: Icons.save_alt_rounded,
              title: 'Auto Save',
              subtitle: 'Automatically save scans to device',
              value: _autoSave,
              onChanged: (v) => setState(() => _autoSave = v),
            ),
            _SettingsDivider(theme),
            _SwitchTile(
              icon: Icons.high_quality_rounded,
              title: 'High Quality',
              subtitle: 'Scan at maximum resolution',
              value: _highQuality,
              onChanged: (v) => setState(() => _highQuality = v),
            ),
            _SettingsDivider(theme),
            _SettingsTile(
              icon: Icons.folder_rounded,
              title: 'Save Location',
              value: 'Documents/Scanner',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintingSection(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            _SettingsTile(
              icon: Icons.aspect_ratio_rounded,
              title: 'Default Paper Size',
              value: _defaultPaperSize,
              onTap: () {
                _showPaperSizePicker();
              },
            ),
            _SettingsDivider(theme),
            _SettingsTile(
              icon: Icons.colorize_rounded,
              title: 'Color Mode',
              value: 'Black & White',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSection(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          children: [
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About',
              value: 'v1.0.0',
              onTap: () {},
            ),
            _SettingsDivider(theme),
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              value: '',
              onTap: () {},
            ),
            _SettingsDivider(theme),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              value: '',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  void _showPaperSizePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final sizes = ['A4', 'A5', 'Letter', 'Legal'];

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text('Paper Size', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              ...sizes.map((size) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() => _defaultPaperSize = size);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (size == _defaultPaperSize)
                              Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 22)
                            else
                              const SizedBox(width: 22),
                            const SizedBox(width: 14),
                            Text(
                              size,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: size == _defaultPaperSize ? FontWeight.w700 : FontWeight.w500,
                                color: size == _defaultPaperSize
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.4),
            activeThumbColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Text(title, style: theme.textTheme.titleSmall),
              const Spacer(),
              if (value.isNotEmpty)
                Text(value, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  final ThemeData theme;
  const _SettingsDivider(this.theme);

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: theme.colorScheme.outline.withValues(alpha: 0.2),
      indent: 54,
    );
  }
}
