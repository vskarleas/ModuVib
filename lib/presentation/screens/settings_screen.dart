import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/ble_protocol.dart';

// ══════════════════════════════════════════════════════════════
// SETTINGS SCREEN — Réglages de l'application NeuroSense
// ══════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = ref.watch(batteryLevelProvider);
    final bleState = ref.watch(bleConnectionProvider);
    final maxThreshold = ref.watch(maxIntensityThresholdProvider);
    final darkMode = ref.watch(darkModeProvider);
    final masterIntensity = ref.watch(masterIntensityProvider);
    final remaining = BleProtocol.estimateRemainingMinutes(battery, masterIntensity);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Titre ──────────────────────────────────────────
            Text(
              'Réglages',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // ── Carte profil ───────────────────────────────────
            _ProfileCard(
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 28),

            // ── Section : Dispositif ───────────────────────────
            _SectionTitle(title: 'Dispositif', textSecondary: textSecondary),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: LucideIcons.bluetooth,
              title: 'Appareil Bluetooth',
              subtitle: bleState == BleConnectionState.connected
                  ? 'NeuroSense-ESP32 connecté'
                  : 'Non connecté',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              trailing: _BleStatusDot(isConnected: bleState == BleConnectionState.connected),
            ),
            _SettingsTile(
              icon: LucideIcons.battery,
              title: 'Batterie',
              subtitle: '$battery% — Autonomie ~${remaining ~/ 60}h${(remaining % 60).toString().padLeft(2, '0')}min',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _SettingsTile(
              icon: LucideIcons.refreshCw,
              title: 'Firmware',
              subtitle: 'v2.1.3 — À jour',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 28),

            // ── Section : Sécurité ─────────────────────────────
            _SectionTitle(title: 'Sécurité', textSecondary: textSecondary),
            const SizedBox(height: 12),
            _SafetyThresholdCard(
              maxThreshold: maxThreshold,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onChanged: (v) {
                ref.read(maxIntensityThresholdProvider.notifier).state = v;
                if (ref.read(masterIntensityProvider) > v) {
                  ref.read(masterIntensityProvider.notifier).state = v;
                }
              },
            ),
            const SizedBox(height: 28),

            // ── Section : Calibration ──────────────────────────
            _SectionTitle(title: 'Calibration', textSecondary: textSecondary),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: LucideIcons.mapPin,
              title: 'Mapping moteurs',
              subtitle: 'Recalibrer la position des moteurs',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => _showMappingDialog(context, isDark),
            ),
            const SizedBox(height: 28),

            // ── Section : Application ──────────────────────────
            _SectionTitle(title: 'Application', textSecondary: textSecondary),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: darkMode ? LucideIcons.moon : LucideIcons.sun,
              title: 'Thème sombre',
              subtitle: darkMode ? 'Activé' : 'Désactivé',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              trailing: Switch(
                value: darkMode,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => ref.read(darkModeProvider.notifier).state = v,
              ),
            ),
            _SettingsTile(
              icon: LucideIcons.bellRing,
              title: 'Notifications',
              subtitle: 'Activées',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _SettingsTile(
              icon: LucideIcons.shield,
              title: 'Sécurité',
              subtitle: 'FaceID activé',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _SettingsTile(
              icon: LucideIcons.info,
              title: 'À propos',
              subtitle: 'NeuroSense — GTS815 ÉTS',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 28),

            // ── Bouton déconnexion ─────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('rememberMe', false);
                  if (context.mounted) context.go(AppRoutes.login);
                },
                icon: const Icon(LucideIcons.logOut, size: 18),
                label: Text(
                  'Déconnexion',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMappingDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(LucideIcons.mapPin, size: 22, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'Mapping moteurs',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'La recalibration des moteurs permet de réassigner les positions '
          'si vous avez modifié le gilet.\n\n'
          'Activez chaque moteur individuellement et confirmez sa position sur le dos.',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Fermer',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Commencer',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Composants privés
// ══════════════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;

  const _ProfileCard({
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.user, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'NeuroSense v1.0',
                  style: GoogleFonts.poppins(fontSize: 13, color: textSecondary),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 20, color: textSecondary),
        ],
      ),
    );
  }
}

class _BleStatusDot extends StatelessWidget {
  final bool isConnected;
  const _BleStatusDot({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? Colors.green : AppColors.error;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}

class _SafetyThresholdCard extends StatelessWidget {
  final double maxThreshold;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final ValueChanged<double> onChanged;

  const _SafetyThresholdCard({
    required this.maxThreshold,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.shieldAlert, size: 20, color: AppColors.error),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seuil de puissance max',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      'Ne jamais dépasser ${(maxThreshold * 100).round()}%',
                      style: GoogleFonts.poppins(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(maxThreshold * 100).round()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.error.withValues(alpha: 0.7),
              inactiveTrackColor: AppColors.error.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayColor: AppColors.error.withValues(alpha: 0.1),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 10,
                elevation: 3,
              ),
            ),
            child: Slider(
              value: maxThreshold,
              min: 0.3,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color textSecondary;
  const _SectionTitle({required this.title, required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: textSecondary.withValues(alpha: 0.6),
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(LucideIcons.chevronRight, size: 18, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
