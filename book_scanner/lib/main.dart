import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_pages.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BiShengApp()));
}

class BiShengApp extends ConsumerStatefulWidget {
  const BiShengApp({super.key});

  @override
  ConsumerState<BiShengApp> createState() => _BiShengAppState();
}

class _BiShengAppState extends ConsumerState<BiShengApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: '毕昇微光',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
