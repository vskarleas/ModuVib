import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/ble_protocol.dart';

// ══════════════════════════════════════════════════════════════
// MANUAL CONTROL SCREEN — Contrôle interactif des moteurs
// ══════════════════════════════════════════════════════════════

void _showNotConnected(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(LucideIcons.bluetoothOff, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Appareil non connecté — commande non envoyée',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.orange.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ),
  );
}

/// Labels pour la grille 5×3 (15 moteurs)
const _kMotorLabels = [
  'M1', 'M2', 'M3',
  'M4', 'M5', 'M6',
  'M7', 'M8', 'M9',
  'M10', 'M11', 'M12',
  'M13', 'M14', 'M15',
];

class ManualControlScreen extends ConsumerStatefulWidget {
  const ManualControlScreen({super.key});

  @override
  ConsumerState<ManualControlScreen> createState() =>
      _ManualControlScreenState();
}

class _ManualControlScreenState extends ConsumerState<ManualControlScreen> {
  /// Ensemble des moteurs sélectionnés (index 0–14)
  final Set<int> _selectedMotors = {};

  /// Mode multi-sélection
  bool _multiSelect = false;

  /// Retourne l'ID moteur BLE (0x01–0x0F) pour un index de grille (0–14)
  int _motorIdForIndex(int index) {
    return BleProtocol.motorGrid[index ~/ 3][index % 3];
  }

  Future<void> _toggleMotor(int index) async {
    final bleService = ref.read(bleServiceProvider);
    final intensity = ref.read(masterIntensityProvider);
    final motorId = _motorIdForIndex(index);

    if (_selectedMotors.contains(index)) {
      // Désactiver ce moteur spécifique
      bleService.sendCommand(
        BleProtocol.motorCommand(motorId, 0x00),
      );
      setState(() => _selectedMotors.remove(index));
    } else {
      // Envoyer la commande BLE — vérifier la connexion
      final byte = BleProtocol.intensityToByte(intensity);
      final sent = await bleService.sendCommand(
        BleProtocol.motorCommand(motorId, byte),
      );
      if (!sent) {
        if (mounted) _showNotConnected(context);
        return;
      }
      setState(() {
        // En mode simple, désélectionner les autres d'abord
        if (!_multiSelect && _selectedMotors.isNotEmpty) {
          for (final prevIndex in _selectedMotors) {
            bleService.sendCommand(
              BleProtocol.motorCommand(_motorIdForIndex(prevIndex), 0x00),
            );
          }
          _selectedMotors.clear();
        }
        _selectedMotors.add(index);
      });
      // Track session start
      if (ref.read(sessionStartTimeProvider) == null) {
        ref.read(sessionStartTimeProvider.notifier).state = DateTime.now();
      }
    }

    // Mettre à jour le provider des moteurs actifs
    final motors = <int, int>{};
    final byte = BleProtocol.intensityToByte(intensity);
    for (final i in _selectedMotors) {
      motors[i] = byte;
    }
    ref.read(activeMotorsProvider.notifier).state = motors;
    ref.read(motorsRunningProvider.notifier).state = _selectedMotors.isNotEmpty;

    HapticFeedback.lightImpact();
  }

  Future<void> _stopAll() async {
    final bleService = ref.read(bleServiceProvider);
    // Arrêt de tous les moteurs sélectionnés
    bleService.sendCommand(BleProtocol.stopCommand());
    // Log session to Firebase
    final startTime = ref.read(sessionStartTimeProvider);
    final intensity = ref.read(masterIntensityProvider);
    await ref.read(sessionServiceProvider).logCurrentSession(
      startTime: startTime,
      meanIntensity: intensity,
    );
    ref.read(sessionStartTimeProvider.notifier).state = null;
    ref.invalidate(sessionHistoryProvider);

    setState(() => _selectedMotors.clear());
    ref.read(activeMotorsProvider.notifier).state = {};
    ref.read(motorsRunningProvider.notifier).state = false;
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary =
        isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary =
        isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────
            Text(
              'Contrôle Manuel',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sélectionnez les moteurs à activer',
              style:
                  GoogleFonts.poppins(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 16),

            // ── Toggle multi-sélection ─────────────────────────
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _ModeTab(
                    label: 'Simple',
                    icon: LucideIcons.mousePointer,
                    isSelected: !_multiSelect,
                    isDark: isDark,
                    onTap: () => setState(() {
                      _multiSelect = false;
                      // Garder au plus un moteur sélectionné
                      if (_selectedMotors.length > 1) {
                        final keep = _selectedMotors.first;
                        _selectedMotors
                          ..clear()
                          ..add(keep);
                      }
                    }),
                  ),
                  _ModeTab(
                    label: 'Multi-sélection',
                    icon: LucideIcons.layers,
                    isSelected: _multiSelect,
                    isDark: isDark,
                    onTap: () => setState(() => _multiSelect = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Grille des moteurs 5×3 ─────────────────────────
            Text(
              'GRILLE DORSALE',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _MotorGrid(
              selectedMotors: _selectedMotors,
              onTapMotor: _toggleMotor,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              isDark: isDark,
            ),
            const SizedBox(height: 20),

            // ── Octets envoyés (debug) ─────────────────────────
            _CommandPreview(
              selectedMotors: _selectedMotors,
              isDark: isDark,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              cardColor: cardColor,
            ),
            const SizedBox(height: 20),

            // ── Bouton tout arrêter ────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _selectedMotors.isEmpty ? null : _stopAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.error.withValues(alpha: 0.3),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(LucideIcons.square, size: 18),
                label: Text(
                  'Tout arrêter',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
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
}

// ══════════════════════════════════════════════════════════════
// Tab de mode (Simple / Multi)
// ══════════════════════════════════════════════════════════════

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg = isDark ? const Color(0xFF333333) : Colors.white;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Grille 5×3 des moteurs
// ══════════════════════════════════════════════════════════════

class _MotorGrid extends StatelessWidget {
  final Set<int> selectedMotors;
  final ValueChanged<int> onTapMotor;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const _MotorGrid({
    required this.selectedMotors,
    required this.onTapMotor,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.divider.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          // Indicateur rangées
          Row(
            children: [
              const Icon(LucideIcons.layoutGrid,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '5 rangées × 3 colonnes',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${selectedMotors.length}/15',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Grille
          for (int row = 0; row < 5; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int col = 0; col < 3; col++) ...[
                  if (col > 0) const SizedBox(width: 10),
                  _MotorButton(
                    index: row * 3 + col,
                    label: _kMotorLabels[row * 3 + col],
                    isSelected:
                        selectedMotors.contains(row * 3 + col),
                    onTap: () => onTapMotor(row * 3 + col),
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Légende
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  label: 'Inactif',
                  textColor: textSecondary),
              const SizedBox(width: 20),
              _LegendDot(
                  color: AppColors.primary,
                  label: 'Actif',
                  textColor: textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bouton moteur individuel ─────────────────────────────────

class _MotorButton extends StatelessWidget {
  final int index;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _MotorButton({
    required this.index,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : isDark
                  ? const Color(0xFF2A2A2A)
                  : AppColors.backgroundAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.divider.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? LucideIcons.zap : LucideIcons.circle,
              size: 24,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Légende ──────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: textColor),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Aperçu des commandes envoyées (debug)
// ══════════════════════════════════════════════════════════════

class _CommandPreview extends StatelessWidget {
  final Set<int> selectedMotors;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardColor;

  const _CommandPreview({
    required this.selectedMotors,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppColors.divider.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.terminal,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Octets BLE',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (selectedMotors.isEmpty)
            Text(
              'Aucun moteur sélectionné',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: textSecondary,
              ),
            )
          else
            ...selectedMotors.map((i) {
              final motorId =
                  BleProtocol.motorGrid[i ~/ 3][i % 3];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _kMotorLabels[i],
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '→  0x${BleProtocol.cmdMotor.toRadixString(16).padLeft(2, '0').toUpperCase()}  '
                      '0x${motorId.toRadixString(16).padLeft(2, '0').toUpperCase()}  '
                      '0xFF',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                        fontFeatures: [
                          const FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
