import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../growth.dart';
import '../routines.dart';
import 'baby_photo.dart';
import 'common.dart';
import 'sheets.dart';
import 'theme.dart';

String _measurement(double value) => NumberFormat('0.##').format(value);

const _tabular = [FontFeature.tabularFigures()];

String babyAge(BabyProfile baby, [DateTime? at]) {
  final birth = baby.dateOfBirth;
  if (birth == null) return tr('Every little moment matters');
  final date = at ?? DateTime.now();
  final months = ageInMonths(birth, date);
  // Newborns are counted in days, then weeks, until about three months.
  if (months < 3) {
    final days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(DateTime(birth.year, birth.month, birth.day)).inDays;
    if (days <= 0) return tr('Born today');
    if (days == 1) return tr('1 day old');
    if (days < 14) return tr('$days days old');
    final weeks = days ~/ 7, rest = days % 7;
    if (weeks < 13) {
      return rest == 0
          ? tr('$weeks weeks old')
          : tr('$weeks weeks, $rest days old');
    }
  }
  return tr('$months months old');
}

void editBabyProfile(BuildContext context, [BabyProfile? baby]) => showSheet(
  context,
  BabyProfileEditor(initial: baby ?? AppScope.of(context).activeBaby),
);

class BabyProfileEditor extends StatefulWidget {
  const BabyProfileEditor({super.key, required this.initial});
  final BabyProfile initial;
  @override
  State<BabyProfileEditor> createState() => _BabyProfileEditorState();
}

class _BabyProfileEditorState extends State<BabyProfileEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.initial.name);
  late DateTime? birth = widget.initial.dateOfBirth;
  late String? photo = widget.initial.photo;
  bool picking = false;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(
          title: 'Baby’s profile',
          subtitle: 'A little introduction to your favourite person.',
        ),
        const SizedBox(height: Space.xl),
        Center(child: BabyPhoto(photo: photo, size: 108)),
        const SizedBox(height: Space.sm),
        TextButton.icon(
          onPressed: picking
              ? null
              : () async {
                  setState(() => picking = true);
                  final value = await pickBabyPhoto(context);
                  if (mounted) {
                    setState(() {
                      if (value != null) photo = value;
                      picking = false;
                    });
                  }
                },
          icon: const Icon(Icons.add_a_photo_outlined),
          label: LText(picking ? 'Opening photo…' : 'Choose profile photo'),
        ),
        if (photo != null)
          TextButton(
            onPressed: () => setState(() => photo = null),
            child: const LText('Remove photo'),
          ),
        LTextFormField(
          controller: name,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: const LInputDecoration(labelText: 'Baby’s name'),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Enter a name' : null,
        ),
        const SizedBox(height: Space.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cake_outlined),
          title: const LText('Date of birth'),
          subtitle: LText(
            birth == null
                ? 'Add a birthday to see age and monthly milestones'
                : DateFormat.yMMMMd().format(birth!),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final now = DateTime.now();
            final value = await showDatePicker(
              context: context,
              initialDate: birth != null && !birth!.isAfter(now) ? birth! : now,
              firstDate: DateTime(1900),
              lastDate: now,
            );
            if (value != null && mounted) setState(() => birth = value);
          },
        ),
        if (birth != null)
          TextButton(
            onPressed: () => setState(() => birth = null),
            child: const LText('Remove date of birth'),
          ),
        const SizedBox(height: Space.xl),
        FilledButton(
          onPressed: picking
              ? null
              : () {
                  if (!form.currentState!.validate()) return;
                  final app = AppScope.of(context);
                  if (birth != null &&
                      app
                          .growthEntriesFor(widget.initial.id)
                          .any((e) => e.date.isBefore(birth!))) {
                    showMessage(
                      context,
                      'The birthday must be on or before the first growth entry.',
                    );
                    return;
                  }
                  app.saveBabyProfile(
                    id: widget.initial.id,
                    name: name.text,
                    dateOfBirth: birth,
                    photo: photo,
                  );
                  Navigator.pop(context);
                },
          child: const LText('Save profile'),
        ),
      ],
    ),
  );
}

/// Title and a line of help at the top of the profile and moment sheets.
class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: LText(
            title,
            style: Desktop.of(context)
                ? theme.textTheme.titleLarge
                : theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: Space.xs),
        LText(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Newest entry (by date, then edit time) that has a value, plus the one
/// before it, so the summary can say how much changed.
(GrowthEntry, GrowthEntry?)? _latestTwo(
  List<GrowthEntry> entries,
  double? Function(GrowthEntry) value,
) {
  final list = entries.where((e) => value(e) != null).toList()
    ..sort((a, b) {
      final day = b.date.compareTo(a.date);
      return day != 0 ? day : b.updatedAt.compareTo(a.updatedAt);
    });
  if (list.isEmpty) return null;
  return (list.first, list.length > 1 ? list[1] : null);
}

class GrowthPage extends StatelessWidget {
  const GrowthPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final baby = app.activeBaby;
    final entries = app.growthEntries;
    final photos = entries
        .where((e) => e.photo != null)
        .toList()
        .reversed
        .toList();
    final weight = _latestTwo(entries, (e) => e.weightKg);
    final height = _latestTwo(entries, (e) => e.heightCm);
    final desktop = Desktop.of(context);
    void addMoment() => showSheet(context, GrowthEditor(baby: baby));
    return Scaffold(
      floatingActionButton: desktop
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add-moment',
              icon: const Icon(Icons.add_rounded),
              label: const LText('Add a moment'),
              onPressed: addMoment,
            ),
      body: PullToSync(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            Space.page,
            0,
            Space.page,
            desktop ? Space.xxl : 96,
          ),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Space.lg,
                  Space.lg,
                  Space.xs,
                  Space.lg,
                ),
                child: Row(
                  children: [
                    BabyPhoto(photo: baby.photo, size: 64),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LText.raw(
                            baby.name.isEmpty ? tr('Baby') : baby.name,
                            style: theme.textTheme.titleLarge,
                          ),
                          LText(
                            babyAge(baby),
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (baby.dateOfBirth != null)
                            LText.raw(
                              DateFormat.yMMMd().format(baby.dateOfBirth!),
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    LIconButton(
                      tooltip: 'Edit profile',
                      onPressed: () => editBabyProfile(context),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            ),
            if (entries.isEmpty) ...[
              const SizedBox(height: Space.lg),
              const _EmptyGrowth(),
            ] else ...[
              const SectionTitle('Latest measurements'),
              LayoutBuilder(
                builder: (context, c) {
                  final stacked =
                      c.maxWidth < 340 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.3;
                  final tiles = [
                    _Stat(
                      label: 'Weight',
                      unit: 'kg',
                      latest: weight,
                      value: (e) => e.weightKg,
                    ),
                    _Stat(
                      label: 'Height',
                      unit: 'cm',
                      latest: height,
                      value: (e) => e.heightCm,
                    ),
                  ];
                  return Card(
                    child: stacked
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [tiles[0], const Divider(), tiles[1]],
                          )
                        : IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: tiles[0]),
                                const VerticalDivider(width: 1),
                                Expanded(child: tiles[1]),
                              ],
                            ),
                          ),
                  );
                },
              ),
            ],
            if (_hasTrend(entries)) ...[
              const SectionTitle('Growth over time'),
              GrowthChart(entries: entries, weight: true),
              GrowthChart(entries: entries, weight: false),
            ],
            if (photos.length >= 2) ...[
              const SectionTitle('Look how you’ve grown'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Comparison(entry: photos.first, label: 'Then'),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: _Comparison(entry: photos.last, label: 'Now'),
                  ),
                ],
              ),
            ],
            if (entries.isNotEmpty) ...[
              const SectionTitle('Journal'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xs),
                child: LText(
                  'Newest first. Tap an entry to edit it.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
            for (var i = 0; i < entries.length; i++) ...[
              if (i == 0 ||
                  entries[i].date.month != entries[i - 1].date.month ||
                  entries[i].date.year != entries[i - 1].date.year)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.xs,
                    Space.lg,
                    Space.xs,
                    Space.sm,
                  ),
                  child: Semantics(
                    header: true,
                    child: LText.raw(
                      DateFormat.yMMMM().format(entries[i].date),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              _MomentCard(entry: entries[i], baby: baby),
              const SizedBox(height: Space.sm),
            ],
          ],
        ),
      ),
    );
  }

  /// A trend line needs at least two measurements of the same kind.
  static bool _hasTrend(List<GrowthEntry> entries) =>
      entries.where((e) => e.weightKg != null).length > 1 ||
      entries.where((e) => e.heightCm != null).length > 1;
}

class _EmptyGrowth extends StatelessWidget {
  const _EmptyGrowth();
  @override
  Widget build(BuildContext context) => const Card(
    child: EmptyState(
      icon: Icons.auto_stories_outlined,
      title: 'Track how your baby grows',
      text: 'Add a weight, height or photo now and then, for example at each clinic visit. You will see the latest numbers, a chart and a keepsake journal here.',
    ),
  );
}

/// One latest measurement, shown as a plain number with its date and the
/// change since the one before.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.unit,
    required this.latest,
    required this.value,
  });
  final String label;
  final String unit;
  final (GrowthEntry, GrowthEntry?)? latest;
  final double? Function(GrowthEntry) value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final l = latest;
    String? change;
    if (l != null && l.$2 != null) {
      final d = value(l.$1)! - value(l.$2!)!;
      change =
          '${d >= 0 ? '+' : '−'}${_measurement(d.abs())} $unit ${tr('since')} ${DateFormat.MMMd().format(l.$2!.date)}';
    }
    return Padding(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LText(label, style: muted),
          const SizedBox(height: Space.xs),
          if (l == null)
            LText('Not measured yet', style: theme.textTheme.bodyLarge)
          else ...[
            LText.raw(
              '${_measurement(value(l.$1)!)} $unit',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFeatures: _tabular,
              ),
            ),
            LText.raw(
              DateFormat.yMMMd().format(l.$1.date),
              style: theme.textTheme.bodySmall,
            ),
            if (change != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.xs),
                child: LText.raw(
                  change,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: _tabular,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.entry, required this.label});
  final GrowthEntry entry;
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (_, c) =>
              BabyPhoto(photo: entry.photo, size: c.maxWidth, square: true),
        ),
        const SizedBox(height: Space.sm),
        LText(label, style: theme.textTheme.titleSmall),
        LText(
          DateFormat.yMMMd().format(entry.date),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.entry, required this.baby});
  final GrowthEntry entry;
  final BabyProfile baby;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final measures = [
      if (entry.weightKg != null) '${_measurement(entry.weightKg!)} kg',
      if (entry.heightCm != null) '${_measurement(entry.heightCm!)} cm',
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            showSheet(context, GrowthEditor(baby: baby, initial: entry)),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.photo != null) ...[
                BabyPhoto(photo: entry.photo, size: 88, square: true),
                const SizedBox(width: Space.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText.raw(
                      baby.dateOfBirth == null
                          ? DateFormat.yMMMd().format(entry.date)
                          : babyAge(baby, entry.date),
                      style: theme.textTheme.titleMedium,
                    ),
                    if (baby.dateOfBirth != null)
                      LText.raw(
                        DateFormat.yMMMd().format(entry.date),
                        style: theme.textTheme.bodySmall,
                      ),
                    if (measures.isNotEmpty) ...[
                      const SizedBox(height: Space.sm),
                      Wrap(
                        spacing: Space.lg,
                        runSpacing: Space.xs,
                        children: [
                          for (final m in measures)
                            LText.raw(
                              m,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontFeatures: _tabular,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (entry.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.sm),
                        child: LText.raw(
                          entry.note,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class GrowthEditor extends StatefulWidget {
  const GrowthEditor({super.key, required this.baby, this.initial});
  final BabyProfile baby;
  final GrowthEntry? initial;
  @override
  State<GrowthEditor> createState() => _GrowthEditorState();
}

class _GrowthEditorState extends State<GrowthEditor> {
  final form = GlobalKey<FormState>();
  late final weight = TextEditingController(
    text: widget.initial?.weightKg?.toString() ?? '',
  );
  late final height = TextEditingController(
    text: widget.initial?.heightCm?.toString() ?? '',
  );
  late final note = TextEditingController(text: widget.initial?.note ?? '');
  late DateTime date =
      widget.initial?.date ?? DateUtils.dateOnly(DateTime.now());
  late String? photo = widget.initial?.photo;
  bool picking = false;
  @override
  void dispose() {
    weight.dispose();
    height.dispose();
    note.dispose();
    super.dispose();
  }

  double? number(String v) => double.tryParse(v.trim().replaceAll(',', '.'));
  String? validate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final n = number(value);
    return n == null || !validMeasurement(n)
        ? tr('Enter a number greater than zero')
        : null;
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(
          title: widget.initial == null ? 'A little moment' : 'Edit moment',
          subtitle: 'Pick the date, then add a measurement, a photo or a memory. Any one is enough.',
        ),
        const SizedBox(height: Space.lg),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_outlined),
          title: LText(DateFormat.yMMMMd().format(date)),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final first = widget.baby.dateOfBirth ?? DateTime(1900);
            final chosen = await showDatePicker(
              context: context,
              initialDate: date.isBefore(first) ? first : date,
              firstDate: first,
              lastDate: DateTime.now(),
            );
            if (chosen != null && mounted) setState(() => date = chosen);
          },
        ),
        const SizedBox(height: Space.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LTextFormField(
                controller: weight,
                validator: validate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const LInputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                ),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: LTextFormField(
                controller: height,
                validator: validate,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const LInputDecoration(
                  labelText: 'Height',
                  suffixText: 'cm',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        if (photo != null) ...[
          Center(child: BabyPhoto(photo: photo, size: 180, square: true)),
          const SizedBox(height: Space.md),
        ],
        OutlinedButton.icon(
          onPressed: picking
              ? null
              : () async {
                  setState(() => picking = true);
                  final value = await pickBabyPhoto(context);
                  if (mounted) {
                    setState(() {
                      if (value != null) photo = value;
                      picking = false;
                    });
                  }
                },
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: LText(
            picking
                ? 'Opening photo…'
                : photo == null
                ? 'Add a photo'
                : 'Change photo',
          ),
        ),
        if (photo != null)
          TextButton(
            onPressed: () => setState(() => photo = null),
            child: const LText('Remove photo'),
          ),
        const SizedBox(height: Space.lg),
        LTextFormField(
          controller: note,
          maxLines: 3,
          maxLength: 1000,
          decoration: const LInputDecoration(
            labelText: 'A memory (optional)',
            hintText: 'That first little smile…',
          ),
        ),
        const SizedBox(height: Space.lg),
        FilledButton(
          onPressed: picking
              ? null
              : () {
                  if (!form.currentState!.validate()) return;
                  final app = AppScope.of(context);
                  final entry = GrowthEntry(
                    id: widget.initial?.id,
                    babyId: widget.baby.id,
                    date: date,
                    weightKg: number(weight.text),
                    heightCm: number(height.text),
                    photo: photo,
                    note: note.text.trim(),
                  );
                  if (!app.saveGrowth(entry)) {
                    showMessage(
                      context,
                      'Add a photo, measurement or memory with a date on or after birth.',
                    );
                    return;
                  }
                  Navigator.pop(context);
                },
          child: const LText('Save moment'),
        ),
        if (widget.initial != null) ...[
          const SizedBox(height: Space.sm),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final app = AppScope.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const LText('Delete this moment?'),
                  content: const LText(
                    'This removes its photo and measurements from the journal.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const LText('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const LText('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              app.setGrowthDeleted(widget.initial!, true);
              Navigator.pop(context);
              showUndo(
                context,
                'Moment deleted',
                () => app.setGrowthDeleted(widget.initial!, false),
              );
            },
            child: const LText('Delete moment'),
          ),
        ],
      ],
    ),
  );
}

class GrowthChart extends StatelessWidget {
  const GrowthChart({super.key, required this.entries, required this.weight});
  final List<GrowthEntry> entries;
  final bool weight;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    double? value(GrowthEntry e) => weight ? e.weightKg : e.heightCm;
    final points = entries.where((e) => value(e) != null).toList()
      ..sort((a, b) {
        final day = a.date.compareTo(b.date);
        return day != 0 ? day : a.updatedAt.compareTo(b.updatedAt);
      });
    if (points.isEmpty) return const SizedBox.shrink();
    final unit = weight ? 'kg' : 'cm';
    // Growth is not a kind of entry, so its one series uses the accent.
    final color = scheme.primary;
    final change = value(points.last)! - value(points.first)!;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: Space.md),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with the latest value, like a fitness chart card.
            Row(
              children: [
                Expanded(
                  child: LText(
                    weight ? 'Weight' : 'Height',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${_measurement(value(points.last)!)} $unit',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
            if (points.length > 1) ...[
              LText.raw(
                '${_measurement(value(points.first)!)} → ${_measurement(value(points.last)!)} $unit (${change >= 0 ? '+' : '−'}${_measurement(change.abs())} ${tr('since first entry')})',
                style: muted,
              ),
              const SizedBox(height: Space.md),
              Semantics(
                label: points
                    .map(
                      (e) =>
                          '${DateFormat.yMMMd().format(e.date)}: ${value(e)} $unit',
                    )
                    .join(', '),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _GrowthPainter(
                      points: [
                        for (final e in points)
                          (e.date.millisecondsSinceEpoch.toDouble(), value(e)!),
                      ],
                      color: color,
                      grid: scheme.outlineVariant,
                      label: (theme.textTheme.labelSmall ?? const TextStyle())
                          .copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: _tabular,
                          ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 42),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    LText(
                      DateFormat.yMMMd().format(points.first.date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    LText(
                      DateFormat.yMMMd().format(points.last.date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              LText(
                'Add another measurement to see the changes.',
                style: muted,
              ),
          ],
        ),
      ),
    );
  }
}

class _GrowthPainter extends CustomPainter {
  _GrowthPainter({
    required this.points,
    required this.color,
    required this.grid,
    required this.label,
  });
  final List<(double, double)> points;
  final Color color;
  final Color grid;
  final TextStyle label;
  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.$2).toList()..sort();
    final minY = values.first;
    final rangeY = values.last - minY;
    final rangeX = points.last.$1 - points.first.$1;
    const left = 42.0;
    final width = size.width - left - 8;
    final height = size.height - 28;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = 8 + height * i / 2;
      canvas.drawLine(Offset(left, y), Offset(size.width - 8, y), gridPaint);
      final text = TextPainter(
        text: TextSpan(
          text: (minY + (rangeY == 0 ? 1 : rangeY) * (1 - i / 2))
              .toStringAsFixed(1),
          style: label,
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: left - 4);
      text.paint(canvas, Offset(0, y - text.height / 2));
    }
    final path = Path();
    final dots = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final x =
          left +
          (rangeX == 0 ? .5 : (points[i].$1 - points.first.$1) / rangeX) *
              width;
      final y =
          8 + height * (1 - (points[i].$2 - minY) / (rangeY == 0 ? 1 : rangeY));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      dots.add(Offset(x, y));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final dot = Paint()..color = color;
    for (final d in dots) {
      canvas.drawCircle(d, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_GrowthPainter old) =>
      old.points != points ||
      old.color != color ||
      old.grid != grid ||
      old.label != label;
}
