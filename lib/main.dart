import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/app_providers.dart';

// ============================================================
// MODUVIB — Point d'entrée de l'application
// ============================================================
// App de contrôle d'un gilet vibrotactile pour victimes
// de brûlures (prurit dorsal). ESP32 + Flutter BLE.
// ============================================================

/// Provider pour l'état initial de la route (remember me)
final initialRouteProvider = StateProvider<String>((ref) => AppRoutes.login);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Check for remember me + active Firebase session
  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('rememberMe') ?? false;
  final hasFirebaseUser = FirebaseAuth.instance.currentUser != null;
  final startRoute = (rememberMe && hasFirebaseUser) ? AppRoutes.home : AppRoutes.login;

  runApp(
    ProviderScope(
      overrides: [
        initialRouteProvider.overrideWith((ref) => startRoute),
      ],
      child: const ModuVibApp(),
    ),
  );
}

class ModuVibApp extends ConsumerWidget {
  const ModuVibApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(darkModeProvider);

    return MaterialApp.router(
      title: 'ModuVib',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}