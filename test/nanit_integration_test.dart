import 'dart:convert';

import 'package:baby_app/src/localization.dart';
import 'package:baby_app/src/nanit_integration.dart';
import 'package:baby_app/src/ui/camera_page.dart';
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

NanitHub testHub(MemoryNanitSecretStore store, FakeNanitHttp http) => NanitHub(
  account: NanitAccount(
    store: store,
    api: NanitApi(http: http),
  ),
  alertSink: NanitAlertSink((_) async {}),
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
    expect(store.values, isEmpty);
  });
}
