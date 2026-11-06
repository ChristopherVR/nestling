import 'dart:async';
import 'dart:io';

import 'package:nestling/src/local_nanit.dart';
import 'package:nestling/src/localization.dart';
import 'package:nestling/src/nanit_integration.dart' show NanitHub;
import 'package:nestling/src/nanit_wifi_setup.dart';
import 'package:nestling/src/ui/camera/camera_help.dart';
import 'package:nestling/src/ui/camera/camera_help_content.dart';
import 'package:nestling/src/ui/camera/camera_issues.dart';
import 'package:nestling/src/ui/camera/camera_live_tips.dart';
import 'package:nestling/src/ui/camera/camera_setup_wizard.dart';
import 'package:nestling/src/ui/local_camera_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanit_camera/nanit_camera.dart';
import 'package:universal_ble/universal_ble.dart';

import 'local_nanit_test.dart' show FakeLocalCamera;
import 'nanit_integration_test.dart' show FakeNanitHttp, testHub;

/// Bluetooth that never touches the radio: each scan/provision applies the
/// next scripted outcome.
class FakeWifiSetup extends NanitWifiSetup {
  final scans = <void Function(FakeWifiSetup)>[];
  final joins = <void Function(FakeWifiSetup)>[];
  int scanCount = 0, joinCount = 0;

  @override
  Future<void> scan() async {
    scanCount++;
    problem = null;
    fault = null;
    devices.clear();
    if (scans.isNotEmpty) scans.removeAt(0)(this);
    notifyListeners();
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> provision(
    String id,
    String ssid,
    String password, {
    bool hidden = false,
  }) async {
    nanitWifiRequest(ssid, password, hidden: hidden);
    joinCount++;
    problem = null;
    fault = null;
    joined = false;
    if (joins.isNotEmpty) joins.removeAt(0)(this);
    notifyListeners();
  }
}

void found(FakeWifiSetup w) =>
    w.devices['AA:BB'] = BleDevice(deviceId: 'AA:BB', name: 'Nanit_N301TEST');

void main() {
  tearDown(() => AppLanguage.use('en'));

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.ensureVisible(f.last);
    await tester.tap(f.last);
    await tester.pumpAndSettle();
  }

  group('error mapping', () {
    test('every issue has a topic with steps on both platforms', () {
      for (final windows in [true, false]) {
        for (final issue in CameraIssue.values) {
          final topic = topicFor(issue, windows: windows);
          expect(topic.title, isNotEmpty);
          expect(topic.summary, isNotEmpty);
          expect(topic.steps, isNotEmpty, reason: issue.name);
        }
      }
    });

    test('hub faults map to specific issues', () {
      expect(
        LocalCameraFault.values.map(issueForLocalFault).toSet(),
        hasLength(LocalCameraFault.values.length),
      );
      expect(
        issueForLocalFault(LocalCameraFault.differentCamera),
        CameraIssue.differentCamera,
      );
      expect(
        issueForWifiFault(WifiSetupFault.bluetoothOff),
        CameraIssue.bluetoothOff,
      );
      expect(
        issueForWifiFault(WifiSetupFault.bluetoothUnavailable),
        CameraIssue.bluetoothPermission,
      );
      expect(
        issueForWifiFault(WifiSetupFault.rejected),
        CameraIssue.wifiRejected,
      );
      expect(
        issueForLiveFailure(NanitLiveFailure.streamLimit),
        CameraIssue.streamLimit,
      );
      expect(
        issueForLiveFailure(NanitLiveFailure.noVideo),
        CameraIssue.firewall,
      );
      expect(
        issueForLiveFailure(NanitLiveFailure.noLanAddress),
        CameraIssue.noLanAddress,
      );
    });

    test('adding by address explains what was wrong', () {
      expect(
        issueForAddError(
          const FormatException('Enter the camera’s local IPv4 address.'),
        ),
        CameraIssue.invalidAddress,
      );
      expect(
        issueForAddError(
          const FormatException(
            'This address did not identify as a supported Nanit camera.',
          ),
        ),
        CameraIssue.notACamera,
      );
      expect(
        issueForAddError(const SocketException('refused')),
        CameraIssue.cannotReachAddress,
      );
      expect(
        issueForAddError(TimeoutException('slow')),
        CameraIssue.cannotReachAddress,
      );
    });

    test('a changed identity on reconnect is reported as such', () async {
      final device = FakeLocalCamera('192.168.1.5')..uid = 'N301OTHER1234';
      final hub =
          LocalNanitHub(
              store: MemoryNanitSecretStore(),
              cameraFactory: (_) => device,
            )
            ..saved = const SavedLocalCamera(
              address: '192.168.1.5',
              uid: 'N301TEST123456',
              firmware: '6.58.615',
            );
      await hub.watch();
      expect(hub.fault, LocalCameraFault.differentCamera);
      await hub.pause();
      expect(hub.fault, isNull);
      hub.dispose();
    });

    test('every camera help string has Afrikaans', () {
      final texts = {
        for (final windows in [true, false])
          for (final t in cameraHelpTopics(windows: windows)) ...t.texts,
        for (final f in cameraFaq) ...[f.question, f.answer],
        for (final a in CameraFixAction.values) cameraFixLabel(a),
        for (final s in CameraHelpSection.values) cameraHelpSectionTitle(s),
      };
      final missing = [
        for (final t in texts)
          if (t != cameraAddressExample && tr(t, language: 'af') == t) t,
      ];
      expect(missing, isEmpty);
    });
  });

  group('wizard', () {
    testWidgets('home Wi-Fi path: steps, back, not found, typed address, '
        'save, done', (tester) async {
      await phone(tester);
      final store = MemoryNanitSecretStore();
      final hub = testHub(store, FakeNanitHttp());
      final discovered = <Map<String, String>>[
        {},
        {'192.168.1.40': 'Nanit camera'},
      ];
      final saved = <(String, String)>[];
      var connected = false;
      var saving = false;
      Object? saveError = const SocketException('no route');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraSetupWizard(
              hub: hub,
              onAccount: () {},
              onConnected: () => connected = true,
              onSaving: (v) => saving = v,
              discover: () async => discovered.removeAt(0),
              save: (address, name) async {
                if (saveError case final e?) {
                  saveError = null;
                  throw e;
                }
                saved.add((address, name));
              },
            ),
          ),
        ),
      );
      expect(find.text('Your camera, at home'), findsOneWidget);
      expect(find.textContaining('Step '), findsNothing);
      // Two equal choices, each with its trade-off.
      expect(find.text('Sign in with Nanit'), findsOneWidget);
      expect(
        find.text('Works without the internet. No motion alerts.'),
        findsOneWidget,
      );
      await tap(tester, 'Home network (no account)');
      expect(store.values[NanitHub.modeKey], 'home');
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(
        find.text('Is your camera already on your Wi-Fi?'),
        findsOneWidget,
      );

      // Back returns to the previous screen.
      await tap(tester, 'Back');
      expect(find.text('Your camera, at home'), findsOneWidget);
      await tap(tester, 'Home network (no account)');
      await tap(tester, 'Already on Wi-Fi');
      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.text('A guest network'), findsOneWidget);

      // Step help lists that step's problems.
      await tap(tester, 'Something not working?');
      expect(find.text('Which Wi-Fi networks work?'), findsWidgets);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tap(tester, 'This device is on the home Wi-Fi');
      expect(find.text('Find the camera on your network'), findsOneWidget);
      await tap(tester, 'Search my network');
      expect(
        find.text('Your camera was not found on this Wi-Fi'),
        findsOneWidget,
      );
      expect(find.text('Set up camera Wi-Fi'), findsOneWidget);
      // The manual address section opens with an example.
      expect(find.text('Connect by address'), findsOneWidget);
      expect(find.text('Nanit (N301…)'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '192.168.1.300');
      await tap(tester, 'Connect by address');
      expect(
        find.text('That does not look like a home-network address'),
        findsOneWidget,
      );

      await tap(tester, 'Search again');
      await tap(tester, '192.168.1.40');
      expect(find.text('Name your camera'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Nursery');
      await tap(tester, 'Save and connect');
      expect(find.text('Nothing answered at that address'), findsOneWidget);
      expect(saving, isFalse);

      await tap(tester, 'Try again');
      expect(saved, [('192.168.1.40', 'Nursery')]);
      expect(saving, isTrue, reason: 'host keeps the wizard for Done');
      expect(find.text('You are all set'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      await tap(tester, 'Start watching');
      expect(connected, isTrue);
      expect(saving, isFalse);
      expect(tester.takeException(), isNull);
      hub.dispose();
    });

    testWidgets('Bluetooth path maps each failure to its fix', (tester) async {
      await phone(tester);
      final hub = testHub(MemoryNanitSecretStore(), FakeNanitHttp());
      final wifi = FakeWifiSetup();
      wifi.scans.addAll([
        (w) {
          w.problem = 'Turn on Bluetooth, then scan again.';
          w.fault = WifiSetupFault.bluetoothOff;
        },
        (w) {
          w.problem = 'Bluetooth is unavailable.';
          w.fault = WifiSetupFault.bluetoothUnavailable;
        },
        (w) {
          w.problem = 'No camera found.';
          w.fault = WifiSetupFault.noCameraFound;
        },
        found,
      ]);
      wifi.joins.addAll([
        (w) {
          w.problem = 'Camera did not confirm Wi-Fi setup (status 401).';
          w.fault = WifiSetupFault.rejected;
        },
        (w) => w.joined = true,
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: CameraSetupWizard(
              hub: hub,
              onAccount: () {},
              wifiSetup: () => wifi,
              discover: () async => {},
            ),
          ),
        ),
      );
      await tap(tester, 'Home network (no account)');
      await tap(tester, 'Set up Wi-Fi');
      expect(find.text('Step 2 of 8'), findsOneWidget);
      expect(find.text('Put the camera in pairing mode'), findsOneWidget);
      await tap(tester, 'The light is flashing');

      await tap(tester, 'Look for camera');
      expect(find.text('Bluetooth is off'), findsOneWidget);
      await tap(tester, 'Look again');
      expect(find.text('Nestling cannot use Bluetooth'), findsOneWidget);
      expect(find.text('Allow Nearby devices.'), findsOneWidget);
      await tap(tester, 'Look again');
      expect(find.text('No camera found nearby'), findsOneWidget);
      // Continue needs a camera.
      expect(
        tester
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Continue'),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'Look again');
      expect(find.text('Nanit_N301TEST'), findsOneWidget);
      await tap(tester, 'Nanit_N301TEST');
      await tap(tester, 'Continue');

      expect(find.text('Enter your home Wi-Fi'), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Home-WiFi');
      await tester.enterText(fields.at(1), 'short');
      await tap(tester, 'Connect camera to Wi-Fi');
      expect(find.text('Check the Wi-Fi name and password'), findsOneWidget);
      expect(wifi.joinCount, 0, reason: 'invalid details are never sent');

      await tester.enterText(fields.at(1), 'correct horse');
      await tap(tester, 'Connect camera to Wi-Fi');
      expect(find.text('The camera could not join your Wi-Fi'), findsOneWidget);
      await tester.enterText(fields.at(1), 'correct horse');
      await tap(tester, 'Connect camera to Wi-Fi');
      expect(find.text('Check this device’s Wi-Fi'), findsOneWidget);
      expect(
        find.text(
          'The camera accepted the Wi-Fi details. It can take a minute to join.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      hub.dispose();
    });

    testWidgets('fits a phone in Afrikaans', (tester) async {
      await phone(tester);
      final hub = testHub(MemoryNanitSecretStore(), FakeNanitHttp());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('af'),
          supportedLocales: const [Locale('en'), Locale('af')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: CameraSetupWizard(hub: hub, onAccount: () {}),
          ),
        ),
      );
      expect(find.text('Jou kamera, by die huis'), findsOneWidget);
      await tap(tester, tr('Home network (no account)', language: 'af'));
      expect(find.text('Stap 1 van 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      hub.dispose();
    });
  });

  group('help', () {
    testWidgets('search finds topics by words in their steps', (tester) async {
      await phone(tester);
      await tester.pumpWidget(const MaterialApp(home: CameraHelpPage()));
      expect(find.text('Quick start'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'weekly');
      await tester.pumpAndSettle();
      expect(find.text('Your camera key needs renewing'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'subscription');
      await tester.pumpAndSettle();
      expect(find.text('Questions people ask'), findsOneWidget);
      expect(find.text('Can I keep using the Nanit app?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'password');
      await tester.pumpAndSettle();
      expect(find.text('The camera could not join your Wi-Fi'), findsOneWidget);
      expect(find.text('Video stopped'), findsNothing);
      await tester.enterText(find.byType(TextField), '403');
      await tester.pumpAndSettle();
      expect(
        find.text('The camera is busy with other viewers'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.textContaining('No help matches that'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('More help opens the problem first and expanded', (
      tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        const MaterialApp(home: CameraHelpPage(focusTopic: 'streamLimit')),
      );
      expect(find.text('Your problem'), findsOneWidget);
      expect(
        find.text(
          'Close the Nanit app on other phones and tablets, or close Nestling on another device.',
        ),
        findsOneWidget,
      );
    });
  });

  group('live screen', () {
    testWidgets('first-time tips, then a specific fix for a changed camera', (
      tester,
    ) async {
      await phone(tester);
      final store = MemoryNanitSecretStore();
      final device = FakeLocalCamera('192.168.1.5')..uid = 'N301OTHER1234';
      final hub = LocalNanitHub(store: store, cameraFactory: (_) => device)
        ..saved = const SavedLocalCamera(
          address: '192.168.1.5',
          uid: 'N301TEST123456',
          firmware: '6.58.615',
          name: 'Nursery',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalCameraWatch(hub: hub)),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('New here? A few tips'), findsOneWidget);
      expect(find.text('A different camera answered'), findsOneWidget);
      expect(find.text('Change camera address'), findsWidgets);
      await tap(tester, 'All tips');
      expect(find.text('Soothing sounds keep playing'), findsOneWidget);
      expect(find.text('Tips for the live view'), findsWidgets);
      Navigator.of(tester.element(find.text('Soothing sounds keep playing')))
          .pop();
      await tester.pumpAndSettle();
      await tap(tester, 'Got it');
      expect(find.text('New here? A few tips'), findsNothing);
      expect(store.values[cameraTipsSeenKey], isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
      hub.dispose();
    });
  });
}
