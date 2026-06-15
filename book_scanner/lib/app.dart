import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

void main() {
  runApp(const ProviderScope(child: BookScannerApp()));
}

class BookScannerApp extends ConsumerStatefulWidget {
  const BookScannerApp({super.key});

  @override
  ConsumerState<BookScannerApp> createState() => _BookScannerAppState();
}

class _BookScannerAppState extends ConsumerState<BookScannerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Book Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return AnimatedTheme(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          data: themeMode == ThemeMode.dark ? AppTheme.dark() : AppTheme.light(),
          child: child!,
        );
      },
    );
  }
}
