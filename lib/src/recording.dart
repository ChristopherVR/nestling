import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Local-only recording of the camera's live video. Files stay in the app's
/// own `Recordings` folder on this device; nothing is ever uploaded.

/// mp4 plays everywhere (phone gallery, Windows, other apps), and libmpv
/// copies the camera's H.264/AAC into it without re-encoding.
const recordingExtension = 'mp4';

/// Safety nets: a recording ends by itself at either limit so a forgotten
/// recording cannot fill the device.
const recordingMaxDuration = Duration(hours: 2);
const recordingMaxBytes = 1500 * 1024 * 1024;

/// A recording that does not grow for this long is treated as stalled (disk
/// full, stream gone) and is closed so what was captured is kept.
const recordingStallLimit = Duration(seconds: 12);

String _two(int n) => n.toString().padLeft(2, '0');

/// `Nestling-2026-11-08_14-30-05.mp4`
String recordingFileName(DateTime start) =>
    'Nestling-${start.year}-${_two(start.month)}-${_two(start.day)}_'
    '${_two(start.hour)}-${_two(start.minute)}-${_two(start.second)}'
    '.$recordingExtension';

final _nameStamp = RegExp(
  r'^Nestling-(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})\.'
  '$recordingExtension\$',
);

/// The start time encoded in a recording's file name, or null for a file
/// that Nestling did not name.
DateTime? recordingStartOf(String fileName) {
  final m = _nameStamp.firstMatch(fileName);
  if (m == null) return null;
  final v = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  return DateTime(v[0], v[1], v[2], v[3], v[4], v[5]);
}

/// `1:05` or `1:02:03`.
String formatRecordingDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}

String formatRecordingSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// One saved recording.
class Recording {
  const Recording({
    required this.path,
    required this.started,
    required this.bytes,
    this.duration,
  });
  final String path;
  final DateTime started;
  final int bytes;

  /// Null when unknown (for example the app was closed mid-recording).
  final Duration? duration;

  String get name => path.split(RegExp(r'[\\/]')).last;
}

/// The `Recordings` folder: list, remember lengths, delete.
class RecordingStore {
  RecordingStore(this.directory);
  final Directory directory;

  String pathFor(DateTime start) =>
      '${directory.path}${Platform.pathSeparator}${recordingFileName(start)}';

  String _lengthFile(String path) => '$path.len';

  Future<void> ensure() => directory.create(recursive: true);

  Future<void> saveDuration(String path, Duration d) async {
    try {
      await File(_lengthFile(path)).writeAsString('${d.inSeconds}');
    } catch (_) {
      // The length is a nicety; the video is already safe.
    }
  }

  /// Newest first. Empty files (a recording that never received video) are
  /// removed rather than listed.
  Future<List<Recording>> list() async {
    if (!await directory.exists()) return const [];
    final out = <Recording>[];
    await for (final e in directory.list()) {
      if (e is! File) continue;
      final name = e.path.split(RegExp(r'[\\/]')).last;
      final start = recordingStartOf(name);
      if (start == null) continue;
      final bytes = await e.length();
      if (bytes == 0) {
        await delete(e.path);
        continue;
      }
      Duration? length;
      try {
        final s = int.tryParse(await File(_lengthFile(e.path)).readAsString());
        if (s != null) length = Duration(seconds: s);
      } catch (_) {}
      out.add(
        Recording(path: e.path, started: start, bytes: bytes, duration: length),
      );
    }
    out.sort((a, b) => b.started.compareTo(a.started));
    return out;
  }

  Future<void> delete(String path) async {
    for (final p in [path, _lengthFile(path)]) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}

/// What the recorder writes through. The app's implementation sets libmpv's
/// `stream-record` property; tests pass a fake.
abstract interface class RecordingSink {
  /// Starts writing the incoming stream to [path], or stops when empty.
  Future<void> setRecordPath(String path);
}

enum RecordingProblem {
  /// Record was pressed with no video on screen.
  notLive,

  /// The video stopped while recording; what was captured is kept.
  streamDropped,

  /// The file stopped growing (device full or write error); kept as is.
  storage,

  /// Reached the safety limit; kept as is.
  limit,

  /// The file could not be started.
  failed,

  /// Nothing was captured.
  empty,
}

/// Records the live video through the attached [RecordingSink].
class RecordingController extends ChangeNotifier {
  RecordingController({
    required this.store,
    DateTime Function()? clock,
    this.tick = const Duration(seconds: 1),
    this.maxDuration = recordingMaxDuration,
    this.maxBytes = recordingMaxBytes,
    this.stallLimit = recordingStallLimit,
  }) : _clock = clock ?? DateTime.now;

  final RecordingStore store;
  final DateTime Function() _clock;
  final Duration tick;
  final Duration maxDuration;
  final int maxBytes;
  final Duration stallLimit;

  RecordingSink? _sink;
  Timer? _timer;
  String? _path;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  int _lastBytes = 0;
  Duration _lastGrowth = Duration.zero;
  bool _stopping = false;
  Future<void>? _stopFuture;
  bool _disposed = false;
  RecordingProblem? _problem;

  bool get recording => _path != null;
  bool get attached => _sink != null;
  Duration get elapsed => _elapsed;

  /// The latest thing worth telling the user; cleared by [clearProblem] and
  /// when a new recording starts.
  RecordingProblem? get problem => _problem;
  void clearProblem() {
    if (_problem == null) return;
    _problem = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// A player is showing video and can be recorded.
  void attach(RecordingSink sink) {
    _sink = sink;
    _notify();
  }

  /// The player is going away. Finishes any recording first.
  Future<void> detach(RecordingSink sink) async {
    if (!identical(_sink, sink)) return;
    await stop(reason: RecordingProblem.streamDropped, quiet: true);
    if (identical(_sink, sink)) _sink = null;
    _notify();
  }

  Future<void> start() async {
    if (recording || _stopping) return;
    final sink = _sink;
    _problem = null;
    if (sink == null) {
      _problem = RecordingProblem.notLive;
      _notify();
      return;
    }
    final now = _clock();
    final path = store.pathFor(now);
    try {
      await store.ensure();
      await sink.setRecordPath(path);
    } catch (_) {
      _problem = RecordingProblem.failed;
      _notify();
      return;
    }
    _path = path;
    _startedAt = now;
    _elapsed = Duration.zero;
    _lastBytes = 0;
    _lastGrowth = Duration.zero;
    _timer = Timer.periodic(tick, (_) => unawaited(_check()));
    _notify();
  }

  Future<void> _check() async {
    final path = _path;
    if (path == null || _stopping) return;
    _elapsed += tick;
    var bytes = _lastBytes;
    try {
      final f = File(path);
      if (await f.exists()) bytes = await f.length();
    } catch (_) {}
    if (bytes > _lastBytes) {
      _lastBytes = bytes;
      _lastGrowth = _elapsed;
    }
    if (_elapsed >= maxDuration || bytes >= maxBytes) {
      await stop(reason: RecordingProblem.limit);
    } else if (_elapsed - _lastGrowth >= stallLimit) {
      // mp4 only grows once libmpv flushes; a long flat line means trouble.
      await stop(
        reason: _lastBytes == 0
            ? RecordingProblem.empty
            : RecordingProblem.storage,
      );
    } else {
      _notify();
    }
  }

  /// Stops recording and keeps the file. [reason] is shown to the user
  /// unless [quiet] (a normal Stop press passes null and is quiet).
  Future<void> stop({RecordingProblem? reason, bool quiet = false}) {
    if (_stopFuture != null) return _stopFuture!;
    if (_path == null) return Future.value();
    return _stopFuture = _stop(reason, quiet).whenComplete(() {
      _stopFuture = null;
    });
  }

  Future<void> _stop(RecordingProblem? reason, bool quiet) async {
    final path = _path!;
    _stopping = true;
    _timer?.cancel();
    _timer = null;
    final length = _startedAt == null
        ? _elapsed
        : _clock().difference(_startedAt!);
    try {
      await _sink?.setRecordPath('');
    } catch (_) {}
    _path = null;
    _startedAt = null;
    var kept = false;
    try {
      final f = File(path);
      kept = await f.exists() && await f.length() > 0;
    } catch (_) {}
    if (kept) {
      await store.saveDuration(path, length);
    } else {
      await store.delete(path);
    }
    _problem = !kept && reason != RecordingProblem.notLive
        ? RecordingProblem.empty
        : (quiet ? null : reason);
    _stopping = false;
    _notify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
