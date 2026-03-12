import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/ble_service.dart';
import '../services/ble_protocol.dart';
import '../services/auth_service.dart';
import '../services/session_service.dart';

// ── BLE ──────────────────────────────────────────────────────────────────────
enum BleConnectionState { disconnected, connecting, connected, error }

final bleConnectionProvider = StateProvider<BleConnectionState>(
  (ref) => BleConnectionState.disconnected,
);

// ── BLE Service ─────────────────────────────────────────────────────────────
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  service.onConnectionChanged = (connected) {
    ref.read(bleConnectionProvider.notifier).state =
        connected ? BleConnectionState.connected : BleConnectionState.disconnected;
    if (!connected) {
      ref.read(motorsRunningProvider.notifier).state = false;
    }
  };
  service.onConnecting = (connecting) {
    if (connecting) {
      ref.read(bleConnectionProvider.notifier).state = BleConnectionState.connecting;
    }
  };
  service.onBatteryChanged = (level) {
    ref.read(batteryLevelProvider.notifier).state = level;
  };
  service.onError = () {
    ref.read(bleConnectionProvider.notifier).state = BleConnectionState.error;
    // Revenir à disconnected après 2 secondes
    Future.delayed(const Duration(seconds: 2), () {
      if (ref.read(bleConnectionProvider) == BleConnectionState.error) {
        ref.read(bleConnectionProvider.notifier).state = BleConnectionState.disconnected;
      }
    });
  };
  return service;
});

// ── Hardware Status ─────────────────────────────────────────────────────────
final batteryLevelProvider = StateProvider<int>((ref) => 84);
final vestTemperatureProvider = StateProvider<double>((ref) => 36.2);
final vestVoltageProvider = StateProvider<double>((ref) => 3.7);

// ── Master Intensity (0.0 – 1.0) ────────────────────────────────────────────
final masterIntensityProvider = StateProvider<double>((ref) => 0.5);

// ── Motors Running State ────────────────────────────────────────────────────
final motorsRunningProvider = StateProvider<bool>((ref) => false);

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

// ── Firebase Auth ───────────────────────────────────────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ── Firestore Session Service ───────────────────────────────────────────────
final sessionServiceProvider = Provider<SessionService>((ref) => SessionService());

// ── Biometric auth preference ───────────────────────────────────────────────
final biometricEnabledProvider = StateProvider<bool>((ref) => true);

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

/// Fetches sessions from Firestore; falls back to empty list when not signed in.
final sessionHistoryProvider = FutureProvider<List<SessionEntry>>((ref) async {
  final sessionService = ref.watch(sessionServiceProvider);
  final records = await sessionService.recentSessions();
  return records
      .map((r) => SessionEntry(
            time: r.time,
            durationMinutes: r.durationMinutes,
            intensity: r.intensity,
          ))
      .toList();
});

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
    ref.read(motorsRunningProvider.notifier).state = false;
    // Envoyer commande stop BLE
    ref.read(bleServiceProvider).sendCommand(BleProtocol.stopCommand());
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
