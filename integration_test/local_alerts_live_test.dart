// Opt-in owned-camera test. Uses real native polling/notifications and a
// separately labelled synthetic cry-policy fixture; does not simulate a baby.
import 'dart:io';

import 'package:baby_app/src/background.dart';
import 'package:baby_app/src/local_camera_alerts.dart';
import 'package:baby_app/src/local_nanit.dart';
import 'package:baby_app/src/nanit_integration.dart';
import 'package:baby_app/src/notifications.dart';
import 'package:baby_app/src/ui/local_camera_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const address = String.fromEnvironment('NANIT_TEST_IP');
  const requireSound = bool.fromEnvironment('ALERT_REQUIRE_SOUND');
  const backgroundSeconds = int.fromEnvironment(
    'ALERT_BACKGROUND_SECONDS',
    defaultValue: 20,
  );
  testWidgets(
    'native detection survives leaving camera and OS background',
    (tester) async {
      final reminders = Reminders();
      await reminders.init();
      if (Platform.isAndroid) await reminders.requestPermission();
      final delivered = <LocalCameraAlert>[];
      final hub = LocalNanitHub(
        store: MemoryNanitSecretStore(),
        deliverAlert: (event) async {
          await deliverLocalCameraAlert(event);
          delivered.add(event);
          debugPrint('ALERT_DELIVERED ${event.kind.name}');
        },
      );
      try {
        await hub.add(address);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(children: [CameraAlertsCard(alerts: hub.alerts)]),
            ),
          ),
        );
        await hub.alerts.setEnabled(true);
        final deadline = DateTime.now().add(const Duration(seconds: 25));
        while (!hub.alerts.healthy && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(hub.alerts.healthy, isTrue, reason: hub.alerts.status);
        final first = hub.alerts.latest!.levelAt!;
        debugPrint('ALERT_INITIAL_LEVEL ${hub.alerts.latest!.dbfs} dBFS');
        await hub.pause();
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Text('Away from camera · monitoring continues'),
            ),
          ),
        );
        delivered.clear();
        debugPrint('ALERT_BACKGROUND_READY $backgroundSeconds seconds');
        // Deliberately no frame pumping: OS background/locked-screen must work.
        final elapsed = Stopwatch()..start();
        if (requireSound) {
          while (elapsed.elapsed.inSeconds < backgroundSeconds &&
              !delivered.any((event) => event.kind == LocalAlertKind.sound)) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
          expect(
            delivered.any((event) => event.kind == LocalAlertKind.sound),
            isTrue,
            reason:
                'No real sound notification arrived during the acoustic test',
          );
          // Keep the app running briefly so the host can inspect the OS notice.
          debugPrint(
            'ALERT_ACOUSTIC_PASS; holding for OS notification inspection',
          );
          await Future<void>.delayed(const Duration(seconds: 20));
        } else {
          await Future<void>.delayed(
            const Duration(seconds: backgroundSeconds),
          );
        }
        expect(hub.streamUrl, isNull);
        expect(hub.alerts.enabled, isTrue);
        expect(hub.alerts.healthy, isTrue, reason: hub.alerts.status);
        expect(
          hub.alerts.latest!.levelAt!,
          greaterThan(first + elapsed.elapsed.inSeconds - 6),
        );
        expect(hub.alerts.notificationProblem, isNull);
        debugPrint(
          'ALERT_BACKGROUND_PASS native levels advanced ${hub.alerts.latest!.levelAt! - first}s; events=${delivered.length}; elapsed=${elapsed.elapsed.inSeconds}s',
        );

        // Test the same production cry policy/delivery path with explicit test
        // probabilities, independently from real acoustic classification.
        final policy = LocalAlertPolicy();
        NanitDetectionSnapshot fixture(double t, List<double> p) =>
            NanitDetectionSnapshot(
              boot: 'a' * 32,
              uptime: t,
              microphone: true,
              speakerActive: false,
              classifier: true,
              levelAt: t,
              dbfs: -80,
              cry: [NanitCryWindow(t, p)],
            );
        policy.accept(
          fixture(10, [0, 0, 0, 0, 0]),
          DateTime.now(),
          sound: false,
          cry: true,
          sensitivity: SoundSensitivity.normal,
        );
        final kinds = policy.accept(
          fixture(15, [.9, .95, .99, 0, 0]),
          DateTime.now(),
          sound: false,
          cry: true,
          sensitivity: SoundSensitivity.normal,
        );
        expect(kinds, [LocalAlertKind.cry]);
        await deliverLocalCameraAlert(
          LocalCameraAlert(kinds.single, DateTime.now()),
          test: true,
        );
        debugPrint(
          'ALERT_SYNTHETIC_CRY_NOTIFICATION_PASS (not acoustic validation)',
        );
        await hub.alerts.setEnabled(false);
        expect(hub.alerts.enabled, isFalse);
        expect(hub.alerts.latest, isNull);
      } finally {
        await hub.alerts.setEnabled(false);
        hub.dispose();
        await BackgroundSync.setCameraMonitoring(false);
        reminders.dispose();
      }
    },
    skip: address.isEmpty,
    timeout: const Timeout(Duration(seconds: backgroundSeconds + 90)),
  );
}
