import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/theme/app_theme.dart';
import 'package:my_pnl/core/theme/semantic_colors.dart';

void main() {
  group('app themes', () {
    test('are a light one and a dark one', () {
      expect(appLightTheme.brightness, Brightness.light);
      expect(appDarkTheme.brightness, Brightness.dark);
    });

    test('each carry the semantic colours drawn for their brightness', () {
      expect(
        appLightTheme.extension<AppSemanticColors>(),
        AppSemanticColors.light,
      );
      expect(
        appDarkTheme.extension<AppSemanticColors>(),
        AppSemanticColors.dark,
      );
    });

    test('read their status colours against the dark surface', () {
      // The whole reason these are not constants: a colour is only "green
      // enough to mean done" relative to what it is drawn on. 3:1 is what WCAG
      // asks of a graphic that carries meaning, which is what all three are.
      //
      // The dark set only. The light set is the one the app already shipped and
      // is not asserted here — two of its three are below this bar against
      // white, which is a fault worth fixing on its own terms rather than by
      // quietly restyling the light theme from a dark-theme change.
      final surface = appDarkTheme.colorScheme.surface.computeLuminance();

      for (final color in [
        AppSemanticColors.dark.positive,
        AppSemanticColors.dark.negative,
        AppSemanticColors.dark.caution,
        AppSemanticColors.dark.focus,
      ]) {
        expect(
          _contrast(color.computeLuminance(), surface),
          greaterThan(3),
          reason: '$color on the dark surface',
        );
      }
    });

    test('keep the two brightnesses telling the same story', () {
      // Same meanings, different values. A dark set that reused the light one
      // would pass every test above except this.
      expect(
        AppSemanticColors.dark.positive,
        isNot(AppSemanticColors.light.positive),
      );
      expect(
        AppSemanticColors.dark.positive.computeLuminance(),
        greaterThan(AppSemanticColors.light.positive.computeLuminance()),
      );
      expect(
        AppSemanticColors.dark.negative,
        isNot(AppSemanticColors.light.negative),
      );
      expect(
        AppSemanticColors.dark.negative.computeLuminance(),
        greaterThan(AppSemanticColors.light.negative.computeLuminance()),
      );
    });
  });

  group('AppSemanticColors.of', () {
    testWidgets('falls back to the light set with no theme extension', (
      tester,
    ) async {
      late AppSemanticColors found;

      // A bare MaterialApp, which is what every widget test in this repo pumps.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              found = AppSemanticColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(found, AppSemanticColors.light);
    });

    testWidgets('finds the set the app theme carries', (tester) async {
      late AppSemanticColors found;

      await tester.pumpWidget(
        MaterialApp(
          theme: appDarkTheme,
          home: Builder(
            builder: (context) {
              found = AppSemanticColors.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(found, AppSemanticColors.dark);
    });
  });
}

/// WCAG contrast ratio between two luminances.
double _contrast(double a, double b) {
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}
