import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/ble_protocol.dart';

// ══════════════════════════════════════════════════════════════
// DASHBOARD SCREEN — Tableau de bord ModuVib
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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Titre ──────────────────────────────────────────
            Text(
              'Tableau de bord',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vue d\'ensemble de votre ModuVib',
              style: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 20),

            // ── État du système ────────────────────────────────
            _SystemStatusCard(isDark: isDark),
            const SizedBox(height: 24),

            // ── Intensité globale ──────────────────────────────
            Text(
              'INTENSITÉ GLOBALE',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _MasterIntensitySlider(isDark: isDark),
            const SizedBox(height: 24),

            // ── Autonomie estimée ──────────────────────────────
            Text(
              'AUTONOMIE',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _BatteryEstimation(isDark: isDark),
            const SizedBox(height: 24),

            // ── Journal d'utilisation ──────────────────────────
            Text(
              'JOURNAL D\'UTILISATION',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _AnalyticsChart(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// État du Système
// ══════════════════════════════════════════════════════════════

class _SystemStatusCard extends ConsumerWidget {
  final bool isDark;
  const _SystemStatusCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temp = ref.watch(vestTemperatureProvider);
    final voltage = ref.watch(vestVoltageProvider);
    final bleState = ref.watch(bleConnectionProvider);
    final battery = ref.watch(batteryLevelProvider);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;
    final isConnected = bleState == BleConnectionState.connected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.2)),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.activity, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                'État du Système',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              _ConnectionBadge(isConnected: isConnected),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatusItem(
                  icon: LucideIcons.thermometer,
                  label: 'Température',
                  value: '${temp.toStringAsFixed(1)}°C',
                  color: temp > 40 ? AppColors.error : AppColors.primary,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _StatusItem(
                  icon: LucideIcons.zap,
                  label: 'Voltage',
                  value: '${voltage.toStringAsFixed(1)}V',
                  color: voltage < 3.2 ? AppColors.error : AppColors.primary,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.divider.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _StatusItem(
                  icon: LucideIcons.battery,
                  label: 'Batterie',
                  value: isConnected ? '$battery%' : '--%',
                  color: !isConnected
                      ? AppColors.textSecondary
                      : (battery < 20 ? AppColors.error : AppColors.primary),
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ),
            ],
          ),
          // ── Connect button (only when disconnected) ──
          if (!isConnected) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: bleState == BleConnectionState.connecting
                    ? null
                    : () {
                        final bleService = ref.read(bleServiceProvider);
                        bleService.connect();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: bleState == BleConnectionState.connecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.bluetooth, size: 18),
                label: Text(
                  bleState == BleConnectionState.connecting
                      ? 'Connexion en cours...'
                      : 'Connecter l\'appareil',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final bool isConnected;
  const _ConnectionBadge({required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? Colors.green : AppColors.error;
    final label = isConnected ? 'Connecté' : 'Déconnecté';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isConnected ? Colors.green.shade700 : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color textPrimary;
  final Color textSecondary;

  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: textSecondary),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Slider d'intensité globale
// ══════════════════════════════════════════════════════════════

class _MasterIntensitySlider extends ConsumerWidget {
  final bool isDark;
  const _MasterIntensitySlider({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intensity = ref.watch(masterIntensityProvider);
    final maxThreshold = ref.watch(maxIntensityThresholdProvider);
    final motorsRunning = ref.watch(motorsRunningProvider);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.gauge, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Puissance globale',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(intensity * 100).round()}%',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.secondary,
              thumbColor: Colors.white,
              overlayColor: AppColors.primary.withValues(alpha: 0.1),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 14,
                elevation: 4,
              ),
            ),
            child: Slider(
              value: intensity,
              max: maxThreshold,
              onChanged: (v) {
                ref.read(masterIntensityProvider.notifier).state = v;
                // MAJ intensité de tous les moteurs en temps réel si actifs
                if (ref.read(motorsRunningProvider)) {
                  ref.read(bleServiceProvider).sendCommand(
                    BleProtocol.masterIntensityCommand(
                      BleProtocol.intensityToByte(v),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0%',
                style: GoogleFonts.poppins(fontSize: 11, color: textSecondary),
              ),
              Text(
                'Max : ${(maxThreshold * 100).round()}%',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Bouton Activer / Arrêter les vibrations ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                final bleService = ref.read(bleServiceProvider);
                if (motorsRunning) {
                  // Master OFF: [0x04, 0x00, 0x00] — coupe tous les moteurs
                  bleService.sendCommand(
                    BleProtocol.masterIntensityCommand(0x00),
                  );
                  // Log session to Firebase
                  final startTime = ref.read(sessionStartTimeProvider);
                  await ref.read(sessionServiceProvider).logCurrentSession(
                    startTime: startTime,
                    meanIntensity: intensity,
                  );
                  ref.read(sessionStartTimeProvider.notifier).state = null;
                  ref.read(motorsRunningProvider.notifier).state = false;
                  // Refresh chart
                  ref.invalidate(sessionHistoryProvider);
                } else {
                  // Master ON: [0x04, 0x00, intensité] — active tous les moteurs
                  final byte = BleProtocol.intensityToByte(intensity);
                  final sent = await bleService.sendCommand(
                    BleProtocol.masterIntensityCommand(byte),
                  );
                  if (!sent) {
                    if (context.mounted) _showNotConnected(context);
                    return;
                  }
                  ref.read(sessionStartTimeProvider.notifier).state =
                      DateTime.now();
                  ref.read(motorsRunningProvider.notifier).state = true;
                  ref.read(lastSessionTimeProvider.notifier).state =
                      DateTime.now();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: motorsRunning
                    ? AppColors.error
                    : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                motorsRunning ? LucideIcons.square : LucideIcons.play,
                size: 18,
              ),
              label: Text(
                motorsRunning
                    ? 'Arrêter les vibrations'
                    : 'Activer les vibrations',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Estimation d'autonomie
// ══════════════════════════════════════════════════════════════

class _BatteryEstimation extends ConsumerWidget {
  final bool isDark;
  const _BatteryEstimation({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battery = ref.watch(batteryLevelProvider);
    final intensity = ref.watch(masterIntensityProvider);
    final bleState = ref.watch(bleConnectionProvider);
    final isConnected = bleState == BleConnectionState.connected;
    final remaining = BleProtocol.estimateRemainingMinutes(battery, intensity);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

    final hours = remaining ~/ 60;
    final mins = remaining % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}min' : '$mins min';

    // Battery level logic
    final IconData batteryIcon;
    final Color batteryColor;
    final String statusLabel;
    final String statusMessage;

    if (!isConnected) {
      batteryIcon = LucideIcons.batteryWarning;
      batteryColor = textSecondary;
      statusLabel = '--';
      statusMessage = 'Appareil non connecté';
    } else if (battery <= 10) {
      batteryIcon = LucideIcons.batteryWarning;
      batteryColor = AppColors.error;
      statusLabel = '$battery%';
      statusMessage = 'Batterie critique — rechargez maintenant';
    } else if (battery <= 25) {
      batteryIcon = LucideIcons.batteryLow;
      batteryColor = Colors.orange;
      statusLabel = '$battery%';
      statusMessage = 'Batterie faible — environ $timeStr restantes';
    } else if (battery <= 50) {
      batteryIcon = LucideIcons.batteryMedium;
      batteryColor = Colors.amber;
      statusLabel = '$battery%';
      statusMessage = 'Environ $timeStr à ${(intensity * 100).round()}% d\'intensité';
    } else {
      batteryIcon = LucideIcons.batteryFull;
      batteryColor = Colors.green;
      statusLabel = '$battery%';
      statusMessage = 'Environ $timeStr à ${(intensity * 100).round()}% d\'intensité';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.2)),
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
                  color: batteryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(batteryIcon, size: 20, color: batteryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Autonomie estimée',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: batteryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: batteryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Battery progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: isConnected ? battery / 100.0 : 0,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            statusMessage,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Graphique analytique — Journal d'utilisation
// ══════════════════════════════════════════════════════════════

class _AnalyticsChart extends ConsumerWidget {
  final bool isDark;
  const _AnalyticsChart({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionHistoryProvider);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erreur de chargement', style: GoogleFonts.poppins(color: textSecondary)),
      data: (sessions) {
    // Fréquence horaire (24 cases)
    final hourCounts = List<int>.filled(24, 0);
    for (final s in sessions) {
      hourCounts[s.time.hour]++;
    }
    final maxCount = hourCounts.reduce(max).clamp(1, 100);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.barChart3, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Fréquence par heure',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                '${sessions.length} sessions',
                style: GoogleFonts.poppins(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _findPeakMessage(hourCounts),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCount.toDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gI, rod, rI) {
                      return BarTooltipItem(
                        '${group.x}h — ${rod.toY.round()} session(s)',
                        GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final h = value.toInt();
                        if (h % 6 == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '${h}h',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: textSecondary,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(24, (i) {
                  final hasData = hourCounts[i] > 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: hourCounts[i].toDouble(),
                        width: 6,
                        color: hasData
                            ? AppColors.primary
                            : AppColors.divider.withValues(alpha: 0.3),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
      }, // end data
    ); // end when
  }

  String _findPeakMessage(List<int> hourCounts) {
    int peakHour = 0;
    for (int i = 1; i < 24; i++) {
      if (hourCounts[i] > hourCounts[peakHour]) peakHour = i;
    }
    if (hourCounts[peakHour] == 0) return 'Pas encore de données';
    return 'Pic d\'utilisation vers ${peakHour}h00';
  }
}
