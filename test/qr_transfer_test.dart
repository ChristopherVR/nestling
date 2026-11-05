import 'dart:convert';
import 'dart:io';

import 'package:nestling/src/models.dart';
import 'package:nestling/src/qr_transfer.dart';
import 'package:nestling/src/store.dart';
import 'package:nestling/src/sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payload survives being split into codes and scanned out of order', () {
    final payload = {
      'app': 'babylog-qr',
      'entries': [
        for (var i = 0; i < 300; i++)
          {'id': 'e$i', 'type': 'feed', 'time': 1792000000000 + i * 60000},
      ],
    };
    final codes = QrTransfer.encode(payload);
    expect(codes.length, greaterThan(1));

    final collector = QrCollector();
    for (final c in codes.reversed) {
      expect(collector.add(c), isTrue);
      expect(
        collector.add(c),
        isFalse,
        reason: 'the same code twice counts once',
      );
    }
    expect(collector.done, isTrue);
    expect(jsonEncode(collector.result()), jsonEncode(payload));
  });

  test('a new set of codes from the other phone starts over', () {
    final first = QrTransfer.encode({'n': List.filled(2000, 'a')});
    final second = QrTransfer.encode({'n': 'b'});
    final collector = QrCollector()..add(first.first);
    collector.add(second.single);
    expect(collector.done, isTrue);
    expect(collector.result()['n'], 'b');
  });

  group('mixed old and new versions', () {
    late Directory dir;
    late AppState app;
    late AppState other;

    setUp(() async {
      AppState.appVersion = '1.5.0';
      dir = await Directory.systemTemp.createTemp('baby-qr-');
      app = await AppState.loadForTesting(File('${dir.path}/a.json'));
      other = await AppState.loadForTesting(File('${dir.path}/b.json'));
    });

    tearDown(() async {
      for (final s in [app, other]) {
        s.dispose();
        await s.pendingSave;
      }
      await dir.delete(recursive: true);
    });

    Map<String, dynamic> scan(List<String> codes) {
      final collector = QrCollector();
      codes.forEach(collector.add);
      return collector.result();
    }

    test('codes keep the marker that versions before the rename require', () {
      expect(scan(app.qrCodesFor(null))['app'], 'babylog-qr');
    });

    test('codes with the old or the new marker are both accepted', () {
      for (final marker in ['babylog-qr', 'nestling-qr']) {
        final feed = Entry(type: EntryType.feed, time: DateTime.now());
        app.addEntry(feed);
        final body = scan(app.qrCodesFor(null))..['app'] = marker;
        other.receiveQr(body);
        expect(other.entries.map((e) => e.id), contains(feed.id), reason: marker);
      }
      expect(
        () => other.receiveQr(scan(app.qrCodesFor(null))..['app'] = 'other'),
        throwsA(isA<SyncException>()),
      );
    });
  });
}
