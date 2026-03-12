import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/app_providers.dart';

// ══════════════════════════════════════════════════════════════
// TOP BAR — Barre supérieure persistante
// ══════════════════════════════════════════════════════════════

class NeuroTopBar extends ConsumerWidget {
  final String title;
  const NeuroTopBar({super.key, this.title = 'NeuroSense'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = ref.watch(batteryLevelProvider);
    final bleState = ref.watch(bleConnectionProvider);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 4,
            left: 20,
            right: 12,
            bottom: 10,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .scaffoldBackgroundColor
                .withValues(alpha: 0.85),
            border: Border(
              bottom: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              _BatteryChip(level: battery),
              const SizedBox(width: 8),
              _BleIcon(state: bleState),
              const SizedBox(width: 8),
              _StopButton(
                onPressed: () => _triggerEmergencyStop(ref, context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerEmergencyStop(WidgetRef ref, BuildContext context) {
    ref.read(emergencyStopProvider.notifier).state = true;
    ref.read(activeMotorsProvider.notifier).state = {};
    ref.read(activePatternProvider.notifier).state = null;
    ref.read(patternTimerSecondsProvider.notifier).state = null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.shieldAlert, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'ARRÊT D\'URGENCE — Tous les moteurs coupés',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      ref.read(emergencyStopProvider.notifier).state = false;
    });
  }
}

// ── Chip Batterie ────────────────────────────────────────────

class _BatteryChip extends StatelessWidget {
  final int level;
  const _BatteryChip({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level > 20 ? AppColors.primary : AppColors.error;
    final icon = level > 50
        ? LucideIcons.batteryFull
        : level > 20
            ? LucideIcons.batteryMedium
            : LucideIcons.batteryLow;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$level%',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Icône Bluetooth ──────────────────────────────────────────

class _BleIcon extends StatelessWidget {
  final BleConnectionState state;
  const _BleIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      BleConnectionState.connected => (AppColors.primary, LucideIcons.bluetooth),
      BleConnectionState.connecting => (Colors.orange, LucideIcons.bluetoothSearching),
      BleConnectionState.error => (AppColors.error, LucideIcons.bluetoothOff),
      BleConnectionState.disconnected => (AppColors.textSecondary, LucideIcons.bluetoothOff),
    };

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

// ── Bouton STOP d'urgence ────────────────────────────────────

class _StopButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StopButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: const SizedBox(
          width: 34,
          height: 34,
          child: Icon(LucideIcons.octagon, size: 18, color: AppColors.error),
        ),
      ),
    );
  }
}
