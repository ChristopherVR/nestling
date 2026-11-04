import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nanit_camera/nanit_camera.dart';

import 'background.dart';

enum LocalAlertKind { sound, cry, unavailable }

enum SoundSensitivity {
  low(-25),
  normal(-35),
  high(-45);

  const SoundSensitivity(this.dbfs);
  final double dbfs;
}

class LocalCameraAlert {
  const LocalCameraAlert(this.kind, this.at);
  final LocalAlertKind kind;
  final DateTime at;
}

/// Nestling's explicit local policy, not Nanit's undocumented notification rule.
/// Sound: two fresh above-threshold readings. Cry: three consecutive native
/// probabilities >= 0.70. No raw candidate/is_alert=false message is an alert.
class LocalAlertPolicy {
  String? _boot;
  double _levelAt = 0, _cryAt = 0;
  int _loud = 0, _cryRun = 0;
  final _last = <LocalAlertKind, DateTime>{};
  final Duration cooldown;
  LocalAlertPolicy({this.cooldown = const Duration(minutes: 1)});
  void rearm() {
    _boot = null;
    _loud = 0;
    _cryRun = 0;
  }

  List<LocalAlertKind> accept(
    NanitDetectionSnapshot s,
    DateTime now, {
    required bool sound,
    required bool cry,
    required SoundSensitivity sensitivity,
  }) {
    if (_boot != s.boot) {
      _boot = s.boot;
      _levelAt = s.levelAt ?? s.uptime;
      _cryAt = s.uptime;
      _loud = _cryRun = 0;
      return [];
    }
    final found = <LocalAlertKind>[];
    void emit(LocalAlertKind kind) {
      final last = _last[kind];
      if (last == null || now.difference(last) >= cooldown) {
        _last[kind] = now;
        found.add(kind);
      }
    }

    if (!sound || !s.levelFresh || s.speakerActive) _loud = 0;
    if (s.levelAt != null && s.levelAt! > _levelAt) {
      if (s.levelAt! - _levelAt > 5) _loud = 0;
      _levelAt = s.levelAt!;
      if (sound && s.levelFresh && !s.speakerActive) {
        _loud = s.dbfs! >= sensitivity.dbfs ? _loud + 1 : 0;
        if (_loud >= 2) emit(LocalAlertKind.sound);
      }
    }
    if (!cry || !s.cryFresh) _cryRun = 0;
    for (final window in s.cry) {
      if (window.at <= _cryAt) continue;
      if (window.at - _cryAt > 7) _cryRun = 0;
      _cryAt = window.at;
      if (!cry || !s.microphone || !s.classifier || s.uptime - window.at > 15) {
        _cryRun = 0;
        continue;
      }
      for (final p in window.probabilities) {
        _cryRun = p >= .70 ? _cryRun + 1 : 0;
        if (_cryRun >= 3) emit(LocalAlertKind.cry);
      }
    }
    return found;
  }
}

class LocalCameraAlerts extends ChangeNotifier {
  LocalCameraAlerts({
    required this.store,
    required this.address,
    required this.uid,
    NanitOfflineCamera Function(String)? cameraFactory,
    Future<void> Function(LocalCameraAlert)? deliver,
    Future<void> Function(bool)? background,
    Future<bool> Function(bool request)? permission,
    this.interval = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _factory = cameraFactory ?? NanitOfflineCamera.new,
       _deliver = deliver ?? _discard,
       _background = background ?? BackgroundSync.setCameraMonitoring,
       _permission = permission ?? _allowed,
       _now = now ?? DateTime.now;
  static Future<void> _discard(LocalCameraAlert _) async {}
  static Future<bool> _allowed(bool _) async => true;
  static const storageKey = 'nestling.localAlerts.v1';
  final NanitSecretStore store;
  final String? Function() address, uid;
  final NanitOfflineCamera Function(String) _factory;
  final Future<void> Function(LocalCameraAlert) _deliver;
  final Future<void> Function(bool) _background;
  final Future<bool> Function(bool) _permission;
  final DateTime Function() _now;
  final Duration interval;
  final policy = LocalAlertPolicy();
  final history = <LocalCameraAlert>[];
  bool enabled = false,
      soundEnabled = true,
      cryEnabled = true,
      changing = false;
  SoundSensitivity sensitivity = SoundSensitivity.normal;
  NanitDetectionSnapshot? latest;
  String? problem, notificationProblem;
  DateTime? lastReceived;
  Timer? _timer, _watchdog;
  NanitOfflineCamera? _camera;
  String? _session;
  int _generation = 0;
  bool _disposed = false, _outageShown = false;
  DateTime? _started;
  DateTime? _unhealthySince;
  String? get status {
    if (!enabled) return 'Monitoring is off';
    if (problem != null) return problem;
    if (lastReceived == null) return 'Connecting to sound monitoring…';
    if (_now().difference(lastReceived!) > const Duration(seconds: 8)) {
      return 'Monitoring interrupted. Reconnecting…';
    }
    if (!latest!.microphone) return 'Camera microphone is muted';
    if (soundEnabled && !latest!.levelFresh) {
      return 'Waiting for microphone levels…';
    }
    if (cryEnabled && !latest!.cryFresh) {
      return 'Cry detection unavailable or stale';
    }
    if (latest!.speakerActive && soundEnabled) {
      return cryEnabled
          ? 'Cry monitoring active · sound alerts paused during speaker playback'
          : 'Camera speaker playing · sound alerts paused';
    }
    return soundEnabled && cryEnabled
        ? 'Monitoring sound and crying on your home network'
        : soundEnabled
        ? 'Monitoring sound on your home network'
        : 'Monitoring possible crying on your home network';
  }

  bool get healthy =>
      enabled &&
      problem == null &&
      latest != null &&
      lastReceived != null &&
      _now().difference(lastReceived!) < const Duration(seconds: 8) &&
      (!soundEnabled || latest!.levelFresh) &&
      (!cryEnabled || latest!.cryFresh);

  Future<void> load() async {
    try {
      final raw = await store.read(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        soundEnabled = data['sound'] as bool? ?? true;
        cryEnabled = data['cry'] as bool? ?? true;
        sensitivity =
            SoundSensitivity.values
                .where((s) => s.name == data['sensitivity'])
                .firstOrNull ??
            SoundSensitivity.normal;
        if (data['enabled'] == true && address() != null) {
          await setEnabled(true, requestPermission: false);
        }
      }
    } catch (_) {
      problem = 'Saved alert settings could not be loaded.';
    }
    _notify();
  }

  Future<void> _save() => store.write(
    storageKey,
    jsonEncode({
      'enabled': enabled,
      'sound': soundEnabled,
      'cry': cryEnabled,
      'sensitivity': sensitivity.name,
    }),
  );

  Future<void> setEnabled(bool on, {bool requestPermission = true}) async {
    if (changing || _disposed) return;
    changing = true;
    problem = null;
    _notify();
    try {
      if (on) {
        if (address() == null) throw StateError('Add a camera first');
        if (!soundEnabled && !cryEnabled) {
          throw StateError('Choose sound or cry alerts first.');
        }
        if (!await _permission(requestPermission)) {
          throw StateError(
            'Allow Nestling notifications to enable camera alerts.',
          );
        }
        await _background(true);
        enabled = true;
        await _save();
        await restart();
      } else {
        enabled = false;
        await _save();
        await _stop();
        await _background(false);
      }
    } catch (e) {
      enabled = false;
      await _stop();
      try {
        await _background(false);
        await _save();
      } catch (_) {
        /* Preserve the original error. */
      }
      problem = e is StateError
          ? e.message.toString()
          : 'Could not start background camera monitoring.';
    } finally {
      changing = false;
      _notify();
    }
  }

  Future<void> configure({
    bool? sound,
    bool? cry,
    SoundSensitivity? level,
  }) async {
    soundEnabled = sound ?? soundEnabled;
    cryEnabled = cry ?? cryEnabled;
    sensitivity = level ?? sensitivity;
    policy.rearm();
    await _save();
    if (!soundEnabled && !cryEnabled && enabled) await setEnabled(false);
    _notify();
  }

  Future<void> restart() async {
    await _stop();
    if (!enabled || _disposed || address() == null) return;
    final generation = _generation;
    _started = _now();
    _unhealthySince = _started;
    _outageShown = false;
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      if (generation != _generation || !enabled) return;
      if (healthy) {
        _unhealthySince = null;
      } else {
        _unhealthySince ??= _now();
      }
      if (!healthy &&
          _now().difference(_unhealthySince!) > const Duration(seconds: 15) &&
          !_outageShown) {
        _outageShown = true;
        unawaited(_emit(LocalAlertKind.unavailable, generation));
      }
      _notify();
    });
    unawaited(_poll(generation));
  }

  Future<void> _poll(int generation) async {
    bool current() => !_disposed && enabled && generation == _generation;
    if (!current()) return;
    try {
      if (_camera == null) {
        var candidate = _factory(address()!);
        NanitOfflineInfo info;
        try {
          info = await candidate.identify();
        } catch (_) {
          candidate.close();
          final found = await BackgroundSync.withMulticast(
            () => NanitOfflineDiscovery().locate(uid()!),
          );
          if (!current()) return;
          if (found == null) rethrow;
          candidate = _factory(found);
          try {
            info = await candidate.identify();
          } catch (_) {
            candidate.close();
            rethrow;
          }
        }
        if (!current()) {
          candidate.close();
          return;
        }
        if (info.uid != uid()) {
          candidate.close();
          throw const FormatException('Different camera at this address');
        }
        _camera = candidate;
        _session = List.generate(
          8,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        policy.rearm();
      }
      final value = await _camera!.pollDetection(_session!);
      if (!current()) return;
      latest = value;
      lastReceived = _now();
      problem = null;
      if (healthy) _outageShown = false;
      for (final kind in policy.accept(
        value,
        _now(),
        sound: soundEnabled,
        cry: cryEnabled,
        sensitivity: sensitivity,
      )) {
        await _emit(kind, generation);
        if (!current()) return;
      }
    } catch (_) {
      if (!current()) return;
      _camera?.close();
      _camera = null;
      _session = null;
      latest = null;
      problem = 'Monitoring interrupted. Reconnecting…';
      policy.rearm();
    }
    if (current()) {
      _notify();
      _timer = Timer(interval, () => _poll(generation));
    }
  }

  Future<void> _emit(LocalAlertKind kind, int generation) async {
    if (!enabled || generation != _generation || _disposed) return;
    final alert = LocalCameraAlert(kind, _now());
    history.insert(0, alert);
    if (history.length > 20) history.removeLast();
    try {
      if (!await _permission(false)) {
        throw StateError('Notifications blocked');
      }
      await _deliver(alert);
      notificationProblem = null;
    } catch (_) {
      notificationProblem =
          'Could not show alerts. Check Nestling notification permissions.';
    }
    _notify();
  }

  Future<void> _stop() async {
    ++_generation;
    _timer?.cancel();
    _watchdog?.cancel();
    final camera = _camera, session = _session;
    _camera = null;
    _session = null;
    latest = null;
    lastReceived = null;
    if (camera != null) {
      try {
        if (session != null) await camera.stopDetection(session);
      } catch (_) {
        /* Lease expires. */
      } finally {
        camera.close();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    enabled = false;
    unawaited(_stop());
    unawaited(_background(false).catchError((Object _) {}));
    super.dispose();
  }
}
