import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_protocol.dart';

// ══════════════════════════════════════════════════════════════
// BLE SERVICE — Connexion ESP32 via flutter_blue_plus
// ══════════════════════════════════════════════════════════════
// UUIDs : à adapter selon le firmware ESP32.
// Le service expose une caractéristique de commande (write)
// et une caractéristique batterie (read / notify).
// ══════════════════════════════════════════════════════════════

/// UUIDs — doivent correspondre au firmware ESP32
const String kEsp32ServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const String kEsp32CommandCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
const String kEsp32BatteryCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a9';

/// Préfixe du nom Bluetooth de l'ESP32
const String kDeviceNamePrefix = 'ModuVib';

class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _batteryChar;
  StreamSubscription? _connectionSub;
  StreamSubscription? _batterySub;
  Timer? _batteryPollTimer;

  // ── Callbacks — branchés par le provider Riverpod ────────────────────────
  void Function(bool isConnected)? onConnectionChanged;
  void Function(bool isConnecting)? onConnecting;
  void Function(int batteryLevel)? onBatteryChanged;
  void Function()? onError;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // ── Connexion ────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_isConnected) return;
    onConnecting?.call(true);

    try {
      // Vérifier que le Bluetooth est activé
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        onError?.call();
        return;
      }

      BluetoothDevice? found;

      final scanSub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName.contains(kDeviceNamePrefix) ||
              r.device.platformName.contains('ESP32')) {
            found = r.device;
            FlutterBluePlus.stopScan();
          }
        }
      });

      // Lancer le scan (s'arrête automatiquement après timeout)
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // Attendre la fin du scan
      await FlutterBluePlus.isScanning
          .where((scanning) => !scanning)
          .first
          .timeout(const Duration(seconds: 15), onTimeout: () => false);

      await scanSub.cancel();

      if (found == null) {
        onError?.call();
        return;
      }

      _device = found;
      await _device!.connect(timeout: const Duration(seconds: 10));

      // Écouter les déconnexions
      _connectionSub = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _onDisconnected();
        }
      });

      // Découvrir services et caractéristiques
      final services = await _device!.discoverServices();
      for (final s in services) {
        if (s.serviceUuid.toString().toLowerCase() ==
            kEsp32ServiceUuid.toLowerCase()) {
          for (final c in s.characteristics) {
            final uuid = c.characteristicUuid.toString().toLowerCase();
            if (uuid == kEsp32CommandCharUuid.toLowerCase()) {
              _commandChar = c;
            } else if (uuid == kEsp32BatteryCharUuid.toLowerCase()) {
              _batteryChar = c;
            }
          }
        }
      }

      _isConnected = true;
      onConnectionChanged?.call(true);

      // Activer les notifications batterie et démarrer le polling
      await _enableBatteryNotifications();
      _startBatteryPolling();
    } catch (_) {
      onError?.call();
    }
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _batteryPollTimer?.cancel();
    await _batterySub?.cancel();
    await _connectionSub?.cancel();

    try {
      await _device?.disconnect();
    } catch (_) {}

    _onDisconnected();
  }

  void _onDisconnected() {
    _batteryPollTimer?.cancel();
    _isConnected = false;
    _device = null;
    _commandChar = null;
    _batteryChar = null;
    onConnectionChanged?.call(false);
  }

  // ── Envoi de commandes ───────────────────────────────────────────────────

  /// Envoie une commande brute (3 octets selon BleProtocol)
  Future<void> sendCommand(Uint8List command) async {
    if (_commandChar == null || !_isConnected) return;
    try {
      await _commandChar!.write(command.toList(), withoutResponse: true);
    } catch (_) {}
  }

  // ── Batterie ─────────────────────────────────────────────────────────────

  void _startBatteryPolling() {
    _requestBattery();
    _batteryPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _requestBattery();
    });
  }

  Future<void> _requestBattery() async {
    if (_batteryChar == null || !_isConnected) return;
    try {
      final value = await _batteryChar!.read();
      if (value.isNotEmpty) {
        onBatteryChanged?.call(value[0].clamp(0, 100));
      }
    } catch (_) {
      // Fallback : envoyer la commande de demande de batterie
      try {
        await sendCommand(BleProtocol.batteryRequestCommand());
      } catch (_) {}
    }
  }

  Future<void> _enableBatteryNotifications() async {
    if (_batteryChar == null) return;
    try {
      await _batteryChar!.setNotifyValue(true);
      _batterySub = _batteryChar!.onValueReceived.listen((value) {
        if (value.isNotEmpty) {
          onBatteryChanged?.call(value[0].clamp(0, 100));
        }
      });
    } catch (_) {}
  }
}
