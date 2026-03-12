import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── BLE ──────────────────────────────────────────────────────────────────────
enum BleConnectionState { disconnected, connecting, connected, error }

final bleConnectionProvider = StateProvider<BleConnectionState>(
  (ref) => BleConnectionState.disconnected,
);

// ── Hardware Status ─────────────────────────────────────────────────────────
final batteryLevelProvider = StateProvider<int>((ref) => 84);
final vestTemperatureProvider = StateProvider<double>((ref) => 36.2);
final vestVoltageProvider = StateProvider<double>((ref) => 3.7);

// ── Master Intensity (0.0 – 1.0) ────────────────────────────────────────────
final masterIntensityProvider = StateProvider<double>((ref) => 0.5);

// ── Safety ──────────────────────────────────────────────────────────────────
final maxIntensityThresholdProvider = StateProvider<double>((ref) => 0.8);
final emergencyStopProvider = StateProvider<bool>((ref) => false);

// ── Active Motors: motorIndex → intensity (0‑255) ───────────────────────────
final activeMotorsProvider = StateProvider<Map<int, int>>((ref) => {});

// ── Session ─────────────────────────────────────────────────────────────────
final lastSessionTimeProvider = StateProvider<DateTime?>(
  (ref) => DateTime.now().subtract(const Duration(minutes: 20)),
);

// ── Patterns ────────────────────────────────────────────────────────────────
final activePatternProvider = StateProvider<String?>((ref) => null);
final patternTimerSecondsProvider = StateProvider<int?>((ref) => null);

// ── Gesture radius (pinch: 1 = single motor, 4 = group) ────────────────────
final activationRadiusProvider = StateProvider<double>((ref) => 1.0);

// ── Preferences ─────────────────────────────────────────────────────────────
final darkModeProvider = StateProvider<bool>((ref) => false);
final rememberMeProvider = StateProvider<bool>((ref) => false);

// ── Analytics / Journal des Démangeaisons ───────────────────────────────────
class SessionEntry {
  final DateTime time;
  final int durationMinutes;
  final double intensity;

  const SessionEntry({
    required this.time,
    required this.durationMinutes,
    required this.intensity,
  });
}

final sessionHistoryProvider = StateProvider<List<SessionEntry>>((ref) => [
      SessionEntry(
        time: DateTime.now().subtract(const Duration(minutes: 20)),
        durationMinutes: 15,
        intensity: 0.6,
      ),
      SessionEntry(
        time: DateTime(2026, 2, 7, 22, 30),
        durationMinutes: 22,
        intensity: 0.4,
      ),
      SessionEntry(
        time: DateTime(2026, 2, 7, 9, 15),
        durationMinutes: 8,
        intensity: 0.7,
      ),
      SessionEntry(
        time: DateTime(2026, 2, 6, 21, 45),
        durationMinutes: 30,
        intensity: 0.5,
      ),
      SessionEntry(
        time: DateTime(2026, 2, 6, 14, 0),
        durationMinutes: 12,
        intensity: 0.3,
      ),
      SessionEntry(
        time: DateTime(2026, 2, 5, 22, 10),
        durationMinutes: 18,
        intensity: 0.55,
      ),
      SessionEntry(
        time: DateTime(2026, 2, 4, 23, 0),
        durationMinutes: 25,
        intensity: 0.65,
      ),
    ]);

// ── Pattern Timer Manager ───────────────────────────────────────────────────
/// Gère le timer des patterns de manière globale (persiste entre les pages)
class PatternTimerNotifier extends StateNotifier<void> {
  PatternTimerNotifier(this.ref) : super(null);

  final Ref ref;
  Timer? _timer;

  /// Démarre un timer pour arrêter automatiquement le pattern
  void startTimer(int totalSeconds) {
    stopTimer();
    ref.read(patternTimerSecondsProvider.notifier).state = totalSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = ref.read(patternTimerSecondsProvider);
      if (remaining == null || remaining <= 1) {
        stopPattern();
      } else {
        ref.read(patternTimerSecondsProvider.notifier).state = remaining - 1;
      }
    });
  }

  /// Arrête le timer sans arrêter le pattern
  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Arrête complètement le pattern et le timer
  void stopPattern() {
    stopTimer();
    ref.read(activePatternProvider.notifier).state = null;
    ref.read(patternTimerSecondsProvider.notifier).state = null;
    ref.read(activeMotorsProvider.notifier).state = {};
  }

  @override
  void dispose() {
    stopTimer();
    super.dispose();
  }
}

final patternTimerNotifierProvider =
    StateNotifierProvider<PatternTimerNotifier, void>((ref) {
  return PatternTimerNotifier(ref);
});
