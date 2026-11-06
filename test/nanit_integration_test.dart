import 'dart:convert';

import 'package:nestling/src/local_nanit.dart';
import 'package:nestling/src/localization.dart';
import 'package:nestling/src/nanit_integration.dart';
import 'package:nestling/src/ui/camera_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

NanitAlert alert(NanitAlertKind kind, {String babyName = 'Markus'}) =>
    NanitAlert(kind: kind, babyName: babyName, at: DateTime(2026));

/// Nanit's cloud API as the sign-in flow sees it, with MFA.
class FakeNanitHttp implements NanitHttp {
  final calls = <String>[];

  @override
  Future<NanitHttpResponse> send(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    calls.add('$method ${uri.path}');
    final b = body is Map ? body : const {};
    switch (uri.path) {
      case '/login' when b['mfa_code'] == null:
        return NanitHttpResponse(482, {
          'mfa_token': 'MFA',
          'suffix': '42',
          'channel': 'sms',
        });
      case '/login':
        return b['mfa_code'] == '123456'
            ? NanitHttpResponse(201, {'access_token': 'ACCESS'})
            : NanitHttpResponse(401, {'message': 'bad code'});
      case '/babies':
        return NanitHttpResponse(200, {
          'babies': [
            {
              'uid': 'd5783a3f',
              'name': 'Markus',
              'camera': {'uid': 'N301CMA2449596'},
            },
          ],
        });
      default:
        if (uri.path.endsWith('/uc_token')) {
          return NanitHttpResponse(200, {
            'token': 'CAMTOKEN',
            'expiration':
                DateTime.now()
                    .add(const Duration(days: 7))
                    .millisecondsSinceEpoch ~/
                1000,
          });
        }
        return NanitHttpResponse(404, null);
    }
  }
}

NanitHub testHub(
  MemoryNanitSecretStore store,
  FakeNanitHttp http, {
  Duration? refreshEvery,
}) => NanitHub(
  account: NanitAccount(
    store: store,
    api: NanitApi(http: http),
  ),
  alertSink: NanitAlertSink((_) async {}),
  refreshEvery: refreshEvery,
);

/// Lets the fake HTTP answer and the UI catch up. (Spinners never settle,
/// so no pumpAndSettle.)
Future<void> step(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  tearDown(() => AppLanguage.use('en'));

  test('camera alerts are worded with the baby name', () {
    final sound = alert(NanitAlertKind.sound);
    expect(nanitAlertTitle(sound), 'Markus: sound detected');
    expect(nanitAlertBody(sound), 'Heard by the Nanit camera');

    final motion = alert(NanitAlertKind.motion);
    expect(nanitAlertTitle(motion), 'Markus: motion detected');
    expect(nanitAlertBody(motion), 'Seen by the Nanit camera');

    expect(
      nanitAlertTitle(alert(NanitAlertKind.sound, babyName: '')),
      'Sound detected',
    );
  });

  test('camera alert and video text has Afrikaans', () {
    AppLanguage.use('af');
    expect(
      nanitAlertTitle(alert(NanitAlertKind.motion)),
      'Markus: beweging bespeur',
    );
    expect(
      nanitAlertBody(alert(NanitAlertKind.sound)),
      'Deur die Nanit-kamera gehoor',
    );
    for (final l in NanitVideoLabel.values) {
      expect(
        nanitVideoLabel(l),
        isNot(englishNanitVideoLabel(l)),
        reason: '${l.name} has no Afrikaans',
      );
    }
  });

  test('video labels match the package wording in English', () {
    for (final l in NanitVideoLabel.values) {
      expect(nanitVideoLabel(l), englishNanitVideoLabel(l));
    }
  });

  testWidgets('sign in with MFA, then pick the camera', (tester) async {
    final store = MemoryNanitSecretStore();
    final http = FakeNanitHttp();
    final hub = testHub(store, http);
    addTearDown(() => tester.runAsync(hub.signOut));

    await tester.pumpWidget(MaterialApp(home: CameraPage(hub: hub)));
    await tester.runAsync(hub.start);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Use a Nanit account instead'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Use a Nanit account instead'));
    await tester.pump();
    expect(find.text('Sign in to Nanit'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(find.text('Sign in to Nanit'));
    await tester.pump();
    await tester.tap(find.text('Sign in to Nanit'));
    await step(tester);

    // The MFA prompt names where the code went.
    expect(find.text('Nanit sent a code to your phone (…42).'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Continue'));
    await step(tester);

    expect(hub.signedIn, isTrue);
    expect(find.text('Which camera?'), findsOneWidget);
    await step(tester);
    expect(find.text('Markus'), findsOneWidget);
    // The password is never stored; the session is.
    expect(jsonEncode(store.values), isNot(contains('secret')));
    expect(store.values['nanit.session'], contains('ACCESS'));
  });

  test('pairing stores the camera and its token, and opens the link', () async {
    final store = MemoryNanitSecretStore();
    final hub = testHub(store, FakeNanitHttp());
    await hub.start();
    await hub.signIn('me@example.com', 'secret', onMfa: (_) async => '123456');
    final babies = await hub.babies();
    await hub.pair(babies.single);

    expect(hub.paired, isTrue);
    expect(hub.account.pairing!.cameraUid, 'N301CMA2449596');
    expect(store.values['nanit.camera_token'], contains('CAMTOKEN'));
    expect(hub.connection, isNotNull);
    expect(hub.live, isNotNull);
    expect(hub.alerts!.mode, NanitAlertMode.off);

    await hub.setManualIp('192.168.6.209');
    expect(hub.account.pairing!.manualIp, '192.168.6.209');

    await hub.forgetCamera();
    expect(hub.paired, isFalse);
    expect(hub.signedIn, isTrue);
    expect(hub.connection, isNull);
    await hub.signOut();
    expect(hub.mode, CameraMode.home);
    expect(store.values.keys, [NanitHub.modeKey]);
  });

  group('camera modes', () {
    /// A store with a home-network camera and a paired account whose
    /// camera key runs out in [keyLeft].
    MemoryNanitSecretStore bothSaved({
      String? mode,
      Duration keyLeft = const Duration(days: 6),
    }) => MemoryNanitSecretStore()
      ..values[LocalNanitHub.storageKey] = jsonEncode(
        const SavedLocalCamera(
          address: '192.168.1.40',
          uid: 'N301CMA2449596',
          firmware: '6.58.615',
        ).toJson(),
      )
      ..values['nanit.session'] = jsonEncode({
        'access_token': 'ACCESS',
        'refresh_token': 'REFRESH',
      })
      ..values['nanit.pairing'] = jsonEncode({
        'baby_uid': 'd5783a3f',
        'baby_name': 'Markus',
        'camera_uid': 'N301CMA2449596',
      })
      ..values['nanit.camera_token'] = jsonEncode({
        'token': 'CAMTOKEN',
        'expiration':
            DateTime.now().add(keyLeft).millisecondsSinceEpoch ~/ 1000,
        'camera_uid': 'N301CMA2449596',
      })
      ..values.addAll({NanitHub.modeKey: ?mode});

    /// Leaves the paired camera's key less than the renewal margin.
    Future<void> makeDue(MemoryNanitSecretStore store, NanitHub hub) async {
      store.values['nanit.camera_token'] = jsonEncode({
        'token': 'CAMTOKEN',
        'expiration':
            DateTime.now()
                .add(const Duration(hours: 5))
                .millisecondsSinceEpoch ~/
            1000,
        'camera_uid': 'N301CMA2449596',
      });
      await hub.account.load();
    }

    test('both modes stay set up; only the active one streams', () async {
      final store = bothSaved();
      final hub = testHub(store, FakeNanitHttp());
      await hub.start();
      expect(hub.mode, CameraMode.home);
      expect(hub.homeReady, isTrue);
      expect(hub.accountReady, isTrue);
      // Home is active, so the account link stays closed.
      expect(hub.connection, isNull);

      await hub.switchMode(CameraMode.account);
      expect(hub.connection, isNotNull);
      expect(hub.local.saved, isNotNull);

      await hub.switchMode(CameraMode.home);
      expect(hub.connection, isNull);
      expect(hub.paired, isTrue);
      expect(hub.signedIn, isTrue);
      hub.dispose();
    });

    test('the chosen mode is remembered across restarts', () async {
      final store = bothSaved();
      final first = testHub(store, FakeNanitHttp());
      await first.start();
      await first.switchMode(CameraMode.account);
      expect(store.values[NanitHub.modeKey], 'account');
      await first.switchMode(CameraMode.home);
      await first.switchMode(CameraMode.account);
      first.dispose();

      final again = testHub(store, FakeNanitHttp());
      await again.start();
      expect(again.mode, CameraMode.account);
      expect(again.connection, isNotNull);
      await again.switchMode(CameraMode.home);
      again.dispose();
    });

    test(
      'without a saved mode, an account-only setup stays on the account',
      () async {
        final store = bothSaved()..values.remove(LocalNanitHub.storageKey);
        final hub = testHub(store, FakeNanitHttp());
        await hub.start();
        expect(hub.mode, CameraMode.account);
        await hub.switchMode(CameraMode.home);
        hub.dispose();
      },
    );

    test('adding a home camera keeps the account paired', () async {
      final store = bothSaved(mode: 'account')
        ..values.remove(LocalNanitHub.storageKey);
      final hub = testHub(store, FakeNanitHttp());
      await hub.start();
      expect(hub.connection, isNotNull);
      store.values[LocalNanitHub.storageKey] = jsonEncode(
        const SavedLocalCamera(
          address: '192.168.1.40',
          uid: 'N301CMA2449596',
          firmware: '6.58.615',
        ).toJson(),
      );
      await hub.local.load();
      await hub.switchMode(CameraMode.home);
      expect(hub.paired, isTrue);
      expect(hub.homeReady, isTrue);
      expect(hub.connection, isNull);
      hub.dispose();
    });

    test('the camera key is renewed at start and on resume even when home '
        'is active', () async {
      final http = FakeNanitHttp();
      final store = bothSaved(keyLeft: const Duration(hours: 20));
      final hub = testHub(store, http);
      await hub.start();
      await pumpEventQueue();
      expect(
        http.calls,
        contains('GET /focus/cameras/N301CMA2449596/uc_token'),
      );
      expect(
        hub.account.cameraTokenExpires!.isAfter(
          DateTime.now().add(const Duration(days: 6)),
        ),
        isTrue,
      );

      // Close to running out again: resuming the app renews it.
      http.calls.clear();
      await makeDue(store, hub);
      hub.appResumed();
      await pumpEventQueue();
      expect(http.calls, ['GET /focus/cameras/N301CMA2449596/uc_token']);
      hub.dispose();
    });

    test('the key is checked on a timer while the app runs', () async {
      final http = FakeNanitHttp();
      final store = bothSaved();
      final hub = testHub(
        store,
        http,
        refreshEvery: const Duration(milliseconds: 50),
      );
      await hub.start();
      await pumpEventQueue();
      expect(http.calls, isEmpty, reason: 'the key has days left');
      await makeDue(store, hub);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        http.calls,
        contains('GET /focus/cameras/N301CMA2449596/uc_token'),
      );
      hub.dispose();
    });
  });
}
