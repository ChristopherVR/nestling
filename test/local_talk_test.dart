import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/src/local_talk.dart';

class FakeMic implements TalkMicrophone {
  FakeMic({this.allowed = true});
  final bool allowed;
  final audio = StreamController<Uint8List>();
  int starts = 0, stops = 0;
  bool open = false;
  @override
  Future<bool> ensurePermission() async => allowed;
  @override
  Future<Stream<Uint8List>> start() async {
    starts++;
    open = true;
    return audio.stream;
  }

  @override
  Future<void> stop() async {
    if (open) stops++;
    open = false;
  }

  @override
  Future<void> dispose() async {}
}

/// A pretend camera FastCGI port that records what each request carried.
class FakeCamera {
  late final ServerSocket server;
  final requests = <BytesBuilder>[];
  final connections = <Socket>[];

  Future<void> start() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((socket) {
      connections.add(socket);
      final body = BytesBuilder();
      requests.add(body);
      socket.listen(
        (data) {
          body.add(data);
          final text = latin1.decode(body.toBytes());
          // Short script requests: answer once the empty stdin ends them.
          String? reply;
          if (text.contains('mkdir')) reply = 'READY';
          if (text.contains('rm -rf')) reply = 'DONE';
          if (reply != null && !text.contains('__replied__')) {
            _reply(socket, reply);
          }
        },
        onError: (_) {},
        onDone: () => socket.destroy(),
      );
    });
  }

  void _reply(Socket socket, String text) {
    final out = utf8.encode('Content-Type: text/plain\r\n\r\n$text');
    socket.add([1, 6, 0, 1, out.length >> 8, out.length & 255, 0, 0, ...out]);
    socket.add([1, 3, 0, 1, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
  }

  Future<void> close() async {
    for (final c in connections) {
      c.destroy();
    }
    await server.close();
  }
}

Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 200));

void main() {
  late FakeCamera camera;
  setUp(() async {
    camera = FakeCamera();
    await camera.start();
  });
  tearDown(() => camera.close());

  LocalTalk make(FakeMic mic, {Duration? maxHold}) => LocalTalk(
    address: '192.168.1.5',
    microphone: mic,
    maxHold: maxHold ?? const Duration(seconds: 60),
    connector: (_, _) =>
        Socket.connect(InternetAddress.loopbackIPv4, camera.server.port),
  );

  test('refuses addresses outside the home network', () {
    expect(() => LocalTalk(address: '8.8.8.8'), throwsA(anything));
  });

  test(
    'microphone stays closed and nothing is sent when permission is off',
    () async {
      final mic = FakeMic(allowed: false);
      final talk = make(mic);
      await talk.start();
      expect(talk.state, TalkState.denied);
      expect(mic.starts, 0);
      expect(camera.requests, isEmpty);
      talk.dispose();
    },
  );

  test(
    'audio flows only while held, and the microphone closes on release',
    () async {
      final mic = FakeMic();
      final talk = make(mic);
      await talk.start();
      expect(talk.state, TalkState.talking);
      expect(mic.open, isTrue);

      mic.audio.add(Uint8List.fromList(List.filled(3200, 200)));
      await settle();
      // Request 0 installs the helper, request 1 carries the voice.
      final talkRequest = camera.requests[1].toBytes();
      expect(latin1.decode(talkRequest), contains('/play.sh'));
      expect(talkRequest.where((b) => b == 200).length, 3200);

      await talk.stop();
      expect(talk.state, TalkState.idle);
      expect(mic.open, isFalse);
      expect(mic.stops, 1);

      // Anything the microphone still emits goes nowhere.
      final before = camera.requests[1].length;
      mic.audio.add(Uint8List.fromList(List.filled(3200, 201)));
      await settle();
      expect(camera.requests[1].length, before);

      // The helper is cleaned up on the camera.
      final last = latin1.decode(camera.requests.last.toBytes());
      expect(last, contains('rm -rf'));
      talk.dispose();
    },
  );

  test(
    'releasing before the camera is ready never leaves the mic open',
    () async {
      final mic = FakeMic();
      final talk = make(mic);
      final starting = talk.start();
      await talk.stop();
      await starting;
      await settle();
      expect(talk.active, isFalse);
      expect(mic.open, isFalse);
      talk.dispose();
    },
  );

  test('a dropped connection ends the talk', () async {
    final mic = FakeMic();
    final talk = make(mic);
    await talk.start();
    for (final c in camera.connections) {
      c.destroy();
    }
    await settle();
    expect(talk.active, isFalse);
    expect(mic.open, isFalse);
    talk.dispose();
  });

  test('closing the screen (dispose) stops the microphone', () async {
    final mic = FakeMic();
    final talk = make(mic);
    await talk.start();
    talk.dispose();
    await settle();
    expect(mic.open, isFalse);
  });

  test('talking ends by itself after the hold limit', () async {
    final mic = FakeMic();
    final talk = make(mic, maxHold: const Duration(milliseconds: 300));
    await talk.start();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(talk.state, TalkState.idle);
    expect(mic.open, isFalse);
    talk.dispose();
  });

  test('camera that cannot be reached is a failure, mic closed', () async {
    final mic = FakeMic();
    final talk = LocalTalk(
      address: '192.168.1.5',
      microphone: mic,
      connector: (_, _) => throw const SocketException('no route'),
    );
    await talk.start();
    expect(talk.state, TalkState.failed);
    expect(mic.open, isFalse);
    talk.dispose();
  });
}
