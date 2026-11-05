import 'package:flutter/material.dart';

import '../distribution.dart';
import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'sheets.dart';
import 'theme.dart';

const _tabular = [FontFeature.tabularFigures()];

class PillsPage extends StatelessWidget {
  const PillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final desktop = Desktop.of(context);
    return Scaffold(
      // On desktop "Add pill" is in the top bar.
      floatingActionButton: desktop
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add_rounded),
              label: const LText('Add pill'),
              onPressed: () => showSheet(context, const MedEditor()),
            ),
      body: PullToSync(
        child: PageWidth(
          child: app.meds.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: Space.xxl),
                    EmptyState(
                      icon: Glyphs.pillOutlinedIcon,
                      title: 'No pills yet',
                      text:
                          'Add a pill, say how often you take it and when you start.\n'
                          'The dose times and alarms are worked out for you.',
                    ),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, box) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: desktop
                        ? const EdgeInsets.fromLTRB(
                            Space.pageWide,
                            Space.lg,
                            Space.pageWide,
                            Space.xxl,
                          )
                        : const EdgeInsets.fromLTRB(
                            Space.page,
                            0,
                            Space.page,
                            96,
                          ),
                    children: _columns(desktop && box.maxWidth >= 820 ? 2 : 1, [
                      for (final med in app.meds) _MedCard(med: med),
                    ]),
                  ),
                ),
        ),
      ),
    );
  }

  /// Lays [cards] out in rows of [count], 12 apart.
  static List<Widget> _columns(int count, List<Widget> cards) => [
    for (var i = 0; i < cards.length; i += count)
      Padding(
        padding: const EdgeInsets.only(bottom: Space.md),
        child: count == 1
            ? cards[i]
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = i; j < i + count; j++) ...[
                      if (j > i) const SizedBox(width: Space.md),
                      Expanded(
                        child: j < cards.length
                            ? cards[j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
      ),
  ];
}

/// One pill: name and schedule, today's doses and the two ways to log one.
class _MedCard extends StatelessWidget {
  const _MedCard({required this.med});
  final Medication med;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final reminds = app.remindHere(med);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsetsDirectional.only(
              start: Space.lg,
              end: Space.xs,
            ),
            leading: Glyphs.pill(24, Baby.pill),
            title: LText.raw(med.name, style: theme.textTheme.titleMedium),
            subtitle: LText(
              [
                if (med.dose.isNotEmpty) med.dose,
                med.scheduleLabel,
              ].join(' · '),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  reminds
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                  semanticLabel: tr(
                    reminds
                        ? 'Reminders on this device'
                        : 'Reminders off on this device',
                  ),
                ),
                LIconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showSheet(context, MedEditor(initial: med)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LText('Today', style: theme.textTheme.titleSmall),
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: [
                    for (final (at, dose) in app.todaySlots(med))
                      ActionChip(
                        // A dose not yet ticked off can be logged at its
                        // planned time.
                        onPressed: dose != null
                            ? () => editEntry(context, dose)
                            : () => showSheet(
                                context,
                                TakePillSheet(
                                  med: med,
                                  time: at.isBefore(now) ? at : null,
                                ),
                              ),
                        avatar: Icon(
                          dose != null
                              ? Icons.check_circle_rounded
                              : at.isBefore(now)
                              ? Icons.error_outline_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: dose != null
                              ? scheme.primary
                              : at.isBefore(now)
                              ? Baby.warn
                              : scheme.onSurfaceVariant,
                        ),
                        label: LText(
                          dose != null
                              ? '${hm(at)} · taken ${hm(dose.time)}'
                              : hm(at),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontFeatures: _tabular,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                ButtonPair(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule_rounded),
                      label: const LText('Other time'),
                      onPressed: () =>
                          showSheet(context, TakePillSheet(med: med)),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_rounded),
                      label: const LText('Taken now'),
                      onPressed: () => takeAndUndo(context, app, med),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void takeAndUndo(
  BuildContext context,
  AppState app,
  Medication med, {
  DateTime? time,
}) {
  final dose = app.takePill(med, time: time);
  showUndo(
    context,
    '${med.name} taken at ${whenLabel(dose.time)}',
    () => app.deleteEntry(dose),
  );
}

/// Mark a pill as taken: which pill (if there are several) and when.
class TakePillSheet extends StatefulWidget {
  const TakePillSheet({super.key, this.med, this.time});
  final Medication? med;
  final DateTime? time;

  @override
  State<TakePillSheet> createState() => _TakePillSheetState();
}

class _TakePillSheetState extends State<TakePillSheet> {
  String? medId;
  late DateTime? time = widget.time;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.meds.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }
    // Default to the pill that is due soonest.
    final byDue = [...app.meds]
      ..sort((a, b) => app.nextDose(a).compareTo(app.nextDose(b)));
    final med =
        app.meds.where((m) => m.id == (medId ?? widget.med?.id)).firstOrNull ??
        byDue.first;
    final next = app.nextDose(med);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: 'Take a pill',
          subtitle: next.isBefore(DateTime.now())
              ? '${med.name} was due at ${hm(next)}'
              : '${med.name} next due ${hm(next)}',
          glyph: Glyphs.pill,
        ),
        if (app.meds.length > 1) ...[
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final m in app.meds)
                ChoiceChip(
                  label: LText(m.name),
                  selected: m.id == med.id,
                  onSelected: (_) => setState(() => medId = m.id),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
        ],
        WhenField(value: time, onChanged: (t) => setState(() => time = t)),
        const SizedBox(height: Space.xl),
        SheetActions(
          primary: FilledButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: LText(
              time == null
                  ? 'Mark as taken now'
                  : 'Mark as taken at ${hm(time!)}',
            ),
            onPressed: () {
              Navigator.pop(context);
              takeAndUndo(context, app, med, time: time);
            },
          ),
        ),
      ],
    );
  }
}

class MedEditor extends StatefulWidget {
  const MedEditor({super.key, this.initial});
  final Medication? initial;

  @override
  State<MedEditor> createState() => _MedEditorState();
}

class _MedEditorState extends State<MedEditor> {
  late final name = TextEditingController(text: widget.initial?.name);
  late final dose = TextEditingController(text: widget.initial?.dose);
  late ScheduleMode mode = widget.initial?.mode ?? ScheduleMode.timesPerDay;
  late int count = widget.initial?.count ?? 2;
  late int start = widget.initial?.startMinutes ?? 8 * 60;

  /// Reminders on this phone; null until changed (then the saved setting applies).
  bool? remind;
  final Map<int, String> reminderStyles = {};

  @override
  void dispose() {
    name.dispose();
    dose.dispose();
    super.dispose();
  }

  Medication get _draft => Medication(
    id: widget.initial?.id,
    name: name.text.trim(),
    dose: dose.text.trim(),
    mode: mode,
    count: count,
    startMinutes: start,
    remind: widget.initial?.remind ?? true,
    createdBy: widget.initial?.createdBy,
  );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final perDay = mode == ScheduleMode.timesPerDay;
    final max = perDay ? 8 : 24;
    // Small group labels inside the sheet.
    final overline = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      letterSpacing: 0.8,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(
          title: widget.initial == null ? 'Add pill' : 'Edit pill',
          glyph: Glyphs.pill,
        ),
        TextField(
          controller: name,
          autofocus: widget.initial == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const LInputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Iron, Vitamins',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.md),
        TextField(
          controller: dose,
          decoration: const LInputDecoration(
            labelText: 'How many (optional)',
            hintText: 'e.g. 1 tablet',
          ),
        ),
        const SizedBox(height: Space.xl),
        LText('How often', style: theme.textTheme.titleSmall),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            for (final m in ScheduleMode.values) ...[
              Expanded(
                child: OptionTile(
                  label: m == ScheduleMode.timesPerDay
                      ? 'Times a day'
                      : 'Every X hours',
                  selected: mode == m,
                  color: scheme.secondaryContainer,
                  onTap: () => setState(() {
                    if (mode == m) return;
                    mode = m;
                    count = (24 / count).round().clamp(
                      1,
                      m == ScheduleMode.timesPerDay ? 8 : 24,
                    );
                  }),
                ),
              ),
              if (m == ScheduleMode.timesPerDay)
                const SizedBox(width: Space.sm),
            ],
          ],
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            IconButton.outlined(
              onPressed: count > 1 ? () => setState(() => count--) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: LText(
                perDay
                    ? '$count× a day'
                    : 'Every $count hour${count == 1 ? '' : 's'}',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFeatures: _tabular,
                ),
              ),
            ),
            IconButton.outlined(
              onPressed: count < max ? () => setState(() => count++) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.wb_sunny_outlined),
          title: const LText('First dose at'),
          trailing: LText(
            minutesOfDay(start),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFeatures: _tabular,
            ),
          ),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: start ~/ 60, minute: start % 60),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                child: child!,
              ),
            );
            if (t != null) setState(() => start = t.hour * 60 + t.minute);
          },
        ),
        const SizedBox(height: Space.sm),
        LText('DOSE TIMES', style: overline),
        const SizedBox(height: Space.xs),
        LText.raw(
          _draft.slots.map(minutesOfDay).join('  ·  '),
          style: theme.textTheme.bodyLarge?.copyWith(fontFeatures: _tabular),
        ),
        const SizedBox(height: Space.lg),
        LText('REMINDER BY DOSE TIME', style: overline),
        const SizedBox(height: Space.xs),
        for (final slot in _draft.slots)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: LText(
                    minutesOfDay(slot),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                SizedBox(
                  width: 190,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: () {
                      final style =
                          reminderStyles[slot] ??
                          app.pillReminderOverride(_draft, slot) ??
                          'default';
                      return Distribution.play && style != 'off'
                          ? 'default'
                          : style;
                    }(),
                    items: [
                      if (!Distribution.play) ...[
                        DropdownMenuItem(
                          value: 'default',
                          child: LText(
                            'Use default (${app.pillAlarm ? 'alarm' : 'notification'})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const DropdownMenuItem(
                          value: 'alarm',
                          child: LText('Alarm'),
                        ),
                        const DropdownMenuItem(
                          value: 'notification',
                          child: LText('Notification'),
                        ),
                      ] else
                        const DropdownMenuItem(
                          value: 'default',
                          child: LText('On'),
                        ),
                      const DropdownMenuItem(value: 'off', child: LText('Off')),
                    ],
                    onChanged: (value) => setState(
                      () => reminderStyles[slot] = value ?? 'default',
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (!perDay && 24 % count != 0)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: Baby.warn),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: LText(
                    'Every $count hours does not fit a day evenly, so the times restart each day at the first dose.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const LText('Remind me on this phone'),
          subtitle: const LText(
            'Reminders are set per dose time on this phone. The other phone has its own settings.',
          ),
          value:
              remind ??
              (widget.initial == null || app.remindHere(widget.initial!)),
          onChanged: (v) => setState(() => remind = v),
        ),
        const SizedBox(height: Space.sm),
        SheetActions(
          leading: widget.initial == null
              ? null
              : DeleteTextButton(
                  onPressed: () {
                    final med = widget.initial!;
                    app.deleteMed(med);
                    Navigator.pop(context);
                    showUndo(
                      context,
                      '${med.name} deleted',
                      () => app.saveMed(med.copyWith(deleted: false)),
                    );
                  },
                ),
          primary: FilledButton.icon(
            icon: const Icon(Icons.check_rounded),
            onPressed: name.text.trim().isEmpty
                ? null
                : () async {
                    if (!await okToOverwrite(context, app, widget.initial) ||
                        !context.mounted) {
                      return;
                    }
                    final saved = _draft;
                    app.saveMed(
                      saved,
                      remindHere:
                          remind ?? (widget.initial == null ? true : null),
                    );
                    app.setPillReminderOverrides(saved, reminderStyles);
                    Navigator.pop(context);
                  },
            label: const LText('Save pill'),
          ),
        ),
      ],
    );
  }
}
