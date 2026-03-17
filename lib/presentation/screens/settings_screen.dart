import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/ble_protocol.dart';
import '../../core/services/auth_service.dart';

// ══════════════════════════════════════════════════════════════
// SETTINGS SCREEN — Réglages de l'application ModuVib
// ══════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = ref.watch(batteryLevelProvider);
    final bleState = ref.watch(bleConnectionProvider);
    final maxThreshold = ref.watch(maxIntensityThresholdProvider);
    final biometricEnabled = ref.watch(biometricEnabledProvider);
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
              isDark: isDark,
            ),
            const SizedBox(height: 28),

            // ── Section : Dispositif ───────────────────────────
            _SectionTitle(title: 'Dispositif', textSecondary: textSecondary),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: LucideIcons.bluetooth,
              title: 'Appareil Bluetooth',
              subtitle: bleState == BleConnectionState.connected
                  ? 'ModuVib-ESP32 connecté'
                  : 'Non connecté',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              trailing: _BleStatusDot(isConnected: bleState == BleConnectionState.connected),
            ),
            _SettingsTile(
              icon: LucideIcons.battery,
              title: 'Batterie',
              subtitle: bleState == BleConnectionState.connected
                  ? '$battery% — Autonomie ~${remaining ~/ 60}h${(remaining % 60).toString().padLeft(2, '0')}min'
                  : '--% — Appareil non connecté',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => _showBatterySheet(context, ref, isDark, textPrimary, textSecondary),
            ),
            _SettingsTile(
              icon: LucideIcons.refreshCw,
              title: 'Firmware',
              subtitle: 'v3.0',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => _showFirmwareSheet(context, isDark, textPrimary, textSecondary),
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
              onChanged: (v) async {
                ref.read(maxIntensityThresholdProvider.notifier).state = v;
                if (ref.read(masterIntensityProvider) > v) {
                  ref.read(masterIntensityProvider.notifier).state = v;
                }
                // Persist to SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble('max_intensity_threshold', v);
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
              icon: isDark ? LucideIcons.moon : LucideIcons.sun,
              title: 'Thème',
              subtitle: ref.watch(themeModeProvider) == ThemeMode.system
                  ? 'Automatique (système)'
                  : ref.watch(themeModeProvider) == ThemeMode.dark
                      ? 'Sombre'
                      : 'Clair',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              trailing: DropdownButtonHideUnderline(
                child: DropdownButton<ThemeMode>(
                  value: ref.watch(themeModeProvider),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('Auto')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Clair')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Sombre')),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeModeProvider.notifier).state = mode;
                    }
                  },
                ),
              ),
            ),
            _SettingsTile(
              icon: LucideIcons.shield,
              title: 'Sécurité biométrique',
              subtitle: biometricEnabled ? 'FaceID / Empreinte activé' : 'Désactivé',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              trailing: Switch(
                value: biometricEnabled,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => ref.read(biometricEnabledProvider.notifier).state = v,
              ),
            ),
            _SettingsTile(
              icon: LucideIcons.info,
              title: 'À propos',
              subtitle: 'ModuVib — GTS815 ÉTS',
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onTap: () => _showLicensesBottomSheet(context),
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
                  await AuthService().signOut();
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

  // ── Battery Bottom Sheet ──────────────────────────────────────
  void _showBatterySheet(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final battery = ref.read(batteryLevelProvider);
    final voltage = ref.read(vestVoltageProvider);
    final intensity = ref.read(masterIntensityProvider);
    final bleState = ref.read(bleConnectionProvider);
    final isConnected = bleState == BleConnectionState.connected;
    final remaining = BleProtocol.estimateRemainingMinutes(battery, intensity);
    final hours = remaining ~/ 60;
    final mins = remaining % 60;

    // Battery status
    final Color batteryColor;
    final IconData batteryIcon;
    final String statusText;
    if (!isConnected) {
      batteryColor = textSecondary;
      batteryIcon = LucideIcons.batteryWarning;
      statusText = 'Appareil non connecté';
    } else if (battery <= 10) {
      batteryColor = AppColors.error;
      batteryIcon = LucideIcons.batteryWarning;
      statusText = 'Critique — rechargez maintenant';
    } else if (battery <= 25) {
      batteryColor = Colors.orange;
      batteryIcon = LucideIcons.batteryLow;
      statusText = 'Faible';
    } else if (battery <= 50) {
      batteryColor = Colors.amber;
      batteryIcon = LucideIcons.batteryMedium;
      statusText = 'Moyen';
    } else {
      batteryColor = Colors.green;
      batteryIcon = LucideIcons.batteryFull;
      statusText = 'Bon';
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        color: bgColor,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Row(
              children: [
                Icon(batteryIcon, size: 24, color: batteryColor),
                const SizedBox(width: 12),
                Text(
                  'Batterie',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: batteryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: batteryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: isConnected ? battery / 100.0 : 0,
                minHeight: 10,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
              ),
            ),
            const SizedBox(height: 20),
            // Info rows
            _BatteryInfoRow(
              label: 'Niveau',
              value: isConnected ? '$battery%' : '--',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _BatteryInfoRow(
              label: 'Tension estimée',
              value: isConnected ? '${voltage.toStringAsFixed(2)} V' : '--',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _BatteryInfoRow(
              label: 'Autonomie restante',
              value: isConnected
                  ? (hours > 0 ? '~${hours}h ${mins}min' : '~$mins min')
                  : '--',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _BatteryInfoRow(
              label: 'Intensité actuelle',
              value: '${(intensity * 100).round()}%',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _BatteryInfoRow(
              label: 'Type de batterie',
              value: 'Powerbank 4.7V',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            const SizedBox(height: 16),
            // Note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'L\'autonomie est une estimation basée sur l\'intensité actuelle. '
                      'Elle peut varier selon le programme utilisé.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Firmware Bottom Sheet ────────────────────────────────────────
  void _showFirmwareSheet(
    BuildContext context,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Container(
            color: bgColor,
            child: Column(
              children: [
                // Drag handle + header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.cpu, size: 20, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Firmware',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Version actuelle : v4.1',
                                style: GoogleFonts.poppins(fontSize: 12, color: textSecondary),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'À jour',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: textSecondary.withValues(alpha: 0.2), height: 1),
                    ],
                  ),
                ),
                // Version history
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: [
                      Text(
                        'Historique des versions',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _FirmwareVersionTile(
                        version: 'v4.1',
                        date: 'Mars 2026',
                        isCurrent: true,
                        changes: const [
                          'Correction des problèmes de connexion Bluetooth pour XIAO ESP32C3',
                        ],
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      
                      const SizedBox(height: 16),
                      _FirmwareVersionTile(
                        version: 'v3.0',
                        date: 'Mars 2026',
                        isCurrent: true,
                        changes: const [
                          'Contrôle manuel avec grille moteurs 5×3',
                          'Protocole BLE 3 octets complet',
                          'Programmes de vibration (Vague, Pluie, Impulsion, Cercle)',
                          'Journal d\'utilisation avec Firebase',
                          'Sécurité biométrique et PIN',
                        ],
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _FirmwareVersionTile(
                        version: 'v2.1',
                        date: 'Février 2026',
                        changes: const [
                          'Support base de données Firebase',
                          'Authentification FaceID / TouchID',
                          'Services Bluetooth créés et connectés à l\'interface',
                          'Suppression des options codées en dur',
                        ],
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      _FirmwareVersionTile(
                        version: 'v1.0',
                        date: 'Janvier 2026',
                        changes: const [
                          'Première itération de l\'interface',
                          'Mise en place de l\'architecture de l\'application',
                        ],
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 16),
                      // ESP32 info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informations matériel',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _FirmwareInfoRow(label: 'Microcontrôleur', value: 'XIAO ESP32C3', textSecondary: textSecondary),
                            _FirmwareInfoRow(label: 'Grille moteurs', value: '5 × 3 (15 moteurs)', textSecondary: textSecondary),
                            _FirmwareInfoRow(label: 'Alimentation', value: 'Powerbank 4.7V', textSecondary: textSecondary),
                            _FirmwareInfoRow(label: 'Communication', value: 'BLE (Bluetooth Low Energy)', textSecondary: textSecondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLicensesBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Container(
            color: bgColor,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Text(
                        'Licences',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // License list
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    children: [
                      _LicenseTile(
                        name: 'Flutter',
                        license: 'BSD 3-Clause License',
                        url: 'https://flutter.dev',
                        textSecondary: textSecondary,
                      ),
                      _LicenseTile(
                        name: 'Firebase',
                        license: 'Apache License 2.0',
                        url: 'https://firebase.google.com',
                        textSecondary: textSecondary,
                      ),
                      _LicenseTile(
                        name: 'flutter_blue_plus',
                        license: 'BSD License',
                        url: 'https://pub.dev/packages/flutter_blue_plus',
                        textSecondary: textSecondary,
                      ),
                      _LicenseTile(
                        name: 'go_router',
                        license: 'BSD License',
                        url: 'https://pub.dev/packages/go_router',
                        textSecondary: textSecondary,
                      ),
                      _LicenseTile(
                        name: 'Riverpod',
                        license: 'MIT License',
                        url: 'https://pub.dev/packages/riverpod',
                        textSecondary: textSecondary,
                      ),
                      _LicenseTile(
                        name: 'fl_chart',
                        license: 'MIT License',
                        url: 'https://pub.dev/packages/fl_chart',
                        textSecondary: textSecondary,
                      ),
                      _LicenseTile(
                        name: 'Google Fonts',
                        license: 'Apache License 2.0',
                        url: 'https://fonts.google.com',
                        textSecondary: textSecondary,
                      ),
                      _LicenseTile(
                        name: 'lucide_icons',
                        license: 'ISC License',
                        url: 'https://pub.dev/packages/lucide_icons',
                        textSecondary: textSecondary,
                      ),
                      _LicenseTile(
                        name: 'local_auth',
                        license: 'BSD License',
                        url: 'https://pub.dev/packages/local_auth',
                        textSecondary: textSecondary,
                      ),
                      _LicenseTile(
                        name: 'shared_preferences',
                        license: 'BSD License',
                        url: 'https://pub.dev/packages/shared_preferences',
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Composants privés
// ══════════════════════════════════════════════════════════════

class _ProfileCard extends ConsumerStatefulWidget {
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const _ProfileCard({
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  // Controllers for all profile editing fields
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _newEmailController;
  late TextEditingController _emailPassController;
  late TextEditingController _currentPassController;
  late TextEditingController _newPassController;
  late TextEditingController _confirmPassController;

  String _displayName = 'Patient';
  String _firstName = '';
  String _lastName = '';

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _newEmailController = TextEditingController();
    _emailPassController = TextEditingController();
    _currentPassController = TextEditingController();
    _newPassController = TextEditingController();
    _confirmPassController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _newEmailController.dispose();
    _emailPassController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final data = doc.data();
      setState(() {
        _firstName = data?['firstName'] as String? ?? '';
        _lastName = data?['lastName'] as String? ?? '';
        final full = '$_firstName $_lastName'.trim();
        _displayName = full.isEmpty ? (user.email?.split('@')[0] ?? 'Patient') : full;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Patient';

    return GestureDetector(
      onTap: () => _showProfileSheet(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.cardColor,
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
                    _displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: widget.textPrimary,
                    ),
                  ),
                  Text(
                    email,
                    style: GoogleFonts.poppins(fontSize: 12, color: widget.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 20, color: widget.textSecondary),
          ],
        ),
      ),
    );
  }

  // ── Profile Bottom Sheet ──────────────────────────────────────

  void _showProfileSheet(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = widget.textPrimary;
    final textSecondary = widget.textSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        color: bgColor,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Row(
              children: [
                Text(
                  'Mon profil',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Section: Nom ──
            _ProfileSectionHeader(
              icon: LucideIcons.userCircle,
              title: 'Nom et prénom',
              textPrimary: textPrimary,
            ),
            const SizedBox(height: 12),
            _ProfileActionTile(
              label: 'Prénom',
              value: _firstName.isEmpty ? 'Non défini' : _firstName,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: widget.isDark,
              onTap: () => _showNameEditDialog(context),
            ),
            _ProfileActionTile(
              label: 'Nom',
              value: _lastName.isEmpty ? 'Non défini' : _lastName,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: widget.isDark,
              onTap: () => _showNameEditDialog(context),
            ),
            const SizedBox(height: 24),

            // ── Section: Email ──
            _ProfileSectionHeader(
              icon: LucideIcons.mail,
              title: 'Adresse email',
              textPrimary: textPrimary,
            ),
            const SizedBox(height: 12),
            _ProfileActionTile(
              label: 'Email',
              value: FirebaseAuth.instance.currentUser?.email ?? '--',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: widget.isDark,
              onTap: () => _showEmailChangeDialog(context),
            ),
            const SizedBox(height: 24),

            // ── Section: Mot de passe ──
            _ProfileSectionHeader(
              icon: LucideIcons.lock,
              title: 'Mot de passe',
              textPrimary: textPrimary,
            ),
            const SizedBox(height: 12),
            _ProfileActionTile(
              label: 'Mot de passe',
              value: '••••••••',
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: widget.isDark,
              onTap: () => _showPasswordChangeDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Name Edit Dialog ──────────────────────────────────────────

  void _showNameEditDialog(BuildContext context) {
    _firstNameController.text = _firstName;
    _lastNameController.text = _lastName;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(LucideIcons.userCircle, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Modifier le nom',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMsg != null) ...[
                  _ErrorBanner(message: errorMsg!),
                  const SizedBox(height: 16),
                ],
                _DialogTextField(
                  controller: _firstNameController,
                  hint: 'Prénom',
                  isDark: widget.isDark,
                ),
                const SizedBox(height: 12),
                _DialogTextField(
                  controller: _lastNameController,
                  hint: 'Nom',
                  isDark: widget.isDark,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final first = _firstNameController.text.trim();
                final last = _lastNameController.text.trim();
                if (first.isEmpty && last.isEmpty) {
                  setState(() => errorMsg = 'Veuillez remplir au moins un champ');
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({'firstName': first, 'lastName': last}, SetOptions(merge: true));

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  _loadUserData();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Nom mis à jour', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                } catch (e) {
                  setState(() => errorMsg = 'Erreur lors de la mise à jour');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Enregistrer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Email Change Dialog ───────────────────────────────────────

  void _showEmailChangeDialog(BuildContext context) {
    _newEmailController.clear();
    _emailPassController.clear();
    String? errorMsg;
    bool obscurePass = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(LucideIcons.mail, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Changer l\'email',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Un email de vérification sera envoyé à la nouvelle adresse. '
                  'Vous devrez cliquer sur le lien pour confirmer le changement.',
                  style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                if (errorMsg != null) ...[
                  _ErrorBanner(message: errorMsg!),
                  const SizedBox(height: 16),
                ],
                _DialogTextField(
                  controller: _newEmailController,
                  hint: 'Nouvelle adresse email',
                  isDark: widget.isDark,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailPassController,
                  obscureText: obscurePass,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Mot de passe actuel',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => obscurePass = !obscurePass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newEmail = _newEmailController.text.trim();
                final password = _emailPassController.text;

                if (newEmail.isEmpty || password.isEmpty) {
                  setState(() => errorMsg = 'Tous les champs sont requis');
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                try {
                  // Re-authenticate first
                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: password,
                  );
                  await user.reauthenticateWithCredential(credential);

                  // Send verification to new email
                  await user.verifyBeforeUpdateEmail(newEmail);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Un email de vérification a été envoyé à $newEmail. Vérifiez votre boîte de réception.',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  String msg;
                  switch (e.code) {
                    case 'wrong-password':
                    case 'invalid-credential':
                      msg = 'Mot de passe incorrect';
                      break;
                    case 'invalid-email':
                      msg = 'Adresse email invalide';
                      break;
                    case 'email-already-in-use':
                      msg = 'Cette adresse email est déjà utilisée';
                      break;
                    case 'requires-recent-login':
                      msg = 'Veuillez vous reconnecter avant de modifier l\'email';
                      break;
                    default:
                      msg = 'Erreur : ${e.code}';
                  }
                  setState(() => errorMsg = msg);
                } catch (e) {
                  setState(() => errorMsg = 'Erreur inattendue');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Envoyer la vérification', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Password Change Dialog ────────────────────────────────────

  void _showPasswordChangeDialog(BuildContext context) {
    _currentPassController.clear();
    _newPassController.clear();
    _confirmPassController.clear();

    bool obscureCurrentPass = true;
    bool obscureNewPass = true;
    bool obscureConfirmPass = true;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(LucideIcons.lock, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Changer le mot de passe',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMsg != null) ...[
                  _ErrorBanner(message: errorMsg!),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _currentPassController,
                  obscureText: obscureCurrentPass,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Mot de passe actuel',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrentPass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => obscureCurrentPass = !obscureCurrentPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassController,
                  obscureText: obscureNewPass,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nouveau mot de passe',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => obscureNewPass = !obscureNewPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassController,
                  obscureText: obscureConfirmPass,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Confirmer le mot de passe',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => obscureConfirmPass = !obscureConfirmPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPass = _currentPassController.text;
                final newPass = _newPassController.text;
                final confirmPass = _confirmPassController.text;

                if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
                  setState(() => errorMsg = 'Tous les champs sont requis');
                  return;
                }
                if (newPass != confirmPass) {
                  setState(() => errorMsg = 'Les nouveaux mots de passe ne correspondent pas');
                  return;
                }
                if (newPass.length < 6) {
                  setState(() => errorMsg = 'Le mot de passe doit contenir au moins 6 caractères');
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    setState(() => errorMsg = 'Utilisateur non trouvé');
                    return;
                  }

                  final credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: currentPass,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPass);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Mot de passe mis à jour avec succès', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                } on FirebaseAuthException catch (e) {
                  String msg = 'Erreur lors de la mise à jour du mot de passe';
                  if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
                    msg = 'Le mot de passe actuel est incorrect';
                  } else if (e.code == 'weak-password') {
                    msg = 'Le nouveau mot de passe est trop faible';
                  }
                  setState(() => errorMsg = msg);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Mettre à jour', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile Sheet Helper Widgets ────────────────────────────────

class _ProfileSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color textPrimary;

  const _ProfileSectionHeader({
    required this.icon,
    required this.title,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
    required this.onTap,
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
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(fontSize: 11, color: textSecondary),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.pencil, size: 16, color: textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: GoogleFonts.poppins(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}

class _DialogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final TextInputType? keyboardType;

  const _DialogTextField({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

// ══════════════════════════════════════════════════════════════
// License Tile Widget
// ══════════════════════════════════════════════════════════════

class _LicenseTile extends StatelessWidget {
  final String name;
  final String license;
  final String url;
  final Color textSecondary;

  const _LicenseTile({
    required this.name,
    required this.license,
    required this.url,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: () {
          // Could add url_launcher to open links
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$name: $license',
                style: GoogleFonts.poppins(),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              license,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              color: textSecondary.withValues(alpha: 0.2),
              height: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Battery Sheet Helper
// ══════════════════════════════════════════════════════════════

class _BatteryInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textPrimary;
  final Color textSecondary;

  const _BatteryInfoRow({
    required this.label,
    required this.value,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, color: textSecondary),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Firmware Sheet Helpers
// ══════════════════════════════════════════════════════════════

class _FirmwareVersionTile extends StatelessWidget {
  final String version;
  final String date;
  final bool isCurrent;
  final List<String> changes;
  final Color textPrimary;
  final Color textSecondary;

  const _FirmwareVersionTile({
    required this.version,
    required this.date,
    this.isCurrent = false,
    required this.changes,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrent ? AppColors.primary : textSecondary.withValues(alpha: 0.3),
                  border: isCurrent
                      ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 3)
                      : null,
                ),
              ),
              Container(
                width: 2,
                height: 80,
                color: textSecondary.withValues(alpha: 0.15),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      version,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? AppColors.primary : textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: GoogleFonts.poppins(fontSize: 12, color: textSecondary),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'actuelle',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                ...changes.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: textSecondary.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FirmwareInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color textSecondary;

  const _FirmwareInfoRow({
    required this.label,
    required this.value,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: textSecondary)),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
