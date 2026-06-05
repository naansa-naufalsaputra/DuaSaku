import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/liquid_glass_theme.dart';

/// Fallback defaults when LiquidGlassTheme extension is not found.
const double _kDefaultBlurSigma = 12.0;
const double _kDefaultSurfaceOpacity = 0.65;
const Color _kDefaultBorderGlowColor = Color(0x4D4D8DFE);
const Color _kDefaultSurfaceTintColor = Color(0xFF161515);
const double _kDefaultInnerHighlightOpacity = 0.08;

/// The visual variant of a [GlassButton].
enum GlassButtonVariant {
  /// Filled glass surface with primary color tint.
  primary,

  /// Outlined glass (border only, transparent/minimal fill).
  secondary,

  /// No surface at all, just glow effect on press.
  text,
}

/// A button widget with glass surface treatment, liquid press animation,
/// and glow feedback.
///
/// Supports three variants:
/// - [GlassButtonVariant.primary]: filled glass with primary tint
/// - [GlassButtonVariant.secondary]: outlined glass (border only)
/// - [GlassButtonVariant.text]: no surface, glow on press only
///
/// Press animation: scale 0.95, glow intensification (100ms down, 150ms up
/// with easeOutCubic).
///
/// Provides [HapticFeedback.lightImpact] on press.
/// Supports [isLoading] state which shows a circular progress indicator
/// and disables tap.
class GlassButton extends StatefulWidget {
  /// The child widget (typically a Text or Row with icon + text).
  final Widget child;

  /// Callback when the button is pressed. When null, the button is disabled.
  final VoidCallback? onPressed;

  /// The visual variant of the button.
  final GlassButtonVariant variant;

  /// Whether the button is in a loading state. When true, shows a circular
  /// progress indicator and disables tap.
  final bool isLoading;

  const GlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.isLoading = false,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  /// Press down duration: 100ms.
  static const _kPressDownDuration = Duration(milliseconds: 100);

  /// Release up duration: 150ms.
  static const _kReleaseUpDuration = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kPressDownDuration,
      reverseDuration: _kReleaseUpDuration,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _onTapDown(TapDownDetails details) {
    if (!_isEnabled) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (!_isEnabled) return;
    _controller.reverse();
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    if (!_isEnabled) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final glassTheme = LiquidGlassTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    // Resolve theme tokens.
    final blurSigma = glassTheme?.blurSigma ?? _kDefaultBlurSigma;
    final surfaceOpacity =
        glassTheme?.surfaceOpacity ?? _kDefaultSurfaceOpacity;
    final surfaceTintColor =
        glassTheme?.surfaceTintColor ?? _kDefaultSurfaceTintColor;
    final baseBorderGlowColor =
        glassTheme?.borderGlowColor ?? _kDefaultBorderGlowColor;
    final innerHighlightOpacity =
        glassTheme?.innerHighlightOpacity ?? _kDefaultInnerHighlightOpacity;

    // Accessibility adjustments.
    final bool isHighContrast = MediaQuery.highContrastOf(context);
    final bool isBoldText = MediaQuery.boldTextOf(context);
    final bool accessibleNavigation =
        MediaQuery.of(context).accessibleNavigation;

    var resolvedSurfaceOpacity = surfaceOpacity;
    var effectiveEnableBlur = true;

    if (isHighContrast) {
      resolvedSurfaceOpacity = 0.9;
      effectiveEnableBlur = false;
    }
    if (isBoldText) {
      resolvedSurfaceOpacity =
          (resolvedSurfaceOpacity + 0.15).clamp(0.0, 1.0);
    }
    if (accessibleNavigation) {
      resolvedSurfaceOpacity = 0.92;
      effectiveEnableBlur = false;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final glowIntensity = 1.0 + _controller.value;

          return Transform.scale(
            scale: _scaleAnimation.value,
            child: _buildVariant(
              context,
              colorScheme: colorScheme,
              blurSigma: blurSigma,
              surfaceTintColor: surfaceTintColor,
              surfaceOpacity: resolvedSurfaceOpacity,
              baseBorderGlowColor: baseBorderGlowColor,
              innerHighlightOpacity: innerHighlightOpacity,
              glowIntensity: glowIntensity,
              enableBlur: effectiveEnableBlur,
              child: child!,
            ),
          );
        },
        child: _buildContent(context, colorScheme),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    if (widget.isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            _contentColor(colorScheme),
          ),
        ),
      );
    }

    return DefaultTextStyle(
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: _contentColor(colorScheme),
                fontWeight: FontWeight.w600,
              ) ??
          TextStyle(color: _contentColor(colorScheme)),
      child: IconTheme(
        data: IconThemeData(
          color: _contentColor(colorScheme),
          size: 20,
        ),
        child: widget.child,
      ),
    );
  }

  Color _contentColor(ColorScheme colorScheme) {
    if (!_isEnabled) {
      return colorScheme.onSurface.withValues(alpha: 0.38);
    }
    switch (widget.variant) {
      case GlassButtonVariant.primary:
        return colorScheme.onPrimary;
      case GlassButtonVariant.secondary:
        return colorScheme.primary;
      case GlassButtonVariant.text:
        return colorScheme.primary;
    }
  }

  Widget _buildVariant(
    BuildContext context, {
    required ColorScheme colorScheme,
    required double blurSigma,
    required Color surfaceTintColor,
    required double surfaceOpacity,
    required Color baseBorderGlowColor,
    required double innerHighlightOpacity,
    required double glowIntensity,
    required bool enableBlur,
    required Widget child,
  }) {
    switch (widget.variant) {
      case GlassButtonVariant.primary:
        return _buildPrimaryVariant(
          context,
          colorScheme: colorScheme,
          blurSigma: blurSigma,
          surfaceOpacity: surfaceOpacity,
          baseBorderGlowColor: baseBorderGlowColor,
          innerHighlightOpacity: innerHighlightOpacity,
          glowIntensity: glowIntensity,
          enableBlur: enableBlur,
          child: child,
        );
      case GlassButtonVariant.secondary:
        return _buildSecondaryVariant(
          context,
          colorScheme: colorScheme,
          blurSigma: blurSigma,
          surfaceOpacity: surfaceOpacity,
          baseBorderGlowColor: baseBorderGlowColor,
          innerHighlightOpacity: innerHighlightOpacity,
          glowIntensity: glowIntensity,
          enableBlur: enableBlur,
          child: child,
        );
      case GlassButtonVariant.text:
        return _buildTextVariant(
          context,
          colorScheme: colorScheme,
          baseBorderGlowColor: baseBorderGlowColor,
          glowIntensity: glowIntensity,
          child: child,
        );
    }
  }

  /// Primary: filled glass surface with primary color tint.
  Widget _buildPrimaryVariant(
    BuildContext context, {
    required ColorScheme colorScheme,
    required double blurSigma,
    required double surfaceOpacity,
    required Color baseBorderGlowColor,
    required double innerHighlightOpacity,
    required double glowIntensity,
    required bool enableBlur,
    required Widget child,
  }) {
    const borderRadius = BorderRadius.all(Radius.circular(16));

    // Primary uses the primary color as the surface tint.
    final primaryTintColor = colorScheme.primary;
    final intensifiedGlowColor = baseBorderGlowColor.withValues(
      alpha: (baseBorderGlowColor.a * glowIntensity).clamp(0.0, 1.0),
    );

    final decoration = BoxDecoration(
      color: primaryTintColor.withValues(alpha: surfaceOpacity),
      borderRadius: borderRadius,
      border: Border.all(
        color: intensifiedGlowColor,
        width: 1.0,
      ),
    );

    final innerHighlight = Container(
      height: 1.0,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
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

    Widget surface = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Container(
        decoration: decoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            innerHighlight,
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              child: Center(child: child),
            ),
          ],
        ),
      ),
    );

    if (enableBlur) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: surface,
        ),
      );
    }

    return RepaintBoundary(child: surface);
  }

  /// Secondary: outlined glass (border only, transparent/minimal fill).
  Widget _buildSecondaryVariant(
    BuildContext context, {
    required ColorScheme colorScheme,
    required double blurSigma,
    required double surfaceOpacity,
    required Color baseBorderGlowColor,
    required double innerHighlightOpacity,
    required double glowIntensity,
    required bool enableBlur,
    required Widget child,
  }) {
    const borderRadius = BorderRadius.all(Radius.circular(16));

    final intensifiedGlowColor = colorScheme.primary.withValues(
      alpha: (0.4 * glowIntensity).clamp(0.0, 1.0),
    );

    // Secondary has minimal fill — just enough for the glass effect.
    final decoration = BoxDecoration(
      color: colorScheme.surface.withValues(alpha: surfaceOpacity * 0.3),
      borderRadius: borderRadius,
      border: Border.all(
        color: intensifiedGlowColor,
        width: 1.0,
      ),
    );

    Widget surface = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Container(
        decoration: decoration,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          child: Center(child: child),
        ),
      ),
    );

    if (enableBlur) {
      surface = ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurSigma * 0.5,
            sigmaY: blurSigma * 0.5,
          ),
          child: surface,
        ),
      );
    }

    return RepaintBoundary(child: surface);
  }

  /// Text: no surface at all, just glow effect on press.
  Widget _buildTextVariant(
    BuildContext context, {
    required ColorScheme colorScheme,
    required Color baseBorderGlowColor,
    required double glowIntensity,
    required Widget child,
  }) {
    // Only show glow when pressed (glowIntensity > 1.0).
    final glowOpacity = ((glowIntensity - 1.0) * 0.3).clamp(0.0, 1.0);
    final glowColor = colorScheme.primary.withValues(alpha: glowOpacity);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          color: glowColor,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        child: Center(child: child),
      ),
    );
  }
}
