import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../presentation/navigation/scaffold_with_nav.dart';
import '../../presentation/screens/login_screen.dart';
import '../../presentation/screens/create_account_screen.dart';
import '../../presentation/screens/email_verification_screen.dart';
import '../../presentation/screens/security_setup_screen.dart';
import '../../presentation/screens/app_lock_screen.dart';
import '../../presentation/screens/dashboard_screen.dart';
import '../../presentation/screens/manual_control_screen.dart';
import '../../presentation/screens/patterns_screen.dart';
import '../../presentation/screens/settings_screen.dart';

// ============================================================
// APP ROUTER — go_router configuration
// ============================================================
// ShellRoute wraps the main tabs in ScaffoldWithNav.
// Individual tab transitions are handled by PageView inside
// ScaffoldWithNav — routes use NoTransitionPage to avoid
// double‑animation conflicts.
// ============================================================

final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String createAccount = '/create-account';
  static const String emailVerification = '/email-verification';
  static const String securitySetup = '/security-setup';
  static const String lock = '/lock';
  static const String home = '/home';
  static const String manualControl = '/manual-control';
  static const String patterns = '/patterns';
  static const String settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final startRoute = ref.watch(initialRouteProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: startRoute,
    routes: [
      // ── Login (full screen, no nav bar) ──
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── Create Account (full screen, no nav bar) ──
      GoRoute(
        path: AppRoutes.createAccount,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const CreateAccountScreen(),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── Email Verification (full screen, no nav bar) ──
      GoRoute(
        path: AppRoutes.emailVerification,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const EmailVerificationScreen(),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── Security Setup (full screen, no nav bar) ──
      GoRoute(
        path: AppRoutes.securitySetup,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SecuritySetupScreen(),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── App Lock (full screen, no nav bar) ──
      GoRoute(
        path: AppRoutes.lock,
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AppLockScreen(),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ── Main Shell (with bottom nav + PageView swipe) ──
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ScaffoldWithNav(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (_, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.manualControl,
            pageBuilder: (_, state) => const NoTransitionPage(
              child: ManualControlScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.patterns,
            pageBuilder: (_, state) => const NoTransitionPage(
              child: PatternsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (_, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
