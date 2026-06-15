import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/liquid_glass_theme.dart';
import 'glass_surface.dart';

/// A tappable glass card that extends [GlassSurface] with press animation,
/// haptic feedback, and minimum touch target enforcement.
///
/// When [onTap] is provided, the card animates on press:
/// - Scale down to 0.96
/// - Border glow intensification
/// - [HapticFeedback.lightImpact] on tap
///
/// Enforces a minimum 48x48dp touch target via [ConstrainedBox] for
/// accessibility compliance.
class GlassCard extends StatefulWidget {
  /// The child widget rendered inside the glass card.
  final Widget child;

  /// Optional tap callback. When null, the card is non-interactive
  /// (no animation, no haptic feedback).
  final VoidCallback? onTap;

  /// Optional long press callback.
  final VoidCallback? onLongPress;

  /// Padding inside the glass surface. Defaults to 16px on all sides.
  final EdgeInsetsGeometry padding;

  /// Whether to apply BackdropFilter blur. When false, renders a solid
  /// semi-transparent surface — use for list items in scrollable contexts.
  final bool enableBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.enableBlur = true,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  /// Fallback duration if LiquidGlassTheme is not available.
  static const _kFallbackDurationFast = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kFallbackDurationFast,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update animation duration from theme if available.
    final glassTheme = LiquidGlassTheme.of(context);
    final duration =
        glassTheme?.animationDurationFast ?? _kFallbackDurationFast;
    if (_controller.duration != duration) {
      _controller.duration = duration;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onTap != null || widget.onLongPress != null;

    // Non-interactive: render a plain GlassSurface with constraints.
    if (!isInteractive) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: GlassSurface(
          enableBlur: widget.enableBlur,
          padding: widget.padding,
          child: widget.child,
        ),
      );
    }

    // Interactive: wrap with gesture detection and press animation.
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onLongPress: widget.onLongPress != null
            ? () {
                HapticFeedback.heavyImpact();
                widget.onLongPress?.call();
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: _AnimatedGlowGlassSurface(
                glowIntensity: _controller.value,
                enableBlur: widget.enableBlur,
                padding: widget.padding,
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Internal widget that renders a [GlassSurface]-like container with
/// an animated border glow intensity for press feedback.
///
/// This duplicates some of [GlassSurface]'s rendering logic to allow
/// dynamic glow intensification during the press animation without
/// rebuilding the entire surface widget.
class _AnimatedGlowGlassSurface extends StatelessWidget {
  final double glowIntensity;
  final bool enableBlur;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _AnimatedGlowGlassSurface({
    required this.glowIntensity,
    required this.enableBlur,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve theme tokens (with fallback)
    final glassTheme = LiquidGlassTheme.of(context);

    if (glassTheme == null && kDebugMode) {
      debugPrint(
        '[GlassCard] WARNING: LiquidGlassTheme extension not found in '
        'current theme. Using hardcoded fallback defaults.',
      );
    }

    final resolvedBlurSigma = glassTheme?.blurSigma ?? 12.0;
    var resolvedSurfaceOpacity = glassTheme?.surfaceOpacity ?? 0.65;
    final baseBorderGlowColor =
        glassTheme?.borderGlowColor ?? const Color(0x4D4D8DFE);
    final surfaceTintColor =
        glassTheme?.surfaceTintColor ?? const Color(0xFF161515);
    final innerHighlightOpacity = glassTheme?.innerHighlightOpacity ?? 0.08;

    // Accessibility adjustments
    final bool isBoldText = MediaQuery.boldTextOf(context);
    final bool isHighContrast = MediaQuery.highContrastOf(context);
    var effectiveEnableBlur = enableBlur;

    if (isHighContrast) {
      resolvedSurfaceOpacity = 0.9;
      effectiveEnableBlur = false;
    }

    if (isBoldText) {
      resolvedSurfaceOpacity = (resolvedSurfaceOpacity + 0.15).clamp(0.0, 1.0);
    }

    final bool accessibleNavigation = MediaQuery.of(
      context,
    ).accessibleNavigation;
    if (accessibleNavigation) {
      resolvedSurfaceOpacity = 0.92;
      effectiveEnableBlur = false;
    }

    // Intensify border glow: scale opacity from 1x to 2x based on animation.
    final intensifiedGlowOpacity =
        (baseBorderGlowColor.a * (1.0 + glowIntensity)).clamp(0.0, 1.0);
    final intensifiedGlowColor = baseBorderGlowColor.withValues(
      alpha: intensifiedGlowOpacity,
    );

    // Build decoration
    const borderRadius = 16.0;
    final roundedRadius = BorderRadius.circular(borderRadius);

    final bool isDarkState = Theme.of(context).brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: surfaceTintColor.withValues(alpha: resolvedSurfaceOpacity),
      borderRadius: roundedRadius,
      border: Border.all(color: intensifiedGlowColor, width: 1.0),
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

    // Inner highlight
    final innerHighlight = Container(
      height: 1.0,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
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

    // Compose widget tree
    Widget surface = Container(
      decoration: decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          innerHighlight,
          Flexible(
            child: Padding(padding: padding, child: child),
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
