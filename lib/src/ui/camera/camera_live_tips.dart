import 'package:flutter/material.dart';
import 'package:nanit_camera/nanit_camera.dart';

import '../../localization.dart';
import 'camera_help.dart';

/// First-visit coaching for the live camera screen, and the same tips on
/// demand from its info button.

const cameraTipsSeenKey = 'nestling.localCamera.tipsSeen.v1';

const _tips = <(IconData, String, String)>[
  (
    Icons.volume_off,
    'Video starts muted',
    'Tap Listen to hear the room. Tap Mute to stop.',
  ),
  (
    Icons.pause_circle_outline,
    'Leaving pauses the video',
    'Video and room readings stop when you leave this screen, and start again muted when you return. Alerts you turned on keep running.',
  ),
  (
    Icons.refresh,
    'Picture stuck?',
    'Tap Reconnect. Nestling also retries by itself every few seconds.',
  ),
  (
    Icons.graphic_eq,
    'Soothing sounds keep playing',
    'Camera sounds play on the camera until their timer ends, even if you close Nestling.',
  ),
  (
    Icons.notifications_active_outlined,
    'Get alerts',
    'Turn on Sound & cry alerts to be notified while you do other things.',
  ),
  (
    Icons.help_outline,
    'Help is always here',
    'Tap the question mark at the top for troubleshooting and answers.',
  ),
];

Future<void> showCameraLiveTips(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: LText(
              'Tips for the live view',
              style: Theme.of(sheet).textTheme.headlineSmall,
            ),
          ),
          for (final (icon, title, text) in _tips)
            ListTile(
              leading: Icon(icon),
              title: LText(title),
              subtitle: LText(text),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    openCameraHelp(context);
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const LText('Camera help'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const LText('Got it'),
                ),
              ],
            ),
          ),
        ],
      ),
    );

/// An inline card shown until dismissed once on this device.
class CameraFirstTimeTips extends StatefulWidget {
  const CameraFirstTimeTips({super.key, required this.store});
  final NanitSecretStore store;

  @override
  State<CameraFirstTimeTips> createState() => _CameraFirstTimeTipsState();
}

class _CameraFirstTimeTipsState extends State<CameraFirstTimeTips> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    widget.store.read(cameraTipsSeenKey).then((v) {
      if (mounted && v == null) setState(() => _show = true);
    }, onError: (_) {});
  }

  Future<void> _dismiss() async {
    setState(() => _show = false);
    try {
      await widget.store.write(cameraTipsSeenKey, '1');
    } catch (_) {
      // Shows again next time; harmless.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('camera-first-tips'),
      elevation: 0,
      color: s.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: s.onTertiaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LText(
                    'New here? A few tips',
                    style: t.titleMedium?.copyWith(
                      color: s.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final (icon, title, _) in _tips.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: s.onTertiaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LText(
                        title,
                        style: t.bodyMedium?.copyWith(
                          color: s.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => showCameraLiveTips(context),
                  child: const LText('All tips'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _dismiss,
                  child: const LText('Got it'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
