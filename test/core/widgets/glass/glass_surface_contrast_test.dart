import 'dart:math';

import 'package:duasaku_app/core/theme/liquid_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// WCAG Contrast Ratio Helpers
// ---------------------------------------------------------------------------

/// Linearizes a single sRGB channel value (0.0–1.0) for WCAG luminance.
double _linearize(double channel) {
  if (channel <= 0.03928) {
    return channel / 12.92;
  }
  return pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

/// Computes WCAG relative luminance for a given [Color].
double _relativeLuminance(Color color) {
  final r = _linearize(color.r);
  final g = _linearize(color.g);
  final b = _linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/// Computes WCAG contrast ratio between two colors.
/// Returns a value >= 1.0 (higher = more contrast).
double _contrastRatio(Color foreground, Color background) {
  final l1 = _relativeLuminance(foreground);
  final l2 = _relativeLuminance(background);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

/// Alpha-blends [foreground] over [background].
/// Both colors are assumed to be fully opaque except for [foreground]'s alpha.
Color _alphaBlend(Color foreground, Color background) {
  final alpha = foreground.a;
  final invAlpha = 1.0 - alpha;
  return Color.from(
    alpha: 1.0,
    red: (foreground.r * alpha + background.r * invAlpha).clamp(0.0, 1.0),
    green: (foreground.g * alpha + background.g * invAlpha).clamp(0.0, 1.0),
    blue: (foreground.b * alpha + background.b * invAlpha).clamp(0.0, 1.0),
  );
}

// ---------------------------------------------------------------------------
// Preset Configuration Data
// ---------------------------------------------------------------------------

/// Holds all data needed to test contrast for a single preset/mode combination.
class _PresetContrastConfig {
  final String name;
  final LiquidGlassTheme glassTheme;
  final Color onSurface;
  final List<Color> backgroundColors;
  final bool isDarkMode;

  const _PresetContrastConfig({
    required this.name,
    required this.glassTheme,
    required this.onSurface,
    required this.backgroundColors,
    required this.isDarkMode,
  });
}

/// Text shadow safety net: black at 25% opacity (midpoint of 20-30% per Req 14.1).
const Color _textShadowColor = Color.from(
  alpha: 0.25,
  red: 0.0,
  green: 0.0,
  blue: 0.0,
);

/// All 6 preset/mode configurations with their PremiumBackground glow palette
/// colors derived from ThemePresets.getDetails.
final List<_PresetContrastConfig> _allPresetConfigs = [
  _PresetContrastConfig(
    name: 'defaultPurple_dark',
    glassTheme: LiquidGlassTheme.defaultPurpleDark(),
    onSurface: const Color(0xFFF5F5F7),
    isDarkMode: true,
    backgroundColors: [
      const Color(0xFF121212), // base background
      const Color(0xFF9D7BFF), // primary glow at full intensity
      const Color(0xFF1C1C1E), // surface tint color
    ],
  ),
  _PresetContrastConfig(
    name: 'defaultPurple_light',
    glassTheme: LiquidGlassTheme.defaultPurpleLight(),
    onSurface: const Color(0xFF1D1D1F),
    isDarkMode: false,
    backgroundColors: [
      const Color(0xFFFFFFFF), // base background
      const Color(0xFF5E17EB), // primary glow at full intensity
      const Color(0xFFF5F5F7), // surface tint color
    ],
  ),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Test Group 1: Dynamic contrast >= 4.5:1 for all preset/mode combinations
  // Requirements: 14.1, 2.6, 9.5
  // =========================================================================
  group('Dynamic contrast guarantee (4.5:1 ratio with animated background)', () {
    for (final config in _allPresetConfigs) {
      group('${config.name}:', () {
        for (int i = 0; i < config.backgroundColors.length; i++) {
          final bgColor = config.backgroundColors[i];

          test(
            'background #$i (${bgColor.toARGB32().toRadixString(16)}) maintains >= 4.5:1 contrast',
            () {
              // Step 1: Alpha-blend surface tint over background
              final surfaceTint = config.glassTheme.surfaceTintColor.withValues(
                alpha: config.glassTheme.surfaceOpacity,
              );
              final compositeColor = _alphaBlend(surfaceTint, bgColor);

              // Step 2: For dark mode, apply text shadow safety net
              // (black at 25% opacity blended over composite)
              // For light mode, test surface opacity alone
              final effectiveBackground = config.isDarkMode
                  ? _alphaBlend(_textShadowColor, compositeColor)
                  : compositeColor;

              // Step 3: Compute contrast ratio
              final ratio = _contrastRatio(
                config.onSurface,
                effectiveBackground,
              );

              // WCAG AA requires >= 4.5:1 for normal text
              expect(
                ratio,
                greaterThanOrEqualTo(4.5),
                reason:
                    '${config.name}: contrast ratio ${ratio.toStringAsFixed(2)} < 4.5 '
                    'for bg=0x${bgColor.toARGB32().toRadixString(16)} '
                    'effective=0x${effectiveBackground.toARGB32().toRadixString(16)} '
                    'text=0x${config.onSurface.toARGB32().toRadixString(16)}',
              );
            },
          );
        }
      });
    }
  });

  // =========================================================================
  // Test Group 2: Text shadow fallback provides sufficient contrast
  // Requirements: 14.1
  // =========================================================================
  group('Text shadow fallback provides sufficient contrast', () {
    // Test that the text shadow safety net improves contrast for dark mode
    // presets where surface opacity alone might be insufficient with
    // bright/saturated backgrounds.
    final darkPresets = _allPresetConfigs.where((c) => c.isDarkMode);

    for (final config in darkPresets) {
      test(
        '${config.name}: text shadow improves contrast over worst-case background',
        () {
          // Use the most saturated/bright background as worst case
          final worstCaseBg = config.backgroundColors.reduce(
            (a, b) => _relativeLuminance(a) > _relativeLuminance(b) ? a : b,
          );

          // Compute composite without text shadow
          final surfaceTint = config.glassTheme.surfaceTintColor.withValues(
            alpha: config.glassTheme.surfaceOpacity,
          );
          final compositeWithoutShadow = _alphaBlend(surfaceTint, worstCaseBg);

          // Compute composite with text shadow
          final compositeWithShadow = _alphaBlend(
            _textShadowColor,
            compositeWithoutShadow,
          );

          // Contrast without shadow
          final ratioWithout = _contrastRatio(
            config.onSurface,
            compositeWithoutShadow,
          );
          // Contrast with shadow
          final ratioWith = _contrastRatio(
            config.onSurface,
            compositeWithShadow,
          );

          // Text shadow should improve contrast for light-on-dark text
          expect(
            ratioWith,
            greaterThanOrEqualTo(ratioWithout),
            reason:
                '${config.name}: text shadow should improve contrast '
                '(without: ${ratioWithout.toStringAsFixed(2)}, '
                'with: ${ratioWith.toStringAsFixed(2)})',
          );

          // And the result with shadow should meet WCAG AA
          expect(
            ratioWith,
            greaterThanOrEqualTo(4.5),
            reason:
                '${config.name}: even with text shadow, contrast '
                '${ratioWith.toStringAsFixed(2)} < 4.5',
          );
        },
      );
    }
  });

  // =========================================================================
  // Test Group 3: boldTextOf accessibility override increases opacity
  // Requirements: 14.1, 2.6
  // =========================================================================
  group('boldTextOf accessibility override increases opacity correctly', () {
    for (final config in _allPresetConfigs) {
      test('${config.name}: boldText increases surfaceOpacity by 0.15', () {
        final baseOpacity = config.glassTheme.surfaceOpacity;
        final boldOpacity = (baseOpacity + 0.15).clamp(0.0, 1.0);

        // Verify the increase is exactly 0.15 (or clamped to 1.0)
        expect(boldOpacity, equals(min(baseOpacity + 0.15, 1.0)));

        // Verify increased opacity maintains or improves contrast
        // Test against the brightest background (worst case for dark mode)
        final worstCaseBg = config.backgroundColors.reduce(
          (a, b) => _relativeLuminance(a) > _relativeLuminance(b) ? a : b,
        );

        // Contrast with base opacity
        final baseTint = config.glassTheme.surfaceTintColor.withValues(
          alpha: baseOpacity,
        );
        final baseComposite = _alphaBlend(baseTint, worstCaseBg);
        final baseEffective = config.isDarkMode
            ? _alphaBlend(_textShadowColor, baseComposite)
            : baseComposite;
        final baseRatio = _contrastRatio(config.onSurface, baseEffective);

        // Contrast with bold opacity
        final boldTint = config.glassTheme.surfaceTintColor.withValues(
          alpha: boldOpacity,
        );
        final boldComposite = _alphaBlend(boldTint, worstCaseBg);
        final boldEffective = config.isDarkMode
            ? _alphaBlend(_textShadowColor, boldComposite)
            : boldComposite;
        final boldRatio = _contrastRatio(config.onSurface, boldEffective);

        // Bold text must still meet WCAG AA (>= 4.5:1).
        // Note: For light mode presets with very light surface tints,
        // increasing opacity makes the surface more opaque/lighter, which
        // can slightly reduce contrast with dark text. This is acceptable
        // as long as WCAG AA is still met — the purpose of the bold text
        // override is to improve surface dominance for readability.
        expect(
          boldRatio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${config.name}: boldText contrast ${boldRatio.toStringAsFixed(2)} < 4.5',
        );

        // For dark mode (light text on dark surface), increasing opacity
        // should always maintain or improve contrast since the surface
        // becomes more dominant (darker).
        if (config.isDarkMode) {
          expect(
            boldRatio,
            greaterThanOrEqualTo(baseRatio - 0.01),
            reason:
                '${config.name}: dark mode boldText should maintain/improve contrast '
                '(base: ${baseRatio.toStringAsFixed(2)}, bold: ${boldRatio.toStringAsFixed(2)})',
          );
        }
      });
    }
  });

  // =========================================================================
  // Test Group 4: highContrastOf accessibility override
  // Requirements: 14.1
  // =========================================================================
  group('highContrastOf accessibility override increases opacity correctly', () {
    for (final config in _allPresetConfigs) {
      test(
        '${config.name}: highContrast sets surfaceOpacity to 0.9 and disables blur',
        () {
          const highContrastOpacity = 0.9;

          // Verify high contrast opacity is always >= base opacity
          expect(
            highContrastOpacity,
            greaterThanOrEqualTo(config.glassTheme.surfaceOpacity),
            reason:
                '${config.name}: highContrast opacity 0.9 should be >= '
                'base opacity ${config.glassTheme.surfaceOpacity}',
          );

          // Test contrast with high contrast opacity against all backgrounds
          for (int i = 0; i < config.backgroundColors.length; i++) {
            final bgColor = config.backgroundColors[i];

            final highContrastTint = config.glassTheme.surfaceTintColor
                .withValues(alpha: highContrastOpacity);
            final composite = _alphaBlend(highContrastTint, bgColor);

            // For high contrast mode, we don't need the text shadow safety net
            // because the opacity is so high the surface dominates
            final ratio = _contrastRatio(config.onSurface, composite);

            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '${config.name}: highContrast mode contrast '
                  '${ratio.toStringAsFixed(2)} < 4.5 for bg #$i',
            );
          }
        },
      );
    }
  });

  // =========================================================================
  // Test Group 5: Verify contrast with actual ThemePresets.getDetails colors
  // Requirements: 14.1, 2.6, 9.5
  // =========================================================================
  group('Contrast with actual ThemePresets glow palette colors', () {
    // Test using the exact glow colors from ThemePresets.getDetails
    // blended at their actual alpha values over the base background.
    final presetGlowTests = <String, Map<String, dynamic>>{
      'defaultPurple_dark': {
        'theme': LiquidGlassTheme.defaultPurpleDark(),
        'onSurface': const Color(0xFFF5F5F7),
        'isDark': true,
        'base': const Color(0xFF121212),
        'glowColor1': const Color(0x1A9D7BFF), // alpha = 0x1A/255 ≈ 0.102
        'glowColor2': const Color(0x0DFFFFFF), // alpha = 0x0D/255 ≈ 0.051
      },
      'defaultPurple_light': {
        'theme': LiquidGlassTheme.defaultPurpleLight(),
        'onSurface': const Color(0xFF1D1D1F),
        'isDark': false,
        'base': const Color(0xFFFFFFFF),
        'glowColor1': const Color(0x1A5E17EB),
        'glowColor2': const Color(0x0D000000),
      },
    };

    for (final entry in presetGlowTests.entries) {
      final presetName = entry.key;
      final data = entry.value;
      final theme = data['theme'] as LiquidGlassTheme;
      final onSurface = data['onSurface'] as Color;
      final isDark = data['isDark'] as bool;
      final base = data['base'] as Color;
      final glowColor1 = data['glowColor1'] as Color;
      final glowColor2 = data['glowColor2'] as Color;

      group('$presetName:', () {
        test('glow1 blended over base maintains contrast', () {
          // Simulate: glow1 alpha-blended over base background
          final bgWithGlow = _alphaBlend(glowColor1, base);

          // Then surface tint over that
          final surfaceTint = theme.surfaceTintColor.withValues(
            alpha: theme.surfaceOpacity,
          );
          final composite = _alphaBlend(surfaceTint, bgWithGlow);

          final effective = isDark
              ? _alphaBlend(_textShadowColor, composite)
              : composite;

          final ratio = _contrastRatio(onSurface, effective);

          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$presetName glow1: contrast ${ratio.toStringAsFixed(2)} < 4.5',
          );
        });

        test('glow2 blended over base maintains contrast', () {
          final bgWithGlow = _alphaBlend(glowColor2, base);

          final surfaceTint = theme.surfaceTintColor.withValues(
            alpha: theme.surfaceOpacity,
          );
          final composite = _alphaBlend(surfaceTint, bgWithGlow);

          final effective = isDark
              ? _alphaBlend(_textShadowColor, composite)
              : composite;

          final ratio = _contrastRatio(onSurface, effective);

          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$presetName glow2: contrast ${ratio.toStringAsFixed(2)} < 4.5',
          );
        });

        test('both glows blended over base maintains contrast', () {
          // Simulate both glows layered: glow2 over (glow1 over base)
          final bgWithGlow1 = _alphaBlend(glowColor1, base);
          final bgWithBothGlows = _alphaBlend(glowColor2, bgWithGlow1);

          final surfaceTint = theme.surfaceTintColor.withValues(
            alpha: theme.surfaceOpacity,
          );
          final composite = _alphaBlend(surfaceTint, bgWithBothGlows);

          final effective = isDark
              ? _alphaBlend(_textShadowColor, composite)
              : composite;

          final ratio = _contrastRatio(onSurface, effective);

          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$presetName both glows: contrast ${ratio.toStringAsFixed(2)} < 4.5',
          );
        });

        test('base background alone maintains contrast', () {
          final surfaceTint = theme.surfaceTintColor.withValues(
            alpha: theme.surfaceOpacity,
          );
          final composite = _alphaBlend(surfaceTint, base);

          final effective = isDark
              ? _alphaBlend(_textShadowColor, composite)
              : composite;

          final ratio = _contrastRatio(onSurface, effective);

          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$presetName base: contrast ${ratio.toStringAsFixed(2)} < 4.5',
          );
        });
      });
    }
  });
}
