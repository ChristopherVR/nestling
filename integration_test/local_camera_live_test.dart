// Explicit opt-in: flutter test integration_test/local_camera_live_test.dart
// -d windows --dart-define=NANIT_TEST_IP=<owned-camera-address>
import 'dart:async';
import 'dart:convert';

import 'package:baby_app/src/local_nanit.dart';
import 'package:baby_app/src/nanit_integration.dart';
import 'package:baby_app/src/ui/camera_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const address = String.fromEnvironment('NANIT_TEST_IP');
  const soakSeconds = int.fromEnvironment(
    'NANIT_SOAK_SECONDS',
    defaultValue: 3,
  );
  testWidgets('real local camera renders muted video and pauses cleanly', (
    tester,
  ) async {
    final hub = LocalNanitHub(store: MemoryNanitSecretStore());
    final playing = Completer<void>();
    var errors = 0;
    var progressEvents = 0;
    Duration? firstPosition, lastPosition;
    final elapsed = Stopwatch()..start();
    try {
      await hub.add(address);
      await hub.watch();
      expect(hub.state, LocalCameraState.ready, reason: hub.problem);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AspectRatio(
              aspectRatio: 16 / 9,
              child: NanitOfflineView(
                url: hub.streamUrl!,
                muted: true,
                onPlaying: () {
                  debugPrint(
                    'Local camera decoded video after ${elapsed.elapsedMilliseconds} ms',
                  );
                  if (!playing.isCompleted) playing.complete();
                },
                onProgress: (position) {
                  firstPosition ??= position;
                  lastPosition = position;
                  progressEvents++;
                },
                onDiagnostics: (values) => debugPrint(
                  'CAMERA_TIMING ${jsonEncode({'elapsed_ms': elapsed.elapsedMilliseconds, ...values})}',
                ),
                onError: () => errors++,
              ),
            ),
          ),
        ),
      );
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!playing.isCompleted &&
          DateTime.now().isBefore(deadline) &&
          errors == 0) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(errors, 0);
      expect(
        playing.isCompleted,
        isTrue,
        reason: 'Native RTSP player must report decoded video dimensions',
      );
      final soakDeadline = DateTime.now().add(Duration(seconds: soakSeconds));
      while (DateTime.now().isBefore(soakDeadline) && errors == 0) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(errors, 0);
      expect(hub.readings?.temperature, isNotNull);
      expect(hub.readings?.humidity, isNotNull);
      expect(hub.sound?.supported, isTrue);
      expect(progressEvents, greaterThan(2));
      expect(lastPosition, greaterThan(firstPosition!));
      if (soakSeconds >= 20) {
        expect(
          (lastPosition! - firstPosition!).inSeconds,
          greaterThan(soakSeconds - 5),
        );
      }
      debugPrint(
        'Local camera soak: $soakSeconds seconds, $progressEvents progress events, '
        'timeline ${firstPosition?.inMilliseconds}..${lastPosition?.inMilliseconds} ms, errors=$errors',
      );
      await tester.pumpWidget(const SizedBox());
      await hub.pause();
      expect(hub.streamUrl, isNull);
      expect(hub.readings, isNull);
      expect(hub.state, LocalCameraState.idle);
    } finally {
      await hub.pause();
      hub.dispose();
    }
  }, skip: address.isEmpty);

  testWidgets(
    'Nestling camera screen pauses in background and during Wi-Fi setup',
    (tester) async {
      final hub = NanitHub(
        account: NanitAccount(store: MemoryNanitSecretStore()),
      );
      try {
        await hub.useLocalCamera(address);
        await hub.start();
        await tester.pumpWidget(MaterialApp(home: CameraPage(hub: hub)));
        final deadline = DateTime.now().add(const Duration(seconds: 35));
        while (find.text('Live · Home network').evaluate().isEmpty &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('Live · Home network'), findsOneWidget);
        expect(find.text('Listen'), findsOneWidget);
        expect(hub.local.state, LocalCameraState.ready);
        final activeUrl = hub.local.streamUrl;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(hub.local.state, LocalCameraState.ready);
        expect(hub.local.streamUrl, activeUrl);
        debugPrint('Local camera lifecycle: inactive retained the same stream');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        // A live binding does not render frames while paused. Waiting for a
        // pumped frame here deadlocks the test before it can resume the app.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(hub.local.state, LocalCameraState.idle);
        expect(hub.local.streamUrl, isNull);
        debugPrint('Local camera lifecycle: paused closed the stream');
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.scrollUntilVisible(
          find.text('Change Wi-Fi'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Change Wi-Fi')),
          alignment: 0.5,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Change Wi-Fi'));
        await tester.pump(const Duration(seconds: 1));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(hub.local.state, LocalCameraState.idle);
        expect(hub.local.streamUrl, isNull);
        expect(find.text('Find nearby camera'), findsOneWidget);
        // Do not scan/connect Bluetooth or send network credentials in this test.
        await tester.pumpWidget(const SizedBox());
      } finally {
        await hub.local.pause();
        hub.dispose();
      }
    },
    skip: address.isEmpty,
  );
}
