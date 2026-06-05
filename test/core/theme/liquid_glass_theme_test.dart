import 'package:duasaku_app/core/theme/liquid_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiquidGlassTheme', () {
    group('factory constructors', () {
      test('defaultPurpleDark has correct token values', () {
        final theme = LiquidGlassTheme.defaultPurpleDark();
        expect(theme.blurSigma, 12.0);
        expect(theme.surfaceOpacity, 0.65);
        expect(theme.innerHighlightOpacity, 0.08);
        expect(theme.animationDuration, const Duration(milliseconds: 300));
        expect(theme.animationDurationFast, const Duration(milliseconds: 150));
        expect(theme.animationDurationSlow, const Duration(milliseconds: 500));
        expect(theme.animationCurve, Curves.easeOutCubic);
        expect(theme.borderGlowColor.a, closeTo(0.3, 0.01));
      });

      test('defaultPurpleLight has correct token values', () {
        final theme = LiquidGlassTheme.defaultPurpleLight();
        expect(theme.blurSigma, 10.0);
        expect(theme.surfaceOpacity, 0.70);
        expect(theme.innerHighlightOpacity, 0.05);
        expect(theme.animationDuration, const Duration(milliseconds: 300));
        expect(theme.animationDurationFast, const Duration(milliseconds: 150));
        expect(theme.animationDurationSlow, const Duration(milliseconds: 500));
        expect(theme.borderGlowColor.a, closeTo(0.2, 0.01));
      });

    });

    group('copyWith', () {
      test('returns identical instance when no params provided', () {
        final theme = LiquidGlassTheme.defaultPurpleDark();
        final copy = theme.copyWith();
        expect(copy, equals(theme));
      });

      test('overrides only specified fields', () {
        final theme = LiquidGlassTheme.defaultPurpleDark();
        final copy = theme.copyWith(blurSigma: 20.0, surfaceOpacity: 0.9);
        expect(copy.blurSigma, 20.0);
        expect(copy.surfaceOpacity, 0.9);
        // Unchanged fields
        expect(copy.innerHighlightOpacity, theme.innerHighlightOpacity);
        expect(copy.animationDuration, theme.animationDuration);
        expect(copy.borderGlowColor, theme.borderGlowColor);
      });
    });

    group('lerp', () {
      test('returns this when other is null', () {
        final theme = LiquidGlassTheme.defaultPurpleDark();
        final result = theme.lerp(null, 0.5);
        expect(result, equals(theme));
      });

      test('interpolates numeric values at t=0.5', () {
        final a = LiquidGlassTheme.defaultPurpleDark();
        final b = LiquidGlassTheme.defaultPurpleDark().copyWith(blurSigma: 15.0, surfaceOpacity: 0.55);
        final mid = a.lerp(b, 0.5);
        expect(mid.blurSigma, closeTo((12.0 + 15.0) / 2, 0.01));
        expect(mid.surfaceOpacity, closeTo((0.65 + 0.55) / 2, 0.01));
      });

      test('snaps duration at t=0.5 boundary', () {
        final a = LiquidGlassTheme.defaultPurpleDark();
        final b = LiquidGlassTheme.defaultPurpleDark().copyWith(animationDuration: const Duration(milliseconds: 250));
        // t < 0.5 → keeps a's duration
        final before = a.lerp(b, 0.49);
        expect(before.animationDuration, a.animationDuration);
        // t >= 0.5 → snaps to b's duration
        final after = a.lerp(b, 0.5);
        expect(after.animationDuration, b.animationDuration);
      });

      test('at t=0 returns values equal to this', () {
        final a = LiquidGlassTheme.defaultPurpleDark();
        final b = LiquidGlassTheme.defaultPurpleDark().copyWith(blurSigma: 15.0, surfaceOpacity: 0.55);
        final result = a.lerp(b, 0.0);
        expect(result.blurSigma, a.blurSigma);
        expect(result.surfaceOpacity, a.surfaceOpacity);
      });

      test('at t=1 returns values equal to other', () {
        final a = LiquidGlassTheme.defaultPurpleDark();
        final b = LiquidGlassTheme.defaultPurpleDark().copyWith(blurSigma: 15.0, surfaceOpacity: 0.55, animationDuration: const Duration(milliseconds: 250));
        final result = a.lerp(b, 1.0);
        expect(result.blurSigma, b.blurSigma);
        expect(result.surfaceOpacity, b.surfaceOpacity);
        expect(result.animationDuration, b.animationDuration);
      });
    });

    group('of(context)', () {
      testWidgets('returns theme extension when registered', (tester) async {
        final glassTheme = LiquidGlassTheme.defaultPurpleDark();
        late LiquidGlassTheme? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: [glassTheme],
            ),
            home: Builder(
              builder: (context) {
                result = LiquidGlassTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(result, isNotNull);
        expect(result!.blurSigma, 12.0);
        expect(result!.surfaceOpacity, 0.65);
      });

      testWidgets('returns null when extension not registered', (tester) async {
        late LiquidGlassTheme? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Builder(
              builder: (context) {
                result = LiquidGlassTheme.of(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(result, isNull);
      });
    });

    group('equality', () {
      test('two instances with same values are equal', () {
        final a = LiquidGlassTheme.defaultPurpleDark();
        final b = LiquidGlassTheme.defaultPurpleDark();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('instances with different values are not equal', () {
        final a = LiquidGlassTheme.defaultPurpleDark();
        final b = LiquidGlassTheme.defaultPurpleDark().copyWith(blurSigma: 15.0);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
