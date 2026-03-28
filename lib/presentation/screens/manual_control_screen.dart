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

  /// Keys pour hit-testing pendant le drag
  final List<GlobalKey> _motorKeys = List.generate(15, (_) => GlobalKey());

  /// null = pas de drag en cours, true = on sélectionne, false = on désélectionne
  bool? _dragSelecting;

  /// Dernier index touché pendant le drag (pour éviter de re-toggler le même)
  int? _lastInteractedIndex;

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

  /// Retourne le flat index du moteur sous la position globale, ou null.
  int? _indexAtPosition(Offset globalPosition) {
    for (int i = 0; i < _motorKeys.length; i++) {
      final ctx = _motorKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = Rect.fromLTWH(
          topLeft.dx, topLeft.dy, box.size.width, box.size.height);
      if (rect.contains(globalPosition)) return i;
    }
    return null;
  }

  void _handlePointerDown(Offset globalPosition) {
    final index = _indexAtPosition(globalPosition);
    if (index == null) return;
    _dragSelecting = !_selectedMotors.contains(index);
    _lastInteractedIndex = index;
    if (_dragSelecting!) {
      _activateMotor(index);
    } else {
      _deactivateMotor(index);
    }
  }

  void _handlePointerMove(Offset globalPosition) {
    if (_dragSelecting == null) return;
    final index = _indexAtPosition(globalPosition);
    if (index == null || index == _lastInteractedIndex) return;
    _lastInteractedIndex = index;
    if (_dragSelecting! && !_selectedMotors.contains(index)) {
      _activateMotor(index);
    } else if (!_dragSelecting! && _selectedMotors.contains(index)) {
      _deactivateMotor(index);
    }
  }

  void _handlePointerUp() {
    _dragSelecting = null;
    _lastInteractedIndex = null;
  }

  Future<void> _activateMotor(int index) async {
    final bleService = ref.read(bleServiceProvider);
    final intensity = ref.read(masterIntensityProvider);
    final motorId = _motorIdForIndex(index);
    final byte = BleProtocol.intensityToByte(intensity);
    final sent =
        await bleService.sendCommand(BleProtocol.motorCommand(motorId, byte));
    if (!sent) {
      if (mounted) _showNotConnected(context);
      return;
    }
    setState(() => _selectedMotors.add(index));
    if (ref.read(sessionStartTimeProvider) == null) {
      ref.read(sessionStartTimeProvider.notifier).state = DateTime.now();
    }
    _updateMotorProviders();
    HapticFeedback.lightImpact();
  }

  Future<void> _deactivateMotor(int index) async {
    final bleService = ref.read(bleServiceProvider);
    final motorId = _motorIdForIndex(index);
    bleService.sendCommand(BleProtocol.motorCommand(motorId, 0x00));
    setState(() => _selectedMotors.remove(index));
    _updateMotorProviders();
    HapticFeedback.lightImpact();
  }

  void _updateMotorProviders() {
    final intensity = ref.read(masterIntensityProvider);
    final byte = BleProtocol.intensityToByte(intensity);
    final motors = <int, int>{};
    for (final i in _selectedMotors) {
      motors[i] = byte;
    }
    ref.read(activeMotorsProvider.notifier).state = motors;
    ref.read(motorsRunningProvider.notifier).state = _selectedMotors.isNotEmpty;
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
              'Touchez ou glissez pour activer les moteurs',
              style: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 20),

            // ── Torso card with motors ────────────────────────
            // GestureDetector claims horizontal drags so the parent PageView
            // does not swipe pages while the user is selecting motors.
            GestureDetector(
              onHorizontalDragStart: (_) {},
              onHorizontalDragUpdate: (_) {},
              onHorizontalDragEnd: (_) {},
              child: Listener(
              onPointerDown: (e) => _handlePointerDown(e.position),
              onPointerMove: (e) => _handlePointerMove(e.position),
              onPointerUp: (_) => _handlePointerUp(),
              onPointerCancel: (_) => _handlePointerUp(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.2)),
                ),
                child: CustomPaint(
                  painter: _TorsoPainter(isDark: isDark),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 4),
                    child: _buildMotorRows(),
                  ),
                ),
              ),
            )),
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
            key: _motorKeys[idx],
            motorId: rowMotors[col],
            isSelected: _selectedMotors.contains(idx),
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

    // Right lower (hip flare → bottom)
    path.quadraticBezierTo(w * 0.86, h * 0.80, w * 0.80, h * 0.90);
    path.quadraticBezierTo(w * 0.68, h * 0.97, w * 0.50, h);

    // Left lower
    path.quadraticBezierTo(w * 0.32, h * 0.97, w * 0.20, h * 0.90);
    path.quadraticBezierTo(w * 0.14, h * 0.80, w * 0.24, h * 0.72);

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
// Motor dot — purely visual, interaction handled by parent Listener
// ══════════════════════════════════════════════════════════════

class _MotorDot extends StatelessWidget {
  final int motorId;
  final bool isSelected;

  const _MotorDot({
    super.key,
    required this.motorId,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const size = 52.0;

    return SizedBox(
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
              color:
                  isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
