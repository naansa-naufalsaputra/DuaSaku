import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/liquid_glass_theme.dart';

// ---------------------------------------------------------------------------
// Fallback defaults when LiquidGlassTheme extension is not found in theme.
// ---------------------------------------------------------------------------
const double _kDefaultBlurSigma = 12.0;
const double _kDefaultSurfaceOpacity = 0.65;
const Color _kDefaultBorderGlowColor = Color(0x4D4D8DFE); // primary@0.3
const Color _kDefaultSurfaceTintColor = Color(0xFF161515);
const double _kDefaultInnerHighlightOpacity = 0.08;

/// A translucent glass container that uses [BackdropFilter] with configurable
/// blur, a semi-transparent surface tint, 1px border glow, and a top-edge
/// inner highlight to simulate light refraction.
///
/// Wraps itself in a [RepaintBoundary] for GPU isolation.
///
/// Respects accessibility settings:
/// - Bold text → increases surface opacity by 0.15
/// - High contrast → sets opacity to 0.9, disables blur
/// - Reduce Transparency (via highContrast proxy) → opacity 0.92, no blur
///
/// Falls back to hardcoded defaults if [LiquidGlassTheme] is not registered.
class GlassSurface extends StatelessWidget {
  /// The child widget rendered inside the glass surface.
  final Widget child;

  /// Override the theme's default blur sigma. When null, uses theme value.
  final double? blurSigma;

  /// Override the theme's default surface opacity. When null, uses theme value.
  final double? surfaceOpacity;

  /// Border radius of the glass surface. Defaults to 16.0.
  final double borderRadius;

  /// Whether to apply BackdropFilter blur. When false, renders a solid
  /// semi-transparent surface without blur — used for list items.
  final bool enableBlur;

  /// Optional padding inside the glass surface.
  final EdgeInsetsGeometry? padding;

  const GlassSurface({
    super.key,
    required this.child,
    this.blurSigma,
    this.surfaceOpacity,
    this.borderRadius = 16.0,
    this.enableBlur = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    // -------------------------------------------------------------------------
    // Resolve theme tokens (with fallback + debug warning)
    // -------------------------------------------------------------------------
    final glassTheme = LiquidGlassTheme.of(context);

    if (glassTheme == null && kDebugMode) {
      debugPrint(
        '[GlassSurface] WARNING: LiquidGlassTheme extension not found in '
        'current theme. Using hardcoded fallback defaults.',
      );
    }

    final resolvedBlurSigma =
        blurSigma ?? glassTheme?.blurSigma ?? _kDefaultBlurSigma;
    var resolvedSurfaceOpacity =
        surfaceOpacity ?? glassTheme?.surfaceOpacity ?? _kDefaultSurfaceOpacity;
    final borderGlowColor =
        glassTheme?.borderGlowColor ?? _kDefaultBorderGlowColor;
    final surfaceTintColor =
        glassTheme?.surfaceTintColor ?? _kDefaultSurfaceTintColor;
    final innerHighlightOpacity =
        glassTheme?.innerHighlightOpacity ?? _kDefaultInnerHighlightOpacity;

    // -------------------------------------------------------------------------
    // Accessibility adjustments
    // -------------------------------------------------------------------------
    final bool isBoldText = MediaQuery.boldTextOf(context);
    final bool isHighContrast = MediaQuery.highContrastOf(context);

    // Determine effective blur state
    var effectiveEnableBlur = enableBlur;

    // High contrast → set opacity to 0.9, disable blur
    if (isHighContrast) {
      resolvedSurfaceOpacity = 0.9;
      effectiveEnableBlur = false;
    }

    // Bold text → increase opacity by 0.15 (clamped to 1.0)
    // Applied after high contrast check so it can stack if needed,
    // but high contrast already sets 0.9 so this would push to 1.0 max.
    if (isBoldText) {
      resolvedSurfaceOpacity = (resolvedSurfaceOpacity + 0.15).clamp(0.0, 1.0);
    }

    // "Reduce Transparency" — use highContrast as proxy on platforms that
    // map the accessibility setting there. If highContrast is already handled
    // above, this acts as an additional check via accessibleNavigation.
    final bool accessibleNavigation = MediaQuery.of(
      context,
    ).accessibleNavigation;
    if (accessibleNavigation) {
      resolvedSurfaceOpacity = 0.92;
      effectiveEnableBlur = false;
    }

    // -------------------------------------------------------------------------
    // Build decoration
    // -------------------------------------------------------------------------
    final roundedRadius = BorderRadius.circular(borderRadius);

    final bool isDarkState = Theme.of(context).brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: surfaceTintColor.withValues(alpha: resolvedSurfaceOpacity),
      borderRadius: roundedRadius,
      border: Border.all(color: borderGlowColor, width: 1.0),
      boxShadow: isDarkState
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
    );

    // Inner highlight: top-edge gradient to simulate light refraction
    final innerHighlight = Container(
      height: 1.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: innerHighlightOpacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );

    // -------------------------------------------------------------------------
    // Compose widget tree
    // -------------------------------------------------------------------------
    Widget surface = Container(
      decoration: decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          innerHighlight,
          Flexible(
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        ],
      ),
    );

    // Apply BackdropFilter only when blur is enabled
    if (effectiveEnableBlur) {
      surface = ClipRRect(
        borderRadius: roundedRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: resolvedBlurSigma,
            sigmaY: resolvedBlurSigma,
          ),
          child: surface,
        ),
      );
    }

    // Wrap in RepaintBoundary for GPU isolation
    return RepaintBoundary(child: surface);
  }
}
