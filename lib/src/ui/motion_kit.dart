// Nestling's shared motion: one set of movements used everywhere, so the app
// feels calm and consistent. Every effect here is cheap (transforms and
// FadeTransition, no Opacity or relayout per frame) and is skipped when the
// phone asks for reduced motion. Durations and curves come from [Motion].
import 'dart:async';

import 'package:flutter/material.dart';

import '../store.dart';
import 'common.dart';
import 'theme.dart';

/// Whether the phone asks for less motion.
bool calmMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Whether the soft style (Blush) is on: its motion is livelier, with a
/// little scale and overshoot, where the default style only fades and glides.
bool playful(BuildContext context) =>
    Theme.of(context).extension<NestPalette>()?.soft ?? false;

/// A gentle overshoot for the soft style: settles past its mark and back.
const springy = Curves.easeOutBack;

// ------------------------------------------------------------------- pages

/// Page transition for every pushed page: the new page fades in while
/// gliding a short way from the side (Material's shared-axis pattern), and
/// the page underneath drifts back and dims a little. Short travel, no
/// overshoot: it reads as smooth rather than busy.
class NestPageTransitionsBuilder extends PageTransitionsBuilder {
  const NestPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.long;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (calmMotion(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final soft = playful(context);
    final enter = CurvedAnimation(
      parent: animation,
      curve: Motion.standard,
      reverseCurve: Motion.standard.flipped,
    );
    final leave = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Motion.standard,
      reverseCurve: Motion.standard.flipped,
    );
    return SlideTransition(
      position: Tween(
        begin: Offset.zero,
        end: Offset(-0.06 * dir, 0),
      ).animate(leave),
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.6).animate(leave),
        child: SlideTransition(
          position: Tween(
            begin: Offset(0.12 * dir, 0),
            end: Offset.zero,
          ).animate(enter),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.6, curve: Curves.easeOut),
            ),
            // The soft style also grows the page in from slightly smaller.
            child: soft
                ? ScaleTransition(
                    scale: Tween(begin: 0.94, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Motion.standard,
                        reverseCurve: Motion.standard.flipped,
                      ),
                    ),
                    child: child,
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- tabs

/// An [IndexedStack] whose newly shown child fades and rises into place
/// ("fade through"). Children keep their state, as in an IndexedStack.
class FadeIndexedStack extends StatefulWidget {
  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });
  final int index;
  final List<Widget> children;

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: 1,
  );
  late final _fade = CurvedAnimation(parent: _c, curve: Motion.enter);
  late final _rise = Tween(
    begin: const Offset(0, 0.015),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Motion.standard));
  late final _grow = Tween(
    begin: 0.96,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _c, curve: springy));
  static const _still = AlwaysStoppedAnimation(Offset.zero);
  static const _whole = AlwaysStoppedAnimation(1.0);

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !calmMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soft = playful(context);
    return IndexedStack(
      index: widget.index,
      children: [
        for (final (i, child) in widget.children.indexed)
          // Every child gets the same wrappers (only the animations differ),
          // so switching tabs never rebuilds a page from scratch.
          FadeTransition(
            opacity: i == widget.index ? _fade : kAlwaysCompleteAnimation,
            child: SlideTransition(
              position: i == widget.index ? _rise : _still,
              child: ScaleTransition(
                scale: i == widget.index && soft ? _grow : _whole,
                child: ActiveGate(
                  active: i == widget.index,
                  child: TickerMode(enabled: i == widget.index, child: child),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Keeps a hidden page from rebuilding on every app change: below it,
/// [AppScope] only notifies while [active], and catches up once when the page
/// is shown again. Saves rebuilding four hidden tabs on each change (e.g.
/// every second while the feed timer runs).
class ActiveGate extends StatefulWidget {
  const ActiveGate({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<ActiveGate> createState() => _ActiveGateState();
}

class _Relay extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _ActiveGateState extends State<ActiveGate> {
  final _relay = _Relay();
  AppState? _app;
  bool _missed = false;

  void _changed() {
    if (widget.active) {
      _relay.ping();
    } else {
      _missed = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (app != _app) {
      _app?.removeListener(_changed);
      _app = app..addListener(_changed);
    }
  }

  @override
  void didUpdateWidget(ActiveGate old) {
    super.didUpdateWidget(old);
    if (widget.active && _missed) {
      _missed = false;
      _relay.ping();
    }
  }

  @override
  void dispose() {
    _app?.removeListener(_changed);
    _relay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AppScope(state: _app!, trigger: _relay, child: widget.child);
}

// ----------------------------------------------------------------- reveals

/// Fades and rises [child] into place the first time it is built, after
/// [delay]. Used for staggered entrances (pass `Reveal.stagger(i)`) and for
/// new list rows: key a row by its id and only new rows animate.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 16,
    this.flash,
  });
  final Widget child;
  final Duration delay;

  /// A colour that washes over the child as it arrives and fades away, so a
  /// newly logged entry catches the eye (soft style only).
  final Color? flash;

  /// How far below its place the child starts, in logical pixels.
  final double offset;

  /// The delay for the [i]th item of a staggered list (capped so long lists
  /// do not keep the last items waiting).
  static Duration stagger(int i) => Duration(milliseconds: 45 * i.clamp(0, 8));

  /// The soft style's livelier stagger: each item pops in a beat later.
  static Duration pop(int i) => Duration(milliseconds: 70 * i.clamp(0, 8));

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.long);
  late final _fade = CurvedAnimation(parent: _c, curve: Motion.enter);
  late final _rise = CurvedAnimation(parent: _c, curve: Motion.standard);
  late final _pop = CurvedAnimation(parent: _c, curve: springy);
  Timer? _wait;
  bool _soft = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _soft = playful(context);
    if (_soft && _c.isDismissed) {
      _c.duration = const Duration(milliseconds: 560);
    }
    if (calmMotion(context)) {
      _wait?.cancel();
      _c.value = 1;
    } else if (_c.isDismissed && _wait == null) {
      if (widget.delay == Duration.zero) {
        _c.forward();
      } else {
        _wait = Timer(widget.delay, () {
          if (mounted) _c.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flash = _soft ? widget.flash : null;
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = _soft ? _pop.value : _rise.value;
          Widget out = Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset * (_soft ? 1.6 : 1)),
            child: _soft
                ? Transform.scale(scale: 0.92 + 0.08 * t, child: child)
                : child,
          );
          if (flash != null && _c.value < 1) {
            // Holds the colour, then lets it fade over the second half.
            final fade = ((1 - _c.value) * 2).clamp(0.0, 1.0);
            out = DecoratedBox(
              decoration: BoxDecoration(
                color: flash.withValues(alpha: flash.a * fade),
              ),
              child: out,
            );
          }
          return out;
        },
      ),
    );
  }
}

/// Gives [child] a quick, gentle bounce (grow and settle) each time [value]
/// changes, e.g. the hero when a new feed is logged. Soft style only.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.value, required this.child});
  final Object? value;
  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.035,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.035,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_c);

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && playful(context) && !calmMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Shows or hides [child] by smoothly growing or shrinking the space it takes
/// while fading it, instead of making the content below jump.
class Collapse extends StatelessWidget {
  const Collapse({super.key, required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Motion.long,
    reverseDuration: Motion.medium,
    switchInCurve: Motion.standard,
    switchOutCurve: Motion.standard,
    transitionBuilder: (child, animation) => SizeTransition(
      sizeFactor: animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: animation, child: child),
    ),
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [...previous, ?current],
    ),
    child: visible
        ? KeyedSubtree(key: const ValueKey(true), child: child)
        : const SizedBox(key: ValueKey(false), width: double.infinity),
  );
}

// -------------------------------------------------------------------- text

/// Text whose changed characters roll into place: each character that
/// changes slides up out of view while its new value slides in. Made for
/// counters and clocks (use tabular figures so widths stay put).
class RollingText extends StatelessWidget {
  const RollingText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(this.style);
    if (calmMotion(context)) return Text(text, style: style);
    // Shrinks to fit narrow phones and large text instead of overflowing.
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, ch) in text.characters.indexed)
              ClipRect(
                child: AnimatedSwitcher(
                  key: ValueKey(i),
                  duration: Motion.medium,
                  switchInCurve: Motion.standard,
                  switchOutCurve: Motion.standard,
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(ch);
                    return SlideTransition(
                      position: Tween(
                        begin: Offset(0, incoming ? 0.7 : -0.7),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Text(ch, key: ValueKey(ch), style: style),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
