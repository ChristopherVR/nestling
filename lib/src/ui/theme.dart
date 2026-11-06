// Nestling's design tokens and Material 3 theme. This file is the single
// source of colour, type, shape, spacing and motion; see
// docs/design-system.md for the reasoning behind each value.
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import 'motion_kit.dart';

// ------------------------------------------------------------------- colour

/// The one accent: a muted slate-teal. Used for primary actions and selected
/// states only; everything else is neutral.
const nestAccent = Color(0xFF2F6F73);

/// Which palette is active: the normal light theme, the night light (a
/// darker light theme used from 6 pm to 6 am) or dark mode.
enum NestMode { light, dim, dark }

/// Colour roles for one kind of entry. Kinds are small accents only (an
/// icon tint, a chart series, a thin indicator), never a filled area.
///
/// All kinds share one tone per mode, so they sit at the same lightness and
/// none shouts louder than another; contrast is guaranteed by tone:
/// * [color] icons, chart series and short labels: light T45, night light
///   T34, dark T75. At least 4.5:1 on every surface of its mode.
/// * [onColor] text on a filled [color] area (rarely needed).
/// * [container] an almost-neutral tint, for the rare small marker.
/// * [onContainer] text on [container].
@immutable
class KindColors {
  const KindColors({
    required this.color,
    required this.onColor,
    required this.container,
    required this.onContainer,
  });
  final Color color;
  final Color onColor;
  final Color container;
  final Color onContainer;

  static KindColors _of(double hue, double chroma, NestMode mode) {
    final p = TonalPalette.of(hue, chroma);
    final soft = TonalPalette.of(hue, 6);
    return switch (mode) {
      NestMode.light => KindColors(
        color: Color(p.get(45)),
        onColor: const Color(0xFFFFFFFF),
        container: Color(soft.get(94)),
        onContainer: Color(p.get(20)),
      ),
      NestMode.dim => KindColors(
        color: Color(p.get(34)),
        onColor: const Color(0xFFFFFFFF),
        container: Color(soft.get(86)),
        onContainer: Color(p.get(15)),
      ),
      NestMode.dark => KindColors(
        color: Color(p.get(75)),
        onColor: Color(p.get(15)),
        container: Color(soft.get(25)),
        onContainer: Color(p.get(90)),
      ),
    };
  }
}

/// HCT hue and chroma of each kind. Hues are spread around the wheel (and
/// away from red/pink, which is reserved for errors); chroma is kept low so
/// they read as calm, desaturated accents. The icon always carries the
/// meaning too, so colour is never the only cue.
abstract final class _Kinds {
  static const feed = (250.0, 26.0); // calm blue
  static const pump = (215.0, 22.0); // cyan-blue, next to feed
  static const sleep = (290.0, 24.0); // slate violet
  static const nappy = (150.0, 22.0); // sage
  static const pee = (100.0, 26.0); // mustard
  static const poo = (55.0, 16.0); // brown
  static const pill = (75.0, 26.0); // ochre, like a pill bottle
  static const warn = (80.0, 40.0); // amber (status, not a kind)
  static const success = (150.0, 26.0);
}

/// The palettes Nestling can be drawn in. [current] ships; the others are
/// candidates under review, built from a [_Spec] each so that switching to
/// one is a one-line change to [NestPalette.shipped].
enum NestVariant {
  current('Slate', 'Calm neutral grey with one muted slate-teal accent'),
  tide('Tide', 'Fresh aqua on warm off-white, like a clear morning'),
  marigold('Marigold', 'Sunny marigold on soft cream, warm without pink'),
  sky('Sky', 'Soft sky blue with a mint companion, airy and light'),
  blush('Blush', 'Warm rose and peach, like the pump app');

  const NestVariant(this.label, this.mood);
  final String label;
  final String mood;
}

/// The recipe for a candidate palette: HCT hues and chromas, from which
/// every role is derived at fixed tones (so contrast holds by construction),
/// plus where the candidate allows a little colour.
class _Spec {
  const _Spec({
    required this.accent,
    required this.secondary,
    required this.neutral,
    required this.darkNeutral,
    required this.kinds,
    this.containerChroma = 32,
    this.containerTone = 90,
    this.tileChroma,
    this.summaryChroma,
    this.sunnyButtons = false,
  });

  /// (hue, chroma) of the primary accent.
  final (double, double) accent;

  /// (hue, chroma) of the secondary role: selected chips, nav indicator.
  final (double, double) secondary;

  /// (hue, chroma) of the light surfaces: a faint warm tint, not cold grey.
  final (double, double) neutral;

  /// (hue, chroma) of the dark surfaces. Kept lower than [neutral], since a
  /// warm tint at low tone reads as brown.
  final (double, double) darkNeutral;

  /// (hue, chroma) per kind, in [NestPalette.kinds] order.
  final Map<String, (double, double)> kinds;

  /// Chroma of primaryContainer (FAB, selected tiles).
  final double containerChroma;

  /// Light-theme tone of primaryContainer. Lower than 90 only with
  /// [sunnyButtons], where it fills the main buttons.
  final double containerTone;

  /// Chroma of each kind's container. When set, quick-log tiles are filled
  /// with it; otherwise tiles stay a neutral tonal surface.
  final double? tileChroma;

  /// Chroma of the tint behind Today's summary, or null for no tint.
  final double? summaryChroma;

  /// Filled buttons use the bright primaryContainer with dark text instead
  /// of a dark primary with white text. For yellow accents, whose AA tone
  /// would otherwise be brown.
  final bool sunnyButtons;
}

const _specs = <NestVariant, _Spec>{
  // Fresh aqua; each quick-log tile carries a whisper of its kind's colour.
  NestVariant.tide: _Spec(
    accent: (192, 44),
    secondary: (192, 18),
    neutral: (100, 3),
    darkNeutral: (200, 3),
    containerChroma: 28,
    tileChroma: 9,
    kinds: {
      'feed': (245, 38),
      'sleep': (292, 34),
      'nappy': (150, 36),
      'pee': (95, 40),
      'poo': (65, 22),
      'pill': (70, 40),
      'pump': (215, 32),
      'warn': (78, 40),
      'success': (145, 34),
    },
  ),
  // Marigold on cream; the cheer is concentrated in sunny buttons and a
  // butter-yellow summary, while tiles stay a calm cream.
  NestVariant.marigold: _Spec(
    accent: (78, 52),
    secondary: (88, 40),
    neutral: (92, 4),
    darkNeutral: (85, 2.5),
    containerChroma: 64,
    containerTone: 83,
    summaryChroma: 22,
    sunnyButtons: true,
    kinds: {
      'feed': (232, 36),
      'sleep': (275, 34),
      'nappy': (140, 36),
      'pee': (100, 40),
      'poo': (65, 24),
      'pill': (82, 40),
      'pump': (200, 30),
      'warn': (75, 40),
      'success': (140, 34),
    },
  ),
  // Sky blue with mint: a light sky summary, mint selection, tinted tiles.
  NestVariant.sky: _Spec(
    accent: (250, 40),
    secondary: (165, 26),
    neutral: (105, 1.5),
    darkNeutral: (250, 4),
    containerChroma: 24,
    tileChroma: 6,
    summaryChroma: 10,
    kinds: {
      'feed': (238, 36),
      'sleep': (300, 32),
      'nappy': (165, 34),
      'pee': (95, 40),
      'poo': (65, 22),
      'pill': (80, 40),
      'pump': (205, 32),
      'warn': (80, 40),
      'success': (150, 34),
    },
  ),
  // The earlier rose theme, close to the Momcozy pump app: a rose accent,
  // peach selection and summary wash, blush-tinted surfaces and tiles. Rebuilt
  // on the same fixed tones as the others, so it keeps their contrast. It is
  // an opt-in choice in Settings, never the default (see [NestPalette.choices]).
  NestVariant.blush: _Spec(
    accent: (13, 58),
    secondary: (40, 24),
    neutral: (25, 4),
    darkNeutral: (355, 4),
    containerChroma: 30,
    tileChroma: 10,
    summaryChroma: 16,
    kinds: {
      'feed': (44, 38),
      'sleep': (278, 36),
      'nappy': (178, 34),
      'pee': (82, 40),
      'poo': (48, 22),
      'pill': (322, 34),
      'pump': (13, 38),
      'warn': (65, 40),
      'success': (165, 34),
    },
  ),
};

/// Everything the theme is built from for one [NestMode]: the Material
/// [ColorScheme] plus Nestling's semantic colours.
@immutable
class NestPalette extends ThemeExtension<NestPalette> {
  const NestPalette({
    required this.mode,
    required this.scheme,
    required this.card,
    required this.feed,
    required this.pump,
    required this.pill,
    required this.sleep,
    required this.nappy,
    required this.pee,
    required this.poo,
    required this.warn,
    required this.success,
    this.variant = NestVariant.current,
    this.summary,
    this.tintedTiles = false,
    this.sunnyButtons = false,
  });

  final NestMode mode;
  final ColorScheme scheme;

  /// Background of cards, sheets and grouped lists: white on the light grey
  /// page, one step above the page in dark mode.
  final Color card;
  final KindColors feed, pump, pill, sleep, nappy, pee, poo, warn, success;

  /// Which palette this is.
  final NestVariant variant;

  /// A soft tint behind Today's summary (baby, last feed), or null for none.
  final Color? summary;

  /// Whether quick-log tiles take their kind's container colour instead of
  /// a neutral tonal surface.
  final bool tintedTiles;

  /// Whether filled buttons use primaryContainer with dark text (see
  /// [_Spec.sunnyButtons]).
  final bool sunnyButtons;

  /// The palette that ships. Change this to adopt a candidate.
  static const shipped = NestVariant.sky;

  /// Preview-only override of [shipped].
  @visibleForTesting
  static NestVariant? debugVariant;

  /// The palettes offered in Settings, default first.
  static const choices = [NestVariant.sky, NestVariant.blush];

  /// The palette chosen in Settings, or null for [shipped].
  static NestVariant? chosen;

  /// The palette in use.
  static NestVariant get active => debugVariant ?? chosen ?? shipped;

  static final _cache = <(NestVariant, NestMode), NestPalette>{};

  static NestPalette of(NestMode mode) => forVariant(active, mode);

  static NestPalette forVariant(NestVariant variant, NestMode mode) =>
      _cache[(variant, mode)] ??= switch (_specs[variant]) {
        null => _build(mode),
        final spec => _fromSpec(variant, spec, mode),
      };

  /// Builds a candidate palette from its [_Spec]. Every role sits at a fixed
  /// tone per mode, so contrast is the same for every candidate.
  static NestPalette _fromSpec(NestVariant variant, _Spec spec, NestMode mode) {
    Color t((double, double) hc, double tone) =>
        Color(Hct.from(hc.$1, hc.$2, tone).toInt());
    final a = spec.accent;
    final ac = (a.$1, spec.containerChroma);
    final sec = spec.secondary;
    final n = mode == NestMode.dark ? spec.darkNeutral : spec.neutral;
    final nv = (n.$1, n.$2 * 1.6 + 2);
    final scheme = switch (mode) {
      NestMode.light => ColorScheme(
        brightness: Brightness.light,
        primary: t(a, 40),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: t(ac, spec.containerTone),
        onPrimaryContainer: t(a, 12),
        primaryFixed: t(ac, 90),
        primaryFixedDim: t(a, 80),
        onPrimaryFixed: t(a, 12),
        onPrimaryFixedVariant: t(a, 30),
        secondary: t((sec.$1, sec.$2 + 8), 40),
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: t(sec, 90),
        onSecondaryContainer: t((sec.$1, sec.$2 + 8), 12),
        tertiary: t((sec.$1, sec.$2 + 8), 40),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: t(sec, 92),
        onTertiaryContainer: t(sec, 12),
        error: const Color(0xFFB3261E),
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFF9DEDC),
        onErrorContainer: const Color(0xFF410E0B),
        surface: t(n, 97.5),
        onSurface: t(n, 11),
        onSurfaceVariant: t(nv, 38),
        surfaceDim: t(n, 87),
        surfaceBright: t(n, 98.5),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: t(n, 96),
        surfaceContainer: t(n, 94.5),
        surfaceContainerHigh: t(n, 92.5),
        surfaceContainerHighest: t(n, 90),
        outline: t(nv, 52),
        outlineVariant: t(nv, 85),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: t(n, 20),
        onInverseSurface: t(n, 95),
        inversePrimary: t(a, 80),
        surfaceTint: Colors.transparent,
      ),
      NestMode.dim => ColorScheme(
        brightness: Brightness.light,
        primary: t(a, 32),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: t(ac, 75),
        onPrimaryContainer: t(a, 8),
        secondary: t((sec.$1, sec.$2 + 8), 32),
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: t(sec, 75),
        onSecondaryContainer: t(sec, 8),
        tertiary: t((sec.$1, sec.$2 + 8), 32),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: t(sec, 77),
        onTertiaryContainer: t(sec, 8),
        error: const Color(0xFF9C2019),
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFE9CBC8),
        onErrorContainer: const Color(0xFF410E0B),
        surface: t(n, 85),
        onSurface: t(n, 8),
        onSurfaceVariant: t(nv, 29),
        surfaceDim: t(n, 78),
        surfaceBright: t(n, 88),
        surfaceContainerLowest: t(n, 89),
        surfaceContainerLow: t(n, 86.5),
        surfaceContainer: t(n, 83),
        surfaceContainerHigh: t(n, 80.5),
        surfaceContainerHighest: t(n, 78),
        outline: t(nv, 44),
        outlineVariant: t(nv, 72),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: t(n, 20),
        onInverseSurface: t(n, 92),
        inversePrimary: t(a, 80),
        surfaceTint: Colors.transparent,
      ),
      NestMode.dark => ColorScheme(
        brightness: Brightness.dark,
        primary: t(a, 80),
        onPrimary: t(a, 18),
        primaryContainer: t((a.$1, spec.containerChroma * 0.8), 30),
        onPrimaryContainer: t(a, 92),
        primaryFixed: t(ac, 90),
        primaryFixedDim: t(a, 80),
        onPrimaryFixed: t(a, 12),
        onPrimaryFixedVariant: t(a, 30),
        secondary: t(sec, 80),
        onSecondary: t(sec, 18),
        secondaryContainer: t((sec.$1, sec.$2 * 0.8), 30),
        onSecondaryContainer: t(sec, 92),
        tertiary: t(sec, 80),
        onTertiary: t(sec, 18),
        tertiaryContainer: t(sec, 28),
        onTertiaryContainer: t(sec, 92),
        error: const Color(0xFFF2B8B5),
        onError: const Color(0xFF601410),
        errorContainer: const Color(0xFF8C1D18),
        onErrorContainer: const Color(0xFFF9DEDC),
        surface: t(n, 7),
        onSurface: t(n, 92),
        onSurfaceVariant: t(nv, 76),
        surfaceDim: t(n, 7),
        surfaceBright: t(n, 24),
        surfaceContainerLowest: t(n, 4),
        surfaceContainerLow: t(n, 10.5),
        surfaceContainer: t(n, 13),
        surfaceContainerHigh: t(n, 17),
        surfaceContainerHighest: t(n, 22),
        outline: t(nv, 60),
        outlineVariant: t(nv, 28),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: t(n, 90),
        onInverseSurface: t(n, 18),
        inversePrimary: t(a, 40),
        surfaceTint: Colors.transparent,
      ),
    };
    KindColors k(String name) {
      final (hue, chroma) = spec.kinds[name]!;
      final tile = (hue, spec.tileChroma ?? 6);
      return switch (mode) {
        NestMode.light => KindColors(
          color: t((hue, chroma), 42),
          onColor: const Color(0xFFFFFFFF),
          container: t(tile, 92.5),
          onContainer: t((hue, chroma), 15),
        ),
        NestMode.dim => KindColors(
          color: t((hue, chroma), 31),
          onColor: const Color(0xFFFFFFFF),
          container: t(tile, 80),
          onContainer: t((hue, chroma), 8),
        ),
        NestMode.dark => KindColors(
          color: t((hue, chroma), 77),
          onColor: t((hue, chroma), 15),
          container: t((hue, (spec.tileChroma ?? 6) * 0.75), 18),
          onContainer: t((hue, chroma), 92),
        ),
      };
    }

    return NestPalette(
      mode: mode,
      scheme: scheme,
      variant: variant,
      card: switch (mode) {
        NestMode.light => const Color(0xFFFFFFFF),
        NestMode.dim => scheme.surfaceContainerLowest,
        NestMode.dark => scheme.surfaceContainerLow,
      },
      summary: switch ((spec.summaryChroma, mode)) {
        (null, _) => null,
        (final c?, NestMode.light) => t((sec.$1, c), 94),
        (final c?, NestMode.dim) => t((sec.$1, c * 0.8), 82),
        (final c?, NestMode.dark) => t((sec.$1, c * 0.4), 13),
      },
      tintedTiles: spec.tileChroma != null,
      sunnyButtons: spec.sunnyButtons && mode != NestMode.dark,
      feed: k('feed'),
      pump: k('pump'),
      pill: k('pill'),
      sleep: k('sleep'),
      nappy: k('nappy'),
      pee: k('pee'),
      poo: k('poo'),
      warn: k('warn'),
      success: k('success'),
    );
  }

  static NestPalette _build(NestMode mode) {
    final accent = Hct.fromInt(nestAccent.toARGB32());
    // Accent tones; containers use a quieter version of the same hue.
    final p = TonalPalette.of(accent.hue, accent.chroma);
    final pc = TonalPalette.of(accent.hue, 10);
    // Neutral greys with a faint cool tint.
    final s = TonalPalette.of(accent.hue, 6);
    Color c(TonalPalette pal, int tone) => Color(pal.get(tone));

    final scheme = switch (mode) {
      NestMode.light => ColorScheme(
        brightness: Brightness.light,
        primary: nestAccent,
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: c(pc, 92),
        onPrimaryContainer: c(p, 15),
        primaryFixed: c(pc, 92),
        primaryFixedDim: const Color(0xFF8CC5C7),
        onPrimaryFixed: c(p, 15),
        onPrimaryFixedVariant: c(p, 30),
        secondary: c(s, 40),
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: c(pc, 92),
        onSecondaryContainer: c(p, 15),
        tertiary: c(s, 40),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: c(s, 92),
        onTertiaryContainer: c(s, 15),
        error: const Color(0xFFB3261E),
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFF9DEDC),
        onErrorContainer: const Color(0xFF410E0B),
        surface: const Color(0xFFF8F9FA),
        onSurface: const Color(0xFF1A1D21),
        onSurfaceVariant: const Color(0xFF5B6168),
        surfaceDim: const Color(0xFFD9DCDF),
        surfaceBright: const Color(0xFFF8F9FA),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFF4F5F7),
        surfaceContainer: const Color(0xFFF1F3F5),
        surfaceContainerHigh: const Color(0xFFEBEDF0),
        surfaceContainerHighest: const Color(0xFFE4E7EA),
        outline: const Color(0xFF79808A),
        outlineVariant: const Color(0xFFD0D5DA),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: const Color(0xFF2E3236),
        onInverseSurface: const Color(0xFFF1F3F5),
        inversePrimary: const Color(0xFF8CC5C7),
        surfaceTint: Colors.transparent,
      ),
      NestMode.dim => ColorScheme(
        brightness: Brightness.light,
        primary: const Color(0xFF285F63),
        onPrimary: const Color(0xFFFFFFFF),
        primaryContainer: c(pc, 82),
        onPrimaryContainer: c(p, 10),
        secondary: c(s, 35),
        onSecondary: const Color(0xFFFFFFFF),
        secondaryContainer: c(pc, 82),
        onSecondaryContainer: c(p, 10),
        tertiary: c(s, 35),
        onTertiary: const Color(0xFFFFFFFF),
        tertiaryContainer: c(s, 82),
        onTertiaryContainer: c(s, 10),
        error: const Color(0xFF9C2019),
        onError: const Color(0xFFFFFFFF),
        errorContainer: const Color(0xFFE9CBC8),
        onErrorContainer: const Color(0xFF410E0B),
        surface: const Color(0xFFD5D9DD),
        onSurface: const Color(0xFF15181B),
        onSurfaceVariant: const Color(0xFF454B52),
        surfaceDim: const Color(0xFFC6CACF),
        surfaceBright: const Color(0xFFDDE0E3),
        surfaceContainerLowest: const Color(0xFFE0E3E6),
        surfaceContainerLow: const Color(0xFFD9DCE0),
        surfaceContainer: const Color(0xFFD0D4D8),
        surfaceContainerHigh: const Color(0xFFCACED3),
        surfaceContainerHighest: const Color(0xFFC3C8CD),
        outline: const Color(0xFF656C74),
        outlineVariant: const Color(0xFFB4BAC0),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: const Color(0xFF2E3236),
        onInverseSurface: const Color(0xFFE8EAED),
        inversePrimary: const Color(0xFF8CC5C7),
        surfaceTint: Colors.transparent,
      ),
      NestMode.dark => ColorScheme(
        brightness: Brightness.dark,
        primary: const Color(0xFF8CC5C7),
        onPrimary: c(p, 15),
        primaryContainer: c(pc, 28),
        onPrimaryContainer: c(p, 90),
        primaryFixed: c(pc, 92),
        primaryFixedDim: const Color(0xFF8CC5C7),
        onPrimaryFixed: c(p, 15),
        onPrimaryFixedVariant: c(p, 30),
        secondary: c(s, 80),
        onSecondary: c(s, 20),
        secondaryContainer: c(pc, 28),
        onSecondaryContainer: c(p, 90),
        tertiary: c(s, 80),
        onTertiary: c(s, 20),
        tertiaryContainer: c(s, 28),
        onTertiaryContainer: c(s, 90),
        error: const Color(0xFFF2B8B5),
        onError: const Color(0xFF601410),
        errorContainer: const Color(0xFF8C1D18),
        onErrorContainer: const Color(0xFFF9DEDC),
        surface: const Color(0xFF0F1113),
        onSurface: const Color(0xFFE8EAED),
        onSurfaceVariant: const Color(0xFFA9B0B7),
        surfaceDim: const Color(0xFF0F1113),
        surfaceBright: const Color(0xFF34393E),
        surfaceContainerLowest: const Color(0xFF0B0C0E),
        surfaceContainerLow: const Color(0xFF16191C),
        surfaceContainer: const Color(0xFF1E2226),
        surfaceContainerHigh: const Color(0xFF262A2F),
        surfaceContainerHighest: const Color(0xFF30353A),
        outline: const Color(0xFF899098),
        outlineVariant: const Color(0xFF3A4046),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: const Color(0xFFE8EAED),
        onInverseSurface: const Color(0xFF1A1D21),
        inversePrimary: nestAccent,
        surfaceTint: Colors.transparent,
      ),
    };
    KindColors k((double, double) hc) => KindColors._of(hc.$1, hc.$2, mode);
    return NestPalette(
      mode: mode,
      scheme: scheme,
      card: switch (mode) {
        NestMode.light => const Color(0xFFFFFFFF),
        NestMode.dim => const Color(0xFFE0E3E6),
        NestMode.dark => const Color(0xFF16191C),
      },
      feed: k(_Kinds.feed),
      pump: k(_Kinds.pump),
      pill: k(_Kinds.pill),
      sleep: k(_Kinds.sleep),
      nappy: k(_Kinds.nappy),
      pee: k(_Kinds.pee),
      poo: k(_Kinds.poo),
      warn: k(_Kinds.warn),
      success: k(_Kinds.success),
    );
  }

  /// Every colour role as (name, colour), for documentation and tests.
  Map<String, Color> get roles {
    final s = scheme;
    return {
      'background (surface)': s.surface,
      'card': card,
      'onSurface': s.onSurface,
      'onSurfaceVariant': s.onSurfaceVariant,
      'surfaceContainerLowest': s.surfaceContainerLowest,
      'surfaceContainerLow': s.surfaceContainerLow,
      'surfaceContainer': s.surfaceContainer,
      'surfaceContainerHigh': s.surfaceContainerHigh,
      'surfaceContainerHighest': s.surfaceContainerHighest,
      'outline': s.outline,
      'outlineVariant': s.outlineVariant,
      'primary': s.primary,
      'onPrimary': s.onPrimary,
      'primaryContainer': s.primaryContainer,
      'onPrimaryContainer': s.onPrimaryContainer,
      'secondaryContainer': s.secondaryContainer,
      'onSecondaryContainer': s.onSecondaryContainer,
      'error': s.error,
      'onError': s.onError,
      'errorContainer': s.errorContainer,
      'onErrorContainer': s.onErrorContainer,
      'inverseSurface': s.inverseSurface,
      'onInverseSurface': s.onInverseSurface,
      'inversePrimary': s.inversePrimary,
      'summary': ?summary,
      for (final (name, k) in kinds) ...{
        'kind.$name': k.color,
        'kind.$name.container': k.container,
      },
    };
  }

  List<(String, KindColors)> get kinds => [
    ('feed', feed),
    ('sleep', sleep),
    ('nappy', nappy),
    ('pee', pee),
    ('poo', poo),
    ('pill', pill),
    ('pump', pump),
    ('warn', warn),
    ('success', success),
  ];

  // A palette is fixed per mode; the theme switches between whole palettes.
  @override
  NestPalette copyWith() => this;

  @override
  NestPalette lerp(NestPalette? other, double t) =>
      t < 0.5 || other == null ? this : other;
}

/// `context.nest` / `context.colors` for widgets.
extension NestContext on BuildContext {
  NestPalette get nest =>
      Theme.of(this).extension<NestPalette>() ?? NestPalette.of(Baby.mode);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Global access to the active palette, for code without a BuildContext and
/// for widgets written before the Material 3 theme. Every value maps onto a
/// [ColorScheme] role or a [NestPalette] colour; nothing here is a free
/// colour. [dark] follows the appearance setting; [dim] is the night light.
abstract final class Baby {
  static bool dark = false;
  static bool dim = false;

  static NestMode get mode =>
      dark ? NestMode.dark : (dim ? NestMode.dim : NestMode.light);
  static NestPalette get palette => NestPalette.of(mode);
  static ColorScheme get _s => palette.scheme;

  static Color get bg => _s.surface;
  static Color get card => palette.card;
  static Color get ink => _s.onSurface;
  static Color get muted => _s.onSurfaceVariant;
  static Color get line => _s.outlineVariant;
  static Color get primary => _s.primary;
  static Color get primarySoft => _s.primaryContainer;
  static Color get onPrimary => _s.onPrimary;
  static Color get error => _s.error;

  /// Background behind illustrations (welcome, photo ring): neutral.
  static List<Color> get hero => [_s.surfaceContainer, _s.surfaceContainer];

  static Color get feed => palette.feed.color;
  static Color get feedSoft => palette.feed.container;
  static Color get nappy => palette.nappy.color;
  static Color get nappySoft => palette.nappy.container;
  static Color get sleep => palette.sleep.color;
  static Color get sleepSoft => palette.sleep.container;
  static Color get pill => palette.pill.color;
  static Color get pillSoft => palette.pill.container;
  static Color get pee => palette.pee.color;
  static Color get peeSoft => palette.pee.container;
  static Color get poo => palette.poo.color;
  static Color get pooSoft => palette.poo.container;
  static Color get pump => palette.pump.color;
  static Color get pumpSoft => palette.pump.container;
  static Color get ok => palette.success.color;
  static Color get warn => palette.warn.color;

  /// Surfaces are tonal, not shadowed (Material 3).
  static List<BoxShadow> get shadow => const [];

  // Wide-window names, kept as aliases of the same roles.
  static Color get surface => _s.surface;
  static Color get sidebar => _s.surfaceContainerLow;
  static Color get border => _s.outlineVariant;
  static Color get borderStrong => _s.outline;
  static Color get hover => _s.onSurface.withValues(alpha: 0.08);
  static Color get ring => _s.primary;
  static Color get highlight => palette.pee.container;
}

// ------------------------------------------------------- spacing and shape

/// 4dp grid. Use these instead of ad-hoc numbers.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Side margin of phone screens (Material compact window).
  static const double page = 16;

  /// Side margin on wide windows.
  static const double pageWide = 24;
}

/// Material 3 shape scale.
abstract final class Corners {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 28;

  static final BorderRadius card = BorderRadius.circular(20);
  static final BorderRadius tile = BorderRadius.circular(md);
}

/// Motion: Material 3 durations and easing.
abstract final class Motion {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const long = Duration(milliseconds: 400);
  static const standard = Curves.easeInOutCubicEmphasized;
  static const enter = Curves.easeOutCubic;
}

/// Button heights. Every Filled, Tonal, Outlined, Text and Segmented button
/// is [height] tall (40 on wide windows); only the action row of a sheet
/// ([SheetActions] in common.dart) is taller, see [sheetAction].
abstract final class Controls {
  static const double height = 48;
  static const double heightDesktop = 40;

  /// The main action row of a sheet: 56 on phones, where it is the most
  /// tapped target; 48 in desktop dialogs, where a pointer needs less.
  static double sheetAction(bool desktop) => desktop ? 48 : 56;
}

/// Shape and size scale for wide windows.
abstract final class DesktopTokens {
  static const double radiusSm = Corners.sm;
  static const double radius = Corners.md;
  static const double radiusLg = Corners.lg;
  static const double controlHeight = Controls.heightDesktop;
  static const double topBarHeight = 64;
  static const double sidebarWidth = 260;
  static const double railWidth = 80;
}

// -------------------------------------------------------------------- theme

final _themes = <(NestVariant, NestMode, bool), ThemeData>{};

/// The app theme. [desktop] gives the denser variant for wide windows.
/// Themes are cached per palette, so calling this on every build is cheap.
ThemeData babyTheme({bool desktop = false}) {
  final key = (NestPalette.active, Baby.mode, desktop);
  return _themes[key] ??= _theme(Baby.palette, desktop: desktop);
}

TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
  // Material 3 type scale on the platform face (Roboto on Android, Segoe UI
  // on Windows). Titles get Medium weight for a more confident hierarchy;
  // numbers that matter use tabular figures where they are shown.
  final t = base.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  return t.copyWith(
    displaySmall: t.displaySmall?.copyWith(letterSpacing: -0.25),
    headlineMedium: t.headlineMedium?.copyWith(letterSpacing: -0.25),
    headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w400),
    titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w500),
    titleMedium: t.titleMedium?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    bodyLarge: t.bodyLarge?.copyWith(letterSpacing: 0.15),
    bodyMedium: t.bodyMedium?.copyWith(
      letterSpacing: 0.2,
      color: scheme.onSurface,
    ),
    bodySmall: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
  );
}

ThemeData _theme(NestPalette nest, {required bool desktop}) {
  final scheme = nest.scheme;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: desktop ? VisualDensity.compact : VisualDensity.standard,
    extensions: [nest],
  );
  final text = _textTheme(base.textTheme, scheme);
  final card = nest.card;
  const stadium = StadiumBorder();
  final controlHeight = desktop ? Controls.heightDesktop : Controls.height;
  // One label style for every button, chip and segment: labelLarge (14/20,
  // Medium), so buttons beside chips or option tiles never look heavier.
  final buttonText = text.labelLarge!.copyWith(letterSpacing: 0.1);
  // Disabled content at 55% and fill at 10% of onSurface, instead of
  // Material's 38%/12%, which all but vanishes on white sheets.
  final disabledFg = scheme.onSurface.withValues(alpha: 0.55);
  final disabledBg = scheme.onSurface.withValues(alpha: 0.10);
  // The theme's compact density would shave 8dp off every button on
  // desktop (40 -> 32); heights here are already the desktop ones.
  const buttonDensity = VisualDensity.standard;
  OutlineInputBorder field(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Corners.md),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final p in TargetPlatform.values) p: NestPageTransitionsBuilder(),
      },
    ),
    splashFactory: desktop ? InkRipple.splashFactory : InkSparkle.splashFactory,
    materialTapTargetSize: desktop
        ? MaterialTapTargetSize.shrinkWrap
        : MaterialTapTargetSize.padded,
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: desktop ? DesktopTokens.topBarHeight : 64,
      titleSpacing: desktop ? Space.pageWide : Space.page,
      titleTextStyle: text.titleLarge?.copyWith(
        fontSize: desktop ? 20 : 22,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface),
      actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    ),
    // Grouped content sits on a white (light) or one-step-lighter (dark)
    // surface. In light themes a faint hairline (half-strength outline) keeps
    // white on near-white legible without drawing boxes around everything.
    cardTheme: CardThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: Corners.card,
        side: nest.mode == NestMode.dark
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    // The bar sits on the page colour, so it reads as part of the page; the
    // pill-shaped indicator glides between tabs.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorShape: const StadiumBorder(),
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelMedium?.copyWith(
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.secondaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: text.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: text.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card,
      selectedColor: scheme.secondaryContainer,
      checkmarkColor: scheme.onSecondaryContainer,
      side: WidgetStateBorderSide.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? BorderSide(color: scheme.secondaryContainer)
            : BorderSide(color: scheme.outlineVariant),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.sm),
      ),
      showCheckmark: false,
      labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
      secondaryLabelStyle: text.labelLarge?.copyWith(
        color: scheme.onSecondaryContainer,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: nest.sunnyButtons ? scheme.primaryContainer : null,
        foregroundColor: nest.sunnyButtons ? scheme.onPrimaryContainer : null,
        disabledBackgroundColor: disabledBg,
        disabledForegroundColor: disabledFg,
        minimumSize: Size(64, controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        visualDensity: buttonDensity,
        shape: stadium,
        textStyle: buttonText,
        iconSize: 18,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: Size(64, controlHeight),
        visualDensity: buttonDensity,
        shape: stadium,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            minimumSize: Size(64, controlHeight),
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            visualDensity: buttonDensity,
            shape: stadium,
            textStyle: buttonText,
            iconSize: 18,
            foregroundColor: scheme.primary,
            disabledForegroundColor: disabledFg,
          ).copyWith(
            // The 3:1 outline, dimmed (not removed) when disabled.
            side: WidgetStateBorderSide.resolveWith(
              (s) => BorderSide(
                color: s.contains(WidgetState.disabled)
                    ? scheme.onSurface.withValues(alpha: 0.2)
                    : scheme.outline,
              ),
            ),
          ),
    ),
    // Text buttons share the height of the others, so a Cancel next to a
    // filled Save in a dialog or sheet lines up instead of being 8dp short.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: Size(48, controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        visualDensity: buttonDensity,
        shape: stadium,
        textStyle: buttonText,
        iconSize: 18,
        disabledForegroundColor: disabledFg,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        minimumSize: Size.square(desktop ? 40 : 48),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: Size(0, controlHeight),
        visualDensity: buttonDensity,
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        foregroundColor: scheme.onSurface,
        disabledForegroundColor: disabledFg,
        side: BorderSide(color: scheme.outline),
        textStyle: buttonText,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 3,
      focusElevation: 3,
      hoverElevation: 4,
      highlightElevation: 3,
      extendedTextStyle: buttonText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.lg),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      modalBackgroundColor: card,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      dragHandleSize: const Size(32, 4),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Corners.xl)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.xl),
      ),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      insetPadding: desktop
          ? const EdgeInsets.all(Space.xxl)
          : const EdgeInsets.symmetric(horizontal: Space.xl, vertical: 24),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      headerHeadlineStyle: text.headlineMedium,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.xs),
      ),
      textStyle: text.bodyLarge,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainer),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      actionTextColor: scheme.inversePrimary,
      width: desktop ? 440 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Corners.xs),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      isDense: desktop,
      contentPadding: desktop
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: field(scheme.outline),
      enabledBorder: field(scheme.outlineVariant),
      focusedBorder: field(scheme.primary, 2),
      errorBorder: field(scheme.error),
      focusedErrorBorder: field(scheme.error, 2),
      hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (s) => text.bodySmall!.copyWith(
          color: s.contains(WidgetState.error)
              ? scheme.error
              : s.contains(WidgetState.focused)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      titleTextStyle: text.bodyLarge?.copyWith(color: scheme.onSurface),
      subtitleTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      leadingAndTrailingTextStyle: text.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      minVerticalPadding: desktop ? 8 : 12,
      contentPadding: EdgeInsets.symmetric(
        horizontal: desktop ? Space.md : Space.lg,
      ),
      shape: RoundedRectangleBorder(borderRadius: Corners.tile),
    ),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? const Icon(Icons.check_rounded)
            : null,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
      labelStyle: text.titleSmall,
      unselectedLabelStyle: text.titleSmall,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.secondaryContainer,
      circularTrackColor: Colors.transparent,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(Corners.xs),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(
        scheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: scheme.error,
      textColor: scheme.onError,
    ),
  );
}
