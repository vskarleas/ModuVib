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
            ),
            _SettingsTile(
              icon: LucideIcons.refreshCw,
              title: 'Firmware',
              subtitle: 'v2.1.3',
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
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
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
  late TextEditingController currentPassController;
  late TextEditingController newPassController;
  late TextEditingController confirmPassController;

  @override
  void initState() {
    super.initState();
    currentPassController = TextEditingController();
    newPassController = TextEditingController();
    confirmPassController = TextEditingController();
  }

  @override
  void dispose() {
    currentPassController.dispose();
    newPassController.dispose();
    confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Patient';

    return FutureBuilder<String>(
      future: user != null 
        ? FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
            final firstName = doc.data()?['firstName'] as String? ?? '';
            final lastName = doc.data()?['lastName'] as String? ?? '';
            return '$firstName $lastName'.trim().isEmpty 
              ? email.split('@')[0] 
              : '$firstName $lastName'.trim();
          })
        : Future.value('Patient'),
      builder: (context, snapshot) {
        final displayName = snapshot.data ?? 'Patient';

        return GestureDetector(
          onTap: () => _showPasswordChangeDialog(context),
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
                        displayName,
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
      },
    );
  }

  void _showPasswordChangeDialog(BuildContext context) {
    // Clear controllers at start
    currentPassController.clear();
    newPassController.clear();
    confirmPassController.clear();

    bool obscureCurrentPass = true;
    bool obscureNewPass = true;
    bool obscureConfirmPass = true;
    String? errorMsg;

    Future<void> handlePasswordChange(
      BuildContext ctx,
      StateSetter setState,
      String currentPass,
      String newPass,
      String confirmPass,
    ) async {
      // Validation
      if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
        setState(() {
          errorMsg = 'Tous les champs sont requis';
        });
        return;
      }

      if (newPass != confirmPass) {
        setState(() {
          errorMsg = 'Les nouveaux mots de passe ne correspondent pas';
        });
        return;
      }

      if (newPass.length < 6) {
        setState(() {
          errorMsg = 'Le mot de passe doit contenir au moins 6 caractères';
        });
        return;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          setState(() {
            errorMsg = 'Utilisateur non trouvé';
          });
          return;
        }

        // Re-authenticate with current password
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPass,
        );

        await user.reauthenticateWithCredential(credential);

        // Update password
        await user.updatePassword(newPass);

        if (ctx.mounted) {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                'Mot de passe mis à jour avec succès',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String msg = 'Erreur lors de la mise à jour du mot de passe';
        if (e.code == 'wrong-password') {
          msg = 'Le mot de passe actuel est incorrect';
        } else if (e.code == 'weak-password') {
          msg = 'Le nouveau mot de passe est trop faible';
        }
        setState(() {
          errorMsg = msg;
        });
      }
    }

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
                // Error message
                if (errorMsg != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      errorMsg!,
                      style: GoogleFonts.poppins(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Current password
                TextField(
                  controller: currentPassController,
                  obscureText: obscureCurrentPass,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Mot de passe actuel',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrentPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => obscureCurrentPass = !obscureCurrentPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),

                // New password
                TextField(
                  controller: newPassController,
                  obscureText: obscureNewPass,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Nouveau mot de passe',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => obscureNewPass = !obscureNewPass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),

                // Confirm password
                TextField(
                  controller: confirmPassController,
                  obscureText: obscureConfirmPass,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Confirmer le mot de passe',
                    hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
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
              child: Text(
                'Annuler',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => handlePasswordChange(
                ctx,
                setState,
                currentPassController.text,
                newPassController.text,
                confirmPassController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Mettre à jour',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
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
