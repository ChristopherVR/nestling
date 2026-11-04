import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nanit_camera/nanit_camera.dart';

import 'background.dart';

class SavedLocalCamera {
  const SavedLocalCamera({
    required this.address,
    required this.uid,
    required this.firmware,
    this.name = 'Nursery camera',
  });
  final String address, uid, firmware, name;
  Map<String, String> toJson() => {
    'address': address,
    'uid': uid,
    'firmware': firmware,
    'name': name,
  };
  factory SavedLocalCamera.fromJson(Map<String, dynamic> json) =>
      SavedLocalCamera(
        address: requireNanitLanAddress(json['address'] as String),
        uid: json['uid'] as String,
        firmware: json['firmware'] as String,
        name: json['name'] as String,
      );
}

enum LocalCameraState { idle, connecting, ready, retrying }

/// Local mode has no Nanit account dependency. Only device identity and its
/// last LAN address are saved, never a Wi-Fi password or streaming token.
class LocalNanitHub extends ChangeNotifier {
  LocalNanitHub({
    required this.store,
    NanitOfflineCamera Function(String)? cameraFactory,
  }) : _cameraFactory = cameraFactory ?? NanitOfflineCamera.new;
  static const storageKey = 'nestling.localCamera.v1';
  final NanitSecretStore store;
  final NanitOfflineCamera Function(String) _cameraFactory;
  SavedLocalCamera? saved;
  NanitRoomReadings? readings;
  LocalCameraState state = LocalCameraState.idle;
  String? problem;
  String? get streamUrl => _bridge?.url;
  NanitOfflineCamera? _camera;
  NanitOfflineBridge? _bridge;
  Timer? _poll, _retry;
  int _generation = 0;
  bool _watching = false, _disposed = false, changingLight = false;

  Future<void> load() async {
    try {
      final raw = await store.read(storageKey);
      if (raw != null) {
        saved = SavedLocalCamera.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      problem =
          'Saved camera details could not be loaded. Add the camera again.';
    }
  }

  Future<Map<String, String>> discover() =>
      BackgroundSync.withMulticast(() => NanitOfflineDiscovery().discover());

  Future<void> add(String address, {String name = 'Nursery camera'}) async {
    final camera = _cameraFactory(address.trim());
    try {
      final info = await camera.identify();
      final next = SavedLocalCamera(
        address: info.address,
        uid: info.uid,
        firmware: info.firmware,
        name: name.trim().isEmpty ? 'Nursery camera' : name.trim(),
      );
      await store.write(storageKey, jsonEncode(next.toJson()));
      saved = next;
      problem = null;
      _notify();
    } finally {
      camera.close();
    }
  }

  Future<void> watch() async {
    _watching = true;
    if (saved == null ||
        state == LocalCameraState.connecting ||
        state == LocalCameraState.ready) {
      return;
    }
    await reconnect();
  }

  Future<void> reconnect() async {
    if (!_watching || saved == null || _disposed) return;
    final closing = _close();
    final generation = _generation;
    bool current() => generation == _generation && _watching && !_disposed;
    await closing;
    if (!current()) return;
    state = LocalCameraState.connecting;
    problem = null;
    _notify();
    final savedCamera = saved!;
    var address = savedCamera.address;
    var camera = _cameraFactory(address);
    _camera = camera;
    try {
      NanitOfflineInfo info;
      try {
        info = await camera.identify();
      } catch (_) {
        if (!current()) return;
        final found = await BackgroundSync.withMulticast(
          () => NanitOfflineDiscovery().locate(savedCamera.uid),
        );
        if (!current()) return;
        if (found == null || found == address) rethrow;
        camera.close();
        address = found;
        camera = _cameraFactory(address);
        _camera = camera;
        info = await camera.identify();
      }
      if (!current()) return;
      if (info.uid != savedCamera.uid) {
        throw const FormatException(
          'A different camera is using the saved address. Find your camera again.',
        );
      }
      await camera.startMedia();
      if (!current()) return;
      final bridge = NanitOfflineBridge(address);
      _bridge = bridge;
      await bridge.start();
      if (!current()) return;
      saved = SavedLocalCamera(
        address: address,
        uid: info.uid,
        firmware: info.firmware,
        name: savedCamera.name,
      );
      await store.write(storageKey, jsonEncode(saved!.toJson()));
      if (!current()) return;
      state = LocalCameraState.ready;
      _notify();
      // Room telemetry uses a separate maintenance service. It must not hold
      // up video startup or tear down healthy media when that service is busy.
      unawaited(_readRoom(generation));
    } catch (e) {
      if (current()) {
        await _failed(
          e is FormatException ? e.message : 'Camera unreachable. Keep this device on the same home network.',
        );
      }
    } finally {
      if (!current()) camera.close();
    }
  }

  void _scheduleRead(int generation) {
    _poll = Timer(const Duration(seconds: 15), () => _readRoom(generation));
  }

  Future<void> _readRoom(int generation) async {
    if (generation != _generation || !_watching || _camera == null) return;
    try {
      final value = await _camera!.readings();
      if (generation != _generation || !_watching) return;
      readings = value;
      problem = null;
    } catch (_) {
      if (generation != _generation || !_watching) return;
      readings = null;
      problem =
          'Room readings unavailable. Video can continue; readings will retry.';
    }
    _notify();
    if (generation == _generation && _watching) _scheduleRead(generation);
  }

  Future<void> streamFailed() async {
    if (_watching && state == LocalCameraState.ready) {
      await _failed('Video connection interrupted. Reconnecting…');
    }
  }

  Future<void> _failed(String message) async {
    await _close();
    if (!_watching || _disposed) return;
    state = LocalCameraState.retrying;
    problem = message;
    _notify();
    _retry = Timer(const Duration(seconds: 8), reconnect);
  }

  Future<void> setNightLight(int percent) async {
    if (_camera == null || state != LocalCameraState.ready || changingLight) {
      return;
    }
    final generation = _generation;
    changingLight = true;
    _notify();
    try {
      final value = await _camera!.setNightLight(percent);
      if (generation == _generation) {
        readings = value;
        problem = null;
      }
    } catch (_) {
      if (generation == _generation) {
        problem = 'Could not change the night light. Try again.';
      }
    } finally {
      changingLight = false;
      _notify();
    }
  }

  Future<void> pause() async {
    _watching = false;
    await _close();
    if (_disposed) return;
    state = LocalCameraState.idle;
    problem = null;
    _notify();
  }

  Future<void> forget() async {
    await pause();
    await store.delete(storageKey);
    saved = null;
    _notify();
  }

  Future<void> _close() async {
    ++_generation;
    _poll?.cancel();
    _retry?.cancel();
    _camera?.close();
    _camera = null;
    final bridge = _bridge;
    _bridge = null;
    readings = null;
    await bridge?.close();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _watching = false;
    unawaited(_close());
    super.dispose();
  }
}
