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

/// Positions relatives (0-1) des 24 moteurs sur la silhouette dorsale.
/// Distribution uniforme et symétrique couvrant toute la surface du dos.
const _kMotorPositions = <Offset>[
  // Rangée 1 : Nuque (y=0.08) - 3 moteurs
  Offset(0.38, 0.08), // 0
  Offset(0.50, 0.08), // 1
  Offset(0.62, 0.08), // 2
  
  // Rangée 2 : Haut épaules (y=0.19) - 5 moteurs
  Offset(0.24, 0.19), // 3
  Offset(0.37, 0.19), // 4
  Offset(0.50, 0.19), // 5
  Offset(0.63, 0.19), // 6
  Offset(0.76, 0.19), // 7
  
  // Rangée 3 : Milieu épaules (y=0.31) - 5 moteurs
  Offset(0.22, 0.31), // 8
  Offset(0.36, 0.31), // 9
  Offset(0.50, 0.31), // 10
  Offset(0.64, 0.31), // 11
  Offset(0.78, 0.31), // 12
  
  // Rangée 4 : Haut du dos (y=0.45) - 5 moteurs
  Offset(0.26, 0.45), // 13
  Offset(0.38, 0.45), // 14
  Offset(0.50, 0.45), // 15
  Offset(0.62, 0.45), // 16
  Offset(0.74, 0.45), // 17
  
  // Rangée 5 : Milieu-bas du dos (y=0.60) - 4 moteurs
  Offset(0.32, 0.60), // 18
  Offset(0.44, 0.60), // 19
  Offset(0.56, 0.60), // 20
  Offset(0.68, 0.60), // 21
  
  // Rangée 6 : Lombaires (y=0.74) - 2 moteurs
  Offset(0.42, 0.74), // 22
  Offset(0.58, 0.74), // 23
];

const _kMotorLabels = [
  'M1', 'M2', 'M3', 'M4',
  'M5', 'M6', 'M7', 'M8', 'M9',
  'M10', 'M11', 'M12', 'M13', 'M14', 'M15',
  'M16', 'M17', 'M18', 'M19', 'M20',
  'M21', 'M22', 'M23', 'M24',
];

/// Mode de contrôle.
enum _ControlMode { precision, dessinLibre }

final _controlModeProvider =
    StateProvider<_ControlMode>((ref) => _ControlMode.precision);

// ══════════════════════════════════════════════════════════════

class ManualControlScreen extends ConsumerWidget {
  const ManualControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(_controlModeProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

    return SafeArea(
      top: false,
      bottom: false,
      child: Column(
        children: [
          // ── En-tête ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  style: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
                ),
                const SizedBox(height: 14),
                _ModeToggle(mode: mode, isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Zone interactive ───────────────────────────────
          Expanded(
            child: mode == _ControlMode.precision
                ? const _BackInteractive()
                : const _ScratchpadMode(),
          ),

          // ── Barre de statut ────────────────────────────────
          const _MotorStatusBar(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Toggle Précision / Dessin Libre
// ══════════════════════════════════════════════════════════════

class _ModeToggle extends ConsumerWidget {
  final _ControlMode mode;
  final bool isDark;
  const _ModeToggle({required this.mode, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ToggleTab(
            label: 'Précision',
            icon: LucideIcons.crosshair,
            isSelected: mode == _ControlMode.precision,
            isDark: isDark,
            onTap: () =>
                ref.read(_controlModeProvider.notifier).state = _ControlMode.precision,
          ),
          _ToggleTab(
            label: 'Dessin Libre',
            icon: LucideIcons.penTool,
            isSelected: mode == _ControlMode.dessinLibre,
            isDark: isDark,
            onTap: () =>
                ref.read(_controlModeProvider.notifier).state = _ControlMode.dessinLibre,
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ToggleTab({
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
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
// Mode Précision — Silhouette dorsale interactive
// ══════════════════════════════════════════════════════════════

class _BackInteractive extends ConsumerStatefulWidget {
  const _BackInteractive();

  @override
  ConsumerState<_BackInteractive> createState() => _BackInteractiveState();
}

class _BackInteractiveState extends ConsumerState<_BackInteractive> {
  Offset? _touchPosition;

  @override
  Widget build(BuildContext context) {
    final activeMotors = ref.watch(activeMotorsProvider);
    final radius = ref.watch(activationRadiusProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: AspectRatio(
          aspectRatio: 0.7,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return GestureDetector(
                onScaleStart: (d) => _onTouch(d.localFocalPoint, size),
                onScaleUpdate: (d) {
                  _onTouch(d.localFocalPoint, size);
                  if (d.pointerCount >= 2) {
                    final newRadius = (d.scale * 1.0).clamp(0.5, 4.0);
                    ref.read(activationRadiusProvider.notifier).state = newRadius;
                  }
                },
                onScaleEnd: (_) => _onRelease(),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundAlt,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _BackPainter(
                      activeMotors: activeMotors,
                      touchPosition: _touchPosition,
                      activationRadius: radius,
                    ),
                    size: Size.infinite,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _onTouch(Offset localPos, Size size) {
    final clampedPos = Offset(
      localPos.dx.clamp(0.0, size.width),
      localPos.dy.clamp(0.0, size.height),
    );
    final rel = Offset(clampedPos.dx / size.width, clampedPos.dy / size.height);
    setState(() => _touchPosition = rel);

    final radius = ref.read(activationRadiusProvider);
    final master = ref.read(masterIntensityProvider);
    final maxT = ref.read(maxIntensityThresholdProvider);
    final effectiveMax = master.clamp(0.0, maxT);
    final activationDist = 0.12 * radius;

    final motors = <int, int>{};
    for (int i = 0; i < _kMotorPositions.length; i++) {
      final dist = (rel - _kMotorPositions[i]).distance;
      if (dist < activationDist) {
        final factor = 1.0 - (dist / activationDist);
        motors[i] = BleProtocol.intensityToByte(effectiveMax * factor);
      }
    }

    if (motors.isNotEmpty) {
      ref.read(activeMotorsProvider.notifier).state = motors;
      HapticFeedback.lightImpact();
    }
  }

  void _onRelease() {
    setState(() => _touchPosition = null);
    ref.read(activeMotorsProvider.notifier).state = {};
  }
}

// ── Peintre de la silhouette dorsale ─────────────────────────

class _BackPainter extends CustomPainter {
  final Map<int, int> activeMotors;
  final Offset? touchPosition;
  final double activationRadius;

  _BackPainter({
    required this.activeMotors,
    required this.touchPosition,
    required this.activationRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Silhouette du torse élargie
    final torsoPath = Path()
      ..moveTo(cx - size.width * 0.35, size.height * 0.05)
      ..quadraticBezierTo(
          cx - size.width * 0.42, size.height * 0.25,
          cx - size.width * 0.40, size.height * 0.45)
      ..quadraticBezierTo(
          cx - size.width * 0.30, size.height * 0.68,
          cx - size.width * 0.18, size.height * 0.82)
      ..quadraticBezierTo(
          cx - size.width * 0.08, size.height * 0.88,
          cx, size.height * 0.86)
      ..quadraticBezierTo(
          cx + size.width * 0.08, size.height * 0.88,
          cx + size.width * 0.18, size.height * 0.82)
      ..quadraticBezierTo(
          cx + size.width * 0.30, size.height * 0.68,
          cx + size.width * 0.40, size.height * 0.45)
      ..quadraticBezierTo(
          cx + size.width * 0.42, size.height * 0.25,
          cx + size.width * 0.35, size.height * 0.05)
      ..quadraticBezierTo(
          cx, size.height * 0.01,
          cx - size.width * 0.35, size.height * 0.05)
      ..close();

    canvas.drawPath(
      torsoPath,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.07)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      torsoPath,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Colonne vertébrale
    final spinePath = Path()
      ..moveTo(cx, size.height * 0.04)
      ..quadraticBezierTo(cx, size.height * 0.45, cx, size.height * 0.84);
    canvas.drawPath(
      spinePath,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Moteurs
    for (int i = 0; i < _kMotorPositions.length; i++) {
      final pos = Offset(
        _kMotorPositions[i].dx * size.width,
        _kMotorPositions[i].dy * size.height,
      );
      final isActive = activeMotors.containsKey(i);
      final intensity = isActive ? activeMotors[i]! / 255.0 : 0.0;

      if (isActive) {
        canvas.drawCircle(
          pos,
          18 * intensity + 8,
          Paint()
            ..color = AppColors.primary.withValues(alpha: 0.3 * intensity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * intensity),
        );
      }

      canvas.drawCircle(
        pos,
        14,
        Paint()
          ..color = isActive
              ? AppColors.primary.withValues(alpha: 0.2 + 0.3 * intensity)
              : AppColors.primary.withValues(alpha: 0.06),
      );
      canvas.drawCircle(
        pos,
        14,
        Paint()
          ..color = isActive
              ? AppColors.primary.withValues(alpha: 0.5 + 0.5 * intensity)
              : AppColors.primary.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        pos,
        5,
        Paint()
          ..color = isActive
              ? AppColors.primary.withValues(alpha: 0.6 + 0.4 * intensity)
              : AppColors.primary.withValues(alpha: 0.2),
      );

      // Étiquette
      final tp = TextPainter(
        text: TextSpan(
          text: _kMotorLabels[i],
          style: TextStyle(
            fontSize: 9,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.9)
                : AppColors.textSecondary.withValues(alpha: 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + 18));
    }

    // Indicateur tactile
    if (touchPosition != null) {
      final tp = Offset(
        touchPosition!.dx * size.width,
        touchPosition!.dy * size.height,
      );
      final r = 12 * activationRadius + 8;
      canvas.drawCircle(
        tp,
        r,
        Paint()..color = AppColors.primary.withValues(alpha: 0.15),
      );
      canvas.drawCircle(
        tp,
        r,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackPainter old) =>
      old.activeMotors != activeMotors ||
      old.touchPosition != touchPosition ||
      old.activationRadius != activationRadius;
}

// ══════════════════════════════════════════════════════════════
// Mode Dessin Libre (Scratchpad) — zone clippée
// ══════════════════════════════════════════════════════════════

class _ScratchpadMode extends ConsumerStatefulWidget {
  const _ScratchpadMode();

  @override
  ConsumerState<_ScratchpadMode> createState() => _ScratchpadModeState();
}

class _ScratchpadModeState extends ConsumerState<_ScratchpadMode> {
  final List<Offset> _points = [];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvasColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: GestureDetector(
                    onPanStart: (d) => _onDraw(d.localPosition, size),
                    onPanUpdate: (d) => _onDraw(d.localPosition, size),
                    onPanEnd: (_) => _onRelease(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: canvasColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.divider.withValues(alpha: 0.3),
                        ),
                      ),
                      child: CustomPaint(
                        painter: _ScratchPainter(points: _points),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => setState(() => _points.clear()),
            icon: const Icon(LucideIcons.eraser, size: 16),
            label: Text('Effacer', style: GoogleFonts.poppins(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _onDraw(Offset position, Size size) {
    // Restreindre les points à l'intérieur de la zone
    final clamped = Offset(
      position.dx.clamp(0.0, size.width),
      position.dy.clamp(0.0, size.height),
    );
    setState(() => _points.add(clamped));

    final relPos = Offset(clamped.dx / size.width, clamped.dy / size.height);
    final master = ref.read(masterIntensityProvider);
    final motors = <int, int>{};

    for (int i = 0; i < _kMotorPositions.length; i++) {
      final dist = (relPos - _kMotorPositions[i]).distance;
      if (dist < 0.2) {
        final factor = 1.0 - (dist / 0.2);
        motors[i] = BleProtocol.intensityToByte(master * factor);
      }
    }

    if (motors.isNotEmpty) {
      ref.read(activeMotorsProvider.notifier).state = motors;
      HapticFeedback.selectionClick();
    }
  }

  void _onRelease() {
    ref.read(activeMotorsProvider.notifier).state = {};
  }
}

class _ScratchPainter extends CustomPainter {
  final List<Offset> points;
  _ScratchPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'Griffonnez ici !\nLes moteurs suivront votre dessin',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
            height: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width * 0.7);
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2),
      );
      return;
    }

    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    for (final p in points) {
      canvas.drawCircle(p, 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScratchPainter old) =>
      old.points.length != points.length;
}

// ══════════════════════════════════════════════════════════════
// Barre de statut des moteurs
// ══════════════════════════════════════════════════════════════

class _MotorStatusBar extends ConsumerWidget {
  const _MotorStatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMotors = ref.watch(activeMotorsProvider);
    final radius = ref.watch(activationRadiusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final count = activeMotors.length;
    final avgIntensity = activeMotors.isEmpty
        ? 0
        : (activeMotors.values.reduce((a, b) => a + b) / count).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: count > 0
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.backgroundAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              count > 0 ? LucideIcons.activity : LucideIcons.hand,
              size: 18,
              color: count > 0 ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count > 0
                      ? '$count moteur${count > 1 ? 's' : ''} actif${count > 1 ? 's' : ''}'
                      : 'Touchez le dos pour stimuler',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  count > 0
                      ? 'Intensité : ${(avgIntensity / 255 * 100).round()}% — Rayon : ${radius.toStringAsFixed(1)}x'
                      : 'Pincez pour modifier la zone',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
