import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nestling/main.dart';
import 'package:nestling/src/store.dart';
import 'package:nestling/src/ui/settings_page.dart';
import 'package:nestling/src/ui/theme.dart';

void main() {
  testWidgets('Blush can be chosen in Settings and switched back to Sky', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => NestPalette.chosen = null);
    final app = (await tester.runAsync(
      () => AppState.loadForTesting(
        File('unused-palette-test.json'),
        persist: false,
      ),
    ))!;
    addTearDown(app.dispose);
    app.completeSetup();
    await tester.pumpWidget(BabyApp(state: app));
    await tester.pumpAndSettle();
    expect(NestPalette.active, NestVariant.sky);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'theme');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    expect(find.byType(PalettePicker), findsOneWidget);

    await tester.tap(find.text('Blush'));
    await tester.pumpAndSettle();
    expect(app.palette, 'blush');
    expect(NestPalette.active, NestVariant.blush);
    final primary = Theme.of(tester.element(find.byType(PalettePicker)))
        .colorScheme
        .primary;
    expect(
      primary,
      NestPalette.forVariant(NestVariant.blush, Baby.mode).scheme.primary,
    );

    await tester.tap(find.text('Sky'));
    await tester.pumpAndSettle();
    expect(app.palette, '');
    expect(NestPalette.active, NestVariant.sky);
  });
}
