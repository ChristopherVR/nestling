import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../history_period.dart';
import '../history_stats.dart';
import 'common.dart';
import 'history_period_controls.dart';
import 'theme.dart';

const _tabular = [FontFeature.tabularFigures()];

class HistoryCharts extends StatefulWidget {
  const HistoryCharts({super.key});

  @override
  State<HistoryCharts> createState() => _HistoryChartsState();
}

class _HistoryChartsState extends State<HistoryCharts> {
  HistoryPeriod period = HistoryPeriod.recent(DateTime.now(), 7);
  bool hourly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final stats = HistoryStats(
      AppScope.of(context).entries,
      now: DateTime.now(),
      days: 7,
      period: period,
    );
    final dates = stats.dates.map(DateFormat('d MMM').format).toList();
    final fullDates = stats.dates
        .map(DateFormat('EEE d MMM yyyy').format)
        .toList();
    final hourIndexes = [
      for (var h = 0; h < 24; h++)
        if (period.hour == null || period.hour == h) h,
    ];
    final hours = [
      for (final h in hourIndexes) '${h.toString().padLeft(2, '0')}:00',
    ];
    Widget chart(
      String title,
      List<num> daily,
      List<num>? byHour,
      Color color, {
      String unit = '',
    }) {
      final values = hourly ? [for (final h in hourIndexes) byHour![h]] : daily;
      return _BarChart(
        title: title,
        values: values,
        labels: hourly ? hours : dates,
        detailLabels: hourly
            ? [
                for (final h in hourIndexes)
                  '${h.toString().padLeft(2, '0')}:00 – ${h.toString().padLeft(2, '0')}:59',
              ]
            : fullDates,
        color: color,
        unit: unit,
        dayCount: stats.dates.length,
        hourly: hourly,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.md),
        LText(
          'Patterns over time: feeds, nappies, sleep',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Space.md),
        HistoryPeriodControls(
          period: period,
          onChanged: (value) => setState(() => period = value),
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: LText('Daily totals'),
              icon: Icon(Icons.calendar_view_week_rounded),
            ),
            ButtonSegment(
              value: true,
              label: LText('By hour'),
              icon: Icon(Icons.schedule_rounded),
            ),
          ],
          selected: {hourly},
          onSelectionChanged: (v) => setState(() => hourly = v.single),
        ),
        const SizedBox(height: Space.md),
        LText(
          hourly
              ? 'Each bar totals that hour across the selected dates. Tap a bar for details; swipe to see more.'
              : 'Each bar is one calendar day. Tap a bar for details; swipe to see more.',
          style: note,
        ),
        const SizedBox(height: Space.xs),
        LText(
          'Mixed nappies count as both wee and poo. Empty days count as zero; today is incomplete.',
          style: note,
        ),
        const SizedBox(height: Space.lg),
        chart(
          hourly ? 'Feeds by hour' : 'Feeds per day',
          stats.feeds,
          stats.feedByHour,
          Baby.feed,
        ),
        chart(
          hourly ? 'Wees by hour' : 'Wees per day',
          stats.pee,
          stats.peeByHour,
          Baby.pee,
        ),
        chart(
          hourly ? 'Poos by hour' : 'Poos per day',
          stats.poo,
          stats.pooByHour,
          Baby.poo,
        ),
        chart(
          hourly ? 'Sleep hours by hour' : 'Sleep hours per day',
          stats.sleepHours,
          stats.sleepByHour,
          Baby.sleep,
          unit: 'h',
        ),
        if (stats.hasPumping)
          chart(
            hourly ? 'Pumping by hour' : 'Pumping sessions per day',
            stats.pumps,
            stats.pumpByHour,
            Baby.pump,
          ),
        if (!hourly) ...[
          if (stats.hasPumping) ...[
            chart(
              'Pumped ml per day',
              stats.pumpMl,
              null,
              Baby.pump,
              unit: 'ml',
            ),
            chart(
              'Pumping minutes per day',
              stats.pumpMinutes,
              null,
              Baby.pump,
              unit: 'min',
            ),
          ],
          chart(
            'Feed minutes per day',
            stats.feedMinutes,
            null,
            Baby.feed,
            unit: 'min',
          ),
          chart(
            'Bottle ml per day',
            stats.bottleMl,
            null,
            Baby.feed,
            unit: 'ml',
          ),
          chart('Pills per day', stats.pills, null, Baby.pill),
        ],
        LText(
          'Sleep is split across the hours and days it covers. Ongoing sleep is included up to now. Feed duration and bottle volume include recorded values only.',
          style: note,
        ),
        if (period.hour == null) ...[
          const SectionTitle('Next-day estimate'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (stats.canEstimate) ...[
                    Wrap(
                      spacing: Space.xl,
                      runSpacing: Space.md,
                      children: [
                        for (final (label, values, unit) in [
                          ('Feeds', stats.feeds, ''),
                          ('Wees', stats.pee, ''),
                          ('Poos', stats.poo, ''),
                          ('Sleep', stats.sleepHours, ' h'),
                        ])
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LText(label, style: note),
                              Text(
                                '≈ ${stats.estimate(values).toStringAsFixed(1)}$unit',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontFeatures: _tabular,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.lg),
                    LText(
                      'Average of ${stats.completedIndexes.length} completed days in this range, including days with no logs. Today is excluded.',
                      style: note,
                    ),
                    const SizedBox(height: Space.xs),
                    LText(
                      'Estimates describe recorded patterns. Missing logs affect the result.',
                      style: note,
                    ),
                  ] else
                    LText(
                      'Select a range with logs on at least 3 completed days to see an estimate. Today is excluded.',
                      style: note,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BarChart extends StatefulWidget {
  const _BarChart({
    required this.title,
    required this.values,
    required this.labels,
    required this.color,
    required this.detailLabels,
    required this.dayCount,
    this.unit = '',
    this.hourly = false,
  });
  final String title;
  final List<num> values;
  final List<String> labels;
  final Color color;
  final List<String> detailLabels;
  final int dayCount;
  final String unit;
  final bool hourly;

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart> {
  int? selected;

  @override
  void didUpdateWidget(covariant _BarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    selected = null;
  }

  String amount(num value) =>
      '${widget.unit == 'h' ? value.toStringAsFixed(1) : value.toStringAsFixed(0)}${widget.unit.isEmpty ? '' : ' ${widget.unit}'}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final values = widget.values;
    final labels = widget.labels;
    final color = widget.color;
    final hourly = widget.hourly;
    final title = widget.title;
    final peak = values.fold<num>(0, math.max);
    final scale = math.max(1, peak.ceil());
    final total = values.fold<num>(0, (a, b) => a + b);
    final peaks = [
      for (var i = 0; i < values.length; i++)
        if (values[i] == peak) labels[i],
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: Space.md),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The series colour as a small key beside the title.
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    top: 6,
                    end: Space.sm,
                  ),
                  child: SizedBox.square(
                    dimension: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: LText(title, style: theme.textTheme.titleMedium),
                ),
                const SizedBox(width: Space.sm),
                Flexible(
                  child: LText(
                    '${tr('Total')}: ${amount(total)}',
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: _tabular,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            LText(
              '${tr('Average per day')}: ${(total / widget.dayCount).toStringAsFixed(1)}${widget.unit.isEmpty ? '' : ' ${widget.unit}'}',
              style: muted,
            ),
            const SizedBox(height: Space.xs),
            LText(
              peak == 0
                  ? 'No logs in this period'
                  : hourly
                  ? '${tr('Peak hour')}: ${peaks.take(3).join(', ')}${peaks.length > 3 ? '…' : ''} · ${amount(peak)}'
                  : '${tr('Highest day')}: ${peaks.take(3).join(', ')}${peaks.length > 3 ? '…' : ''} · ${amount(peak)}',
              style: muted,
            ),
            const SizedBox(height: Space.lg),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Text(
                  '${widget.detailLabels[selected!]} · ${amount(values[selected!])}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFeatures: _tabular,
                  ),
                ),
              ),
            LText(
              '${tr('Scale')}: 0 – ${amount(scale)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Space.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(
                  constraints.maxWidth,
                  values.length * 52.0,
                );
                return SizedBox(
                  height: 184,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: values.length,
                    itemExtent: width / values.length,
                    itemBuilder: (context, i) => InkWell(
                      onTap: () => setState(() => selected = i),
                      child: Semantics(
                        label:
                            '${tr(title)}, ${labels[i]}: ${amount(values[i])}',
                        selected: selected == i,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 18,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  amount(values[i]),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: selected == i
                                        ? scheme.onSurface
                                        : scheme.onSurfaceVariant,
                                    fontFeatures: _tabular,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: Space.xs),
                            // Bars stand on a hairline baseline.
                            DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: scheme.outlineVariant,
                                  ),
                                ),
                              ),
                              child: SizedBox(
                                height: 120,
                                width: double.infinity,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 20,
                                    height: 119 * values[i] / scale,
                                    decoration: BoxDecoration(
                                      color: color,
                                      border: selected == i
                                          ? Border.all(
                                              color: scheme.onSurface,
                                              width: 2,
                                            )
                                          : null,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(Corners.xs),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: Space.sm),
                            SizedBox(
                              height: 24,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    labels[i],
                                    maxLines: 1,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: selected == i
                                          ? scheme.onSurface
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
