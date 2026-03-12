import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../screens/dashboard_screen.dart';
import '../screens/manual_control_screen.dart';
import '../screens/patterns_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/top_bar.dart';

// ══════════════════════════════════════════════════════════════
// SCAFFOLD AVEC NAVIGATION — Swipe + Onglets
// ══════════════════════════════════════════════════════════════
// PageView = source unique de vérité pour l'affichage.
// GoRouter synchronise uniquement l'URL (deep links, back).
// Le paramètre `child` du ShellRoute n'est pas utilisé.
// ══════════════════════════════════════════════════════════════

class ScaffoldWithNav extends StatefulWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  @override
  State<ScaffoldWithNav> createState() => _ScaffoldWithNavState();
}

class _ScaffoldWithNavState extends State<ScaffoldWithNav> {
  static const _routes = [
    AppRoutes.home,
    AppRoutes.manualControl,
    AppRoutes.patterns,
    AppRoutes.settings,
  ];

  PageController? _pageController;
  int _currentIndex = 0;
  bool _isAnimating = false;

  int _indexFromLocation(String location) {
    if (location.startsWith(AppRoutes.manualControl)) return 1;
    if (location.startsWith(AppRoutes.patterns)) return 2;
    if (location.startsWith(AppRoutes.settings)) return 3;
    return 0;
  }

  // ── Lifecycle ────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeIndex = _indexFromLocation(
      GoRouterState.of(context).uri.toString(),
    );

    if (_pageController == null) {
      _currentIndex = routeIndex;
      _pageController = PageController(initialPage: routeIndex);
      return;
    }

    if (routeIndex != _currentIndex && !_isAnimating) {
      setState(() => _currentIndex = routeIndex);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController!.hasClients) {
          _pageController!.jumpToPage(routeIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  // ── Callbacks de navigation ──────────────────────────────

  void _onPageSwiped(int index) {
    if (_isAnimating || index == _currentIndex) return;
    setState(() => _currentIndex = index);
    context.go(_routes[index]);
  }

  void _onNavTap(int index) {
    if (index == _currentIndex || _isAnimating) return;
    setState(() {
      _currentIndex = index;
      _isAnimating = true;
    });
    _pageController!
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
      if (!mounted) return;
      _isAnimating = false;
      context.go(_routes[index]);
    });
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Column(
        children: [
          const NeuroTopBar(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageSwiped,
              children: const [
                DashboardScreen(),
                ManualControlScreen(),
                PatternsScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Barre de Navigation Inférieure (Glassmorphisme)
// ══════════════════════════════════════════════════════════════

class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlassNavBar({required this.currentIndex, required this.onTap});

  static const _items = <_NavItem>[
    _NavItem(icon: LucideIcons.layoutDashboard, label: 'Accueil'),
    _NavItem(icon: LucideIcons.hand, label: 'Contrôle'),
    _NavItem(icon: LucideIcons.waves, label: 'Programmes'),
    _NavItem(icon: LucideIcons.settings, label: 'Réglages'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Séparateur dégradé
            Container(
              height: 1.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x0064B5F6),
                    AppColors.primaryLight,
                    AppColors.primary,
                    AppColors.primaryLight,
                    Color(0x0064B5F6),
                  ],
                ),
              ),
            ),
            Container(
              decoration: GlassDecoration.navBar(),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 68,
                  child: Row(
                    children: List.generate(_items.length, (i) {
                      return _NavBarItem(
                        item: _items[i],
                        isSelected: currentIndex == i,
                        onTap: () => onTap(i),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Élément de navigation ────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.primary
        : AppColors.textSecondary.withValues(alpha: 0.6);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Icon(item.icon, size: 21, color: color),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
