// Real camera test: toggles muted video and synchronized Listen repeatedly.
// Android must use tool/test_camera_android.ps1 and its isolated cameraTest ID.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const address = String.fromEnvironment('NANIT_TEST_IP');
  const seconds = int.fromEnvironment('NANIT_SOAK_SECONDS', defaultValue: 30);
  testWidgets('low latency muted video switches safely to synchronized Listen', (
    tester,
  ) async {
    final camera = NanitOfflineCamera(address);
    final bridge = NanitOfflineBridge(address);
    final muted = ValueNotifier(true);
    var playing = 0;
    var errors = 0;
    var progress = 0;
    Map<String, String>? diagnostics;
    try {
      await camera.startMedia();
      await bridge.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: muted,
              builder: (context, value, child) => NanitOfflineView(
                url: bridge.url!,
                muted: value,
                onPlaying: () => playing++,
                onError: () => errors++,
                onProgress: (_) => progress++,
                onDiagnostics: (values) => diagnostics = values,
              ),
            ),
          ),
        ),
      );
      for (var phase = 0; phase < 5; phase++) {
        diagnostics = null;
        muted.value = phase.isEven;
        final opened = Stopwatch()..start();
        while ((playing < phase + 1 || diagnostics == null) &&
            opened.elapsed.inSeconds < 25) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(playing, phase + 1);
        expect(errors, 0);
        final initial = progress;
        final duration = phase < 3 ? seconds : 5;
        final soak = Stopwatch()..start();
        while (soak.elapsed.inSeconds < duration && errors == 0) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(errors, 0);
        expect(progress - initial, greaterThan(duration * 5));
        expect(diagnostics, isNotNull);
        expect(diagnostics!['untimed'], muted.value ? 'yes' : 'no');
        // mpv resolves "auto" to the selected numeric track ID after opening.
        expect(
          diagnostics!['audio'],
          muted.value ? 'no' : anyOf('auto', matches(r'^\d+$')),
        );
        if (!muted.value) {
          expect(diagnostics!['audio-params'], contains('samplerate'));
          final sync = double.tryParse(diagnostics!['avsync'] ?? '');
          expect(sync, isNotNull);
          expect(sync!.abs(), lessThan(0.1));
        }
        debugPrint(
          'LISTEN_PHASE ${jsonEncode({'phase': phase, 'muted': muted.value, 'seconds': duration, 'startup_ms': opened.elapsedMilliseconds - soak.elapsedMilliseconds, 'progress_events': progress - initial, 'errors': errors, ...diagnostics!})}',
        );
      }
      await tester.pumpWidget(const SizedBox());
    } finally {
      await tester.pumpWidget(const SizedBox());
      await bridge.close();
      camera.close();
      muted.dispose();
    }
  }, skip: address.isEmpty);
}
