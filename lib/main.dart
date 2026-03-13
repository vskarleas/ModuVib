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
import 'core/services/local_security_service.dart';

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

  // Load persisted settings
  final prefs = await SharedPreferences.getInstance();
  final savedThreshold = prefs.getDouble('max_intensity_threshold') ?? 0.8;

  // Check for active Firebase session
  final currentUser = FirebaseAuth.instance.currentUser;

  String startRoute = AppRoutes.login;
  if (currentUser != null) {
    final security = LocalSecurityService();
    final setupComplete = await security.isSecuritySetupComplete(currentUser.uid);
    // Security set up → lock screen (PIN / Face ID), otherwise → setup flow
    startRoute = setupComplete ? AppRoutes.lock : AppRoutes.securitySetup;
  }

  runApp(
    ProviderScope(
      overrides: [
        initialRouteProvider.overrideWith((ref) => startRoute),
        maxIntensityThresholdProvider.overrideWith((ref) => savedThreshold),
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
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'ModuVib',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}