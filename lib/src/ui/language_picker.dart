import 'package:flutter/material.dart';

import 'common.dart';
import 'theme.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.showLabel = true});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel) ...[
          Semantics(
            header: true,
            child: LText(
              'Language',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: Space.sm),
        ],
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('English')),
            ButtonSegment(value: 'af', label: Text('Afrikaans')),
          ],
          selected: {app.language},
          onSelectionChanged: (selection) => app.setLanguage(selection.single),
        ),
      ],
    );
  }
}
