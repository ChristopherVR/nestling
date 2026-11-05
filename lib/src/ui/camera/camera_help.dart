import 'package:flutter/material.dart';

import '../../localization.dart';
import '../common.dart' show EmptyState;
import 'camera_art.dart';
import 'camera_help_content.dart';
import 'camera_issues.dart';
import '../theme.dart';

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
    final s = context.colors;
    final t = Theme.of(context).textTheme;
    // A plain card: only the icon and title carry the error colour, so a
    // serious problem stands out without a red panel.
    final accent = topic.serious ? s.error : s.onSurfaceVariant;
    final steps = compact ? topic.steps.take(2).toList() : topic.steps;
    final available = [
      for (final a in topic.actions)
        if (actions[a] != null) a,
    ];
    return Card(
      key: ValueKey('issue-${issue.name}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.lg,
          Space.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(topic.icon, color: accent),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: LText(
                      topic.title,
                      style: t.titleMedium?.copyWith(
                        color: topic.serious ? s.error : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            LText(topic.summary, style: t.bodyMedium),
            if (topic.example != null) ...[
              const SizedBox(height: Space.sm),
              _Example(topic.example!),
            ],
            if (steps.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              LText('What to try', style: t.titleSmall),
              const SizedBox(height: Space.xs),
              NumberedSteps(steps),
            ],
            if (detail != null && detail != topic.summary) ...[
              const SizedBox(height: Space.sm),
              LText(
                detail!,
                style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: Space.sm),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.xs,
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
                  icon: const Icon(Icons.help_outline_rounded),
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
            padding: const EdgeInsets.symmetric(vertical: Space.xs / 2),
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
  const _Example(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LText('Example:', style: t.bodyMedium),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.xs,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.outlineVariant),
            borderRadius: BorderRadius.circular(Corners.sm),
          ),
          child: Text(
            text,
            style: t.titleSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
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
        const SizedBox(height: Space.sm),
        _Example(topic.example!),
      ],
      if (topic.id == CameraTopicId.findAddress) ...[
        const SizedBox(height: Space.md),
        const RouterListExample(),
      ],
      if (topic.steps.isNotEmpty) ...[
        const SizedBox(height: Space.sm),
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
    childrenPadding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
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
        padding: const EdgeInsets.only(bottom: Space.xl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.sm),
            child: LText(
              'Something not working?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.sm),
            child: LText('Tap a problem to see what to do.'),
          ),
          for (final t in topics)
            _TopicTile(t, initiallyExpanded: topics.length == 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, 0),
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
            padding: const EdgeInsets.only(bottom: Space.xxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.sm,
                  Space.lg,
                  Space.sm,
                ),
                child: SearchBar(
                  controller: _search,
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(
                    context.colors.surfaceContainerHigh,
                  ),
                  hintText: tr('Search help, e.g. password, sound, address'),
                  leading: const Icon(Icons.search_rounded),
                  trailing: [
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip: tr('Clear search'),
                        icon: const Icon(Icons.close_rounded),
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
                    childrenPadding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      0,
                      Space.lg,
                      Space.lg,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [LText(f.answer)],
                  ),
              ],
              if (shown.isEmpty && faq.isEmpty)
                const EmptyState(
                  icon: Icons.search_off_rounded,
                  text: 'No help matches that. Try a simpler word such as Wi-Fi, Bluetooth, sound or address.',
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.xl,
                  Space.lg,
                  0,
                ),
                child: LText(
                  'Home network mode has been tested on the Nanit Pro camera with firmware 6.58.615. Other models or firmware may behave differently.',
                  style: t.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
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
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.page + Space.xs,
        Space.xl,
        Space.page,
        Space.sm,
      ),
      child: LText(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// The whole setup on one card, for people who just want the gist.
class _QuickStart extends StatelessWidget {
  const _QuickStart();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: Space.lg),
    child: Card(
      child: Padding(
        padding: EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CameraIllustration(CameraScene.network, height: 128),
            SizedBox(height: Space.md),
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
  });
  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final s = context.colors;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(title, style: t.titleSmall),
            const SizedBox(height: Space.sm),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 20, color: s.onSurfaceVariant),
                    const SizedBox(width: Space.md),
                    Expanded(child: LText(item, style: t.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
