import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../store.dart';
import 'theme.dart';
import '../localization.dart';
export '../localization.dart';

/// Gives every widget below access to [AppState] and rebuilds them on change.
/// [trigger] replaces the state as the rebuild signal (see `ActiveGate`,
/// which holds back rebuilds of hidden tabs).
class AppScope extends InheritedNotifier<Listenable> {
  const AppScope({
    super.key,
    required this.state,
    Listenable? trigger,
    required super.child,
  }) : super(notifier: trigger ?? state);

  final AppState state;

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.state;
}

// ------------------------------------------------------------------ formatting

final _hm = DateFormat.Hm();
DateFormat get _longDay => DateFormat('EEEE d MMMM');

String hm(DateTime t) => _hm.format(t);

String minutesOfDay(int m) => hm(DateTime(2000, 1, 1, m ~/ 60, m % 60));

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dayLabel(DateTime d) {
  final now = DateTime.now();
  if (sameDay(d, now)) return tr('Today');
  if (sameDay(d, DateTime(now.year, now.month, now.day - 1))) {
    return tr('Yesterday');
  }
  return _longDay.format(d);
}

String whenLabel(DateTime t) =>
    sameDay(t, DateTime.now()) ? hm(t) : '${dayLabel(t)} ${hm(t)}';

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.isNegative) return tr('in ${duration(-d)}');
  if (d.inMinutes < 1) return tr('just now');
  return tr('${duration(d)} ago');
}

String duration(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 48) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inDays} days';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return tr('Night shift');
  if (h < 12) return tr('Good morning');
  if (h < 18) return tr('Good afternoon');
  return tr('Good evening');
}

String sideLabel(FeedSide s) => switch (s) {
  FeedSide.left => tr('Left'),
  FeedSide.right => tr('Right'),
  FeedSide.both => tr('Both'),
  FeedSide.bottle => tr('Bottle'),
};

String nappyLabel(NappyKind k) => switch (k) {
  NappyKind.pee => tr('Pee'),
  NappyKind.poo => tr('Poo'),
  NappyKind.both => tr('Pee + Poo'),
};

String entryTitle(Entry e) => switch (e.type) {
  EntryType.feed => switch (e.side) {
    null => 'Feed',
    FeedSide.bottle => 'Bottle feed',
    final side => 'Feed · ${sideLabel(side)}',
  },
  EntryType.nappy => 'Nappy · ${nappyLabel(e.nappy ?? NappyKind.pee)}',
  EntryType.pill => e.medName ?? 'Pill',
  EntryType.sleep => e.endTime == null ? 'Sleeping' : 'Sleep',
  EntryType.pump => switch (e.side) {
    FeedSide.left || FeedSide.right => 'Pumping · ${sideLabel(e.side!)}',
    _ => 'Pumping',
  },
};

String? entryDetail(Entry e) {
  if (e.type == EntryType.sleep) {
    return e.endTime == null
        ? 'Since ${hm(e.time)}'
        : '${hm(e.time)} – ${hm(e.endTime!)} · ${duration(e.endTime!.difference(e.time))}';
  }
  final perSide =
      e.type == EntryType.pump && e.leftMl != null && e.rightMl != null;
  final parts = [
    if (e.durationMin != null) '${e.durationMin} min',
    if (perSide)
      '${e.leftMl} + ${e.rightMl} ml'
    else if (e.amountMl != null)
      '${e.amountMl} ml',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

// ------------------------------------------------------------------ icons

/// Draws an icon at a size and colour. Most are Material Symbols; there is no
/// poo symbol, so that one is painted.
typedef Glyph = Widget Function(double size, Color color);

Glyph _sym(IconData icon) =>
    (size, color) => Icon(icon, size: size, color: color, fill: 1);

abstract final class Glyphs {
  static final sleep = _sym(Symbols.bedtime_rounded);
  static final feed = _sym(Symbols.breastfeeding_rounded);
  static final bottle = _sym(Symbols.water_bottle_rounded);
  static final nappy = _sym(Symbols.baby_changing_station_rounded);
  static final pee = _sym(Symbols.water_drop_rounded);
  static final pump = _sym(Symbols.water_full_rounded);
  static final camera = _sym(Symbols.videocam_rounded);
  // Every build tracks habits, not pills (see habitWording).
  static final pill = _sym(Symbols.task_alt_rounded);
  static const pillIcon = Icons.task_alt_rounded;
  static const pillOutlinedIcon = Icons.task_alt_outlined;
  static final alarm = _sym(Symbols.alarm_rounded);
  static final left = _sym(Symbols.arrow_back_rounded);
  static final right = _sym(Symbols.arrow_forward_rounded);
  static final bothSides = _sym(Symbols.sync_alt_rounded);
  static final baby = _sym(Symbols.child_care_rounded);
  static final light = _sym(Symbols.light_mode_rounded);
  static final dark = _sym(Symbols.dark_mode_rounded);
  static final auto = _sym(Symbols.brightness_auto_rounded);
  static final wifi = _sym(Symbols.wifi_rounded);
  static final heart = _sym(Symbols.favorite_rounded);

  static Widget poo(double size, Color color) =>
      CustomPaint(size: Size.square(size), painter: _PooPainter(color));

  /// Pee and poo together: a drop and a poo, overlapping.
  static Widget peeAndPoo(double size, Color color) => SizedBox.square(
    dimension: size,
    child: Stack(
      children: [
        Positioned(left: 0, top: 0, child: pee(size * 0.62, Baby.pee)),
        Positioned(right: 0, bottom: 0, child: poo(size * 0.66, Baby.poo)),
      ],
    ),
  );
}

class _PooPainter extends CustomPainter {
  _PooPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..color = color;
    RRect tier(double l, double t, double r, double b, double radius) =>
        RRect.fromLTRBR(
          l * s,
          t * s,
          r * s,
          b * s,
          Radius.circular(radius * s),
        );
    canvas
      ..drawRRect(tier(0.10, 0.62, 0.90, 0.90, 0.14), paint)
      ..drawRRect(tier(0.20, 0.42, 0.80, 0.68, 0.13), paint)
      ..drawRRect(tier(0.32, 0.24, 0.68, 0.48, 0.12), paint)
      ..drawPath(
        Path()
          ..moveTo(0.42 * s, 0.30 * s)
          ..quadraticBezierTo(0.48 * s, 0.10 * s, 0.64 * s, 0.07 * s)
          ..quadraticBezierTo(0.60 * s, 0.20 * s, 0.62 * s, 0.30 * s)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(_PooPainter old) => old.color != color;
}

/// Icon and colours used for an entry everywhere in the app.
({Glyph glyph, Color soft, Color strong}) lookOf(Entry e) => switch (e.type) {
  EntryType.feed => (
    glyph: e.side == FeedSide.bottle ? Glyphs.bottle : Glyphs.feed,
    soft: Baby.feedSoft,
    strong: Baby.feed,
  ),
  EntryType.sleep => (
    glyph: Glyphs.sleep,
    soft: Baby.sleepSoft,
    strong: Baby.sleep,
  ),
  EntryType.nappy => nappyLook(e.nappy ?? NappyKind.pee),
  EntryType.pill => (
    glyph: Glyphs.pill,
    soft: Baby.pillSoft,
    strong: Baby.pill,
  ),
  EntryType.pump => (
    glyph: Glyphs.pump,
    soft: Baby.pumpSoft,
    strong: Baby.pump,
  ),
};

({Glyph glyph, Color soft, Color strong}) nappyLook(NappyKind k) => switch (k) {
  NappyKind.pee => (glyph: Glyphs.pee, soft: Baby.peeSoft, strong: Baby.pee),
  NappyKind.poo => (glyph: Glyphs.poo, soft: Baby.pooSoft, strong: Baby.poo),
  NappyKind.both => (
    glyph: Glyphs.peeAndPoo,
    soft: Baby.nappySoft,
    strong: Baby.nappy,
  ),
};

// ------------------------------------------------------------------ actions

void showUndo(BuildContext context, String message, VoidCallback onUndo) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: LText(message),
        action: SnackBarAction(label: tr('Undo'), onPressed: onUndo),
        duration: const Duration(seconds: 5),
        persist: false,
      ),
    );
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: LText(message)));
}

/// Picks a time; if the time would be in the future it is taken as yesterday,
/// so logging a 23:30 feed at 00:10 just works.
Future<DateTime?> pickTime(BuildContext context, DateTime initial) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (t == null) return null;
  final now = DateTime.now();
  // A time within the last day: today, or yesterday if that would be in the
  // future. Older dates (picked with the calendar) keep their day.
  if (now.difference(initial).inHours < 24) {
    var result = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    if (result.isAfter(now.add(const Duration(minutes: 5)))) {
      result = DateTime(now.year, now.month, now.day - 1, t.hour, t.minute);
    }
    return result;
  }
  return DateTime(initial.year, initial.month, initial.day, t.hour, t.minute);
}

// ------------------------------------------------------------------ widgets

/// Pull down to refresh: syncs with the paired phones (or runs [onRefresh])
/// and says how it went.
class PullToSync extends StatelessWidget {
  const PullToSync({super.key, required this.child, this.onRefresh});
  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: Baby.primary,
    backgroundColor: Baby.card,
    onRefresh: onRefresh ?? () => refreshAndSync(context),
    child: child,
  );
}

/// The same explicit sync action for touch gestures and the toolbar button.
Future<void> refreshAndSync(BuildContext context) async {
  final app = context.findAncestorWidgetOfExactType<AppScope>()!.state;
  await app.refreshIps();
  if (app.peers.isEmpty) {
    if (context.mounted) {
      showMessage(
        context,
        'Up to date. Pair the other phone in Settings to sync.',
      );
    }
    return;
  }
  final error = await app.syncAll(force: true);
  if (!context.mounted) return;
  final names = app.peers
      .map((p) => p.name.isEmpty ? p.host : p.name)
      .join(', ');
  showMessage(
    context,
    error == null ? 'Synced with $names' : 'Could not sync: $error',
  );
}

/// Mouse/keyboard alternative to pulling down a list on touch screens.
class RefreshSyncButton extends StatefulWidget {
  const RefreshSyncButton({super.key, this.onRefresh});
  final Future<void> Function()? onRefresh;

  @override
  State<RefreshSyncButton> createState() => _RefreshSyncButtonState();
}

class _RefreshSyncButtonState extends State<RefreshSyncButton> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await (widget.onRefresh?.call() ?? refreshAndSync(context));
    } catch (error) {
      if (mounted) showMessage(context, 'Could not sync: $error');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _refreshing || AppScope.of(context).syncing;
    return LIconButton(
      tooltip: busy ? 'Refreshing' : 'Refresh',
      onPressed: busy ? null : _refresh,
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded),
    );
  }
}

// ------------------------------------------------------------------ desktop

/// The desktop design layer: wide windows (Windows, macOS, Linux, or a big
/// tablet in landscape) get a sidebar, a top bar, compact bordered controls
/// and centred dialogs instead of bottom sheets. Phones keep their layout.
abstract final class Desktop {
  /// Window width from which the desktop layout is used.
  static const double breakpoint = 840;

  /// Window width from which the sidebar shows labels, not just icons.
  static const double wideSidebar = 1200;

  static bool of(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpoint;

  /// Shortcut label for the platform's main modifier, e.g. "Ctrl K".
  static String shortcut(String key) =>
      '${defaultTargetPlatform == TargetPlatform.macOS ? '⌘' : 'Ctrl'} $key';
}

/// Applies the compact desktop theme below it while the window is wide.
/// The widget tree keeps the same shape when the window is resized, so
/// nothing below loses its state.
class DesktopScope extends StatelessWidget {
  const DesktopScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: Desktop.of(context) ? babyTheme(desktop: true) : Theme.of(context),
    child: child,
  );
}

/// A keyboard key hint, e.g. "Ctrl K" or "Esc".
class Kbd extends StatelessWidget {
  const Kbd(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(Corners.xs),
    ),
    child: LText(
      label,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

/// Fluid content width with a comfortable limit on large desktop displays.
class PageWidth extends StatelessWidget {
  const PageWidth({super.key, required this.child, this.maxWidth = 1200});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// An icon on a tinted circle: the signature of each kind of entry, used in
/// lists, sheet headers and stat cards.
class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.glyph,
    required this.color,
    required this.iconColor,
    this.size = 40,
  });
  final Glyph glyph;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: glyph(size * 0.5, iconColor),
  );
}

/// Today's totals as small icons with numbers: feeds, wet and dirty nappies.
class Counts extends StatelessWidget {
  const Counts({
    super.key,
    required this.feeds,
    required this.pee,
    required this.poo,
    this.extra,
  });
  final int feeds;
  final int pee;
  final int poo;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget item(Glyph g, Color c, String n) => Padding(
      padding: const EdgeInsetsDirectional.only(start: Space.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          g(16, c),
          const SizedBox(width: Space.xs),
          LText(n, style: style),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(
          Glyphs.feed,
          Baby.feed,
          extra == null ? '$feeds' : '$feeds ($extra)',
        ),
        item(Glyphs.pee, Baby.pee, '$pee'),
        item(Glyphs.poo, Baby.poo, '$poo'),
      ],
    );
  }
}

/// A section heading above a card or list (Material list subheader).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.xs,
          Space.xl,
          Space.xs,
          Space.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: LText(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Scales its child down slightly while pressed, for tactile feedback on the
/// big buttons. Does nothing when animations are disabled.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child});
  final Widget child;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    // The soft style squashes further and springs back with a little wobble.
    final soft = context.nest.soft;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !still ? (soft ? 0.9 : 0.98) : 1,
        duration: still
            ? Duration.zero
            : soft && !_down
            ? const Duration(milliseconds: 650)
            : Motion.short,
        curve: soft && !_down ? Curves.elasticOut : Motion.enter,
        child: widget.child,
      ),
    );
  }
}

/// A quick-log button: a neutral tonal button with the kind's icon, a label
/// and a live hint ("Next: Right", "Due now"). At least 72dp tall, so it is
/// easy to hit one-handed in the dark. Only the icon carries the kind's
/// colour, unless the palette tints tiles, when [soft] fills it.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.glyph,
    required this.label,
    required this.hint,
    required this.soft,
    required this.strong,
    required this.onTap,
    this.vivid,
  });

  final Glyph glyph;
  final String label;
  final String hint;
  final Color soft;
  final Color strong;
  final VoidCallback onTap;

  /// The icon colour in the soft style's round button (defaults to [strong]).
  final Color? vivid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final desktop = Desktop.of(context);
    if (!desktop && context.nest.soft) return _round(context);
    return PressScale(
      child: Material(
        color: context.nest.tintedTiles ? soft : scheme.surfaceContainerHigh,
        borderRadius: Corners.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: desktop ? 64 : 72),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Space.lg,
                Space.md,
                Space.md,
                Space.md,
              ),
              child: Row(
                children: [
                  glyph(24, strong),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LText(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
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
                            hint,
                            key: ValueKey(hint),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
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
      ),
    );
  }

  /// The soft style: a pastel circle with a bright icon, label and hint
  /// below, sitting four or five to a row inside one card.
  Widget _round(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressScale(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 12, 2, 10),
            child: Column(
              children: [
                // Shrinks to fit on the narrowest phones.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.maxWidth.clamp(36.0, 60.0);
                    return Container(
                      width: size,
                      height: size,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: soft,
                        shape: BoxShape.circle,
                      ),
                      child: glyph(size * 0.5, vivid ?? strong),
                    );
                  },
                ),
                const SizedBox(height: Space.sm),
                LText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 15),
                ),
                AnimatedSwitcher(
                  duration: Motion.medium,
                  switchInCurve: Motion.enter,
                  child: LText(
                    hint,
                    key: ValueKey(hint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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

/// One logged entry as a row: icon, title/detail, time.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.showDay = false,
  });
  final Entry entry;
  final VoidCallback onTap;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final look = lookOf(entry);
    final elsewhere = app.loggedElsewhere(entry);
    final detail = [
      ?entryDetail(entry),
      if (elsewhere != null) 'by $elsewhere',
    ].join(' · ');
    final duplicate = app.isPossibleDuplicate(entry);
    final desktop = Desktop.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: desktop ? 56 : 72),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: desktop ? Space.sm : Space.md,
          ),
          child: Row(
            children: [
              if (context.nest.soft)
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: look.soft,
                    borderRadius: BorderRadius.circular(Corners.md),
                  ),
                  child: look.glyph(22, look.strong),
                )
              else
                SizedBox(
                  width: 24,
                  child: Center(child: look.glyph(24, look.strong)),
                ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      entryTitle(entry),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      LText(
                        detail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (duplicate)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.content_copy_rounded,
                              size: 14,
                              color: Baby.warn,
                            ),
                            const SizedBox(width: Space.xs),
                            Flexible(
                              child: LText(
                                'Possible duplicate from the other phone',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: Baby.warn,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              LText(
                showDay && !sameDay(entry.time, DateTime.now())
                    ? DateFormat('EEE d MMM, HH:mm').format(entry.time)
                    : hm(entry.time),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card holding a list of rows separated by inset dividers.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Title row at the top of every bottom sheet, with a close button.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.glyph,
    this.soft,
    this.strong,
  });
  final String title;
  final String? subtitle;
  final Glyph? glyph;
  final Color? soft;
  final Color? strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desktop = Desktop.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Row(
        children: [
          if (glyph != null) ...[
            // The soft style sets the icon on a pastel tile.
            if (context.nest.soft && soft != null)
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(Corners.lg),
                ),
                child: glyph!(26, strong ?? Baby.pill),
              )
            else
              glyph!(28, strong ?? Baby.pill),
            const SizedBox(width: Space.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: LText(
                    title,
                    style: desktop
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: LText(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          LIconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// Selectable option tile (feed side, appearance, schedule type...). The
/// selected one gets the accent's selected state (secondary container and a
/// 2dp primary outline); [color] and [glyphColor] are kept for callers.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
    this.glyph,
    this.glyphColor,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final Glyph? glyph;
  final Color? glyphColor;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final desktop = Desktop.of(context);
    final accent = scheme.primary;
    final radius = BorderRadius.circular(desktop ? Corners.md : Corners.lg);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        animationDuration: Motion.short,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? accent : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: glyph == null ? 48 : (desktop ? 64 : 76),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: desktop ? Space.sm : Space.md,
                horizontal: Space.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (glyph != null) ...[
                    glyph!(
                      24,
                      selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: Space.xs),
                  ],
                  LText(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                  // Reserves a line for the badge so tiles in a row line
                  // up; a minimum, not a fixed height, so large text is
                  // not clipped.
                  if (badge != null || glyph != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 16),
                      child: badge == null
                          ? null
                          : LText(
                              badge!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: accent,
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A "When" row: Now / an earlier time, plus a calendar button for the date.
class WhenField extends StatelessWidget {
  const WhenField({super.key, required this.value, required this.onChanged});

  /// Null means "now".
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final theme = Theme.of(context);
    return Row(
      children: [
        LText('When', style: theme.textTheme.titleSmall),
        const SizedBox(width: Space.lg),
        Expanded(
          child: Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              ChoiceChip(
                label: const LText('Now'),
                selected: v == null,
                onSelected: (_) => onChanged(null),
              ),
              ChoiceChip(
                avatar: Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                label: LText(v == null ? 'Earlier' : whenLabel(v)),
                selected: v != null,
                onSelected: (_) async {
                  final t = await pickTime(context, v ?? DateTime.now());
                  if (t != null) onChanged(t);
                },
              ),
            ],
          ),
        ),
        LIconButton(
          tooltip: 'Pick date',
          icon: const Icon(Icons.calendar_month_rounded),
          onPressed: () async {
            final base = v ?? DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: base,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now(),
            );
            if (d != null) {
              onChanged(
                DateTime(d.year, d.month, d.day, base.hour, base.minute),
              );
            }
          },
        ),
      ],
    );
  }
}

/// A centred empty, error or first-use state: icon, title, a line of help
/// and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    this.title,
    this.text,
    this.action,
  });
  final IconData icon;
  final String? title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: scheme.onSurfaceVariant),
          if (title != null) ...[
            const SizedBox(height: Space.lg),
            LText(
              title!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
          if (text != null) ...[
            SizedBox(height: title == null ? Space.lg : Space.xs),
            LText(
              text!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: Space.lg), action!],
        ],
      ),
    );
  }
}

/// Two buttons side by side with equal widths; stacked full width when large
/// text on a phone would squeeze or wrap their labels. Decided from the
/// window rather than a LayoutBuilder, so it also works inside
/// IntrinsicHeight rows (the desktop card grids).
class ButtonPair extends StatelessWidget {
  const ButtonPair({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final stack = MediaQuery.sizeOf(context).width / scale < 380;
    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const SizedBox(height: Space.sm),
            child,
          ],
        ],
      );
    }
    return Row(
      children: [
        for (final (i, child) in children.indexed) ...[
          if (i > 0) const SizedBox(width: Space.sm),
          Expanded(child: child),
        ],
      ],
    );
  }
}

/// The action row at the bottom of every sheet: a full-width [primary]
/// (usually Save), optionally beside a [secondary] of equal width (such as
/// Start timer) or after a [leading] text button (such as Delete).
///
/// Buttons inside are [Controls.sheetAction] tall: the one place where the
/// main action is bigger than the 48dp standard, because a sheet's Save is
/// the thumb target that is tapped most, often half asleep.
class SheetActions extends StatelessWidget {
  const SheetActions({
    super.key,
    required this.primary,
    this.secondary,
    this.leading,
  });
  final Widget primary;
  final Widget? secondary;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = WidgetStatePropertyAll(
      Size(64, Controls.sheetAction(Desktop.of(context))),
    );
    ButtonStyle tall(ButtonStyle? s) =>
        (s ?? const ButtonStyle()).copyWith(minimumSize: size);
    final Widget row;
    if (secondary != null) {
      row = ButtonPair(children: [secondary!, primary]);
    } else if (leading != null) {
      row = Row(
        children: [
          leading!,
          const SizedBox(width: Space.md),
          Expanded(child: primary),
        ],
      );
    } else {
      row = SizedBox(width: double.infinity, child: primary);
    }
    return FilledButtonTheme(
      data: FilledButtonThemeData(style: tall(theme.filledButtonTheme.style)),
      child: OutlinedButtonTheme(
        data: OutlinedButtonThemeData(
          style: tall(theme.outlinedButtonTheme.style),
        ),
        child: row,
      ),
    );
  }
}

/// Style for a FilledButton that confirms something destructive (Delete,
/// Discard, Forget): the error colour, so it never looks like a Save.
ButtonStyle dangerButtonStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: scheme.error,
    foregroundColor: scheme.onError,
  );
}

/// A text button for Delete in sheets and editors: error colour and a bin.
class DeleteTextButton extends StatelessWidget {
  const DeleteTextButton({
    super.key,
    required this.onPressed,
    this.label = 'Delete',
  });
  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.error,
    ),
    icon: const Icon(Icons.delete_outline_rounded),
    label: LText(label),
    onPressed: onPressed,
  );
}
