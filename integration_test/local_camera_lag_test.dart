// Opt-in transport fault test. Uses only a separate local playback session.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const address = String.fromEnvironment('NANIT_TEST_IP');
  testWidgets('a short transport stall cannot leave playback permanently late', (
    tester,
  ) async {
    final camera = NanitOfflineCamera(address);
    final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <Socket>[];
    final tasks = <Future<void>>[];
    final stalled = Completer<void>();
    final failed = Completer<void>();
    final playback = Completer<void>();
    final recovered = Completer<void>();
    final generation = ValueNotifier<int>(0);
    var errors = 0;
    final elapsed = Stopwatch()..start();
    var injected = false;
    proxy.listen((client) {
      final task = () async {
        final remote = await Socket.connect(address, 554);
        sockets.addAll([client, remote]);
        client.setOption(SocketOption.tcpNoDelay, true);
        remote.setOption(SocketOption.tcpNoDelay, true);
        Future<void> forward(
          Socket input,
          Socket output,
          bool cameraSide,
        ) async {
          await for (final chunk in input) {
            if (cameraSide &&
                playback.isCompleted &&
                !injected &&
                elapsed.elapsed.inSeconds >= 10) {
              injected = true;
              debugPrint('CAMERA_STALL_START ${elapsed.elapsedMilliseconds}');
              await Future<void>.delayed(const Duration(seconds: 3));
              debugPrint('CAMERA_STALL_END ${elapsed.elapsedMilliseconds}');
              stalled.complete();
            }
            output.add(chunk);
            await output.flush();
          }
        }

        try {
          await Future.any([
            forward(client, remote, false),
            forward(remote, client, true),
          ]);
        } catch (_) {
          // The player closes this deliberately delayed connection to recover.
        } finally {
          client.destroy();
          remote.destroy();
        }
      }();
      tasks.add(task);
    });
    final bridge = NanitOfflineBridge(
      address,
      connector: (_, _) =>
          Socket.connect(InternetAddress.loopbackIPv4, proxy.port),
    );
    try {
      await camera.startMedia();
      await bridge.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: generation,
              builder: (context, value, child) => NanitOfflineView(
                key: ValueKey(value),
                url: bridge.url!,
                onPlaying: () {
                  if (!playback.isCompleted) playback.complete();
                  if (value > 0 && !recovered.isCompleted) recovered.complete();
                },
                onError: () {
                  errors++;
                  if (!failed.isCompleted) failed.complete();
                  // Same recovery mechanism as the host: dispose the old player and
                  // create a fresh connection, discarding its TCP and decoder backlog.
                  generation.value++;
                },
                onDiagnostics: (values) => debugPrint(
                  'STALL_TIMING ${jsonEncode({'elapsed_ms': elapsed.elapsedMilliseconds, ...values})}',
                ),
              ),
            ),
          ),
        ),
      );
      while (!recovered.isCompleted &&
          elapsed.elapsed < const Duration(seconds: 30)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(playback.isCompleted, isTrue);
      expect(stalled.isCompleted, isTrue);
      expect(
        failed.isCompleted,
        isTrue,
        reason: 'The host must be asked to reopen a stream that keeps playing a stale backlog.',
      );
      expect(
        recovered.isCompleted,
        isTrue,
        reason: 'The new connection must decode video.',
      );
      final settled = elapsed.elapsed + const Duration(seconds: 3);
      while (elapsed.elapsed < settled) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(errors, 1, reason: 'Recovery must not become a reconnect loop.');
      debugPrint('CAMERA_STALL_RECOVERY ${elapsed.elapsedMilliseconds}');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await bridge.close();
      for (final socket in sockets) {
        socket.destroy();
      }
      await proxy.close();
      await Future.wait(tasks);
      camera.close();
      generation.dispose();
    }
  }, skip: address.isEmpty);
}
