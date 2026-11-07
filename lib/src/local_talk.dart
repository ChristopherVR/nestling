import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nanit_camera/nanit_camera.dart';
import 'package:record/record.dart';

/// Talking through a Nanit camera on the home network.
///
/// APP-SIDE ADAPTER. The nanit_camera package has no talk-back; the research
/// repo only proves it in `prototypes/nanit_offline_talk.py`: the camera's
/// FastCGI service (TCP 8081, the same one [NanitOfflineCamera] uses) runs a
/// tiny helper that pipes raw PCM16 / 16 kHz / mono from the request body
/// into `pacat --playback`, the camera's speaker. This file does the same
/// from Dart. Upstream, it belongs in NanitOfflineCamera as `talk()`.
///
/// Not verified on a real camera: that speech is intelligible and that the
/// camera accepts a request body that ends before its declared length.
///
/// Privacy rule: the microphone is only open between [start] and [stop].

enum TalkState { idle, starting, talking, denied, failed }

/// Where the voice comes from. A fake in tests.
abstract class TalkMicrophone {
  /// Asks for (or checks) microphone permission.
  Future<bool> ensurePermission();

  /// Raw PCM16 little-endian, 16 kHz, mono.
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> dispose();
}

class RecordTalkMicrophone implements TalkMicrophone {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> ensurePermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start() => _recorder.startStream(
    const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: LocalTalk.sampleRate,
      numChannels: 1,
    ),
  );

  @override
  Future<void> stop() async {
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

class LocalTalk extends ChangeNotifier {
  LocalTalk({
    required String address,
    TalkMicrophone? microphone,
    this.connector,
    this.maxHold = const Duration(seconds: 60),
    this.volumePercent = 25,
  }) : address = requireNanitLanAddress(address),
       _mic = microphone ?? RecordTalkMicrophone();

  static const sampleRate = 16000;
  static const _bytesPerSecond = sampleRate * 2;

  final String address;
  final Future<Socket> Function(String, int)? connector;

  /// Talking always ends after this, even if the button is somehow stuck.
  final Duration maxHold;

  /// Speaker volume for this stream only; the camera's own volume is kept.
  final int volumePercent;

  final TalkMicrophone _mic;
  TalkState state = TalkState.idle;
  bool _wanted = false, _disposed = false, _busy = false;
  Socket? _socket;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<List<int>>? _socketSub;
  Timer? _limit;
  String? _dir;
  final BytesBuilder _reply = BytesBuilder(copy: false);
  Completer<void>? _finished;

  bool get active => state == TalkState.starting || state == TalkState.talking;

  void _set(TalkState next) {
    if (_disposed || state == next) return;
    state = next;
    notifyListeners();
  }

  /// Button pressed. Safe to call again while already talking.
  Future<void> start() async {
    if (_disposed || _wanted || _busy) return;
    _wanted = true;
    _busy = true;
    _set(TalkState.starting);
    try {
      if (!await _mic.ensurePermission()) {
        _wanted = false;
        _set(TalkState.denied);
        return;
      }
      if (!_wanted) {
        await _teardown(TalkState.idle);
        return;
      }
      _dir = '/tmp/nestling-talk-${_token()}';
      await _install();
      if (!_wanted) {
        await _teardown(TalkState.idle);
        return;
      }
      final socket = await _open();
      _socket = socket;
      _finished = Completer<void>();
      _socketSub = socket.listen(
        _onReply,
        // A dropped connection ends the talk at once.
        onError: (_) => _drop(),
        onDone: _drop,
        cancelOnError: true,
      );
      _sendRequestHead(socket);
      final audio = await _mic.start();
      if (!_wanted || _socket == null) {
        await _teardown(TalkState.idle);
        return;
      }
      _micSub = audio.listen(_sendAudio, onError: (_) => _drop());
      _limit = Timer(maxHold, () => unawaited(stop()));
      _set(TalkState.talking);
    } catch (_) {
      await _teardown(TalkState.failed);
    } finally {
      _busy = false;
      // Released while still starting: shut everything down now.
      if (!_wanted && active) await _teardown(TalkState.idle);
    }
  }

  /// Button released, screen closed, app backgrounded, connection lost.
  Future<void> stop() async {
    _wanted = false;
    if (_busy) return; // start() notices and tears down.
    if (state == TalkState.denied || state == TalkState.failed) {
      _set(TalkState.idle);
      return;
    }
    await _teardown(TalkState.idle);
  }

  void _drop() {
    if (_socket == null) return;
    _wanted = false;
    unawaited(_teardown(active ? TalkState.failed : TalkState.idle));
  }

  Future<void> _teardown(TalkState end) async {
    _limit?.cancel();
    _limit = null;
    // The screen shows "not talking" at once, before the camera is told.
    _set(end);
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _mic.stop();
    } catch (_) {}
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        // End of the audio; the helper then finishes by itself.
        _record(socket, 5, const []);
        await socket.flush();
        await _finished?.future.timeout(const Duration(seconds: 2));
      } catch (_) {}
      await _socketSub?.cancel();
      socket.destroy();
    }
    _socketSub = null;
    _finished = null;
    final dir = _dir;
    _dir = null;
    if (dir != null) await _cleanup(dir);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _wanted = false;
    _disposed = true; // no more notifications from here on
    // Fire and forget; the microphone and speaker stream must close even as
    // the screen goes.
    unawaited(_teardown(TalkState.idle).whenComplete(_mic.dispose));
    super.dispose();
  }

  // --- camera side ---------------------------------------------------------

  static String _token() {
    final r = Random.secure();
    return List.generate(12, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<Socket> _open() async {
    final socket =
        await (connector?.call(address, 8081) ??
            Socket.connect(address, 8081, timeout: const Duration(seconds: 3)));
    // A write after the camera hung up is expected; it must not escape.
    unawaited(socket.done.then((_) {}, onError: (Object _) {}));
    return socket;
  }

  /// Writes the small helper that plays stdin on the speaker. Only fixed
  /// text and a random hex token are used; nothing typed by the user.
  String _helperScript(String dir) {
    final volume = (volumePercent.clamp(1, 30) * 65536 / 100).round();
    final seconds = maxHold.inSeconds + 10;
    return '#!/bin/sh\n'
        'PATH=/usr/sbin:/usr/bin:/sbin:/bin\nexport PATH\n'
        "printf 'Content-Type: text/plain\\r\\n\\r\\n'\n"
        'echo \$\$ > $dir/pid\n'
        'exec timeout $seconds /usr/bin/pacat --playback '
        '--client-name=nestling-talk --rate=$sampleRate --channels=1 '
        '--format=s16le --raw --volume=$volume\n';
  }

  Future<void> _install() async {
    final dir = _dir!;
    final encoded = base64.encode(utf8.encode(_helperScript(dir)));
    await _run(
      "printf 'Content-Type: text/plain\\r\\n\\r\\n'\n"
      'set -e\numask 077\nmkdir $dir\n'
      "printf '%s' '$encoded' | base64 -d > $dir/play.sh\n"
      'chmod 700 $dir/play.sh\nprintf READY\n',
      expect: 'READY',
    );
  }

  Future<void> _cleanup(String dir) async {
    try {
      await _run(
        "printf 'Content-Type: text/plain\\r\\n\\r\\n'\n"
        '[ -f $dir/pid ] && kill \$(cat $dir/pid) 2>/dev/null\n'
        'rm -rf $dir\nprintf DONE\n',
        expect: 'DONE',
      );
    } catch (_) {}
  }

  /// One short FastCGI request that runs [script] in /bin/sh.
  Future<void> _run(String script, {required String expect}) async {
    final socket = await _open();
    final body = BytesBuilder(copy: false);
    final done = Completer<void>();
    final sub = socket.listen(
      (data) {
        final end = _FcgiReply.feed(body, data);
        if (end && !done.isCompleted) done.complete();
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    try {
      final bytes = utf8.encode('$script\n');
      _record(socket, 1, const [0, 1, 0, 0, 0, 0, 0, 0]);
      _record(socket, 4, _params('/bin/sh', bytes.length));
      _record(socket, 4, const []);
      for (var i = 0; i < bytes.length; i += 60000) {
        _record(socket, 5, bytes.sublist(i, min(bytes.length, i + 60000)));
      }
      _record(socket, 5, const []);
      await socket.flush();
      await done.future.timeout(const Duration(seconds: 8));
      if (!utf8.decode(body.toBytes(), allowMalformed: true).contains(expect)) {
        throw const FormatException('The camera did not accept the request');
      }
    } finally {
      await sub.cancel();
      socket.destroy();
    }
  }

  void _sendRequestHead(Socket socket) {
    // The declared length is the longest possible talk; audio simply stops
    // early. The length is only a cap for the camera's request reader.
    final length = maxHold.inSeconds * _bytesPerSecond;
    _record(socket, 1, const [0, 1, 0, 0, 0, 0, 0, 0]);
    _record(socket, 4, _params('$_dir/play.sh', length));
    _record(socket, 4, const []);
  }

  void _sendAudio(Uint8List chunk) {
    final socket = _socket;
    if (socket == null || !_wanted) return;
    try {
      for (var i = 0; i < chunk.length; i += 60000) {
        _record(socket, 5, chunk.sublist(i, min(chunk.length, i + 60000)));
      }
    } catch (_) {
      _drop();
    }
  }

  void _onReply(List<int> data) {
    if (_FcgiReply.feed(_reply, data) && _finished?.isCompleted == false) {
      _finished!.complete();
    }
  }

  @visibleForTesting
  static List<int> params(String script, int length) => _params(script, length);

  static List<int> _params(String script, int length) {
    final out = <int>[];
    for (final e in {
      'SCRIPT_FILENAME': script,
      'SCRIPT_NAME': '/nestling-talk',
      'REQUEST_METHOD': 'POST',
      'SERVER_PROTOCOL': 'HTTP/1.1',
      'GATEWAY_INTERFACE': 'CGI/1.1',
      'SERVER_NAME': 'localhost',
      'SERVER_PORT': '8081',
      'CONTENT_TYPE': 'application/octet-stream',
      'CONTENT_LENGTH': '$length',
    }.entries) {
      final k = utf8.encode(e.key), v = utf8.encode(e.value);
      out.addAll([k.length, v.length, ...k, ...v]);
    }
    return out;
  }

  static void _record(Socket socket, int kind, List<int> body) {
    socket.add([1, kind, 0, 1, body.length >> 8, body.length & 255, 0, 0]);
    if (body.isNotEmpty) socket.add(body);
  }
}

/// Minimal FastCGI reply reader: collects stdout and reports the end record.
class _FcgiReply {
  static final _pending = Expando<BytesBuilder>();

  /// Adds [data] to [out]'s raw bytes; true once an end-request record
  /// (type 3) is complete. Stdout text is what the caller inspects.
  static bool feed(BytesBuilder out, List<int> data) {
    final raw = _pending[out] ??= BytesBuilder(copy: false);
    raw.add(data);
    final bytes = raw.toBytes();
    var i = 0, ended = false;
    final text = BytesBuilder(copy: false);
    while (bytes.length - i >= 8) {
      final len = bytes[i + 4] * 256 + bytes[i + 5], pad = bytes[i + 6];
      if (bytes.length - i < 8 + len + pad) break;
      if (bytes[i + 1] == 6) {
        text.add(bytes.sublist(i + 8, i + 8 + len));
      }
      if (bytes[i + 1] == 3) ended = true;
      i += 8 + len + pad;
    }
    out.add(text.toBytes());
    final rest = bytes.sublist(i);
    raw.clear();
    raw.add(rest);
    return ended;
  }
}
