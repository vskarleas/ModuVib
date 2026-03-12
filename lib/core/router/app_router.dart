import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../presentation/navigation/scaffold_with_nav.dart';
import '../../presentation/screens/login_screen.dart';
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
