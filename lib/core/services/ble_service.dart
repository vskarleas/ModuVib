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

  /// Completer-based lock: non-null means a connection attempt is in progress.
  /// More robust than a boolean because it survives async gaps.
  Completer<void>? _connectLock;

  Future<void> connect() async {
    // Strict single-attempt guard
    if (_isConnected) return;
    if (_connectLock != null) return;
    _connectLock = Completer<void>();
    onConnecting?.call(true);

    try {
      // Cancel any lingering scan from a previous attempt
      await FlutterBluePlus.stopScan();

      // Vérifier que le Bluetooth est activé
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        onError?.call();
        return;
      }

      BluetoothDevice? found;

      // 1) Check already-bonded devices (Android only, returns [] on iOS)
      try {
        final bonded = await FlutterBluePlus.bondedDevices;
        for (final d in bonded) {
          if (d.platformName.contains(kDeviceNamePrefix) ||
              d.platformName.contains('ESP32')) {
            found = d;
            break;
          }
        }
      } catch (_) {
        // bondedDevices not supported on this platform
      }

      // 2) Check system-connected devices (works on both iOS & Android)
      if (found == null) {
        try {
          final systemConnected = await FlutterBluePlus.systemDevices([]);
          for (final d in systemConnected) {
            if (d.platformName.contains(kDeviceNamePrefix) ||
                d.platformName.contains('ESP32')) {
              found = d;
              break;
            }
          }
        } catch (_) {}
      }

      // 3) If not found, scan
      if (found == null) {
        final scanSub = FlutterBluePlus.onScanResults.listen((results) {
          for (final r in results) {
            if (r.device.platformName.contains(kDeviceNamePrefix) ||
                r.device.platformName.contains('ESP32')) {
              found = r.device;
              FlutterBluePlus.stopScan();
            }
          }
        });

        await FlutterBluePlus.startScan(
          timeout: const Duration(seconds: 10),
          androidUsesFineLocation: false,
        );

        // Attendre la fin du scan
        await FlutterBluePlus.isScanning
            .where((scanning) => !scanning)
            .first
            .timeout(const Duration(seconds: 15), onTimeout: () => false);

        await scanSub.cancel();
      }

      if (found == null) {
        onError?.call();
        return;
      }

      _device = found;

      // Écouter les déconnexions AVANT connect() pour ne rien manquer.
      await _connectionSub?.cancel();
      _connectionSub = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected && _isConnected) {
          _onDisconnected();
        }
      });

      await _device!.connect(timeout: const Duration(seconds: 10));

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

      // Marquer connecté seulement après que tout est prêt
      _isConnected = true;
      onConnectionChanged?.call(true);

      // Activer les notifications batterie et démarrer le polling
      await _enableBatteryNotifications();
      _startBatteryPolling();
    } catch (_) {
      onError?.call();
    } finally {
      // Always release the lock, no matter what happened
      _connectLock?.complete();
      _connectLock = null;
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

  /// Envoie une commande brute (3 octets selon BleProtocol).
  /// Retourne `true` si la commande a été envoyée, `false` sinon.
  Future<bool> sendCommand(Uint8List command) async {
    if (_commandChar == null || !_isConnected) return false;
    try {
      await _commandChar!.write(command.toList(), withoutResponse: false);
      return true;
    } catch (_) {
      return false;
    }
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
