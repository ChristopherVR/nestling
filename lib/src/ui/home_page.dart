import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'baby_photo.dart';
import 'camera_page.dart';
import 'common.dart';
import 'growth_page.dart';
import 'hub_page.dart';
import 'motion_kit.dart';
import 'pills_page.dart';
import 'pump_page.dart';
import 'routines_page.dart';
import 'settings_page.dart';
import 'setup/motion.dart';
import 'sheets.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onSeeHistory,
    required this.onSeeRoutines,
  });
  final VoidCallback onSeeHistory;
  final VoidCallback onSeeRoutines;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _tick;
  Duration? _every;
  late bool _visible = !AppScope.of(context).startedHeadless;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onShow: () => setState(() => _visible = true),
      onHide: () {
        _visible = false;
        _setTick(null);
      },
    );
  }

  /// Keeps "x min ago" current: every 30 seconds while the app is on screen
  /// (the feed timer card ticks every second by itself).
  void _setTick(Duration? every) {
    if (every == _every) return;
    _tick?.cancel();
    _every = every;
    _tick = every == null
        ? null
        : Timer.periodic(every, (_) {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    _setTick(_visible ? const Duration(seconds: 30) : null);
    final today = app.entriesOn(DateTime.now());

    final nap = app.activeSleep;
    final soft = context.nest.soft;
    final quick = <Widget>[
      _Guided(
        on: app.tourPending && _guideStep(app) == _Guide.feed,
        child: ActionTile(
          glyph: app.bottleFirst ? Glyphs.bottle : Glyphs.feed,
          label: 'Feed',
          hint: app.suggestedSide != null
              ? 'Next: ${sideLabel(app.suggestedSide!)}'
              : 'Log a feed',
          soft: Baby.feedSoft,
          strong: Baby.feed,
          vivid: context.nest.feed.vivid,
          onTap: () => showSheet(context, const FeedSheet()),
        ),
      ),
      _Guided(
        on: app.tourPending && _guideStep(app) == _Guide.nappy,
        child: ActionTile(
          glyph: Glyphs.nappy,
          label: 'Nappy',
          hint: 'Pee or poo',
          soft: Baby.nappySoft,
          strong: Baby.nappy,
          vivid: context.nest.nappy.vivid,
          onTap: () => showSheet(context, const NappySheet()),
        ),
      ),
      ActionTile(
        glyph: Glyphs.sleep,
        label: nap == null ? 'Sleep' : 'End nap',
        hint: nap == null
            ? 'Start a nap'
            : duration(DateTime.now().difference(nap.time)),
        soft: Baby.sleepSoft,
        strong: Baby.sleep,
        vivid: context.nest.sleep.vivid,
        onTap: () => _napTap(context, app),
      ),
      ActionTile(
        glyph: Glyphs.pill,
        label: 'Pill',
        hint: _pillHint(app),
        soft: Baby.pillSoft,
        strong: Baby.pill,
        vivid: context.nest.pill.vivid,
        onTap: () => _pillTap(context, app),
      ),
      if (app.pumpOnToday) _pumpTile(context, app),
    ];
    // Today reads top to bottom as: what is happening now (timer, summary),
    // what to log next (the buttons), and what has been logged. Everything
    // else waits further down. Sections glide in one after another the first
    // time Today is shown; the timer card grows in and out of place.
    final overview = <Widget>[
      Collapse(
        visible: app.timerStart != null,
        child: Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: _TimerCard(app: app),
        ),
      ),
      const SizedBox(height: Space.sm),
      if (soft)
        Reveal(
          child: Pulse(
            value: app.lastFeed?.time,
            child: _SoftHero(app: app),
          ),
        )
      else
        Reveal(
          child: _SummaryTint(child: _StatusCard(app: app)),
        ),
      // A new parent's next step comes before the buttons it points at, so it
      // is never pushed off screen (e.g. by the night-light notice).
      Collapse(
        visible: app.tourPending,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.lg),
          child: _FirstLogGuide(app: app),
        ),
      ),
      const SizedBox(height: Space.lg),
      const PumpLiveCard(),
      if (soft)
        // One card holding a row of round buttons that pop in one by one.
        Reveal(
          delay: Reveal.pop(1),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.xs,
                vertical: Space.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, q) in quick.indexed)
                    Expanded(
                      child: Reveal(delay: Reveal.pop(i + 2), child: q),
                    ),
                ],
              ),
            ),
          ),
        )
      else
        Reveal(
          delay: Reveal.stagger(1),
          child: _QuickGrid(children: quick),
        ),
    ];
    final activity = <Widget>[
      SectionTitle(
        'Today',
        trailing: Counts(
          feeds: today.where((e) => e.type == EntryType.feed).length,
          pee: today
              .where(
                (e) => e.type == EntryType.nappy && e.nappy != NappyKind.poo,
              )
              .length,
          poo: today
              .where(
                (e) => e.type == EntryType.nappy && e.nappy != NappyKind.pee,
              )
              .length,
        ),
      ),
      // New entries glide into the list and the card grows to fit them.
      Reveal(
        delay: Reveal.stagger(2),
        child: AnimatedSize(
          duration: Motion.long,
          curve: Motion.standard,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: Motion.medium,
            child: today.isEmpty
                ? const Card(
                    key: ValueKey('empty'),
                    child: EmptyState(
                      icon: Icons.edit_note_rounded,
                      text: 'Nothing logged yet today.\nTap Feed, Nappy or Pill above to start.',
                    ),
                  )
                : ListCard(
                    key: const ValueKey('list'),
                    children: [
                      for (final (i, e) in today.take(8).indexed)
                        Reveal(
                          key: ValueKey(e.id),
                          delay: Reveal.stagger(i),
                          offset: 8,
                          flash: lookOf(e).soft,
                          child: EntryTile(
                            entry: e,
                            onTap: () => editEntry(context, e),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
      const SizedBox(height: Space.xs),
      Align(
        child: TextButton.icon(
          onPressed: widget.onSeeHistory,
          icon: const Icon(Icons.history_rounded),
          label: const LText('See all history'),
        ),
      ),
    ];
    final plan = <Widget>[
      if (app.cameraOnToday) ...[
        const SizedBox(height: Space.md),
        const CameraTodayCard(),
      ],
      ..._tips(context, app),
      _PlanSection(app: app, onSeeRoutines: widget.onSeeRoutines),
    ];
    if (Desktop.of(context)) {
      return _desktop(context, app, today, activity);
    }
    return LayoutBuilder(
      builder: (context, constraints) => PullToSync(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            Space.page,
            Space.xs,
            Space.page,
            Space.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (constraints.maxWidth >= 900)
              Row(
                key: const ValueKey('today-columns'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...overview, ...plan],
                    ),
                  ),
                  const SizedBox(width: Space.xl),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: activity,
                    ),
                  ),
                ],
              )
            else ...[
              ...overview,
              ...activity,
              ...plan,
            ],
          ],
        ),
      ),
    );
  }

  /// Desktop: status cards and quick actions in grids, then today's log
  /// beside the routines and reminder.
  Widget _desktop(
    BuildContext context,
    AppState app,
    List<Entry> today,
    List<Widget> activity,
  ) {
    final nap = app.activeSleep;
    final next = app.meds.isEmpty
        ? null
        : app.meds
              .map((m) => (m, app.nextDose(m)))
              .reduce((a, b) => a.$2.isBefore(b.$2) ? a : b);
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final columns = constraints.maxWidth >= 980 ? 4 : 2;
        Widget grid(List<Widget> cells) => Column(
          children: [
            for (var i = 0; i < cells.length; i += columns) ...[
              if (i > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + columns; j++) ...[
                      if (j > i) const SizedBox(width: 12),
                      Expanded(
                        child: j < cells.length
                            ? cells[j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
        final stats = [
          _LastFeedCard(app: app),
          _LastNappyCard(app: app),
          _StatCard(
            title: nap == null ? 'Sleep' : 'Sleeping',
            value: nap == null ? 'Awake' : _agoShort(nap.time),
            detail: nap == null
                ? 'Put down for a nap'
                : 'Since ${hm(nap.time)}',
            color: Baby.sleep,
            soft: Baby.sleepSoft,
            glyph: Glyphs.sleep,
            onTap: () => _napTap(context, app),
          ),
          _StatCard(
            title: 'Next pill',
            value: next == null
                ? 'None'
                : next.$2.isBefore(now)
                ? 'Due now'
                : hm(next.$2),
            detail: next == null ? 'Add pills' : next.$1.name,
            color: Baby.pill,
            soft: Baby.pillSoft,
            glyph: Glyphs.pill,
            onTap: () => _pillTap(context, app),
          ),
        ];
        final actions = [
          ActionTile(
            glyph: Glyphs.feed,
            label: 'Feed',
            hint: app.suggestedSide != null
                ? 'Next: ${sideLabel(app.suggestedSide!)}'
                : 'Log a feed',
            soft: Baby.feedSoft,
            strong: Baby.feed,
            onTap: () => showSheet(context, const FeedSheet()),
          ),
          ActionTile(
            glyph: Glyphs.nappy,
            label: 'Nappy',
            hint: 'Pee or poo',
            soft: Baby.nappySoft,
            strong: Baby.nappy,
            onTap: () => showSheet(context, const NappySheet()),
          ),
          ActionTile(
            glyph: Glyphs.pill,
            label: 'Pill',
            hint: _pillHint(app),
            soft: Baby.pillSoft,
            strong: Baby.pill,
            onTap: () => _pillTap(context, app),
          ),
          if (app.pumpOnToday) _pumpTile(context, app),
          if (app.cameraOnToday)
            ActionTile(
              glyph: Glyphs.camera,
              label: 'Camera',
              hint: 'Watch the baby',
              soft: Baby.primarySoft,
              strong: Baby.primary,
              onTap: () => openCamera(context),
            ),
          ActionTile(
            glyph: Glyphs.sleep,
            label: nap == null ? 'Start nap' : 'End nap',
            hint: nap == null
                ? 'Put down for a nap'
                : 'Sleeping · ${duration(now.difference(nap.time))}',
            soft: Baby.sleepSoft,
            strong: Baby.sleep,
            onTap: () => _napTap(context, app),
          ),
        ];
        final side = <Widget>[
          RoutinePreview(onOpen: widget.onSeeRoutines),
          const SizedBox(height: 12),
          _ReminderRow(app: app),
        ];
        return PullToSync(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              if (app.timerStart != null) ...[
                _TimerCard(app: app),
                const SizedBox(height: 16),
              ],
              grid(stats),
              const SizedBox(height: 12),
              grid(actions),
              if (wide)
                Row(
                  key: const ValueKey('today-columns'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: activity,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [const SectionTitle('Plan'), ...side],
                      ),
                    ),
                  ],
                )
              else ...[
                ...activity,
                const SizedBox(height: 8),
                ...side,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _pumpTile(BuildContext context, AppState app) {
    final last = app.entriesOn(DateTime.now(), EntryType.pump).firstOrNull;
    return ActionTile(
      glyph: Glyphs.pump,
      label: 'Pump',
      hint: last == null
          ? 'Pump or log'
          : duration(DateTime.now().difference(last.time)),
      soft: Baby.pumpSoft,
      strong: Baby.pump,
      vivid: context.nest.pump.vivid,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PumpPage()),
      ),
    );
  }

  String _pillHint(AppState app) {
    if (app.meds.isEmpty) return 'Add pills';
    final next = app.meds
        .map(app.nextDose)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return next.isBefore(DateTime.now()) ? 'Due now' : 'Next ${hm(next)}';
  }

  void _pillTap(BuildContext context, AppState app) => showSheet(
    context,
    app.meds.isEmpty ? const MedEditor() : const TakePillSheet(),
  );
}

/// Quick-log tiles two to a row; an odd last tile spans the full width.
class _QuickGrid extends StatelessWidget {
  const _QuickGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i += 2) ...[
        if (i > 0) const SizedBox(height: Space.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              if (i + 1 < children.length) ...[
                const SizedBox(width: Space.sm),
                Expanded(child: children[i + 1]),
              ],
            ],
          ),
        ),
      ],
    ],
  );
}

class _TimerCard extends StatefulWidget {
  const _TimerCard({required this.app});
  final AppState app;

  @override
  State<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<_TimerCard> {
  /// The card as last drawn while running. When the timer stops, the card
  /// shrinks away (see Collapse) still showing this, instead of going blank.
  Widget? _last;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    if (app.timerStart == null) return _last ?? const SizedBox.shrink();
    return _last = _card(context, app);
  }

  Widget _card(BuildContext context, AppState app) {
    final theme = Theme.of(context);
    final feed = context.nest.feed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.lg,
          Space.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Glyphs.feed(20, feed.color),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: LText(
                    app.timerPaused
                        ? 'A little burping break'
                        : 'Feeding since ${hm(app.timerStart!)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            Semantics(
              liveRegion: false,
              label: tr('Active feeding time'),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _TimerDigits(app: app),
              ),
            ),
            LText(
              app.timerPaused
                  ? 'Timer paused · take your time'
                  : 'Active feeding time',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                for (final s in const [
                  FeedSide.left,
                  FeedSide.right,
                  FeedSide.both,
                ]) ...[
                  Expanded(
                    child: OptionTile(
                      label: sideLabel(s),
                      selected: app.timerSide == s,
                      color: Baby.card,
                      onTap: () => app.switchTimerSide(s),
                    ),
                  ),
                  if (s != FeedSide.both) const SizedBox(width: Space.sm),
                ],
              ],
            ),
            const SizedBox(height: Space.md),
            ButtonPair(
              children: [
                OutlinedButton.icon(
                  onPressed: () => app.timerPaused
                      ? app.resumeFeedTimer()
                      : app.pauseFeedTimer(),
                  icon: Icon(
                    app.timerPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                  ),
                  label: LText(
                    app.timerPaused ? 'Resume feeding' : 'Pause to burp',
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.stop_rounded),
                  label: const LText('Stop & save'),
                  onPressed: () => app.stopFeedTimer(),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const LText('Every 5 minutes'),
              subtitle: const LText('Remind me during active feeding'),
              value: app.timerReminders,
              onChanged: app.setTimerReminders,
            ),
            ValueListenableBuilder<String?>(
              valueListenable: app.reminders.timerProblem,
              builder: (_, problem, _) => problem == null
                  ? const SizedBox.shrink()
                  : LText(
                      problem,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () async {
                  final discard = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const LText('Discard this feed?'),
                      content: const LText(
                        'The timer will stop without saving a feed.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const LText('Keep feeding'),
                        ),
                        FilledButton(
                          style: dangerButtonStyle(ctx),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const LText('Discard'),
                        ),
                      ],
                    ),
                  );
                  if (discard == true) app.stopFeedTimer(save: false);
                },
                child: const LText('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The running feed time. Only these digits rebuild every second, not the
/// whole card, and each changed digit rolls into place.
class _TimerDigits extends StatefulWidget {
  const _TimerDigits({required this.app});
  final AppState app;

  @override
  State<_TimerDigits> createState() => _TimerDigitsState();
}

class _TimerDigitsState extends State<_TimerDigits> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.app.feedElapsed();
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return RollingText(
      '$mm:$ss',
      style: Theme.of(context).textTheme.displayLarge
          ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// Routines and the feed reminder under one quiet heading. The reminder line
/// is always shown; the routine preview folds open and closed in place.
class _PlanSection extends StatefulWidget {
  const _PlanSection({required this.app, required this.onSeeRoutines});
  final AppState app;
  final VoidCallback onSeeRoutines;

  @override
  State<_PlanSection> createState() => _PlanSectionState();
}

class _PlanSectionState extends State<_PlanSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(
        'Plan',
        trailing: LIconButton(
          tooltip: _open ? 'Hide routines' : 'Show routines',
          onPressed: () => setState(() => _open = !_open),
          icon: AnimatedRotation(
            turns: _open ? 0.5 : 0,
            duration: Motion.medium,
            curve: Motion.standard,
            child: const Icon(Icons.expand_more_rounded),
          ),
        ),
      ),
      _ReminderRow(app: widget.app),
      Collapse(
        visible: _open,
        child: Padding(
          padding: const EdgeInsets.only(top: Space.md),
          child: RoutinePreview(onOpen: widget.onSeeRoutines),
        ),
      ),
    ],
  );
}

/// A status card on the desktop Today grid.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
    required this.soft,
    this.glyph,
    this.hero = false,
    this.onTap,
  });
  final String title;
  final String value;
  final String detail;
  final Color color;
  final Color soft;
  final Glyph? glyph;
  final bool hero;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (glyph != null) ...[
                    glyph!(18, color),
                    const SizedBox(width: Space.sm),
                  ],
                  Expanded(
                    child: LText(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.sm),
              LText(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (hero
                            ? theme.textTheme.headlineLarge
                            : theme.textTheme.headlineSmall)
                        ?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
              ),
              const SizedBox(height: Space.xs),
              LText(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _agoShort(DateTime t) {
  final d = DateTime.now().difference(t);
  return d.inMinutes < 1 ? 'Just now' : duration(d);
}

class _LastFeedCard extends StatelessWidget {
  const _LastFeedCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final last = app.lastFeed;
    return _StatCard(
      title: 'Since last feed',
      color: Baby.feed,
      soft: Baby.feedSoft,
      hero: true,
      glyph: last?.side == FeedSide.bottle ? Glyphs.bottle : Glyphs.feed,
      value: last == null ? 'Not yet' : _agoShort(last.time),
      detail: last == null
          ? 'No feeds logged'
          : [
              last.side == null ? 'Breast' : sideLabel(last.side!),
              hm(last.time),
              ?entryDetail(last),
            ].join(' · '),
      onTap: last == null ? null : () => editEntry(context, last),
    );
  }
}

class _LastNappyCard extends StatelessWidget {
  const _LastNappyCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final last = app.lastNappy;
    return _StatCard(
      title: 'Last nappy',
      color: Baby.nappy,
      soft: Baby.nappySoft,
      glyph: Glyphs.nappy,
      value: last == null ? 'Not yet' : _agoShort(last.time),
      detail: last == null
          ? 'No nappies logged'
          : '${nappyLabel(last.nappy ?? NappyKind.pee)} · ${hm(last.time)}',
      onTap: last == null ? null : () => editEntry(context, last),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final at = app.feedReminderAt;
    final String text;
    if (!app.feedReminderOn) {
      text = 'Feed reminder is off. Tap to set one';
    } else if (at == null) {
      text =
          'Feed reminder: ${feedIntervalLabel(app.feedReminderMinutes)} after each feed';
    } else if (at.isAfter(DateTime.now())) {
      text = 'Next feed reminder at ${hm(at)}';
    } else {
      text = 'Feed was due at ${hm(at)}';
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(
          app.feedReminderOn ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
          color: app.feedReminderOn ? Baby.feed : null,
        ),
        title: LText(text),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showFeedReminderSheet(context),
      ),
    );
  }
}

/// The top of Today, as plain text: who, then the time since the last feed
/// (the number that matters at 3 am), then the last nappy and sleep as
/// list rows. No card: the type hierarchy carries it.
/// Today's summary on a soft accent tint, when the palette asks for one.
class _SummaryTint extends StatelessWidget {
  const _SummaryTint({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tint = context.nest.summary;
    if (tint == null) return child;
    return Material(
      color: tint,
      borderRadius: Corners.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.md,
          Space.lg,
          Space.md,
          Space.sm,
        ),
        child: child,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final baby = app.activeBaby;
    final name = baby.name.trim();
    final last = app.lastFeed;
    final nappy = app.lastNappy;
    final nap = app.activeSleep;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.xs),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: tr('Edit profile'),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => editBabyProfile(context),
                  child: BabyPhoto(photo: baby.photo, size: 40),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText.raw(
                      name.isEmpty ? tr('Your baby') : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (baby.dateOfBirth != null)
                      LText(babyAge(baby), style: muted)
                    else
                      InkWell(
                        onTap: () => editBabyProfile(context),
                        child: LText(
                          'Add a birthday',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Semantics(
          button: last != null,
          child: InkWell(
            borderRadius: Corners.tile,
            onTap: last == null ? null : () => editEntry(context, last),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.xs,
                vertical: Space.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(
                    'Last feed',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    switchInCurve: Motion.enter,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [...previous, ?current],
                    ),
                    child: LText(
                      last == null ? 'No feeds yet' : ago(last.time),
                      key: ValueKey(last?.time),
                      style:
                          (last == null
                                  ? theme.textTheme.headlineSmall
                                  : theme.textTheme.displaySmall)
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  LText(
                    last == null
                        ? 'Tap Feed below when the next one starts'
                        : [
                            last.side == null
                                ? 'Breast'
                                : sideLabel(last.side!),
                            hm(last.time),
                            ?entryDetail(last),
                          ].join(' · '),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        _MiniStat(
          glyph: Glyphs.nappy,
          color: Baby.nappy,
          label: 'Last nappy',
          value: nappy == null
              ? 'None yet'
              : '${ago(nappy.time)} · ${nappyLabel(nappy.nappy ?? NappyKind.pee)}',
          onTap: nappy == null
              ? () => showSheet(context, const NappySheet())
              : () => editEntry(context, nappy),
        ),
        _MiniStat(
          glyph: Glyphs.sleep,
          color: Baby.sleep,
          label: nap == null ? 'Sleep' : 'Sleeping',
          value: nap == null
              ? 'Awake'
              : duration(DateTime.now().difference(nap.time)),
          onTap: () => _napTap(context, app),
        ),
      ],
    );
  }
}

void _napTap(BuildContext context, AppState app) {
  final nap = app.activeSleep;
  if (nap == null) {
    showSheet(context, const SleepSheet());
  } else {
    app.endSleep(nap);
  }
}

/// The soft style's Today hero: the baby and the time since the last feed
/// on a peach-to-blush wash, with the last nappy and sleep on two frosted
/// tiles. The time rolls when it changes.
class _SoftHero extends StatelessWidget {
  const _SoftHero({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final baby = app.activeBaby;
    final name = baby.name.trim();
    final last = app.lastFeed;
    final nappy = app.lastNappy;
    final nap = app.activeSleep;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Baby.hero,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >=
              320 * MediaQuery.textScalerOf(context).scale(1);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: tr('Edit profile'),
                    child: GestureDetector(
                      onTap: () => editBabyProfile(context),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Baby.card.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: BabyPhoto(photo: baby.photo, size: 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LText.raw(
                          name.isEmpty ? tr('Your baby') : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                        if (baby.dateOfBirth != null)
                          LText(babyAge(baby), style: muted)
                        else
                          GestureDetector(
                            onTap: () => editBabyProfile(context),
                            child: LText(
                              'Add a birthday',
                              style: muted?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // The greeting is a nicety: it gives way on narrow screens.
                  if (wide) ...[
                    const SizedBox(width: Space.sm),
                    LText(greeting(), style: muted),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Semantics(
                button: last != null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: last == null ? null : () => editEntry(context, last),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText('Since last feed', style: muted),
                      if (last == null)
                        LText(
                          'No feeds yet',
                          style: theme.textTheme.headlineMedium,
                        )
                      else
                        RollingText(
                          tr(_agoShort(last.time)),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontSize: 42,
                            height: 1.15,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      LText(
                        last == null
                            ? 'Tap Feed below when the next one starts'
                            : [
                                last.side == null
                                    ? 'Breast'
                                    : sideLabel(last.side!),
                                hm(last.time),
                                ?entryDetail(last),
                              ].join(' · '),
                        style: muted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _HeroStat(
                      glyph: Glyphs.nappy,
                      color: context.nest.nappy.vivid,
                      label: 'Last nappy',
                      value: nappy == null ? 'None yet' : ago(nappy.time),
                      onTap: nappy == null
                          ? () => showSheet(context, const NappySheet())
                          : () => editEntry(context, nappy),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroStat(
                      glyph: Glyphs.sleep,
                      color: context.nest.sleep.vivid,
                      label: nap == null ? 'Sleep' : 'Sleeping',
                      value: nap == null
                          ? 'Awake'
                          : duration(DateTime.now().difference(nap.time)),
                      onTap: () => _napTap(context, app),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A small frosted tile inside the soft hero.
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.glyph,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final Glyph glyph;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressScale(
      child: Material(
        color: Baby.card.withValues(alpha: Baby.dark ? 0.35 : 0.7),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: [
                glyph(22, color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: Motion.medium,
                        child: LText(
                          value,
                          key: ValueKey(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
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

/// A secondary figure under the last feed: icon, label, value.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.glyph,
    required this.color,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final Glyph glyph;
  final Color color;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: Corners.tile,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.xs,
            vertical: Space.sm,
          ),
          child: Row(
            children: [
              glyph(20, color),
              const SizedBox(width: Space.md),
              // Label left, value right; the value wraps below at large
              // text sizes instead of squeezing.
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: Space.md,
                  children: [
                    LText(label, style: theme.textTheme.bodyLarge),
                    LText(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The steps of the first-log guide, worked out from what has been logged.
enum _Guide { feed, nappy, done }

_Guide _guideStep(AppState app) => app.lastFeed == null
    ? _Guide.feed
    : app.lastNappy == null
    ? _Guide.nappy
    : _Guide.done;

/// Rings a quick-log button while the guide points at it. The ring breathes
/// a few times, then stays still.
class _Guided extends StatelessWidget {
  const _Guided({required this.on, required this.child});
  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    final primary = Theme.of(context).colorScheme.primary;
    return Loop(
      period: const Duration(milliseconds: 900),
      cycles: 6,
      reverse: true,
      rest: 1,
      builder: (context, t) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: Corners.card,
          border: Border.all(
            color: primary.withValues(alpha: 0.4 + 0.6 * t),
            width: 2,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// After setup: a short guide that follows real logging, first a feed, then
/// a nappy, then a word on where everything ends up.
class _FirstLogGuide extends StatelessWidget {
  const _FirstLogGuide({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final step = _guideStep(app);
    final (title, text) = switch (step) {
      _Guide.feed => (
        'Log your first feed',
        'Tap Feed when the next feed starts. Use the timer, or just pick a '
            'side and save.',
      ),
      _Guide.nappy => (
        'Nice! Now a nappy',
        'Tap Nappy at the next change: pee, poo or both, in one tap.',
      ),
      _Guide.done => (
        'That’s the basics',
        'Everything you log shows on Today and in History. Reminders and '
            'sharing are in Settings.',
      ),
    };
    final index = _Guide.values.indexOf(step);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.sm,
          Space.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              value: '${index + 1} / ${_Guide.values.length}',
              child: Row(
                children: [
                  for (var i = 0; i < _Guide.values.length; i++)
                    AnimatedContainer(
                      duration: Motion.medium,
                      margin: const EdgeInsetsDirectional.only(end: Space.xs),
                      width: i == index ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= index
                            ? scheme.primary
                            : scheme.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Space.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Space.xs),
                  LText(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: app.finishTour,
                child: LText(step == _Guide.done ? 'Got it' : 'Skip tour'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Things setup no longer asks up front, offered on Today once they matter.
/// (The night light announces itself with its own banner.)
List<Widget> _tips(BuildContext context, AppState app) {
  if (app.tourPending) return const [];
  return [
    if (app.peers.isEmpty && app.lastFeed != null && app.tipShown('share'))
      _TipCard(
        glyph: Glyphs.heart,
        title: 'Share with your partner',
        text: 'Both phones keep the same log over your home Wi‑Fi.',
        dismiss: 'Not now',
        action: 'Connect',
        onDismiss: () => app.dismissTip('share'),
        onAction: () {
          app.dismissTip('share');
          openAddDevice(context);
        },
      ),
  ].expand((tip) => [const SizedBox(height: Space.md), tip]).toList();
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.glyph,
    required this.title,
    required this.text,
    required this.dismiss,
    required this.action,
    required this.onDismiss,
    required this.onAction,
  });
  final Glyph glyph;
  final String title;
  final String text;
  final String dismiss;
  final String action;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.sm,
          Space.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: Space.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LText(title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: Space.xs),
                        LText(
                          text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(onPressed: onDismiss, child: LText(dismiss)),
                TextButton(onPressed: onAction, child: LText(action)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
