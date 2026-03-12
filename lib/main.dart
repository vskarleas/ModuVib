import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/app_providers.dart';

// ============================================================
// MODUVUB — Point d'entrée de l'application
// ============================================================
// App de contrôle d'un gilet vibrotactile pour victimes
// de brûlures (prurit dorsal). ESP32 + Flutter BLE.
// ============================================================

/// Provider pour l'état initial de la route (remember me)
final initialRouteProvider = StateProvider<String>((ref) => AppRoutes.login);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Check for remember me
  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('rememberMe') ?? false;
  final startRoute = rememberMe ? AppRoutes.home : AppRoutes.login;

  runApp(
    ProviderScope(
      overrides: [
        initialRouteProvider.overrideWith((ref) => startRoute),
      ],
      child: const ModuVubApp(),
    ),
  );
}

class ModuVubApp extends ConsumerWidget {
  const ModuVubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(darkModeProvider);

    return MaterialApp.router(
      title: 'ModuVub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}