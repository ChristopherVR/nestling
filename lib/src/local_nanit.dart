import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:nanit_camera/nanit_camera.dart';

import 'background.dart';
import 'local_camera_alerts.dart';

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

/// Why [LocalNanitHub.problem] is set, so the UI can offer a specific fix.
enum LocalCameraFault {
  /// No answer at the saved address, and discovery did not find it elsewhere.
  unreachable,

  /// Another camera answered at the saved address.
  differentCamera,

  /// The address answered, but not as a supported Nanit camera.
  notACamera,

  /// The camera answered but its video/audio source did not start.
  videoDidNotStart,

  /// Video was playing, then stopped.
  videoInterrupted,
  roomReadings,
  nightLight,
  savedDetails,
}

/// Local mode has no Nanit account dependency. Only device identity and its
/// last LAN address are saved, never a Wi-Fi password or streaming token.
class LocalNanitHub extends ChangeNotifier {
  LocalNanitHub({
    required this.store,
    NanitOfflineCamera Function(String)? cameraFactory,
    Future<void> Function(LocalCameraAlert)? deliverAlert,
    Future<bool> Function(bool)? alertPermission,
    Future<void> Function(bool)? alertBackground,
  }) : _cameraFactory = cameraFactory ?? NanitOfflineCamera.new {
    alerts = LocalCameraAlerts(
      store: store,
      address: () => saved?.address,
      uid: () => saved?.uid,
      cameraFactory: _cameraFactory,
      deliver: deliverAlert,
      permission: alertPermission,
      background: alertBackground,
    );
  }
  late final LocalCameraAlerts alerts;
  static const storageKey = 'nestling.localCamera.v1';
  final NanitSecretStore store;
  final NanitOfflineCamera Function(String) _cameraFactory;
  SavedLocalCamera? saved;
  NanitRoomReadings? readings;
  NanitSoundState? sound;
  String? soundProblem;
  bool changingSound = false;
  LocalCameraState state = LocalCameraState.idle;
  String? problem;

  /// The kind of [problem]; null when [problem] is null.
  LocalCameraFault? fault;
  String? get streamUrl => _bridge?.url;
  NanitOfflineCamera? _camera;
  NanitOfflineBridge? _bridge;
  Timer? _poll, _retry, _soundPoll;
  int _soundRevision = 0;
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
      fault = LocalCameraFault.savedDetails;
    }
    await alerts.load();
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
      await alerts.restart();
      problem = null;
      fault = null;
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
    fault = null;
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
      unawaited(_readSound(generation));
    } catch (e) {
      if (current()) {
        await _failed(
          e is FormatException ? e.message : 'Camera unreachable. Keep this device on the same home network.',
          fault: switch (e) {
            FormatException(:final message)
                when message.contains('different camera') =>
              LocalCameraFault.differentCamera,
            FormatException() => LocalCameraFault.notACamera,
            SocketException(:final message)
                when message.contains('did not start video') =>
              LocalCameraFault.videoDidNotStart,
            _ => LocalCameraFault.unreachable,
          },
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
      fault = null;
    } catch (_) {
      if (generation != _generation || !_watching) return;
      readings = null;
      problem =
          'Room readings unavailable. Video can continue; readings will retry.';
      fault = LocalCameraFault.roomReadings;
    }
    _notify();
    if (generation == _generation && _watching) _scheduleRead(generation);
  }

  Future<void> streamFailed() async {
    if (_watching && state == LocalCameraState.ready) {
      await _failed(
        'Video connection interrupted. Reconnecting…',
        fault: LocalCameraFault.videoInterrupted,
      );
    }
  }

  Future<void> _readSound(int generation) async {
    if (generation != _generation || !_watching || _camera == null) return;
    final revision = _soundRevision;
    try {
      final value = await _camera!.soundStatus();
      if (generation != _generation || !_watching) return;
      if (revision == _soundRevision && !changingSound) {
        sound = value;
        soundProblem = null;
        _notify();
      }
    } catch (_) {
      if (generation != _generation || !_watching) return;
      if (revision == _soundRevision && !changingSound) {
        sound = null;
        soundProblem = 'Could not check camera sounds. Retrying…';
        _notify();
      }
    }
    if (generation == _generation && _watching) {
      _soundPoll = Timer(
        const Duration(seconds: 3),
        () => _readSound(generation),
      );
    }
  }

  Future<void> playSound(NanitSoundTrack track, int volume, int seconds) =>
      _soundAction(
        (camera) => camera.playSound(track, volume: volume, seconds: seconds),
      );

  Future<void> stopSound() => _soundAction((camera) => camera.stopSound());

  Future<void> setSoundVolume(int volume) =>
      _soundAction((camera) => camera.setSoundVolume(volume));

  Future<void> _soundAction(
    Future<NanitSoundState> Function(NanitOfflineCamera) action,
  ) async {
    final camera = _camera;
    if (camera == null || state != LocalCameraState.ready || changingSound) {
      return;
    }
    final generation = _generation;
    final revision = ++_soundRevision;
    changingSound = true;
    soundProblem = null;
    _notify();
    try {
      final value = await action(camera);
      if (generation == _generation) sound = value;
    } catch (_) {
      if (generation == _generation) {
        soundProblem = 'The camera did not confirm that sound action. Check its status and retry.';
      }
    } finally {
      if (revision == _soundRevision) changingSound = false;
      _notify();
    }
  }

  Future<void> _failed(
    String message, {
    LocalCameraFault fault = LocalCameraFault.unreachable,
  }) async {
    await _close();
    if (!_watching || _disposed) return;
    state = LocalCameraState.retrying;
    problem = message;
    this.fault = fault;
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
        fault = null;
      }
    } catch (_) {
      if (generation == _generation) {
        problem = 'Could not change the night light. Try again.';
        fault = LocalCameraFault.nightLight;
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
    fault = null;
    _notify();
  }

  Future<void> forget() async {
    await alerts.setEnabled(false);
    await store.delete(LocalCameraAlerts.storageKey);
    await pause();
    await store.delete(storageKey);
    saved = null;
    _notify();
  }

  Future<void> _close() async {
    ++_generation;
    _poll?.cancel();
    _retry?.cancel();
    _soundPoll?.cancel();
    ++_soundRevision;
    changingSound = false;
    sound = null;
    soundProblem = null;
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
    alerts.dispose();
    _watching = false;
    unawaited(_close());
    super.dispose();
  }
}
