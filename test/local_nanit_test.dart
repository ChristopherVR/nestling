import 'dart:async';
import 'dart:convert';

import 'package:baby_app/src/local_nanit.dart';
import 'package:baby_app/src/ui/camera_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

import 'nanit_integration_test.dart' show FakeNanitHttp, testHub;

class FakeLocalCamera extends NanitOfflineCamera {
  FakeLocalCamera(super.address);
  Completer<NanitOfflineInfo>? pendingIdentity;
  Completer<NanitRoomReadings>? pendingReadings;
  String uid = 'N301TEST123456';
  int starts = 0, reads = 0, lights = 0;
  bool closed = false;
  int soundPlays = 0, soundStops = 0;
  NanitSoundState sound = const NanitSoundState(
    supported: true,
    playing: false,
  );
  @override
  Future<NanitSoundState> soundStatus() async => sound;
  @override
  Future<NanitSoundState> playSound(
    NanitSoundTrack track, {
    int volume = 20,
    int seconds = 900,
  }) async {
    soundPlays++;
    return sound = NanitSoundState(
      supported: true,
      playing: true,
      track: track,
      volume: volume,
      remainingSeconds: seconds,
    );
  }

  @override
  Future<NanitSoundState> stopSound() async {
    soundStops++;
    return sound = const NanitSoundState(supported: true, playing: false);
  }

  @override
  Future<NanitOfflineInfo> identify() async =>
      pendingIdentity?.future ??
      NanitOfflineInfo(address: address, uid: uid, firmware: '6.58.615');
  @override
  Future<void> startMedia() async {
    starts++;
  }

  @override
  Future<NanitRoomReadings> readings() async {
    reads++;
    if (pendingReadings != null) return pendingReadings!.future;
    return NanitRoomReadings(
      temperature: 22,
      humidity: 60,
      nightLight: 0,
      at: DateTime.now(),
    );
  }

  @override
  Future<NanitRoomReadings> setNightLight(int percent) async {
    lights++;
    return readings();
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'watch never plays sounds; explicit controls preserve the video connection',
    () async {
      final device = FakeLocalCamera('192.168.1.5');
      final hub =
          LocalNanitHub(
              store: MemoryNanitSecretStore(),
              cameraFactory: (_) => device,
            )
            ..saved = const SavedLocalCamera(
              address: '192.168.1.5',
              uid: 'N301TEST123456',
              firmware: '6.58.615',
            );
      try {
        await hub.watch();
        await Future<void>.delayed(Duration.zero);
        final url = hub.streamUrl;
        expect(device.soundPlays, 0);
        expect(hub.sound?.playing, isFalse);
        await hub.playSound(NanitSoundTrack.whiteNoise, 25, 300);
        expect(hub.sound?.track, NanitSoundTrack.whiteNoise);
        expect(hub.sound?.volume, 25);
        expect(hub.sound?.remainingSeconds, 300);
        expect(hub.streamUrl, url);
        await hub.stopSound();
        expect(hub.sound?.playing, isFalse);
        expect(device.soundStops, 1);
        expect(hub.streamUrl, url);
        await hub.pause();
        expect(
          device.soundStops,
          1,
          reason: 'Leaving must not stop a timed sound',
        );
      } finally {
        await hub.pause();
        hub.dispose();
      }
    },
  );

  test(
    'slow or failed room telemetry cannot block or disconnect video',
    () async {
      final device = FakeLocalCamera('192.168.1.5')
        ..pendingReadings = Completer<NanitRoomReadings>();
      final hub =
          LocalNanitHub(
              store: MemoryNanitSecretStore(),
              cameraFactory: (_) => device,
            )
            ..saved = const SavedLocalCamera(
              address: '192.168.1.5',
              uid: 'N301TEST123456',
              firmware: '6.58.615',
            );
      try {
        await hub.watch().timeout(const Duration(seconds: 1));
        final url = hub.streamUrl;
        expect(hub.state, LocalCameraState.ready);
        expect(url, isNotNull);
        expect(hub.readings, isNull);
        device.pendingReadings!.completeError(
          TimeoutException('maintenance busy'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(hub.state, LocalCameraState.ready);
        expect(hub.streamUrl, url);
        expect(device.closed, isFalse);
        expect(hub.problem, contains('Room readings unavailable'));
      } finally {
        await hub.pause();
        hub.dispose();
      }
    },
  );

  test(
    'late room telemetry after pause cannot revive readings or polling',
    () async {
      final device = FakeLocalCamera('192.168.1.5')
        ..pendingReadings = Completer<NanitRoomReadings>();
      final hub =
          LocalNanitHub(
              store: MemoryNanitSecretStore(),
              cameraFactory: (_) => device,
            )
            ..saved = const SavedLocalCamera(
              address: '192.168.1.5',
              uid: 'N301TEST123456',
              firmware: '6.58.615',
            );
      await hub.watch();
      await hub.pause();
      device.pendingReadings!.complete(
        NanitRoomReadings(temperature: 22, at: DateTime.now()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(hub.readings, isNull);
      expect(hub.state, LocalCameraState.idle);
      hub.dispose();
    },
  );

  test(
    'local setup saves only camera metadata and does not start media',
    () async {
      final store = MemoryNanitSecretStore();
      final device = FakeLocalCamera('192.168.1.5');
      final hub = LocalNanitHub(store: store, cameraFactory: (_) => device);
      await hub.add('192.168.1.5', name: 'Nursery');
      final json = jsonDecode(store.values[LocalNanitHub.storageKey]!);
      expect(
        json.keys,
        unorderedEquals(['address', 'uid', 'firmware', 'name']),
      );
      expect(device.starts, 0);
      expect(device.lights, 0);
      expect(device.closed, isTrue);
      final restored = LocalNanitHub(store: store);
      await restored.load();
      expect(restored.saved!.name, 'Nursery');
      await restored.forget();
      expect(store.values, isEmpty);
      hub.dispose();
      restored.dispose();
    },
  );

  test(
    'local startup makes no account requests and opens no legacy connection',
    () async {
      final store = MemoryNanitSecretStore();
      await store.write(
        LocalNanitHub.storageKey,
        jsonEncode(
          const SavedLocalCamera(
            address: '192.168.1.5',
            uid: 'N301TEST123456',
            firmware: '6.58.615',
          ).toJson(),
        ),
      );
      final http = FakeNanitHttp();
      final tested = testHub(store, http);
      await tested.start();
      expect(tested.hasCamera, isTrue);
      expect(tested.connection, isNull);
      expect(http.calls, isEmpty);
      expect(tested.local.state, LocalCameraState.idle);
      tested.dispose();
    },
  );

  test(
    'leaving while connection is pending cannot revive video or write controls',
    () async {
      final store = MemoryNanitSecretStore();
      final device = FakeLocalCamera('192.168.1.5')
        ..pendingIdentity = Completer<NanitOfflineInfo>();
      final hub = LocalNanitHub(store: store, cameraFactory: (_) => device)
        ..saved = const SavedLocalCamera(
          address: '192.168.1.5',
          uid: 'N301TEST123456',
          firmware: '6.58.615',
        );
      final watching = hub.watch();
      await Future<void>.delayed(Duration.zero);
      await hub.pause();
      device.pendingIdentity!.complete(
        const NanitOfflineInfo(
          address: '192.168.1.5',
          uid: 'N301TEST123456',
          firmware: '6.58.615',
        ),
      );
      await watching;
      expect(device.starts, 0);
      expect(device.lights, 0);
      expect(device.closed, isTrue);
      expect(hub.state, LocalCameraState.idle);
      expect(hub.streamUrl, isNull);
      hub.dispose();
    },
  );

  test('changed identity never starts a different camera', () async {
    final device = FakeLocalCamera('192.168.1.5')..uid = 'N301OTHER1234';
    final hub =
        LocalNanitHub(
            store: MemoryNanitSecretStore(),
            cameraFactory: (_) => device,
          )
          ..saved = const SavedLocalCamera(
            address: '192.168.1.5',
            uid: 'N301TEST123456',
            firmware: '6.58.615',
          );
    await hub.watch();
    expect(device.starts, 0);
    expect(hub.problem, contains('different camera'));
    expect(hub.readings, isNull);
    await hub.pause();
    hub.dispose();
  });

  test(
    'watching reads status without changing controls; pause clears readings',
    () async {
      final device = FakeLocalCamera('192.168.1.5');
      final hub =
          LocalNanitHub(
              store: MemoryNanitSecretStore(),
              cameraFactory: (_) => device,
            )
            ..saved = const SavedLocalCamera(
              address: '192.168.1.5',
              uid: 'N301TEST123456',
              firmware: '6.58.615',
            );
      await hub.watch();
      expect(hub.state, LocalCameraState.ready);
      expect(device.starts, 1);
      expect(device.reads, 1);
      expect(device.lights, 0);
      expect(hub.streamUrl, startsWith('rtsp://127.0.0.1:'));
      await Future<void>.delayed(Duration.zero);
      expect(hub.readings!.temperature, 22);
      await hub.setNightLight(50);
      expect(device.lights, 1);
      await hub.pause();
      expect(hub.readings, isNull);
      expect(hub.streamUrl, isNull);
      expect(device.closed, isTrue);
      hub.dispose();
    },
  );

  testWidgets(
    'local onboarding is default, fits a phone and rejects public addresses',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final http = FakeNanitHttp();
      final tested = testHub(MemoryNanitSecretStore(), http);
      await tester.pumpWidget(MaterialApp(home: CameraPage(hub: tested)));
      await tester.runAsync(tested.start);
      await tester.pump();
      expect(find.text('Your camera, at home'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      await tester.pump();
      expect(find.text('Already on Wi-Fi'), findsOneWidget);
      expect(find.text('Set up Wi-Fi'), findsOneWidget);
      await tester.tap(find.text('Already on Wi-Fi'));
      await tester.pump();
      await tester.tap(find.text('This device is on the home Wi-Fi'));
      await tester.pump();
      await tester.ensureVisible(find.text('Enter the address yourself'));
      await tester.tap(find.text('Enter the address yourself'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '8.8.8.8');
      await tester.ensureVisible(find.text('Connect by address'));
      await tester.tap(find.text('Connect by address'));
      await tester.pump();
      final card = find.text('That does not look like a home-network address');
      await tester.ensureVisible(card);
      expect(card, findsOneWidget);
      expect(
        find.text('Enter the camera’s local IPv4 address.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expect(http.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      tested.dispose();
    },
  );
}
