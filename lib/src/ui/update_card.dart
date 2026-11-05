import 'dart:io';

import 'package:flutter/material.dart';

import '../localization.dart';
import '../updates.dart';
import 'theme.dart';

Future<void> showAppUpdates(BuildContext context, {AppUpdates? updates}) {
  final service = updates ?? AppUpdates.instance;
  if (!service.usesPlayStore) service.check(manual: true);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const LText('App updates'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(child: UpdateCard(updates: service)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const LText('Close'),
        ),
      ],
    ),
  );
}

class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, this.updates});
  final AppUpdates? updates;

  @override
  Widget build(BuildContext context) {
    final updates = this.updates ?? AppUpdates.instance;
    if (updates.usesPlayStore) {
      return ListenableBuilder(
        listenable: updates,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LText(
              'Updates for this version are provided by Google Play.',
            ),
            if (updates.message != null) ...[
              const SizedBox(height: Space.sm),
              LText(updates.message!),
            ],
            const SizedBox(height: Space.lg),
            FilledButton.icon(
              onPressed: updates.openStore,
              icon: const Icon(Icons.shop_outlined),
              label: const LText('Open Google Play'),
            ),
          ],
        ),
      );
    }
    return ListenableBuilder(
      listenable: updates,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (updates.available != null)
              LText(
                'New update available: ${updates.available!.version}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            if (updates.message != null) ...[
              const SizedBox(height: Space.sm),
              LText(updates.message!),
            ],
            if (updates.downloading) ...[
              const SizedBox(height: Space.lg),
              LinearProgressIndicator(value: updates.progress),
              const SizedBox(height: Space.sm),
              LText('Downloading: ${(updates.progress * 100).round()}%'),
            ] else if (updates.available != null) ...[
              const SizedBox(height: Space.sm),
              const LText(
                'Download from GitHub, then confirm installation in Android. Your logs stay on this device.',
              ),
              const SizedBox(height: Space.lg),
              FilledButton.icon(
                onPressed: updates.checking ? null : updates.install,
                icon: const Icon(Icons.system_update_rounded),
                label: const LText('Update'),
              ),
            ],
            if (updates.checking) ...[
              const SizedBox(height: Space.lg),
              const LinearProgressIndicator(),
              const SizedBox(height: Space.sm),
              const LText('Checking for updates…'),
            ],
            if (!Platform.isAndroid)
              const LText('App updates are available on Android.'),
          ],
        );
      },
    );
  }
}
