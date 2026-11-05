import 'package:flutter/material.dart';

import '../../localization.dart';
import 'camera_art.dart';
import 'camera_help_content.dart';
import 'camera_issues.dart';

bool _windows(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.windows;

/// A problem with what happened, why, and what to do: shown in place of a
/// bare error message. Only [actions] the screen can perform get buttons.
class CameraIssueCard extends StatelessWidget {
  const CameraIssueCard({
    super.key,
    required this.issue,
    this.actions = const {},
    this.detail,
    this.compact = false,
  });
  final CameraIssue issue;
  final Map<CameraFixAction, VoidCallback> actions;

  /// The technical message, if any, shown small under the explanation.
  final String? detail;

  /// Shows only the first two steps, with the rest behind "More help".
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final topic = topicFor(issue, windows: _windows(context));
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final background = topic.serious ? s.errorContainer : s.secondaryContainer;
    final foreground = topic.serious
        ? s.onErrorContainer
        : s.onSecondaryContainer;
    final steps = compact ? topic.steps.take(2).toList() : topic.steps;
    final available = [
      for (final a in topic.actions)
        if (actions[a] != null) a,
    ];
    return Card(
      key: ValueKey('issue-${issue.name}'),
      elevation: 0,
      color: background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(topic.icon, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: LText(
                      topic.title,
                      style: t.titleMedium?.copyWith(color: foreground),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LText(
              topic.summary,
              style: t.bodyMedium?.copyWith(color: foreground),
            ),
            if (topic.example != null) ...[
              const SizedBox(height: 8),
              _Example(topic.example!, foreground: foreground),
            ],
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              LText(
                'What to try',
                style: t.labelLarge?.copyWith(color: foreground),
              ),
              const SizedBox(height: 4),
              NumberedSteps(steps, color: foreground),
            ],
            if (detail != null && detail != topic.summary) ...[
              const SizedBox(height: 8),
              LText(detail!, style: t.bodySmall?.copyWith(color: foreground)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (i, a) in available.indexed)
                  i == 0
                      ? FilledButton(
                          onPressed: actions[a],
                          child: LText(cameraFixLabel(a)),
                        )
                      : OutlinedButton(
                          onPressed: actions[a],
                          child: LText(cameraFixLabel(a)),
                        ),
                TextButton.icon(
                  onPressed: () => openCameraHelp(context, topicId: topic.id),
                  icon: const Icon(Icons.help_outline),
                  label: const LText('More help'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "1. … 2. …" with each number in its own column, so wrapped lines align.
class NumberedSteps extends StatelessWidget {
  const NumberedSteps(this.steps, {super.key, this.color});
  final List<String> steps;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 24, child: Text('${i + 1}.', style: style)),
                Expanded(child: LText(step, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Looks like: 192.168.1.25" in a chip-like box.
class _Example extends StatelessWidget {
  const _Example(this.text, {this.foreground});
  final String text;
  final Color? foreground;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LText('Example:', style: t.bodyMedium?.copyWith(color: foreground)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: foreground ?? Theme.of(context).colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(text, style: t.titleSmall?.copyWith(color: foreground)),
        ),
      ],
    );
  }
}

/// The summary, example and steps of [topic], for expandable lists.
class CameraTopicBody extends StatelessWidget {
  const CameraTopicBody(this.topic, {super.key});
  final CameraHelpTopic topic;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LText(topic.summary),
      if (topic.example != null) ...[
        const SizedBox(height: 8),
        _Example(topic.example!),
      ],
      if (topic.id == CameraTopicId.findAddress) ...[
        const SizedBox(height: 12),
        const RouterListExample(),
      ],
      if (topic.steps.isNotEmpty) ...[
        const SizedBox(height: 8),
        NumberedSteps(topic.steps),
      ],
    ],
  );
}

class _TopicTile extends StatelessWidget {
  const _TopicTile(this.topic, {this.initiallyExpanded = false});
  final CameraHelpTopic topic;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: PageStorageKey('topic-${topic.id}'),
    initiallyExpanded: initiallyExpanded,
    leading: Icon(topic.icon),
    title: LText(topic.title),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    expandedCrossAxisAlignment: CrossAxisAlignment.start,
    children: [CameraTopicBody(topic)],
  );
}

/// "Something not working?" for one setup step: its likely problems, and a
/// way into the full help.
Future<void> showCameraStepHelp(
  BuildContext context, {
  required List<String> topicIds,
}) {
  final all = cameraHelpTopics(windows: _windows(context));
  final topics = [for (final id in topicIds) all.firstWhere((t) => t.id == id)];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: LText(
              'Something not working?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: LText('Tap a problem to see what to do.'),
          ),
          for (final t in topics)
            _TopicTile(t, initiallyExpanded: topics.length == 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheet);
                openCameraHelp(context);
              },
              icon: const Icon(Icons.menu_book_outlined),
              label: const LText('All camera help & FAQ'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> openCameraHelp(BuildContext context, {String? topicId}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CameraHelpPage(focusTopic: topicId)),
    );

/// Searchable troubleshooting and FAQ.
class CameraHelpPage extends StatefulWidget {
  const CameraHelpPage({super.key, this.focusTopic});

  /// Opened expanded and first, e.g. from an error's "More help".
  final String? focusTopic;

  @override
  State<CameraHelpPage> createState() => _CameraHelpPageState();
}

class _CameraHelpPageState extends State<CameraHelpPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Iterable<String> texts, [String keywords = '']) {
    if (_query.isEmpty) return true;
    final words = _query.toLowerCase().split(RegExp(r'\s+'));
    final hay = [...texts.map(tr), ...texts, keywords].join(' ').toLowerCase();
    return words.every(hay.contains);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final topics = cameraHelpTopics(windows: _windows(context));
    final focus = widget.focusTopic;
    final shown = [
      for (final topic in topics)
        if (_matches(topic.texts, topic.keywords)) topic,
    ];
    final faq = [
      for (final f in cameraFaq)
        if (_matches([f.question, f.answer])) f,
    ];
    final focused = _query.isEmpty && focus != null
        ? shown.where((x) => x.id == focus).firstOrNull
        : null;
    return Scaffold(
      appBar: AppBar(title: const LText('Camera help')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SearchBar(
                  controller: _search,
                  hintText: tr('Search help, e.g. password, sound, address'),
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: tr('Clear search'),
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
                  ],
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              if (focused != null) ...[
                _Header('Your problem'),
                _TopicTile(focused, initiallyExpanded: true),
              ],
              if (_query.isEmpty) ...[
                _Header('Quick start'),
                const _QuickStart(),
              ],
              for (final section in CameraHelpSection.values)
                if (shown.any((x) => x.section == section && x != focused)) ...[
                  _Header(cameraHelpSectionTitle(section)),
                  for (final topic in shown)
                    if (topic.section == section && topic != focused)
                      _TopicTile(
                        topic,
                        initiallyExpanded:
                            _query.isNotEmpty && shown.length <= 2,
                      ),
                ],
              if (faq.isNotEmpty) ...[
                _Header('Questions people ask'),
                for (final f in faq)
                  ExpansionTile(
                    leading: const Icon(Icons.question_answer_outlined),
                    title: LText(f.question),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [LText(f.answer)],
                  ),
              ],
              if (shown.isEmpty && faq.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off, size: 40),
                      const SizedBox(height: 12),
                      LText(
                        'No help matches that. Try a simpler word such as Wi-Fi, Bluetooth, sound or address.',
                        textAlign: TextAlign.center,
                        style: t.bodyLarge,
                      ),
                    ],
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: LText(
                  'Home network mode has been tested on the Nanit Pro camera with firmware 6.58.615. Other models or firmware may behave differently.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: LText(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// The whole setup on one card, for people who just want the gist.
class _QuickStart extends StatelessWidget {
  const _QuickStart();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CameraIllustration(CameraScene.network, height: 128),
            SizedBox(height: 12),
            NumberedSteps([
              'Connect this device to your home Wi-Fi, the same one the camera uses.',
              'Camera already works in the Nanit app? Choose Already on Wi-Fi and search.',
              'New, reset or moved camera? Choose Set up Wi-Fi, press the pairing button on its back, and follow the steps.',
              'Pick your camera, give it a name, and watch.',
            ]),
          ],
        ),
      ),
    ),
  );
}

/// A titled card of short lines, each with [icon].
class CameraInfoCard extends StatelessWidget {
  const CameraInfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.tonal = false,
  });
  final String title;
  final IconData icon;
  final List<String> items;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final fg = tonal ? s.onSecondaryContainer : s.onSurface;
    return Card(
      elevation: 0,
      color: tonal ? s.secondaryContainer : s.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(title, style: t.titleSmall?.copyWith(color: fg)),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: tonal ? fg : s.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LText(
                        item,
                        style: t.bodyMedium?.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
