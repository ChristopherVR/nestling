import 'package:nestling/src/distribution.dart';
import 'package:nestling/src/localization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final original = Distribution.play;
  tearDown(() => Distribution.play = original);

  for (final play in [true, false]) {
    test('the ${play ? 'Play' : 'GitHub'} build says habits instead of pills', () {
      Distribution.play = play;
      expect(tr('Pills', language: 'en'), 'Habits');
      expect(tr('Pills', language: 'af'), 'Gewoontes');
      expect(tr('Pill time: Pumping', language: 'en'), 'Habit time: Pumping');
      expect(tr('08:00 · taken 09:05', language: 'en'), '08:00 · done 09:05');
      expect(
        tr(
          'Nothing logged yet today.\nTap Feed, Nappy or Pill above to start.',
          language: 'af',
        ),
        'Nog niks vandag aangeteken nie.\n'
        'Tik Voeding, Doek of Gewoonte hier bo om te begin.',
      );
    });
  }

  test('every habit wording has an Afrikaans translation', () {
    expect(
      habitWording.values.where((text) => !afrikaans.containsKey(text)),
      isEmpty,
    );
  });
}
