import 'package:baby_app/src/local_nanit.dart';
import 'package:baby_app/src/ui/local_camera_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanit_camera/nanit_camera.dart';

class SoundTestHub extends LocalNanitHub {
  SoundTestHub() : super(store: MemoryNanitSecretStore()) {
    saved = const SavedLocalCamera(
      address: '192.168.1.5',
      uid: 'N301TEST123456',
      firmware: '6.58.615',
    );
    state = LocalCameraState.ready;
    sound = const NanitSoundState(supported: true, playing: false);
  }
  final plays = <(NanitSoundTrack, int, int)>[];
  int stops = 0;
  @override
  Future<void> watch() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> playSound(NanitSoundTrack track, int volume, int seconds) async {
    plays.add((track, volume, seconds));
    sound = NanitSoundState(
      supported: true,
      playing: true,
      track: track,
      volume: volume,
      remainingSeconds: seconds,
    );
    notifyListeners();
  }

  @override
  Future<void> setSoundVolume(int volume) async {
    sound = NanitSoundState(
      supported: true,
      playing: true,
      track: sound!.track,
      volume: volume,
      remainingSeconds: sound!.remainingSeconds,
    );
    notifyListeners();
  }

  @override
  Future<void> stopSound() async {
    stops++;
    sound = const NanitSoundState(supported: true, playing: false);
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'phone sound controls only play on request and provide volume and stop',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hub = SoundTestHub();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalCameraWatch(hub: hub)),
        ),
      );
      await tester.pumpAndSettle();
      expect(hub.plays, isEmpty);
      final soundPicker = find.byType(DropdownButtonFormField<NanitSoundTrack>);
      await tester.ensureVisible(soundPicker);
      await tester.tap(soundPicker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('White noise').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Play sound'));
      await tester.tap(find.text('Play sound'));
      await tester.pumpAndSettle();
      expect(hub.plays, [(NanitSoundTrack.whiteNoise, 20, 900)]);
      expect(
        find.text('White noise is playing · 15 min remaining'),
        findsOneWidget,
      );
      final slider = tester.widget<Slider>(find.byType(Slider));
      slider.onChanged!(35);
      slider.onChangeEnd!(35);
      await tester.pumpAndSettle();
      expect(hub.sound!.volume, 35);
      await tester.ensureVisible(find.text('Stop sound'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop sound'));
      await tester.pumpAndSettle();
      expect(hub.stops, 1);
      expect(hub.sound!.playing, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      hub.dispose();
    },
  );
}
