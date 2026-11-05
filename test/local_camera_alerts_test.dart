import 'package:nestling/src/local_camera_alerts.dart';
import 'package:nestling/src/local_nanit.dart';
import 'package:nestling/src/ui/local_camera_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

const boot = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
NanitDetectionSnapshot sample(
  double t, {
  double db = -20,
  bool speaker = false,
  bool mic = true,
  List<double> cry = const [0, 0, 0, 0, 0],
  double? cryAt,
  String id = boot,
}) => NanitDetectionSnapshot(
  boot: id,
  uptime: t,
  microphone: mic,
  speakerActive: speaker,
  classifier: true,
  levelAt: t,
  dbfs: db,
  cry: [NanitCryWindow(cryAt ?? t, cry)],
);

class DetectionCamera extends NanitOfflineCamera {
  DetectionCamera() : super('192.168.1.5');
  int polls = 0, stops = 0;
  bool fail = false;
  @override
  Future<NanitOfflineInfo> identify() async => const NanitOfflineInfo(
    address: '192.168.1.5',
    uid: 'N301TEST123456',
    firmware: '6.58.615',
  );
  @override
  Future<NanitDetectionSnapshot> pollDetection(String session) async {
    if (fail) throw StateError('offline');
    return sample((++polls * 2).toDouble());
  }

  @override
  Future<void> stopDetection(String session) async {
    stops++;
  }

  @override
  void close() {}
}

void main() {
  test('sound debounces, cools down, respects mute and speaker playback', () {
    final policy = LocalAlertPolicy();
    List<LocalAlertKind> take(NanitDetectionSnapshot s, [int seconds = 0]) =>
        policy.accept(
          s,
          DateTime(2026).add(Duration(seconds: seconds)),
          sound: true,
          cry: true,
          sensitivity: SoundSensitivity.normal,
        );
    expect(take(sample(10)), isEmpty); // initial data is not a new alert
    expect(take(sample(12)), isEmpty);
    expect(take(sample(14)), [LocalAlertKind.sound]);
    expect(take(sample(16)), isEmpty);
    expect(take(sample(18, speaker: true), 61), isEmpty);
    expect(take(sample(20), 62), isEmpty);
    expect(take(sample(22, mic: false), 63), isEmpty);
    expect(take(sample(24), 64), isEmpty);
    expect(take(sample(26), 65), [LocalAlertKind.sound]);
  });

  test('cry needs three consecutive probabilities and skips old windows', () {
    final p = LocalAlertPolicy();
    List<LocalAlertKind> take(NanitDetectionSnapshot s) => p.accept(
      s,
      DateTime(2026),
      sound: false,
      cry: true,
      sensitivity: SoundSensitivity.normal,
    );
    expect(take(sample(10, cry: [1, 1, 1, 1, 1])), isEmpty);
    expect(take(sample(15, cry: [.9, 0, .9, 0, .9])), isEmpty);
    expect(take(sample(20, cry: [.9, .9, 0, 0, 0])), [LocalAlertKind.cry]);
    expect(take(sample(21, cryAt: 20, cry: [.9, .9, 0, 0, 0])), isEmpty);
    expect(take(sample(1, id: 'b' * 32, cry: [1, 1, 1, 1, 1])), isEmpty);
  });

  test('stale cry data, a gap and disabled types cannot trigger', () {
    final p = LocalAlertPolicy();
    p.accept(
      sample(10),
      DateTime(2026),
      sound: false,
      cry: true,
      sensitivity: SoundSensitivity.normal,
    );
    expect(
      p.accept(
        sample(40, cryAt: 20, cry: [1, 1, 1, 1, 1]),
        DateTime(2026),
        sound: false,
        cry: true,
        sensitivity: SoundSensitivity.normal,
      ),
      isEmpty,
    );
    expect(
      p.accept(
        sample(45, cry: [1, 1, 0, 0, 0]),
        DateTime(2026),
        sound: false,
        cry: true,
        sensitivity: SoundSensitivity.normal,
      ),
      isEmpty,
    );
    expect(
      p.accept(
        sample(50, cry: [1, 1, 1, 1, 1]),
        DateTime(2026),
        sound: false,
        cry: false,
        sensitivity: SoundSensitivity.normal,
      ),
      isEmpty,
    );
  });

  testWidgets(
    'alerts continue after leaving camera; off stops sampler and service',
    (tester) async {
      final camera = DetectionCamera();
      final delivered = <LocalCameraAlert>[];
      final background = <bool>[];
      final hub = LocalNanitHub(
        store: MemoryNanitSecretStore(),
        cameraFactory: (_) => camera,
        deliverAlert: (a) async => delivered.add(a),
        alertBackground: (on) async => background.add(on),
      );
      hub.saved = const SavedLocalCamera(
        address: '192.168.1.5',
        uid: 'N301TEST123456',
        firmware: '6.58.615',
      );
      await hub.alerts.setEnabled(true);
      await tester.pump();
      await hub.pause();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(camera.polls, greaterThanOrEqualTo(3));
      expect(delivered.single.kind, LocalAlertKind.sound);
      expect(hub.streamUrl, isNull);
      expect(hub.alerts.healthy, isTrue);
      await hub.alerts.setEnabled(false);
      final before = camera.polls;
      await tester.pump(const Duration(seconds: 10));
      expect(camera.polls, before);
      expect(camera.stops, 1);
      expect(background, [true, false]);
      hub.dispose();
    },
  );

  testWidgets(
    'phone controls expose independent alert types without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final monitor = LocalCameraAlerts(
        store: MemoryNanitSecretStore(),
        address: () => '192.168.1.5',
        uid: () => 'N301TEST123456',
        background: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: [CameraAlertsCard(alerts: monitor)]),
          ),
        ),
      );
      expect(find.text('Sound alerts'), findsOneWidget);
      expect(find.text('Cry alerts'), findsOneWidget);
      expect(find.text('Monitor in background'), findsOneWidget);
      expect(monitor.enabled, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      monitor.dispose();
    },
  );

  test('permission denial does not start background monitoring', () async {
    var starts = 0;
    final monitor = LocalCameraAlerts(
      store: MemoryNanitSecretStore(),
      address: () => '192.168.1.5',
      uid: () => 'N301TEST123456',
      permission: (_) async => false,
      background: (on) async {
        if (on) starts++;
      },
    );
    await monitor.setEnabled(true);
    expect(monitor.enabled, isFalse);
    expect(starts, 0);
    expect(monitor.problem, contains('notifications'));
    monitor.dispose();
  });

  testWidgets('outage notifies once and recovery rearms without replay', (
    tester,
  ) async {
    final camera = DetectionCamera();
    final events = <LocalCameraAlert>[];
    var now = DateTime(2026);
    final monitor = LocalCameraAlerts(
      store: MemoryNanitSecretStore(),
      address: () => '192.168.1.5',
      uid: () => 'N301TEST123456',
      cameraFactory: (_) => camera,
      background: (_) async {},
      deliver: (e) async => events.add(e),
      now: () => now,
    );
    await monitor.setEnabled(true);
    await tester.pump();
    camera.fail = true;
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(monitor.healthy, isFalse);
    for (var i = 0; i < 12; i++) {
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
    }
    expect(events.where((e) => e.kind == LocalAlertKind.unavailable).length, 1);
    camera.fail = false;
    await tester.pump(const Duration(seconds: 3));
    expect(monitor.healthy, isTrue);
    expect(events.where((e) => e.kind == LocalAlertKind.sound), isEmpty);
    await monitor.setEnabled(false);
    monitor.dispose();
  });

  testWidgets(
    'saved opt-in resumes without asking notification permission again',
    (tester) async {
      final store = MemoryNanitSecretStore();
      await store.write(
        LocalCameraAlerts.storageKey,
        '{"enabled":true,"sound":false,"cry":true,"sensitivity":"high"}',
      );
      final camera = DetectionCamera();
      final requests = <bool>[];
      final monitor = LocalCameraAlerts(
        store: store,
        address: () => '192.168.1.5',
        uid: () => 'N301TEST123456',
        cameraFactory: (_) => camera,
        background: (_) async {},
        permission: (request) async {
          requests.add(request);
          return true;
        },
      );
      await monitor.load();
      await tester.pump();
      expect(requests, [false]);
      expect(monitor.enabled, isTrue);
      expect(monitor.soundEnabled, isFalse);
      expect(monitor.sensitivity, SoundSensitivity.high);
      await monitor.setEnabled(false);
      monitor.dispose();
    },
  );
}
