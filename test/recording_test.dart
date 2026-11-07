import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/src/localization.dart';
import 'package:nestling/src/recording.dart';
import 'package:nestling/src/ui/camera/recording_view.dart';

class _FakeSink implements RecordingSink {
  final paths = <String>[];
  bool writes = true;
  bool fail = false;
  String? _open;

  /// Pretend libmpv wrote more video.
  void grow(int bytes) {
    final o = _open;
    if (o != null) {
      File(o).writeAsBytesSync(List.filled(bytes, 1), mode: FileMode.append);
    }
  }

  @override
  Future<void> setRecordPath(String path) async {
    if (fail) throw StateError('no');
    paths.add(path);
    if (path.isEmpty) {
      _open = null;
    } else {
      _open = path;
      if (writes) File(path).writeAsBytesSync([1, 2, 3]);
    }
  }
}

/// Lets the page's real file reads finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

void main() {
  late Directory dir;
  late RecordingStore store;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('nestling-rec');
    store = RecordingStore(Directory('${dir.path}/Recordings'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('file names carry the start time and parse back', () {
    final t = DateTime(2026, 11, 8, 4, 5, 6);
    expect(recordingFileName(t), 'Nestling-2026-11-08_04-05-06.mp4');
    expect(recordingStartOf('Nestling-2026-11-08_04-05-06.mp4'), t);
    expect(recordingStartOf('holiday.mp4'), isNull);
    expect(recordingStartOf('Nestling-2026-11-08_04-05-06.mp4.len'), isNull);
  });

  test('durations and sizes read plainly', () {
    expect(formatRecordingDuration(const Duration(seconds: 65)), '1:05');
    expect(formatRecordingDuration(const Duration(seconds: 3723)), '1:02:03');
    expect(formatRecordingSize(500), '1 KB');
    expect(formatRecordingSize(5 * 1024 * 1024), '5.0 MB');
  });

  test('list is newest first, with lengths, and drops empty files', () async {
    await store.ensure();
    final a = store.pathFor(DateTime(2026, 1, 1, 10));
    final b = store.pathFor(DateTime(2026, 1, 2, 10));
    final empty = store.pathFor(DateTime(2026, 1, 3, 10));
    File(a).writeAsBytesSync([1, 2]);
    File(b).writeAsBytesSync([1, 2, 3]);
    File(empty).writeAsBytesSync([]);
    File('${dir.path}/Recordings/notes.txt').writeAsStringSync('x');
    await store.saveDuration(b, const Duration(seconds: 42));
    final list = await store.list();
    expect(list.map((r) => r.path), [b, a]);
    expect(list.first.duration, const Duration(seconds: 42));
    expect(list.last.duration, isNull);
    expect(File(empty).existsSync(), isFalse);
    await store.delete(b);
    expect((await store.list()).single.path, a);
    expect(File('$b.len').existsSync(), isFalse);
  });

  test('record without video says so and writes nothing', () async {
    final c = RecordingController(store: store);
    await c.start();
    expect(c.recording, isFalse);
    expect(c.problem, RecordingProblem.notLive);
    c.dispose();
  });

  test('start then stop keeps the file and its length', () async {
    final sink = _FakeSink();
    final c = RecordingController(
      store: store,
      clock: () => DateTime(2026, 1, 1, 10),
    )..attach(sink);
    await c.start();
    expect(c.recording, isTrue);
    expect(sink.paths.single, endsWith('Nestling-2026-01-01_10-00-00.mp4'));
    await c.stop();
    expect(c.recording, isFalse);
    expect(sink.paths.last, '');
    expect(c.problem, isNull);
    expect((await store.list()).single.duration, Duration.zero);
    c.dispose();
  });

  test('stopping when nothing was written removes the file', () async {
    final sink = _FakeSink()..writes = false;
    final c = RecordingController(store: store)..attach(sink);
    await c.start();
    await c.stop();
    expect(c.problem, RecordingProblem.empty);
    expect(await store.list(), isEmpty);
    c.dispose();
  });

  test('a failure to start is reported and nothing is recording', () async {
    final sink = _FakeSink()..fail = true;
    final c = RecordingController(store: store)..attach(sink);
    await c.start();
    expect(c.recording, isFalse);
    expect(c.problem, RecordingProblem.failed);
    c.dispose();
  });

  test('losing the player stops and saves quietly', () async {
    final sink = _FakeSink();
    final c = RecordingController(store: store)..attach(sink);
    await c.start();
    await c.detach(sink);
    expect(c.recording, isFalse);
    expect(c.attached, isFalse);
    expect(sink.paths.last, '');
    expect(c.problem, isNull);
    expect(await store.list(), hasLength(1));
    c.dispose();
  });

  test('a stream drop stops with a reason and keeps the video', () async {
    final sink = _FakeSink();
    final c = RecordingController(store: store)..attach(sink);
    await c.start();
    await c.stop(reason: RecordingProblem.streamDropped);
    expect(c.problem, RecordingProblem.streamDropped);
    expect(await store.list(), hasLength(1));
    c.dispose();
  });

  test('a stalled file (storage) ends the recording by itself', () async {
    final sink = _FakeSink();
    final c = RecordingController(
      store: store,
      tick: const Duration(milliseconds: 5),
      stallLimit: const Duration(milliseconds: 40),
    )..attach(sink);
    await c.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(c.recording, isFalse);
    expect(c.problem, RecordingProblem.storage);
    expect(await store.list(), hasLength(1));
    c.dispose();
  });

  test('the size limit ends the recording by itself', () async {
    final sink = _FakeSink();
    final c = RecordingController(
      store: store,
      tick: const Duration(milliseconds: 5),
      maxBytes: 100,
    )..attach(sink);
    await c.start();
    sink.grow(200);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(c.recording, isFalse);
    expect(c.problem, RecordingProblem.limit);
    c.dispose();
  });

  testWidgets('recordings page lists, and offers share and delete', (
    tester,
  ) async {
    AppLanguage.use('en');
    await tester.runAsync(() async {
      await store.ensure();
      final p = store.pathFor(DateTime(2026, 1, 2, 10, 30));
      File(p).writeAsBytesSync(List.filled(2048, 1));
      await store.saveDuration(p, const Duration(seconds: 75));
    });
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('af'), Locale('en')],
          home: RecordingsPage(store: store),
        ),
      ),
    );
    await settle(tester);
    expect(find.textContaining('1:15 · 2 KB'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Delete this recording?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1:15'), findsOneWidget);
  });

  testWidgets('empty recordings page explains itself in Afrikaans', (
    tester,
  ) async {
    AppLanguage.use('af');
    addTearDown(() => AppLanguage.use('en'));
    await tester.runAsync(
      () => tester.pumpWidget(
        MaterialApp(
          locale: const Locale('af'),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('af'), Locale('en')],
          home: RecordingsPage(store: store),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Opnames'), findsOneWidget);
    expect(find.textContaining('Nog geen opnames'), findsOneWidget);
  });

  test('every recording message has an Afrikaans translation', () {
    for (final p in RecordingProblem.values) {
      AppLanguage.use('en');
      final en = recordingProblemText(p);
      expect(tr(en, language: 'af'), isNot(en), reason: '$p');
    }
  });
}
