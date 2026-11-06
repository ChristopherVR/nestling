// Renders phone-sized screenshots of the main screens for design review.
// Skipped in normal runs (see dart_test.yaml). To render:
//
//   flutter test --run-skipped --tags preview test/ui_preview_test.dart
//
// Output: build/preview/*.png (override with PREVIEW_OUT).
@Tags(['preview'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:nestling/main.dart';
import 'package:nestling/src/growth.dart';
import 'package:nestling/src/models.dart';
import 'package:nestling/src/routines.dart';
import 'package:nestling/src/store.dart';
import 'package:nestling/src/pump_ble.dart';
import 'package:nestling/src/pump_session.dart';
import 'package:nestling/src/ui/home_page.dart';
import 'package:nestling/src/ui/hub_page.dart';
import 'package:nestling/src/ui/pills_page.dart';
import 'package:nestling/src/ui/setup_page.dart';
import 'package:nestling/src/ui/sheets.dart';
import 'package:nestling/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pump_session_test.dart' show FakePump;

final _root = Directory.current.path;
final _out = Platform.environment['PREVIEW_OUT'] ?? '$_root/build/preview';

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Loads every font family declared in pubspec.yaml, plus the icon fonts.
Future<void> _loadFonts() async {
  final flutter =
      Platform.environment['FLUTTER_ROOT'] ?? r'D:\Development\tools\flutter';
  final icons = '$flutter/bin/cache/artifacts/material_fonts';
  final pubspec = File('$_root/pubspec.yaml').readAsStringSync();
  final families = <String, List<String>>{};
  String? family;
  for (final line in const LineSplitter().convert(pubspec)) {
    final f = RegExp(r'^\s+- family:\s*(\S+)').firstMatch(line);
    if (f != null) family = f.group(1);
    final a = RegExp(r'asset:\s*(assets/fonts/\S+)').firstMatch(line);
    if (a != null && family != null) {
      (families[family] ??= []).add('$_root/${a.group(1)}');
    }
  }
  for (final e in families.entries) {
    await _loadFont(e.key, e.value);
  }
  final config = jsonDecode(
    File('$_root/.dart_tool/package_config.json').readAsStringSync(),
  );
  final symbols = (config['packages'] as List).firstWhere(
    (p) => p['name'] == 'material_symbols_icons',
  );
  final symbolsDir = Directory.fromUri(
    Uri.file('$_root/.dart_tool/package_config.json')
        .resolve(symbols['rootUri'] as String),
  ).path;
  // Flutter's bundled Roboto has no arrows ("3.3 → 6.5 kg"), and tests have
  // no font fallback. `python tool/website_screenshots.py fonts` writes
  // copies with the arrows added; use them when present.
  String roboto(String w) {
    final patched = '$_root/build/preview-fonts/roboto-$w.ttf';
    return File(patched).existsSync() ? patched : '$icons/roboto-$w.ttf';
  }

  await _loadFont('Roboto', [
    for (final w in ['regular', 'medium', 'bold']) roboto(w),
  ]);
  await _loadFont('MaterialIcons', ['$icons/materialicons-regular.otf']);
  for (final style in ['Outlined', 'Rounded', 'Sharp']) {
    await _loadFont('packages/material_symbols_icons/MaterialSymbols$style', [
      '$symbolsDir/lib/fonts/MaterialSymbols$style.ttf',
    ]);
  }
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await initializeDateFormatting('en');
  });

  late Directory dir;
  late AppState app;
  final boundary = GlobalKey();
  final now = DateTime(2026, 10, 31, 10, 20);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ui-preview-');
    app = await AppState.loadForTesting(
      File('${dir.path}/app.json'),
      persist: false,
    );
    Baby.dark = false;
    Baby.dim = false;
  });
  tearDown(() async {
    app.dispose();
    await app.pendingSave;
    await dir.delete(recursive: true);
  });

  Future<void> start(WidgetTester tester) async {
    debugDisableShadows = false;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2340);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: BabyApp(state: app, now: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(
    WidgetTester tester,
    String name, {
    double pixelRatio = 1.25,
  }) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ImageByteFormat.png);
      final file = File('$_out/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    final suffix = dark ? '-dark' : '';
    testWidgets('setup$suffix', (tester) async {
      if (dark) app.setAppearance('dark');
      await start(tester);
      expect(find.byType(SetupPage), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        await snap(tester, 'setup-$i$suffix');
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(field.first, 'Mia');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await snap(tester, 'setup-$i-filled$suffix');
        }
        if (find.byType(SetupPage).evaluate().isEmpty) break;
        await next(tester);
      }
      await snap(tester, 'after-setup$suffix');
      debugDisableShadows = true;
    });

    testWidgets('screens$suffix', (tester) async {
      _seed(app, DateTime.now());
      app.saveMed(Medication(name: 'Tummy time', count: 3, startMinutes: 540));
      if (dark) app.setAppearance('dark');
      await start(tester);
      await snap(tester, 'today$suffix');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await snap(tester, 'today-scrolled$suffix');
      Future<void> tab(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }

      for (final label in ['History', 'Habits', 'Routines', 'Growth']) {
        await tab(label);
        await snap(tester, '${label.toLowerCase()}$suffix');
      }
      await tab('History');
      await tester.tap(find.text('Charts'));
      await snap(tester, 'history-charts$suffix');
      await tester.tap(find.text('Activity log'));
      await tab('Today');
      final home = tester.element(find.byType(HomePage));
      for (final (name, sheet) in [
        ('feed', const FeedSheet() as Widget),
        ('nappy', const NappySheet()),
        ('sleep', const SleepSheet()),
      ]) {
        unawaited(showSheet(home, sheet));
        await snap(tester, '$name-sheet$suffix');
        Navigator.of(home).pop();
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Settings'));
      await snap(tester, 'settings$suffix');
      debugDisableShadows = true;
    });
  }
  // Every palette candidate on the main screens, for side-by-side review:
  //   flutter test --run-skipped --tags preview test/ui_preview_test.dart \
  //     --plain-name palette
  // Output: build/preview/palette/<variant>/<screen>[-dark].png. Compose
  // them with `python tool/palette_compare.py`.
  for (final variant in NestVariant.values) {
    for (final dark in [false, true]) {
      final suffix = dark ? '-dark' : '';
      testWidgets('palette ${variant.name}$suffix', (tester) async {
        NestPalette.debugVariant = variant;
        addTearDown(() => NestPalette.debugVariant = null);
        _seed(app, DateTime.now());
        app.saveMed(
          Medication(name: 'Tummy time', count: 3, startMinutes: 540),
        );
        if (dark) app.setAppearance('dark');
        await start(tester);
        Future<void> shot(String name) =>
            snap(tester, 'palette/${variant.name}/$name$suffix');
        Future<void> tab(String label) async {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();
        }

        await shot('today');
        await tab('History');
        await shot('history');
        await tab('Habits');
        await shot('habits');
        await tab('Today');
        final home = tester.element(find.byType(HomePage));
        unawaited(showSheet(home, const FeedSheet()));
        await shot('feed-sheet');
        Navigator.of(home).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Settings'));
        await shot('settings');
        debugDisableShadows = true;
      });
    }
  }

  // Button audit: the screens and sheets with buttons, on a phone at normal
  // and 1.5x text and on a desktop window. Output:
  // build/preview/audit/<phone|phone-1.5x|desktop>/<screen>.png.
  for (final (config, size, ratio, scale) in [
    ('phone', const Size(1080, 2340), 2.625, 1.0),
    ('phone-1.5x', const Size(1080, 2340), 2.625, 1.5),
    ('desktop', const Size(1280, 820), 1.0, 1.0),
  ]) {
    testWidgets('audit $config', (tester) async {
      _seed(app, DateTime.now());
      app.saveMed(Medication(name: 'Tummy time', count: 3, startMinutes: 540));
      debugDisableShadows = false;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: BabyApp(state: app, now: () => now),
        ),
      );
      await tester.pumpAndSettle();
      final desktop = config == 'desktop';
      Future<void> shot(String name) =>
          snap(tester, 'audit/$config/$name', pixelRatio: desktop ? 1 : 1.25);
      Future<void> tab(String label) async {
        final nav = find.byType(NavigationBar).evaluate().isNotEmpty
            ? find.descendant(
                of: find.byType(NavigationBar),
                matching: find.text(label),
              )
            : find.text(label).first;
        await tester.tap(nav);
        await tester.pumpAndSettle();
      }

      await shot('today');
      for (final label in ['History', 'Habits', 'Routines', 'Growth']) {
        await tab(label);
        await shot(label.toLowerCase());
      }
      await tab('Today');
      final home = tester.element(find.byType(HomePage));
      for (final (name, sheet) in [
        ('feed-sheet', const FeedSheet() as Widget),
        ('nappy-sheet', const NappySheet()),
        ('sleep-sheet', const SleepSheet()),
        ('pump-sheet', const PumpSheet()),
        ('take-habit-sheet', const TakePillSheet()),
        ('habit-editor', const MedEditor()),
      ]) {
        unawaited(showSheet(home, sheet));
        await shot(name);
        Navigator.of(home).pop();
        await tester.pumpAndSettle();
      }
      // An entry being edited: Save plus Delete.
      unawaited(editEntry(home, app.entries.first));
      await shot('edit-entry-sheet');
      Navigator.of(home).pop();
      await tester.pumpAndSettle();
      // The feed timer card, with its button pair.
      app.startFeedTimer(FeedSide.left);
      await tester.pumpAndSettle();
      await shot('today-timer');
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await shot('discard-dialog');
      await tester.tap(find.text('Keep feeding'));
      await tester.pumpAndSettle();
      app.stopFeedTimer(save: false);
      await tester.pumpAndSettle();
      await tester.tap(
        desktop ? find.text('Settings').last : find.byTooltip('Settings'),
      );
      await tester.pumpAndSettle();
      await shot('settings');
      for (var i = 1; i <= 4; i++) {
        await tester.drag(
          find.byType(Scrollable).last,
          Offset(0, desktop ? -600 : -1400),
        );
        await shot('settings-$i');
      }
      debugDisableShadows = true;
    });
  }

  testWidgets('pump', (tester) async {
    _seed(app, DateTime.now());
    for (final (h, l, r) in [(7, 70, 55), (11, 60, 50), (15, 80, 65)]) {
      app.addEntry(
        Entry(
          type: EntryType.pump,
          time: DateTime.now().subtract(Duration(hours: h)),
          side: FeedSide.both,
          durationMin: 18,
          leftMl: l,
          rightMl: r,
          amountMl: l + r,
        ),
      );
    }
    // Two pretend pumps, so the live controls show.
    PumpHub.supportedOverride = true;
    addTearDown(() => PumpHub.supportedOverride = null);
    final hub = PumpHub.instance..attach(app);
    for (final (id, side) in [('l', 0), ('r', 1)]) {
      final pump = FakePump()..status[2] = side;
      final session = PumpSession(pump);
      await tester.runAsync(session.start);
      hub.pumps[id] = ConnectedPump(id, 'M5 Smart')
        ..session = session
        ..state = PumpLinkState.ready;
      app.rememberPump(id, {'name': 'M5 Smart', 'side': side});
    }
    await start(tester);
    await snap(tester, 'pump-today');
    await tester.tap(find.text('Pump'));
    await snap(tester, 'pump-page');
    await tester.tap(find.text('Left'));
    await snap(tester, 'pump-detail');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await snap(tester, 'pump-page-scrolled');
    unawaited(
      showSheet(tester.element(find.byType(Scaffold).last), const PumpSheet()),
    );
    await snap(tester, 'pump-sheet');
    hub.pumps.clear();
    // Remembering the pumps queued a delayed save; write it now so no timer
    // is left pending when the test ends.
    app.flush();
    debugDisableShadows = true;
  });

  for (final (name, appearance, hour) in [
    ('dark', 'dark', 10),
    ('night-light', 'light', 22),
  ]) {
    testWidgets(name, (tester) async {
      final at = DateTime(2026, 10, 31, hour, 20);
      _seed(app, DateTime.now());
      app.setAppearance(appearance);
      if (name == 'night-light') app.setNightLight(true);
      debugDisableShadows = false;
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = const Size(1080, 2340);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: BabyApp(state: app, now: () => at),
        ),
      );
      await snap(tester, 'today-$name');
      debugDisableShadows = true;
    });
  }

  testWidgets('desktop', (tester) async {
    _seed(app, DateTime.now());
    debugDisableShadows = false;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 820);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: BabyApp(state: app, now: () => now),
      ),
    );
    await snap(tester, 'desktop-today');
    debugDisableShadows = true;
  });

  // The phone screenshots on the website (website/images),
  // at 600 x 1081.
  // Render all three cases with `--plain-name website`, then convert them to
  // webp with tool/website_screenshots.py.
  Future<void> websiteView(WidgetTester tester, DateTime now) async {
    debugDisableShadows = false;
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.5;
    tester.view.physicalSize = const Size(600, 1081);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: BabyApp(state: app, now: () => now),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) =>
      snap(tester, 'web-$name', pixelRatio: 1.5);

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('website setup', (tester) async {
    await websiteView(tester, DateTime.now());
    await shot(tester, 'setup-welcome');
    await next(tester);
    await shot(tester, 'setup-look');
    await next(tester);
    await tester.enterText(find.byType(TextField).first, 'Mia');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    // Birthday and photo, then "How is Mia fed?".
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    await shot(tester, 'setup-feeding');
    debugDisableShadows = true;
  });

  testWidgets('website', (tester) async {
    final version = AppState.appVersion;
    AppState.appVersion = '1.5.1';
    addTearDown(() => AppState.appVersion = version);
    final today = DateTime.now();
    _seedWebsite(app, today);
    // Pumping is optional; without its tile the camera card fits on screen.
    app.setShowPump(false);
    await websiteView(tester, today);

    await shot(tester, 'today');
    final home = tester.element(find.byType(HomePage));
    for (final (name, sheet) in [
      ('feed', const FeedSheet() as Widget),
      ('nappy', const NappySheet()),
    ]) {
      unawaited(showSheet(home, sheet));
      await shot(tester, '$name-sheet');
      Navigator.of(home).pop();
      await tester.pumpAndSettle();
    }
    await tab(tester, 'Habits');
    await shot(tester, 'habits');
    await tab(tester, 'Routines');
    await shot(tester, 'routines');
    await tab(tester, 'Growth');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -315));
    await shot(tester, 'growth');
    await tab(tester, 'History');
    await shot(tester, 'history');
    await tester.tap(find.text('Charts'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Daily totals'), const Offset(0, -380));
    await shot(tester, 'charts');
    await tester.tap(find.text('Activity log'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Export and import'));
    await shot(tester, 'backup-menu');
    await tester.tapAt(const Offset(5, 700));
    await tester.pumpAndSettle();
    await tab(tester, 'Today');

    openHub(tester.element(find.byType(HomePage)));
    await shot(tester, 'family');
    // The pairing QR code needs a running sync server and a Wi-Fi address.
    await tester.runAsync(
      () => app.server.start(
        onInfo: (_, _) => (status: 404, body: null),
        onSync: (_, _) async => (status: 404, body: null),
      ),
    );
    app.ips = ['192.168.1.23'];
    openAddDevice(tester.element(find.byType(HubPage)));
    await shot(tester, 'add-device');
    debugDisableShadows = true;
  });

  testWidgets('website pump', (tester) async {
    final today = DateTime.now();
    _seedWebsite(app, today);
    for (final (h, l, r) in [(3, 65, 50), (7, 70, 55), (11, 60, 50)]) {
      app.addEntry(
        Entry(
          type: EntryType.pump,
          time: today.subtract(Duration(hours: h)),
          side: FeedSide.both,
          durationMin: 18,
          leftMl: l,
          rightMl: r,
          amountMl: l + r,
        ),
      );
    }
    PumpHub.supportedOverride = true;
    addTearDown(() => PumpHub.supportedOverride = null);
    final hub = PumpHub.instance..attach(app);
    for (final (id, side) in [('l', 0), ('r', 1)]) {
      final pump = FakePump()..status[2] = side;
      final session = PumpSession(pump);
      await tester.runAsync(session.start);
      hub.pumps[id] = ConnectedPump(id, 'M5 Pro')
        ..session = session
        ..state = PumpLinkState.ready;
      app.rememberPump(id, {'name': 'M5 Pro', 'side': side});
    }
    await websiteView(tester, today);
    await tester.tap(find.text('Pump'));
    await shot(tester, 'pump');
    // Let the sync that adding entries queued run, and write the pending
    // save, so no timer is left when the test ends.
    await tester.pump(const Duration(seconds: 2));
    hub.pumps.clear();
    app.flush();
    debugDisableShadows = true;
  });
}

/// The website's sample family: Mia at four months, with a growth journal,
/// two habits, three routines and two other devices in the family hub.
void _seedWebsite(AppState app, DateTime today) {
  _seed(app, today, days: 7);
  final born = today.subtract(const Duration(days: 125));
  app.saveBabyProfile(name: 'Mia', dateOfBirth: born);
  final baby = app.activeBaby.id;
  for (final (days, kg, cm) in [
    (2, 3.3, 50.0),
    (30, 4.4, 54.0),
    (60, 5.3, 58.0),
    (90, 6.0, 61.0),
    (120, 6.5, 63.5),
  ]) {
    app.saveGrowth(
      GrowthEntry(
        babyId: baby,
        date: DateTime(born.year, born.month, born.day + days),
        weightKg: kg,
        heightCm: cm,
      ),
    );
  }
  final midnight = DateTime(today.year, today.month, today.day);
  final water = Medication(name: 'Drink water', count: 4, startMinutes: 7 * 60);
  final stretch = Medication(
    name: 'Stretches',
    count: 1,
    startMinutes: 20 * 60,
  );
  app.saveMed(water);
  app.saveMed(stretch);
  for (final h in [1, 7, 13, 19]) {
    final at = midnight.add(Duration(hours: h, minutes: 5));
    if (at.isBefore(today)) app.takePill(water, time: at);
  }
  app.takePill(
    stretch,
    time: midnight.subtract(const Duration(hours: 3, minutes: 50)),
  );
  final yesterday = midnight.subtract(const Duration(days: 1));
  for (final (name, minutes, days, notes, by) in [
    ('Bath time', 18 * 60 + 30, [1, 3, 5, 7], 'Warm, not hot', 'Dad'),
    ('Bedtime story', 19 * 60, [1, 2, 3, 4, 5, 6, 7], '', 'Mum'),
    ('Tummy time', 10 * 60, [1, 2, 3, 4, 5, 6, 7], 'Five minutes', 'Gran'),
  ]) {
    final routine = Routine(
      babyId: baby,
      name: name,
      minutes: minutes,
      weekdays: days,
      notes: notes,
    );
    app.saveRoutine(routine);
    app.completeRoutine(
      routine,
      doneBy: by,
      time: yesterday.add(Duration(minutes: minutes + 4)),
    );
  }
  for (final (id, name, minutes, came, sent) in [
    ('dad', "Dad's phone", 2, 2, 3),
    ('gran', "Gran's tablet", 60, 4, 0),
  ]) {
    final at = today.subtract(Duration(minutes: minutes));
    app.peers.add(
      Peer(
          deviceId: id,
          host: '192.168.1.${id.length + 20}',
          port: 8765,
          key: '123456',
          name: name,
        )
        ..appVersion = AppState.appVersion
        ..record(
          SyncRecord(
            at: at,
            outgoing: sent > 0,
            sent: sent,
            received: came,
            newThere: sent,
            newHere: {'entries': came},
            bytes: 2048,
          ),
        ),
    );
  }
}

void _seed(AppState app, DateTime now, {int days = 4}) {
  app.deviceName = "Mum's phone";
  app.saveBabyProfile(
    name: 'Mia',
    dateOfBirth: now.subtract(const Duration(days: 23)),
  );
  app.setNightLight(false);
  final midnight = DateTime(now.year, now.month, now.day);
  for (var d = days - 1; d >= 0; d--) {
    final day = midnight.subtract(Duration(days: d));
    for (final (i, h) in [1.2, 4.0, 7.1, 9.6, 12.5, 15.4, 18.3, 21.2].indexed) {
      final t = day.add(Duration(minutes: (h * 60).round()));
      if (t.isAfter(now)) continue;
      final bottle = (i + d) % 4 == 3;
      app.addEntry(
        Entry(
          type: EntryType.feed,
          time: t,
          side: bottle
              ? FeedSide.bottle
              : (i.isEven ? FeedSide.left : FeedSide.right),
          durationMin: bottle ? null : 10 + (d + i) % 9,
          amountMl: bottle ? 90 : null,
          by: 'Mum',
        ),
      );
    }
    for (final (i, h) in [2.0, 6.5, 9.9, 14.0, 19.0].indexed) {
      final t = day.add(Duration(minutes: (h * 60).round()));
      if (t.isAfter(now)) continue;
      app.addEntry(
        Entry(
          type: EntryType.nappy,
          time: t,
          nappy: NappyKind.values[(i + d) % NappyKind.values.length],
          by: 'Dad',
        ),
      );
    }
  }
  app.completeSetup();
}
