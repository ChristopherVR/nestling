import 'dart:math';

import 'package:baby_app/src/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  for (final mode in NestMode.values) {
    group('$mode palette', () {
      final p = NestPalette.of(mode);
      final s = p.scheme;
      // Every surface text or a kind accent can sit on.
      final surfaces = {
        'surface': s.surface,
        'card': p.card,
        'surfaceContainer': s.surfaceContainer,
        'surfaceContainerHigh': s.surfaceContainerHigh,
      };

      test('text roles pass WCAG AA (4.5:1) on every surface', () {
        for (final MapEntry(key: name, value: bg) in surfaces.entries) {
          for (final (role, fg) in [
            ('onSurface', s.onSurface),
            ('onSurfaceVariant', s.onSurfaceVariant),
            ('primary', s.primary),
            ('error', s.error),
          ]) {
            expect(
              _contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$role on $name',
            );
          }
        }
      });

      test('kind accents pass WCAG AA (4.5:1) on every surface', () {
        for (final (name, kind) in p.kinds) {
          for (final MapEntry(key: surface, value: bg) in surfaces.entries) {
            expect(
              _contrast(kind.color, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$name on $surface',
            );
          }
          expect(
            _contrast(kind.onContainer, kind.container),
            greaterThanOrEqualTo(4.5),
            reason: '$name onContainer',
          );
        }
      });

      test('filled and container pairs pass WCAG AA', () {
        for (final (name, fg, bg) in [
          ('onPrimary', s.onPrimary, s.primary),
          ('onPrimaryContainer', s.onPrimaryContainer, s.primaryContainer),
          (
            'onSecondaryContainer',
            s.onSecondaryContainer,
            s.secondaryContainer,
          ),
          ('onError', s.onError, s.error),
          ('onErrorContainer', s.onErrorContainer, s.errorContainer),
          ('onInverseSurface', s.onInverseSurface, s.inverseSurface),
        ]) {
          expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
        }
        // Component outlines (text fields, outlined buttons): 3:1.
        expect(_contrast(s.outline, p.card), greaterThanOrEqualTo(3));
      });

      test('kinds share one lightness and stay desaturated', () {
        final hcts = [
          for (final (_, k) in p.kinds) Hct.fromInt(k.color.toARGB32()),
        ];
        for (final hct in hcts) {
          expect(hct.chroma, lessThan(42), reason: '$hct');
          expect(
            (hct.tone - hcts.first.tone).abs(),
            lessThan(2),
            reason: '$hct',
          );
        }
      });

      test('no red or pink outside the error roles', () {
        final error = {
          s.error,
          s.onError,
          s.errorContainer,
          s.onErrorContainer,
        };
        for (final MapEntry(key: role, value: c) in p.roles.entries) {
          if (error.contains(c)) continue;
          final hct = Hct.fromInt(c.toARGB32());
          final reddish = hct.hue < 40 || hct.hue > 330;
          expect(reddish && hct.chroma > 12, isFalse, reason: '$role $hct');
        }
      });
    });
  }

  test('prints the role table', () {
    final buffer = StringBuffer('role | light | night light | dark\n');
    final light = NestPalette.of(NestMode.light).roles;
    final dim = NestPalette.of(NestMode.dim).roles;
    final dark = NestPalette.of(NestMode.dark).roles;
    for (final role in light.keys) {
      buffer.writeln(
        '$role | ${_hex(light[role]!)} | ${_hex(dim[role]!)} | '
        '${_hex(dark[role]!)}',
      );
    }
    // ignore: avoid_print
    print(buffer);
  });
}
