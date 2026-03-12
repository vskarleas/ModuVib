import 'dart:typed_data';

/// Protocole de communication BLE léger pour ESP32.
///
/// Chaque commande est un tableau de 3 octets :
///   [COMMANDE, CIBLE, VALEUR]
///
/// Exemples :
///   Motor 5, pleine puissance : [0x01, 0x05, 0xFF]
///   Pattern Vague, 75%       : [0x02, 0x01, 0xBF]
///   Arrêt d'urgence          : [0x03, 0x00, 0x00]
class BleProtocol {
  BleProtocol._();

  // ── Commandes ────────────────────────────────────────────────────────────
  static const int cmdMotor = 0x01;
  static const int cmdPattern = 0x02;
  static const int cmdStop = 0x03;
  static const int cmdMasterIntensity = 0x04;
  static const int cmdPing = 0x05;
  static const int cmdBatteryRequest = 0x06;

  // ── Identifiants moteur (3×3 grille dorsale) ─────────────────────────────
  static const int motorTopLeft = 0x01;
  static const int motorTopCenter = 0x02;
  static const int motorTopRight = 0x03;
  static const int motorMidLeft = 0x04;
  static const int motorMidCenter = 0x05;
  static const int motorMidRight = 0x06;
  static const int motorBotLeft = 0x07;
  static const int motorBotCenter = 0x08;
  static const int motorBotRight = 0x09;

  // ── Identifiants pattern ─────────────────────────────────────────────────
  static const int patternWave = 0x01;
  static const int patternRain = 0x02;
  static const int patternPulse = 0x03;
  static const int patternCircle = 0x04;

  // ── Constructeurs de commandes ───────────────────────────────────────────

  /// Commande moteur : [0x01, motorId, intensité(0‑255)]
  static Uint8List motorCommand(int motorId, int intensity) {
    return Uint8List.fromList([cmdMotor, motorId, intensity.clamp(0, 255)]);
  }

  /// Commande pattern : [0x02, patternId, intensité(0‑255)]
  static Uint8List patternCommand(int patternId, int intensity) {
    return Uint8List.fromList([cmdPattern, patternId, intensity.clamp(0, 255)]);
  }

  /// Arrêt d'urgence : [0x03, 0x00, 0x00]
  static Uint8List stopCommand() {
    return Uint8List.fromList([cmdStop, 0x00, 0x00]);
  }

  /// Intensité master : [0x04, 0x00, intensité(0‑255)]
  static Uint8List masterIntensityCommand(int intensity) {
    return Uint8List.fromList([cmdMasterIntensity, 0x00, intensity.clamp(0, 255)]);
  }

  /// Ping keep-alive : [0x05, 0x00, 0x00]
  static Uint8List pingCommand() {
    return Uint8List.fromList([cmdPing, 0x00, 0x00]);
  }

  /// Demande niveau batterie : [0x06, 0x00, 0x00]
  static Uint8List batteryRequestCommand() {
    return Uint8List.fromList([cmdBatteryRequest, 0x00, 0x00]);
  }

  /// Convertit une intensité normalisée (0.0‑1.0) en octet (0‑255).
  static int intensityToByte(double normalized) {
    return (normalized.clamp(0.0, 1.0) * 255).round();
  }

  /// Estime l'autonomie restante en minutes.
  /// [batteryPercent] : 0‑100, [currentIntensity] : 0.0‑1.0
  static int estimateRemainingMinutes(int batteryPercent, double currentIntensity) {
    const double maxMinutesAtFull = 120; // 2h à 100%
    if (currentIntensity <= 0) return (batteryPercent / 100 * maxMinutesAtFull * 2).round();
    final factor = 1.0 / currentIntensity;
    return (batteryPercent / 100 * maxMinutesAtFull * factor).round();
  }
}
