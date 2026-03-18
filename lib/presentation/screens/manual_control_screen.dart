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

class ManualControlScreen extends ConsumerStatefulWidget {
  const ManualControlScreen({super.key});

  @override
  ConsumerState<ManualControlScreen> createState() =>
      _ManualControlScreenState();
}

class _ManualControlScreenState extends ConsumerState<ManualControlScreen> {
  /// Ensemble des moteurs sélectionnés (flat index 0–14)
  final Set<int> _selectedMotors = {};

  /// true = Précision (single), false = Dessin Libre (multi)
  bool _precisionMode = true;

  /// Convert flat index (0–14) to motor ID using the variable-width grid.
  int _motorIdForIndex(int flatIndex) {
    int offset = 0;
    for (int row = 0; row < BleProtocol.motorGrid.length; row++) {
      final rowLen = BleProtocol.motorGrid[row].length;
      if (flatIndex < offset + rowLen) {
        return BleProtocol.motorGrid[row][flatIndex - offset];
      }
      offset += rowLen;
    }
    return 0x01;
  }

  Future<void> _toggleMotor(int index) async {
    final bleService = ref.read(bleServiceProvider);
    final intensity = ref.read(masterIntensityProvider);
    final motorId = _motorIdForIndex(index);

    if (_selectedMotors.contains(index)) {
      bleService.sendCommand(
        BleProtocol.motorCommand(motorId, 0x00),
      );
      setState(() => _selectedMotors.remove(index));
    } else {
      final byte = BleProtocol.intensityToByte(intensity);
      final sent = await bleService.sendCommand(
        BleProtocol.motorCommand(motorId, byte),
      );
      if (!sent) {
        if (mounted) _showNotConnected(context);
        return;
      }
      setState(() {
        // En mode Précision, désélectionner les autres d'abord
        if (_precisionMode && _selectedMotors.isNotEmpty) {
          for (final prevIndex in _selectedMotors) {
            bleService.sendCommand(
              BleProtocol.motorCommand(_motorIdForIndex(prevIndex), 0x00),
            );
          }
          _selectedMotors.clear();
        }
        _selectedMotors.add(index);
      });
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
    bleService.sendCommand(BleProtocol.stopCommand());
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
    final intensity = ref.watch(masterIntensityProvider);
    final intensityPercent = (intensity * 100).round();

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
              'Touchez le dos pour activer les moteurs',
              style:
                  GoogleFonts.poppins(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 16),

            // ── Mode tabs ─────────────────────────────────────
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
                    label: 'Précision',
                    icon: LucideIcons.crosshair,
                    isSelected: _precisionMode,
                    isDark: isDark,
                    onTap: () => setState(() {
                      _precisionMode = true;
                      if (_selectedMotors.length > 1) {
                        final keep = _selectedMotors.first;
                        _selectedMotors
                          ..clear()
                          ..add(keep);
                      }
                    }),
                  ),
                  _ModeTab(
                    label: 'Dessin Libre',
                    icon: LucideIcons.penTool,
                    isSelected: !_precisionMode,
                    isDark: isDark,
                    onTap: () => setState(() => _precisionMode = false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Torso card with motors ────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppColors.divider.withValues(alpha: 0.2)),
              ),
              child: CustomPaint(
                painter: _TorsoPainter(isDark: isDark),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 28, horizontal: 4),
                  child: _buildMotorRows(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Status bar ────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.divider.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.activity,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_selectedMotors.length} moteur${_selectedMotors.length != 1 ? "s" : ""} actif${_selectedMotors.length != 1 ? "s" : ""}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Intensité : $intensityPercent%',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Bouton tout arrêter ──────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _selectedMotors.isEmpty ? null : _stopAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade300,
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

  /// Builds the variable-width motor rows from BleProtocol.motorGrid
  Widget _buildMotorRows() {
    final rows = <Widget>[];
    int flatIndex = 0;

    for (int row = 0; row < BleProtocol.motorGrid.length; row++) {
      if (row > 0) rows.add(const SizedBox(height: 10));
      final rowMotors = BleProtocol.motorGrid[row];
      final motorWidgets = <Widget>[];

      for (int col = 0; col < rowMotors.length; col++) {
        if (col > 0) motorWidgets.add(const SizedBox(width: 10));
        final idx = flatIndex;
        motorWidgets.add(
          _MotorDot(
            motorId: rowMotors[col],
            isSelected: _selectedMotors.contains(idx),
            onTap: () => _toggleMotor(idx),
          ),
        );
        flatIndex++;
      }

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: motorWidgets,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Torso background painter
// ══════════════════════════════════════════════════════════════

class _TorsoPainter extends CustomPainter {
  final bool isDark;
  _TorsoPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();

    // Top center (neck)
    path.moveTo(w * 0.36, h * 0.01);
    path.quadraticBezierTo(w * 0.50, 0, w * 0.64, h * 0.01);

    // Right shoulder
    path.quadraticBezierTo(w * 0.82, h * 0.03, w * 0.90, h * 0.10);
    path.quadraticBezierTo(w * 0.95, h * 0.16, w * 0.92, h * 0.25);

    // Right side (upper back → waist)
    path.quadraticBezierTo(w * 0.88, h * 0.40, w * 0.84, h * 0.52);
    path.quadraticBezierTo(w * 0.80, h * 0.64, w * 0.76, h * 0.72);

    // Right lower (hip → bottom)
    path.quadraticBezierTo(w * 0.70, h * 0.84, w * 0.62, h * 0.93);
    path.quadraticBezierTo(w * 0.56, h * 0.98, w * 0.50, h);

    // Left lower
    path.quadraticBezierTo(w * 0.44, h * 0.98, w * 0.38, h * 0.93);
    path.quadraticBezierTo(w * 0.30, h * 0.84, w * 0.24, h * 0.72);

    // Left side (waist → upper back)
    path.quadraticBezierTo(w * 0.20, h * 0.64, w * 0.16, h * 0.52);
    path.quadraticBezierTo(w * 0.12, h * 0.40, w * 0.08, h * 0.25);

    // Left shoulder
    path.quadraticBezierTo(w * 0.05, h * 0.16, w * 0.10, h * 0.10);
    path.quadraticBezierTo(w * 0.18, h * 0.03, w * 0.36, h * 0.01);

    path.close();

    // Fill
    final fillPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1A2030)
          : AppColors.primary.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border
    final strokePaint = Paint()
      ..color = isDark
          ? AppColors.primary.withValues(alpha: 0.15)
          : AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
// Tab de mode (Précision / Dessin Libre)
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
// Motor dot — circular button matching the torso image design
// ══════════════════════════════════════════════════════════════

class _MotorDot extends StatelessWidget {
  final int motorId;
  final bool isSelected;
  final VoidCallback onTap;

  const _MotorDot({
    required this.motorId,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const size = 52.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : isDark
                        ? const Color(0xFF252535)
                        : AppColors.primary.withValues(alpha: 0.06),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.primary.withValues(alpha: 0.18),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 16 : 10,
                  height: isSelected ? 16 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'M$motorId',
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
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
