import 'dart:convert';
import 'dart:io';

import 'package:nestling/src/models.dart';
import 'package:nestling/src/store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Installs and backups from before the Baby Log -> Nestling rename.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('baby-rename-');
  });

  tearDown(() => dir.delete(recursive: true));

  File at(String name) => File('${dir.path}${Platform.pathSeparator}$name');

  test('a new install uses nestling.json', () async {
    expect((await AppState.dataFile(dir, '')).path, at('nestling.json').path);
    expect(
      (await AppState.dataFile(dir, 'b')).path,
      at('nestling_b.json').path,
    );
    expect(at('nestling.json').existsSync(), isFalse);
  });

  for (final profile in ['', 'b']) {
    final suffix = profile.isEmpty ? '' : '_$profile';
    test('the old babylog$suffix.json is copied over once', () async {
      at('babylog$suffix.json').writeAsStringSync('{"old": true}');
      final file = await AppState.dataFile(dir, profile);
      expect(file.path, at('nestling$suffix.json').path);
      expect(file.readAsStringSync(), '{"old": true}');
      // The old file stays as a backup and no temp file is left behind.
      expect(at('babylog$suffix.json').readAsStringSync(), '{"old": true}');
      expect(at('nestling$suffix.json.tmp').existsSync(), isFalse);

      // Once migrated, the new file wins and is never overwritten.
      file.writeAsStringSync('{"new": true}');
      final again = await AppState.dataFile(dir, profile);
      expect(again.readAsStringSync(), '{"new": true}');
    });
  }

  test('a migrated log loads with its data', () async {
    final old = await AppState.loadForTesting(at('babylog.json'));
    final feed = Entry(type: EntryType.feed, time: DateTime.now());
    old.addEntry(feed);
    old.dispose();
    await old.pendingSave;

    final loaded = await AppState.loadForTesting(
      await AppState.dataFile(dir, ''),
    );
    addTearDown(() async {
      loaded.dispose();
      await loaded.pendingSave;
    });
    expect(loaded.dataFilePath, at('nestling.json').path);
    expect(loaded.entries.map((e) => e.id), contains(feed.id));
  });

  test('backups are written as nestling and old babylog ones import', () async {
    final app = await AppState.loadForTesting(at('a.json'));
    final copy = await AppState.loadForTesting(at('b.json'));
    addTearDown(() async {
      for (final s in [app, copy]) {
        s.dispose();
        await s.pendingSave;
      }
    });
    final feed = Entry(type: EntryType.feed, time: DateTime.now());
    app.addEntry(feed);
    final backup = jsonDecode(app.exportBackup()) as Map<String, dynamic>;
    expect(backup['app'], 'nestling');

    expect(copy.importBackup(jsonEncode(backup)).entries, 1);
    final legacy = {...backup, 'app': 'babylog'};
    final nappy = Entry(
      type: EntryType.nappy,
      time: DateTime.now(),
      nappy: NappyKind.pee,
    );
    legacy['entries'] = [nappy.toJson()];
    expect(copy.importBackup(jsonEncode(legacy)).entries, 1);
    expect(
      copy.entries.map((e) => e.id),
      containsAll([feed.id, nappy.id]),
    );
    expect(
      () => copy.importBackup(jsonEncode({...backup, 'app': 'other'})),
      throwsFormatException,
    );
  });
}
