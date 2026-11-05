import 'dart:convert';
import 'dart:io';

import 'package:nestling/src/models.dart';
import 'package:nestling/src/store.dart';
import 'package:nestling/src/sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Wi-Fi pairing exchanges deltas and receives edits and deletions',
    () async {
      final dir = await Directory.systemTemp.createTemp('baby-wifi-sync-');
      final app = await AppState.loadForTesting(File('${dir.path}/app.json'));
      AppState.appVersion = '1.5.0';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        app.dispose();
        await app.pendingSave;
        await dir.delete(recursive: true);
      });

      var remote = Entry(
        type: EntryType.nappy,
        time: DateTime.now(),
        nappy: NappyKind.pee,
      );
      var remoteSeq = 1;
      var knowsUs = false;
      final sent = <Map<String, dynamic>>[];
      final identity = {
        'deviceId': 'phone',
        'name': 'Phone',
        'appVersion': '1.5.0',
        'port': server.port,
      };
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/info') {
          // Both header names, so peers from before the rename understand it.
          expect(request.headers.value('x-nestling-key'), '123456');
          expect(request.headers.value('x-nestling-device'), app.deviceId);
          expect(request.headers.value('x-babylog-key'), '123456');
          expect(request.headers.value('x-babylog-device'), app.deviceId);
          request.response.write(
            jsonEncode({...identity, 'seq': remoteSeq, 'knowsYou': knowsUs}),
          );
        } else {
          expect(request.uri.path, '/sync');
          expect(request.method, 'POST');
          final body = jsonDecode(
            await utf8.decodeStream(request),
          ) as Map<String, dynamic>;
          expect(body['key'], '123456');
          sent.add(body);
          knowsUs = true;
          request.response.write(
            jsonEncode({
              'from': identity,
              'seq': remoteSeq,
              'took': {'feed': (body['entries'] as List).length},
              'entries': [
                if ((body['since'] as int) < remoteSeq) remote.toJson(),
              ],
            }),
          );
        }
        await request.response.close();
      });

      final feed = Entry(
        type: EntryType.feed,
        time: DateTime.now(),
        side: FeedSide.left,
      );
      app.addEntry(feed);
      final peer = await app.pair('127.0.0.1', server.port, '123456');
      expect(peer.lastError, isNull);
      expect(app.entries.map((e) => e.id), containsAll([feed.id, remote.id]));
      expect((sent.single['entries'] as List).single['id'], feed.id);

      // No records changed: the /info request is enough, with no POST.
      await app.syncPeer(peer);
      expect(sent, hasLength(1));

      final next = Entry(
        type: EntryType.feed,
        time: DateTime.now(),
        side: FeedSide.right,
      );
      app.addEntry(next);
      await app.syncPeer(peer);
      expect((sent.last['entries'] as List).single['id'], next.id);
      expect(sent.last['since'], 1);

      remote = Entry(
        id: remote.id,
        type: remote.type,
        time: remote.time,
        nappy: NappyKind.both,
        updatedAt: remote.updatedAt.add(const Duration(seconds: 1)),
      );
      remoteSeq++;
      await app.syncPeer(peer);
      expect(
        app.entries.singleWhere((e) => e.id == remote.id).nappy,
        NappyKind.both,
      );
      expect(sent.last['entries'], isEmpty);

      remote = remote.copyWith(
        updatedAt: remote.updatedAt.add(const Duration(seconds: 1)),
        deleted: true,
      );
      remoteSeq++;
      await app.syncPeer(peer);
      expect(app.entries.map((e) => e.id), isNot(contains(remote.id)));
      expect(app.entries.map((e) => e.id), containsAll([feed.id, next.id]));
      expect(sent.last['entries'], isEmpty);
    },
  );

  group('mixed old and new versions', () {
    test('pairing codes use the old scheme and both schemes are read', () {
      final uri = PairInfo('192.168.1.23', 8766, '482913').toUri();
      expect(uri, startsWith('babylog://pair?'));
      for (final scheme in ['babylog', 'nestling']) {
        final info = PairInfo.parse('$scheme://pair?h=10.0.0.2&p=8770&k=111222')!;
        expect((info.host, info.port, info.key), ('10.0.0.2', 8770, '111222'));
      }
      expect(PairInfo.parse('other://pair?h=10.0.0.2&k=111222'), isNull);
    });

    test('the server reads old-only, new-only and both header names', () async {
      final asked = <(String, String)>[];
      final server = SyncServer();
      await server.start(
        anyPort: true,
        onInfo: (key, id) {
          asked.add((key, id));
          return (status: HttpStatus.ok, body: {'deviceId': 'me'});
        },
        onSync: (_, _) async => (status: HttpStatus.ok, body: null),
      );
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      Future<void> ask(Map<String, String> headers) async {
        final req = await client.get('127.0.0.1', server.port!, '/info');
        headers.forEach(req.headers.set);
        final res = await req.close();
        await res.drain<void>();
        expect(res.statusCode, HttpStatus.ok);
      }

      // A peer from before the rename.
      await ask({'x-babylog-key': '1', 'x-babylog-device': 'old'});
      // A possible future peer that only sends the new names.
      await ask({'x-nestling-key': '2', 'x-nestling-device': 'new'});
      // This version: both, with the new name preferred.
      await ask({
        'x-nestling-key': '3',
        'x-nestling-device': 'now',
        'x-babylog-key': 'x',
        'x-babylog-device': 'x',
      });
      expect(asked, [('1', 'old'), ('2', 'new'), ('3', 'now')]);
    });

    test('getInfo reaches a server that only reads the old headers', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final ok = request.headers.value('x-babylog-key') == '123456' &&
            request.headers.value('x-babylog-device') == 'me';
        request.response.statusCode = ok ? HttpStatus.ok : HttpStatus.forbidden;
        request.response.write(jsonEncode({'deviceId': 'old-phone'}));
        await request.response.close();
      });
      final info = await getInfo('127.0.0.1', server.port, '123456', 'me');
      expect(info['deviceId'], 'old-phone');
    });
  });
}
