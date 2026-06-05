import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// ThemeExtension that provides all liquid glass design tokens.
///
/// Access via `LiquidGlassTheme.of(context)` or
/// `Theme.of(context).extension<LiquidGlassTheme>()`.
@immutable
class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme> {
  /// Gaussian blur radius for BackdropFilter.
  final double blurSigma;

  /// Alpha transparency of the glass surface tint color.
  final double surfaceOpacity;

  /// Colored border glow on glass surfaces (theme accent at reduced opacity).
  final Color borderGlowColor;

  /// Surface tint color applied over the blurred backdrop.
  final Color surfaceTintColor;

  /// Opacity of the top-edge inner highlight (simulates light refraction).
  final double innerHighlightOpacity;

  /// Standard animation duration (e.g. nav indicator, card press).
  final Duration animationDuration;

  /// Fast animation duration (e.g. button press down).
  final Duration animationDurationFast;

  /// Slow animation duration (e.g. bottom sheet entry).
  final Duration animationDurationSlow;

  /// Default animation curve for all liquid animations.
  final Curve animationCurve;

  const LiquidGlassTheme({
    required this.blurSigma,
    required this.surfaceOpacity,
    required this.borderGlowColor,
    required this.surfaceTintColor,
    required this.innerHighlightOpacity,
    required this.animationDuration,
    required this.animationDurationFast,
    required this.animationDurationSlow,
    required this.animationCurve,
  });

  // ---------------------------------------------------------------------------
  // Factory constructors for each preset/mode combination
  // ---------------------------------------------------------------------------

  /// defaultPurple preset — dark mode.
  factory LiquidGlassTheme.defaultPurpleDark() {
    const primaryColor = Color(0xFF9D7BFF);
    const surfaceColor = Color(0xFF1C1C1E);
    return LiquidGlassTheme(
      blurSigma: 12.0,
      surfaceOpacity: 0.65,
      borderGlowColor: primaryColor.withValues(alpha: 0.3),
      surfaceTintColor: surfaceColor,
      innerHighlightOpacity: 0.08,
      animationDuration: const Duration(milliseconds: 300),
      animationDurationFast: const Duration(milliseconds: 150),
      animationDurationSlow: const Duration(milliseconds: 500),
      animationCurve: Curves.easeOutCubic,
    );
  }

  /// defaultPurple preset — light mode.
  factory LiquidGlassTheme.defaultPurpleLight() {
    const primaryColor = Color(0xFF5E17EB);
    const surfaceColor = Color(0xFFF5F5F7);
    return LiquidGlassTheme(
      blurSigma: 10.0,
      surfaceOpacity: 0.70,
      borderGlowColor: primaryColor.withValues(alpha: 0.2),
      surfaceTintColor: surfaceColor,
      innerHighlightOpacity: 0.05,
      animationDuration: const Duration(milliseconds: 300),
      animationDurationFast: const Duration(milliseconds: 150),
      animationDurationSlow: const Duration(milliseconds: 500),
      animationCurve: Curves.easeOutCubic,
    );
  }

  // ---------------------------------------------------------------------------
  // Convenience accessor
  // ---------------------------------------------------------------------------

  /// Retrieves the [LiquidGlassTheme] from the nearest [Theme] ancestor.
  ///
  /// Returns `null` if the extension is not registered in the current theme.
  static LiquidGlassTheme? of(BuildContext context) {
    return Theme.of(context).extension<LiquidGlassTheme>();
  }

  // ---------------------------------------------------------------------------
  // ThemeExtension overrides
  // ---------------------------------------------------------------------------

  @override
  LiquidGlassTheme copyWith({
    double? blurSigma,
    double? surfaceOpacity,
    Color? borderGlowColor,
    Color? surfaceTintColor,
    double? innerHighlightOpacity,
    Duration? animationDuration,
    Duration? animationDurationFast,
    Duration? animationDurationSlow,
    Curve? animationCurve,
  }) {
    return LiquidGlassTheme(
      blurSigma: blurSigma ?? this.blurSigma,
      surfaceOpacity: surfaceOpacity ?? this.surfaceOpacity,
      borderGlowColor: borderGlowColor ?? this.borderGlowColor,
      surfaceTintColor: surfaceTintColor ?? this.surfaceTintColor,
      innerHighlightOpacity:
          innerHighlightOpacity ?? this.innerHighlightOpacity,
      animationDuration: animationDuration ?? this.animationDuration,
      animationDurationFast:
          animationDurationFast ?? this.animationDurationFast,
      animationDurationSlow:
          animationDurationSlow ?? this.animationDurationSlow,
      animationCurve: animationCurve ?? this.animationCurve,
    );
  }

  @override
  LiquidGlassTheme lerp(LiquidGlassTheme? other, double t) {
    if (other is! LiquidGlassTheme) return this;
    return LiquidGlassTheme(
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
      surfaceOpacity:
          lerpDouble(surfaceOpacity, other.surfaceOpacity, t) ?? surfaceOpacity,
      borderGlowColor:
          Color.lerp(borderGlowColor, other.borderGlowColor, t) ??
          borderGlowColor,
      surfaceTintColor:
          Color.lerp(surfaceTintColor, other.surfaceTintColor, t) ??
          surfaceTintColor,
      innerHighlightOpacity:
          lerpDouble(innerHighlightOpacity, other.innerHighlightOpacity, t) ??
          innerHighlightOpacity,
      // Durations and curves don't lerp — snap to target at t >= 0.5.
      animationDuration: t < 0.5 ? animationDuration : other.animationDuration,
      animationDurationFast: t < 0.5
          ? animationDurationFast
          : other.animationDurationFast,
      animationDurationSlow: t < 0.5
          ? animationDurationSlow
          : other.animationDurationSlow,
      animationCurve: t < 0.5 ? animationCurve : other.animationCurve,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LiquidGlassTheme) return false;
    return blurSigma == other.blurSigma &&
        surfaceOpacity == other.surfaceOpacity &&
        borderGlowColor == other.borderGlowColor &&
        surfaceTintColor == other.surfaceTintColor &&
        innerHighlightOpacity == other.innerHighlightOpacity &&
        animationDuration == other.animationDuration &&
        animationDurationFast == other.animationDurationFast &&
        animationDurationSlow == other.animationDurationSlow &&
        animationCurve == other.animationCurve;
  }

  @override
  int get hashCode => Object.hash(
    blurSigma,
    surfaceOpacity,
    borderGlowColor,
    surfaceTintColor,
    innerHighlightOpacity,
    animationDuration,
    animationDurationFast,
    animationDurationSlow,
    animationCurve,
  );
}
