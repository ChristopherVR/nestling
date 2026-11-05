import 'dart:async';

import 'package:flutter/material.dart';

import '../routines.dart';
import 'baby_photo.dart';
import 'common.dart';
import 'growth_page.dart';
import 'hub_page.dart';
import 'language_picker.dart';
import 'nestling_mark.dart';
import 'setup/illustrations.dart';
import 'setup/motion.dart';
import 'theme.dart';

/// How the baby is fed, asked in setup. Bottle makes new feeds start on
/// Bottle; the others keep the usual left/right suggestion.
enum _Feeding { breast, bottle, both }

/// First-time setup: a welcome, then one short question per screen (name,
/// birthday, photo, feeding). Everything is optional and changeable later;
/// reminders, night light and sharing are offered on Today when they matter.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _pages = PageController();
  int _step = 0;
  late final _baby = TextEditingController(text: AppScope.of(context).babyName);
  // More babies added during setup; the first baby is [_baby].
  final _more = <TextEditingController>[];
  late DateTime? _birth = AppScope.of(context).activeBaby.dateOfBirth;
  late String? _photo = AppScope.of(context).activeBaby.photo;
  _Feeding? _feeding;
  static const _count = 6;

  @override
  void dispose() {
    _pages.dispose();
    _baby.dispose();
    for (final c in _more) {
      c.dispose();
    }
    super.dispose();
  }

  String get _name => _baby.text.trim();

  void _saveProfile() {
    final app = AppScope.of(context);
    final baby = app.activeBaby;
    if (_name == baby.name.trim() &&
        _birth == baby.dateOfBirth &&
        _photo == baby.photo) {
      return;
    }
    app.saveBabyProfile(name: _name, dateOfBirth: _birth, photo: _photo);
  }

  /// Extra babies are added once, when setup finishes. The first baby stays
  /// selected.
  void _saveMoreBabies() {
    final app = AppScope.of(context);
    final seen = {
      for (final b in app.babies) b.name.trim().toLowerCase(),
      _name.toLowerCase(),
    };
    for (final c in _more) {
      final name = c.text.trim();
      if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
      app.addBaby(name, select: false);
    }
  }

  void _finish() {
    final app = AppScope.of(context);
    _saveProfile();
    _saveMoreBabies();
    if (_feeding != null) app.setBottleFirst(_feeding == _Feeding.bottle);
    app.completeSetup(tour: true);
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    if (step >= _count) return _finish();
    _pages.animateToPage(
      step,
      duration: reducedMotion(context)
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _count - 1;
    return Scaffold(
      body: SafeArea(
        child: PageWidth(
          maxWidth: 560,
          child: Column(
            children: [
              if (_step > 0)
                _TopBar(
                  step: _step,
                  count: _count,
                  onBack: () => _go(_step - 1),
                  onSkip: last ? null : _finish,
                ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) {
                    if (_step == 1) _saveProfile();
                    setState(() => _step = i);
                  },
                  children: [
                    for (final (i, page) in [
                      _Welcome(onSkip: _finish),
                      _Names(
                        baby: _baby,
                        more: _more,
                        onAdd: () =>
                            setState(() => _more.add(TextEditingController())),
                        onRemove: (c) => setState(() {
                          _more.remove(c);
                          c.dispose();
                        }),
                        onDone: () => _go(2),
                      ),
                      _Birthday(
                        name: _name,
                        value: _birth,
                        onChanged: (d) => setState(() => _birth = d),
                      ),
                      _Photo(
                        name: _name,
                        photo: _photo,
                        onChanged: (p) => setState(() => _photo = p),
                      ),
                      _FeedingStep(
                        name: _name,
                        value: _feeding,
                        onChanged: (f) {
                          setState(() => _feeding = f);
                          // A single choice moves straight on, as if
                          // Continue had been tapped.
                          Timer(const Duration(milliseconds: 260), () {
                            if (mounted && _step == 4) _go(5);
                          });
                        },
                      ),
                      _Done(
                        name: _name,
                        birth: _birth,
                        photo: _photo,
                        more: _more
                            .where((c) => c.text.trim().isNotEmpty)
                            .length,
                      ),
                    ].indexed)
                      PageFx(controller: _pages, index: i, child: page),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.xl,
                  Space.sm,
                  Space.xl,
                  Space.lg,
                ),
                child: SheetActions(
                  primary: FilledButton(
                    onPressed: () => _go(_step + 1),
                    child: LText(
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      _step == 0
                          ? 'Get started'
                          : last
                          ? 'Start using Nestling'
                          : 'Continue',
                    ),
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

/// Back arrow, a row of step dots and Skip.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.step,
    required this.count,
    required this.onBack,
    required this.onSkip,
  });
  final int step;
  final int count;
  final VoidCallback onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    // The welcome screen has no dot; the questions and the finish do.
    final dots = count - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          LIconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: onBack,
          ),
          Expanded(
            child: Semantics(
              value: '$step / $dots',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= dots; i++)
                    AnimatedContainer(
                      duration: reducedMotion(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == step ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i <= step
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 84,
            child: onSkip == null
                ? null
                : TextButton(onPressed: onSkip, child: const LText('Skip')),
          ),
        ],
      ),
    );
  }
}

/// One question: big heading, a line of help and the answer below. Scrolls
/// on small screens; each part eases in one after another.
class _Question extends StatelessWidget {
  const _Question({
    required this.title,
    required this.text,
    required this.child,
  });
  final String title;
  final String text;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
    children: [
      Entrance(
        child: Semantics(
          header: true,
          child: LText(
            title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
      const SizedBox(height: Space.sm),
      Entrance(
        index: 1,
        child: LText(
          text,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
      const SizedBox(height: Space.xxl),
      Entrance(index: 2, child: child),
    ],
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSkip});
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: (constraints.maxHeight * 0.46).clamp(220.0, 400.0),
          margin: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
          child: Stack(
            children: [
              Center(
                child: FractionallySizedBox(
                  heightFactor: 0.72,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Loop(
                      period: const Duration(milliseconds: 2400),
                      cycles: 2,
                      reverse: true,
                      rest: 0.5,
                      builder: (context, t) => Transform.translate(
                        offset: Offset(0, 6 - 12 * smooth(t)),
                        child: const CustomPaint(
                          painter: NestlingMark(
                            layer: MarkLayer.bare,
                            sparkle: Color(0xFFD0D5DA),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: 4,
                end: 4,
                child: TextButton(
                  onPressed: onSkip,
                  child: const LText('Skip'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            Space.xl,
            Space.xl,
            Space.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Entrance(
                index: 1,
                child: Semantics(
                  header: true,
                  child: LText(
                    'Welcome to Nestling',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ),
              const SizedBox(height: Space.sm),
              Entrance(
                index: 2,
                child: LText(
                  'Feeds, nappies, sleep and growth in one calm place, '
                  'shared with everyone who helps.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: Space.xl),
              const Entrance(index: 3, child: LanguagePicker(showLabel: false)),
              const SizedBox(height: 4),
              Entrance(
                index: 4,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.devices_rounded),
                    label: const LText(
                      'Joining a partner? Connect their phone',
                    ),
                    onPressed: () => openAddDevice(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Names extends StatelessWidget {
  const _Names({
    required this.baby,
    required this.more,
    required this.onAdd,
    required this.onRemove,
    required this.onDone,
  });
  final TextEditingController baby;
  final List<TextEditingController> more;
  final VoidCallback onAdd;
  final ValueChanged<TextEditingController> onRemove;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final big = Theme.of(context).textTheme.titleLarge;
    return _Question(
      title: 'What’s your baby’s name?',
      text: 'A first name or a nickname is fine.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: baby,
            style: big,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => onDone(),
            decoration: const LInputDecoration(
              hintText: 'e.g. Emma',
              contentPadding: EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.lg + 2,
              ),
            ),
          ),
          for (final c in more)
            Padding(
              key: ObjectKey(c),
              padding: const EdgeInsets.only(top: 12),
              child: TextField(
                controller: c,
                style: big,
                textCapitalization: TextCapitalization.words,
                decoration: LInputDecoration(
                  labelText: 'Another baby',
                  hintText: 'e.g. Noah',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: Space.md + 2,
                  ),
                  suffixIcon: LIconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => onRemove(c),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const LText('Add another baby'),
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

String _babyOr(String name) => name.isEmpty ? tr('your baby') : name;

class _Birthday extends StatelessWidget {
  const _Birthday({
    required this.name,
    required this.value,
    required this.onChanged,
  });
  final String name;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final v = value;
    return _Question(
      title: 'When was ${_babyOr(name)} born?',
      text: 'Used to show their age in weeks and months.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: CalendarDatePicker(
              initialDate: v,
              currentDate: today,
              firstDate: DateTime(today.year - 3),
              lastDate: today,
              onDateChanged: onChanged,
            ),
          ),
          const SizedBox(height: Space.lg),
          AnimatedSwitcher(
            duration: Motion.medium,
            child: v == null
                ? const SizedBox(height: 24)
                : LText(
                    babyAge(BabyProfile(name: name, dateOfBirth: v), today),
                    key: ValueKey(v),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
          ),
        ],
      ),
    );
  }
}

/// The baby's photo (or placeholder) in a soft ring, with a camera badge.
class _PhotoRing extends StatelessWidget {
  const _PhotoRing({required this.photo, this.size = 168, this.badge = false});
  final String? photo;
  final double size;
  final bool badge;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Stack(
      children: [
        BabyPhoto(photo: photo, size: size),
        if (badge)
          PositionedDirectional(
            end: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 3,
                ),
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 22,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
      ],
    ),
  );
}

class _Photo extends StatelessWidget {
  const _Photo({
    required this.name,
    required this.photo,
    required this.onChanged,
  });
  final String name;
  final String? photo;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Future<void> pick() async {
      final p = await pickBabyPhoto(context);
      if (p != null) onChanged(p);
    }

    return _Question(
      title: 'Add a photo of ${_babyOr(name)}',
      text: 'It shows on Today. Photos stay on your own devices.',
      child: Column(
        children: [
          Semantics(
            button: true,
            label: tr('Choose a photo'),
            child: GestureDetector(
              onTap: pick,
              child: _PhotoRing(photo: photo, badge: true),
            ),
          ),
          const SizedBox(height: Space.xl),
          OutlinedButton(
            onPressed: pick,
            child: LText(photo == null ? 'Choose a photo' : 'Change photo'),
          ),
        ],
      ),
    );
  }
}

class _FeedingStep extends StatelessWidget {
  const _FeedingStep({
    required this.name,
    required this.value,
    required this.onChanged,
  });
  final String name;
  final _Feeding? value;
  final ValueChanged<_Feeding> onChanged;

  @override
  Widget build(BuildContext context) => _Question(
    title: 'How is ${_babyOr(name)} fed?',
    text: 'This only sets where a new feed starts. You can log any kind.',
    child: Column(
      children: [
        for (final (f, glyph, title, text) in [
          (
            _Feeding.breast,
            Glyphs.feed,
            'Breastfeeding',
            'Nestling suggests which side is next',
          ),
          (_Feeding.bottle, Glyphs.bottle, 'Bottle', 'Log how much they drank'),
          (
            _Feeding.both,
            Glyphs.bothSides,
            'A bit of both',
            'Breast and bottle, whatever works',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: _ChoiceCard(
              glyph: glyph,
              title: title,
              text: text,
              selected: value == f,
              onTap: () => onChanged(f),
            ),
          ),
      ],
    ),
  );
}

/// A large tappable answer: icon, title and a line of explanation.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.glyph,
    required this.title,
    required this.text,
    required this.selected,
    required this.onTap,
  });
  final Glyph glyph;
  final String title;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Baby.card,
        animationDuration: Motion.short,
        shape: RoundedRectangleBorder(
          borderRadius: Corners.card,
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: Corners.card,
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                glyph(
                  28,
                  selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      LText(
                        text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: Motion.short,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.name,
    required this.birth,
    required this.photo,
    required this.more,
  });
  final String name;
  final DateTime? birth;
  final String? photo;
  final int more;

  @override
  Widget build(BuildContext context) {
    final b = birth;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.xl,
        Space.xxl,
        Space.xl,
        Space.lg,
      ),
      children: [
        if (photo != null)
          Center(
            child: Entrance(child: _PhotoRing(photo: photo, size: 132)),
          )
        else if (name.isEmpty)
          const SuccessArt()
        else
          const Entrance(
            child: Center(
              child: SizedBox.square(
                dimension: 190,
                child: CustomPaint(
                  painter: NestlingMark(
                    layer: MarkLayer.bare,
                    sparkle: Color(0xFFD0D5DA),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        Entrance(
          index: 1,
          child: LText(
            name.isEmpty ? 'You are all set!' : '$name’s nest is ready',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        if (b != null) ...[
          const SizedBox(height: 6),
          Entrance(
            index: 2,
            child: LText(
              babyAge(BabyProfile(name: name, dateOfBirth: b)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Entrance(
          index: 3,
          child: LText(
            more > 0
                ? 'Switch between babies at the top of Today.'
                : 'Next, we’ll show you how to log the first feed. '
                      'Reminders, sharing and themes are in Settings '
                      'whenever you want them.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
