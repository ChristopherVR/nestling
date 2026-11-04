// Explicit opt-in: flutter test integration_test/local_camera_live_test.dart
// -d windows --dart-define=NANIT_TEST_IP=<owned-camera-address>
import 'dart:async';

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
  testWidgets('real local camera renders muted video and pauses cleanly', (
    tester,
  ) async {
    final hub = LocalNanitHub(store: MemoryNanitSecretStore());
    final playing = Completer<void>();
    var errors = 0;
    try {
      await hub.add(address);
      await hub.watch();
      expect(hub.state, LocalCameraState.ready, reason: hub.problem);
      expect(hub.readings?.temperature, isNotNull);
      expect(hub.readings?.humidity, isNotNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AspectRatio(
              aspectRatio: 16 / 9,
              child: NanitOfflineView(
                url: hub.streamUrl!,
                muted: true,
                onPlaying: () {
                  if (!playing.isCompleted) playing.complete();
                },
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
      await tester.pump(const Duration(seconds: 3));
      expect(errors, 0);
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
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(const Duration(milliseconds: 200));
        expect(hub.local.state, LocalCameraState.idle);
        expect(hub.local.streamUrl, isNull);
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
