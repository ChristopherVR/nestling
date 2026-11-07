import 'package:flutter/material.dart';

import '../../local_talk.dart';
import '../../localization.dart';
import '../theme.dart';

/// Press and hold to speak through the camera; let go to stop. Sound only
/// flows while a finger (or the mouse button) is down.
class TalkButton extends StatelessWidget {
  const TalkButton({super.key, required this.talk, this.enabled = true});
  final LocalTalk talk;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: talk,
    builder: (context, _) {
      final s = Theme.of(context).colorScheme;
      final t = Theme.of(context).textTheme;
      final live = talk.active;
      final message = switch (talk.state) {
        TalkState.talking => 'Talking… let go to stop',
        TalkState.starting => 'Getting ready…',
        TalkState.denied =>
          'Microphone access is off. Allow it in your device settings to talk.',
        TalkState.failed => 'Could not talk through the camera. Try again.',
        TalkState.idle => 'Press and hold Talk to speak to your baby.',
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            enabled: enabled,
            label: tr('Talk'),
            hint: tr('Press and hold Talk to speak to your baby.'),
            child: Listener(
              onPointerDown: enabled ? (_) => talk.start() : null,
              onPointerUp: (_) => talk.stop(),
              onPointerCancel: (_) => talk.stop(),
              child: AnimatedContainer(
                duration: Motion.short,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.xl,
                  vertical: Space.md,
                ),
                decoration: BoxDecoration(
                  color: !enabled
                      ? s.onSurface.withValues(alpha: 0.12)
                      : live
                      ? s.primary
                      : s.secondaryContainer,
                  borderRadius: BorderRadius.circular(Corners.xl),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      live ? Icons.mic : Icons.mic_none,
                      color: live ? s.onPrimary : s.onSecondaryContainer,
                    ),
                    const SizedBox(width: Space.sm),
                    LText(
                      live ? 'Talking…' : 'Talk',
                      style: t.labelLarge?.copyWith(
                        color: live ? s.onPrimary : s.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: LText(
              message,
              style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
            ),
          ),
        ],
      );
    },
  );
}
