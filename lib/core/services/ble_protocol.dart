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

  // ── Identifiants moteur  grille dorsale — 15 moteurs, 3, 4, 3, 2, 3) ───
  // Rangée 1 (haut)
  static const int motor1  = 0x01;
  static const int motor2  = 0x02;
  static const int motor3  = 0x03;

  // Rangée 2
  static const int motor4  = 0x04;
  static const int motor5  = 0x05;
  static const int motor6  = 0x06;
  static const int motor7  = 0x07;

  // Rangée 3 (milieu)
  static const int motor8  = 0x08;
  static const int motor9  = 0x09;
  static const int motor10 = 0x0A;

  // Rangée 4
  static const int motor11 = 0x0B;
  static const int motor12 = 0x0C;
 
  // Rangée 5 (bas)
  static const int motor13 = 0x0D;
  static const int motor14 = 0x0E;
  static const int motor15 = 0x0F;

  static const int motorCount = 15;

  /// Grille moteur
  static const List<List<int>> motorGrid = [
    [0x01, 0x02, 0x03],
    [0x04, 0x05, 0x06, 0x07],
    [0x08, 0x09, 0x0A],
    [0x0B, 0x0C],
    [0x0D, 0x0E, 0x0F],
  ];

  // ── Identifiants pattern ─────────────────────────────────────────────────
  static const int patternWave = 0x01;
  static const int patternRain = 0x02;
  static const int patternPulse = 0x03;
  static const int patternCircle = 0x04;

  // ── Fréquences fixes des programmes (0.0–1.0) ───────────────────────────
  static const double frequencyWave   = 0.73; // Vague
  static const double frequencyRain   = 0.44; // Pluie
  static const double frequencyPulse  = 0.87; // Impulsion
  static const double frequencyCircle = 0.82; // Cercle

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
