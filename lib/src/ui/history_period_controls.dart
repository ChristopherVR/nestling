import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../history_period.dart';
import 'common.dart';
import 'theme.dart';

/// Shared, explicit time filters for the log and chart screens.
class HistoryPeriodControls extends StatelessWidget {
  const HistoryPeriodControls({
    super.key,
    required this.period,
    required this.onChanged,
    this.allowAll = false,
    this.showHour = true,
  });

  final HistoryPeriod period;
  final ValueChanged<HistoryPeriod> onChanged;
  final bool allowAll;

  /// Whether the time-of-day dropdown is part of these controls.
  final bool showHour;

  @override
  Widget build(BuildContext context) {
    final today = HistoryPeriod.day(DateTime.now());
    final single = period.start != null && period.start == period.end;
    void changeDates(DateTime? start, DateTime? end) =>
        onChanged(HistoryPeriod(start: start, end: end, hour: period.hour));
    Future<void> pick(bool range) async {
      final first = DateTime(1970);
      if (range) {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: first,
          lastDate: today,
          initialDateRange: period.start == null
              ? null
              : DateTimeRange(start: period.start!, end: period.end!),
        );
        if (picked != null) changeDates(picked.start, picked.end);
      } else {
        final picked = await showDatePicker(
          context: context,
          firstDate: first,
          lastDate: today,
          initialDate: period.end ?? today,
        );
        if (picked != null) changeDates(picked, picked);
      }
    }

    final desktop = Desktop.of(context);
    final theme = Theme.of(context);
    final chips = <Widget>[
      if (allowAll)
        ChoiceChip(
          label: const LText('All time'),
          selected: period.start == null,
          onSelected: (_) => changeDates(null, null),
        ),
      for (final (label, days, offset) in [
        ('Today', 1, 0),
        ('Yesterday', 1, 1),
        ('7 days', 7, 0),
        ('14 days', 14, 0),
        ('30 days', 30, 0),
      ])
        Builder(
          builder: (_) {
            final end = DateTime(today.year, today.month, today.day - offset);
            final start = DateTime(end.year, end.month, end.day - days + 1);
            return ChoiceChip(
              label: LText(label),
              selected: period.start == start && period.end == end,
              onSelected: (_) => changeDates(start, end),
            );
          },
        ),
      ActionChip(
        avatar: const Icon(Icons.calendar_today_outlined),
        label: const LText('Choose day'),
        onPressed: () => pick(false),
      ),
      ActionChip(
        avatar: const Icon(Icons.date_range_rounded),
        label: const LText('Date range'),
        onPressed: () => pick(true),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One row that scrolls sideways on phones, wrapping on wide windows.
        if (desktop)
          Wrap(spacing: Space.sm, runSpacing: Space.sm, children: chips)
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final (i, chip) in chips.indexed) ...[
                  if (i > 0) const SizedBox(width: Space.sm),
                  chip,
                ],
              ],
            ),
          ),
        if (period.start != null)
          Row(
            children: [
              if (single)
                LIconButton(
                  tooltip: 'Previous day',
                  onPressed: () {
                    final d = period.start!;
                    final previous = DateTime(d.year, d.month, d.day - 1);
                    changeDates(previous, previous);
                  },
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              Expanded(
                child: Text(
                  single
                      ? DateFormat('EEE d MMM yyyy').format(period.start!)
                      : '${DateFormat('d MMM yyyy').format(period.start!)} – ${DateFormat('d MMM yyyy').format(period.end!)}',
                  textAlign: single ? TextAlign.center : TextAlign.start,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (single)
                LIconButton(
                  tooltip: 'Next day',
                  onPressed: period.end!.isBefore(today)
                      ? () {
                          final d = period.end!;
                          final next = DateTime(d.year, d.month, d.day + 1);
                          changeDates(next, next);
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
            ],
          ),
        if (showHour) ...[
          const SizedBox(height: Space.sm),
          HistoryHourPicker(period: period, onChanged: onChanged),
        ],
        const SizedBox(height: Space.sm),
      ],
    );
  }
}

/// "Time of day" dropdown: limits a period to one hour of each day.
class HistoryHourPicker extends StatelessWidget {
  const HistoryHourPicker({
    super.key,
    required this.period,
    required this.onChanged,
  });
  final HistoryPeriod period;
  final ValueChanged<HistoryPeriod> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    key: ValueKey(period.hour),
    initialValue: period.hour ?? -1,
    decoration: LInputDecoration(labelText: 'Time of day'),
    isExpanded: true,
    items: [
      const DropdownMenuItem(value: -1, child: LText('All hours')),
      for (var h = 0; h < 24; h++)
        DropdownMenuItem(
          value: h,
          child: Text(
            '${h.toString().padLeft(2, '0')}:00 – ${h.toString().padLeft(2, '0')}:59',
          ),
        ),
    ],
    onChanged: (h) => onChanged(
      HistoryPeriod(
        start: period.start,
        end: period.end,
        hour: h == -1 ? null : h,
      ),
    ),
  );
}
