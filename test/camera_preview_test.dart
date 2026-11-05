// Renders phone-sized screenshots of the camera setup, help and live screens
// for design review and the user guide. Skipped in normal runs. To render:
//
//   flutter test --run-skipped --tags preview test/camera_preview_test.dart
//
// Output: build/preview/camera-*.png (override with PREVIEW_OUT).
@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:nestling/src/local_nanit.dart';
import 'package:nestling/src/nanit_wifi_setup.dart';
import 'package:nestling/src/ui/camera/camera_help.dart';
import 'package:nestling/src/ui/camera/camera_setup_wizard.dart';
import 'package:nestling/src/ui/local_camera_page.dart';
import 'package:nestling/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

import 'camera_setup_wizard_test.dart' show FakeWifiSetup, found;
import 'local_nanit_test.dart' show FakeLocalCamera;
import 'nanit_integration_test.dart' show FakeNanitHttp, testHub;

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
  await _loadFont('Roboto', ['$icons/roboto-regular.ttf']);
  await _loadFont('MaterialIcons', ['$icons/materialicons-regular.otf']);
}

void main() {
  setUpAll(_loadFonts);
  final boundary = GlobalKey();

  Future<void> show(WidgetTester tester, Widget home, {bool dark = false}) async {
    Baby.dark = dark;
    Baby.dim = false;
    debugDisableShadows = false;
    addTearDown(() => Baby.dark = false);
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 2340);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: babyTheme(),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> snap(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: 1.25);
      final data = await image.toByteData(format: ImageByteFormat.png);
      final file = File('$_out/camera-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final f = find.text(text).last;
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Widget page(Widget body) =>
      Scaffold(appBar: AppBar(title: const Text('Camera')), body: body);

  for (final dark in [false, true]) {
    testWidgets('wizard${dark ? ' dark' : ''}', (tester) async {
      final hub = testHub(MemoryNanitSecretStore(), FakeNanitHttp());
      final wifi = FakeWifiSetup()
        ..scans.addAll([
          (w) {
            w.problem = 'Turn on Bluetooth, then scan again.';
            w.fault = WifiSetupFault.bluetoothOff;
          },
          found,
        ])
        ..joins.add((w) => w.joined = true);
      final results = [
        <String, String>{},
        {'192.168.1.25': 'Nanit camera'},
      ];
      await show(
        tester,
        page(
          CameraSetupWizard(
            hub: hub,
            onAccount: () {},
            wifiSetup: () => wifi,
            discover: () async => results.removeAt(0),
            save: (_, _) async {},
          ),
        ),
        dark: dark,
      );
      final p = dark ? 'dark-' : '';
      await snap(tester, '${p}01-intro');
      if (dark) {
        hub.dispose();
        debugDisableShadows = true;
        return;
      }
      await tap(tester, 'Get started');
      await snap(tester, '02-path');
      await tap(tester, 'Set up Wi-Fi');
      await snap(tester, '03-pairing');
      await tap(tester, 'The light is flashing');
      await tap(tester, 'Look for camera');
      await snap(tester, '04-bluetooth-off');
      await tap(tester, 'Look again');
      await tap(tester, 'Nanit_N301TEST');
      await snap(tester, '05-bluetooth-found');
      await tap(tester, 'Continue');
      await tester.enterText(find.byType(TextField).first, 'Home-WiFi');
      FocusManager.instance.primaryFocus?.unfocus();
      await snap(tester, '06-wifi');
      await tester.enterText(find.byType(TextField).at(1), 'correct horse');
      FocusManager.instance.primaryFocus?.unfocus();
      await tap(tester, 'Connect camera to Wi-Fi');
      await snap(tester, '07-network');
      await tap(tester, 'This device is on the home Wi-Fi');
      await tap(tester, 'Search my network');
      await snap(tester, '08-not-found');
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -900),
      );
      await snap(tester, '09-manual-address');
      await tap(tester, 'Search again');
      await snap(tester, '10-found');
      await tap(tester, 'Nanit camera');
      await snap(tester, '11-name');
      await tap(tester, 'Save and connect');
      await snap(tester, '12-done');
      await tester.pumpWidget(const SizedBox());
      hub.dispose();
      debugDisableShadows = true;
    });
  }

  testWidgets('step help sheet', (tester) async {
    final hub = testHub(MemoryNanitSecretStore(), FakeNanitHttp());
    await show(tester, page(CameraSetupWizard(hub: hub, onAccount: () {})));
    await tap(tester, 'Get started');
    await tap(tester, 'Already on Wi-Fi');
    await tap(tester, 'Something not working?');
    await snap(tester, 'step-help');
    hub.dispose();
    debugDisableShadows = true;
  });

  testWidgets('help page', (tester) async {
    await show(tester, const CameraHelpPage());
    await snap(tester, 'help');
    await tester.enterText(find.byType(TextField), 'password');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await snap(tester, 'help-search');
    await show(tester, const CameraHelpPage(focusTopic: 'streamLimit'));
    await snap(tester, 'help-focus');
    await show(tester, const CameraHelpPage(focusTopic: 'findAddress'));
    await snap(tester, 'help-address');
    debugDisableShadows = true;
  });

  testWidgets('live screen problem', (tester) async {
    final device = FakeLocalCamera('192.168.1.25')..uid = 'N301OTHER1234';
    final hub =
        LocalNanitHub(
            store: MemoryNanitSecretStore(),
            cameraFactory: (_) => device,
          )
          ..saved = const SavedLocalCamera(
            address: '192.168.1.25',
            uid: 'N301TEST123456',
            firmware: '6.58.615',
            name: 'Nursery',
          );
    await show(tester, page(LocalCameraWatch(hub: hub)));
    await tester.pump();
    await snap(tester, 'live-first-time');
    await tap(tester, 'Got it');
    await tester.drag(find.byType(ListView).first, const Offset(0, -330));
    await snap(tester, 'live-problem');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 9));
    hub.dispose();
    debugDisableShadows = true;
  });
}
