import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nanit_camera/nanit_camera.dart';
import 'package:universal_ble/universal_ble.dart';

/// Why [NanitWifiSetup.problem] is set, so the UI can offer a specific fix.
enum WifiSetupFault {
  bluetoothOff,

  /// Permission denied, no adapter, or the platform refused to scan.
  bluetoothUnavailable,
  noCameraFound,

  /// The selected device has no Nanit Wi-Fi setup service.
  notNanit,

  /// The camera answered but did not accept the Wi-Fi details.
  rejected,

  /// Timed out or disconnected part-way.
  interrupted,
}

/// Platform adapter for the independently tested Nanit BLE flow.
class NanitWifiSetup extends ChangeNotifier {
  final Map<String, BleDevice> devices = {};
  bool scanning = false, busy = false, joined = false;
  String? problem;

  /// The kind of [problem]; null when [problem] is null.
  WifiSetupFault? fault;
  StreamSubscription<BleDevice>? _scan;
  Timer? _scanTimer;
  String? _connected;
  bool _disposed = false;
  int _generation = 0;

  Future<void> scan() async {
    if (scanning || busy) return;
    problem = null;
    fault = null;
    devices.clear();
    scanning = true;
    _notify();
    try {
      await UniversalBle.requestPermissions();
      if (_disposed) return;
      if (await UniversalBle.getBluetoothAvailabilityState() !=
          AvailabilityState.poweredOn) {
        throw const FormatException('Turn on Bluetooth, then scan again.');
      }
      if (_disposed) return;
      _scan = UniversalBle.scanStream.listen(
        (device) {
          if ((device.name ?? '').startsWith('Nanit_')) {
            devices[device.deviceId] = device;
            _notify();
          }
        },
        onError: (_) {
          problem = 'Bluetooth scan failed. Check Bluetooth and Nearby devices permissions.';
          fault = WifiSetupFault.bluetoothUnavailable;
          unawaited(stopScan());
        },
      );
      await UniversalBle.startScan();
      if (_disposed) {
        await stopScan();
        return;
      }
      _scanTimer = Timer(const Duration(seconds: 15), () async {
        await stopScan();
        if (devices.isEmpty) {
          problem = 'No camera found. Check its flashing pairing light, keep it nearby and close the Nanit app.';
          fault = WifiSetupFault.noCameraFound;
          _notify();
        }
      });
    } catch (e) {
      problem = e is FormatException ? e.message : 'Bluetooth is unavailable. Check Nearby devices permissions and try again.';
      fault = e is FormatException
          ? WifiSetupFault.bluetoothOff
          : WifiSetupFault.bluetoothUnavailable;
      await stopScan();
    }
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    await _scan?.cancel();
    _scan = null;
    if (scanning) {
      try {
        await UniversalBle.stopScan();
      } catch (_) {}
    }
    scanning = false;
    _notify();
  }

  Future<void> provision(
    String id,
    String ssid,
    String password, {
    bool hidden = false,
  }) async {
    if (busy || _disposed) return;
    // Validate before opening GATT; an aborted connection exits pairing mode.
    final payload = nanitWifiRequest(ssid, password, hidden: hidden);
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    busy = true;
    joined = false;
    problem = null;
    fault = null;
    _notify();
    final queue = StreamController<(String, Uint8List)>();
    final events = StreamIterator(queue.stream);
    final subscriptions = <StreamSubscription>[];
    NanitWifiFlow? flow;
    try {
      await stopScan();
      if (!current()) return;
      _connected = id;
      await UniversalBle.connect(id, timeout: const Duration(seconds: 20));
      if (!current()) return;
      final services = await UniversalBle.discoverServices(id);
      if (!current()) return;
      final service = services
          .where((s) => s.uuid.toLowerCase() == nanitSetupService)
          .firstOrNull;
      if (service == null ||
          ![nanitSetupFlow, nanitSetupData].every(
            (uuid) => service.characteristics.any(
              (c) => c.uuid.toLowerCase() == uuid,
            ),
          )) {
        throw const FormatException(
          'This device does not offer Nanit Wi-Fi setup.',
        );
      }
      // 20 bytes also works at the default MTU; the verified flow permits <=32.
      flow = NanitWifiFlow(payload);
      for (final uuid in [nanitSetupFlow, nanitSetupData]) {
        subscriptions.add(
          UniversalBle.characteristicValueStream(id, uuid).listen(
            (data) {
              if (!queue.isClosed) queue.add((uuid, data));
            },
            onError: (Object e) {
              if (!queue.isClosed) queue.addError(e);
            },
          ),
        );
        await UniversalBle.subscribeNotifications(id, nanitSetupService, uuid);
        if (!current()) return;
      }
      subscriptions.add(
        UniversalBle.connectionStream(id).listen((connected) {
          if (!connected && !queue.isClosed) {
            queue.addError(
              const FormatException('Camera disconnected during Wi-Fi setup.'),
            );
          }
        }),
      );
      queue.add((
        nanitSetupFlow,
        await UniversalBle.read(id, nanitSetupService, nanitSetupFlow),
      ));
      final deadline = DateTime.now().add(const Duration(seconds: 100));
      while (current() && flow.completed == null) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero ||
            !await events.moveNext().timeout(remaining)) {
          throw TimeoutException('Wi-Fi setup timed out');
        }
        final (channel, bytes) = events.current;
        for (final (uuid, packet) in flow.event(channel, bytes)) {
          if (!current()) return;
          final characteristic = service.characteristics.firstWhere(
            (c) => c.uuid.toLowerCase() == uuid,
          );
          try {
            await UniversalBle.write(
              id,
              nanitSetupService,
              uuid,
              packet,
              withoutResponse: !characteristic.properties.contains(
                CharacteristicProperty.write,
              ),
            );
          } finally {
            packet.fillRange(0, packet.length, 0);
          }
        }
      }
      if (!current()) return;
      final status = nanitWifiStatus(flow.completed!);
      if (status != 200) {
        throw FormatException(
          'Camera did not confirm Wi-Fi setup (status $status). Check the network name and password.',
        );
      }
      joined = true;
    } catch (e) {
      if (current()) {
        problem = e is FormatException ? e.message : 'Wi-Fi setup was interrupted. Enable pairing mode again and retry.';
        fault = switch (e) {
          FormatException(:final message) when message.contains('status') =>
            WifiSetupFault.rejected,
          FormatException(:final message)
              when message.contains('does not offer') =>
            WifiSetupFault.notNanit,
          _ => WifiSetupFault.interrupted,
        };
      }
    } finally {
      flow?.clear();
      payload.fillRange(0, payload.length, 0);
      for (final s in subscriptions) {
        await s.cancel();
      }
      await events.cancel();
      await queue.close();
      try {
        await UniversalBle.disconnect(id);
      } catch (_) {}
      _connected = null;
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(stopScan());
    final id = _connected;
    if (id != null) unawaited(UniversalBle.disconnect(id).catchError((_) {}));
    super.dispose();
  }
}
