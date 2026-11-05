// Opt-in native-player A/B fixture. Android: use the guarded cameraTest launcher.
// Never records audio. Still images require NANIT_TIMING_IMAGES=true and remain
// private in the test app's temporary directory; never commit those images.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nanit_camera/nanit_camera.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const address = String.fromEnvironment('NANIT_TEST_IP');
  const seconds = int.fromEnvironment('NANIT_SOAK_SECONDS', defaultValue: 30);
  const images = bool.fromEnvironment('NANIT_TIMING_IMAGES');
  const selected = String.fromEnvironment('NANIT_TIMING_VARIANT');
  // Baseline mirrors released 1.5.34, independently of future package changes.
  const baseline = {
    'rtsp-transport': 'tcp',
    'profile': 'low-latency',
    'cache': 'no',
    'cache-on-disk': 'no',
    'demuxer-readahead-secs': '0',
    'audio-buffer': '0.1',
  };
  const variants = <String, Map<String, String>>{
    'baseline': {},
    'audio40': {'audio-buffer': '0.04'},
    'demux': {
      'audio-buffer': '0.04',
      'demuxer-lavf-o': 'fflags=+nobuffer,avioflags=direct',
    },
    'software': {'audio-buffer': '0.04', 'hwdec': 'no'},
    'audio0': {'audio-buffer': '0'},
    // Diagnostic only: excludes audio, so cannot replace synchronized Listen.
    'video_only': {'audio': 'no', 'untimed': 'yes', 'hwdec': 'no'},
  };
  for (final variant in variants.entries) {
    testWidgets('native latency comparison: ${variant.key}', (tester) async {
      MediaKit.ensureInitialized();
      final camera = NanitOfflineCamera(address);
      final bridge = NanitOfflineBridge(address);
      final player = Player(
        configuration: const PlayerConfiguration(
          title: 'Nestling latency test',
          bufferSize: 4 * 1024 * 1024,
        ),
      );
      final video = VideoController(player);
      var progress = 0;
      var completed = false;
      Duration? first, last;
      final errors = <String>[];
      final subscriptions = <StreamSubscription>[
        player.stream.position.listen((position) {
          first ??= position;
          last = position;
          progress++;
        }),
        player.stream.completed.listen((value) => completed |= value),
        player.stream.error.listen(errors.add),
      ];
      try {
        await camera.startMedia();
        await bridge.start();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: Text('Latency: ${variant.key}')),
              body: Video(controller: video, controls: NoVideoControls),
            ),
          ),
        );
        final native = player.platform as NativePlayer;
        // Ensure the controller cannot subsequently overwrite hwdec options.
        await video.platform.future;
        for (final entry in {...baseline, ...variant.value}.entries) {
          await native.setProperty(entry.key, entry.value);
        }
        await player.setVolume(0); // Decode audio and retain the A/V clock.
        await player.open(Media(bridge.url!));
        final startup = Stopwatch()..start();
        while ((player.state.width ?? 0) == 0 &&
            startup.elapsed.inSeconds < 25) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(player.state.width, greaterThan(0));
        final elapsed = Stopwatch()..start();
        var nextSample = 1;
        while (elapsed.elapsed.inSeconds < seconds) {
          await tester.pump(const Duration(milliseconds: 100));
          if (elapsed.elapsed.inSeconds < nextSample) continue;
          nextSample++;
          final values = <String, Object?>{
            'variant': variant.key,
            'platform': Platform.operatingSystem,
            'elapsed_ms': elapsed.elapsedMilliseconds,
          };
          for (final name in const [
            'time-pos',
            'demuxer-cache-time',
            'demuxer-cache-duration',
            'avsync',
            'hwdec-current',
            'decoder-frame-drop-count',
            'frame-drop-count',
            'paused-for-cache',
            'audio-buffer',
            'audio-delay',
            'video-sync',
            'demuxer-lavf-o',
            'audio-samplerate',
            'audio-device',
            'ao',
            'video-dec-params',
          ]) {
            values[name] = await native.getProperty(name);
          }
          debugPrint('LATENCY_SAMPLE ${jsonEncode(values)}');
          if (images && (nextSample == 16 || nextSample == 26)) {
            final before = DateTime.now().toUtc();
            final bytes = await player.screenshot(format: null);
            final after = DateTime.now().toUtc();
            expect(bytes, isNotNull);
            final directory = await getTemporaryDirectory();
            final file = File(
              '${directory.path}/latency-${variant.key}-$nextSample.bgra',
            );
            await file.writeAsBytes(bytes!);
            debugPrint(
              'LATENCY_IMAGE ${jsonEncode({'variant': variant.key, 'path': file.path, 'capture_start_utc': before.toIso8601String(), 'capture_end_utc': after.toIso8601String(), 'width': player.state.width, 'height': player.state.height})}',
            );
          }
        }
        expect(completed, isFalse);
        expect(progress, greaterThan(seconds * 5));
        expect((last! - first!).inSeconds, greaterThan(seconds - 3));
        debugPrint(
          'LATENCY_RESULT ${jsonEncode({'variant': variant.key, 'platform': Platform.operatingSystem, 'seconds': seconds, 'startup_ms': startup.elapsedMilliseconds - elapsed.elapsedMilliseconds, 'progress_events': progress, 'player_errors': errors})}',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await player.dispose();
        await bridge.close();
        camera.close();
      }
    }, skip: address.isEmpty || (selected.isNotEmpty && selected != variant.key));
  }
}
