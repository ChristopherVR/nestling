import 'package:baby_app/src/localization.dart';
import 'package:baby_app/src/nanit_integration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

NanitAlert alert(
  NanitAlertKind kind, {
  String babyName = 'Markus',
  bool provisional = false,
}) => NanitAlert(
  kind: kind,
  babyName: babyName,
  provisional: provisional,
  at: DateTime(2026),
);

void main() {
  test('camera alerts are worded with the baby name', () {
    final sound = alert(NanitAlertKind.sound, provisional: true);
    expect(nanitAlertTitle(sound), 'Markus: sound detected');
    expect(nanitAlertBody(sound), contains('Experimental'));

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
    addTearDown(() => AppLanguage.use('en'));
    final a = alert(NanitAlertKind.motion, provisional: true);
    expect(nanitAlertTitle(a), 'Markus: beweging bespeur');
    expect(nanitAlertBody(a), startsWith('Eksperimenteel'));
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
}
