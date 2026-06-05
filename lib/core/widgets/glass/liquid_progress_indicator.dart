import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/liquid_glass_theme.dart';

/// The visual variant of the [LiquidProgressIndicator].
enum LiquidProgressVariant {
  /// A horizontal bar with fluid wave motion on the leading edge.
  linear,

  /// A circular ring with liquid surface wobble effect.
  circular,
}

/// A progress indicator with liquid fill animation.
///
/// Supports both [LiquidProgressVariant.linear] and
/// [LiquidProgressVariant.circular] variants.
///
/// In determinate mode ([value] is non-null), the fill smoothly interpolates
/// to the target value over 400ms with [Curves.easeOutCubic].
/// Values are clamped to [0.0, 1.0]. Invalid values (NaN, infinity) are
/// treated as 0.0.
///
/// In indeterminate mode ([value] is null), a continuous wave/wobble
/// animation plays.
///
/// The track is rendered as a subtle glass surface appearance, and the fill
/// uses the theme's primary color (or [color] override).
class LiquidProgressIndicator extends StatefulWidget {
  /// The progress value between 0.0 and 1.0.
  /// When null, the indicator runs in indeterminate (continuous animation) mode.
  /// Invalid values (NaN, infinity) are treated as 0.0.
  final double? value;

  /// The visual variant. Defaults to [LiquidProgressVariant.linear].
  final LiquidProgressVariant variant;

  /// Override color for the progress fill. Defaults to theme primary color.
  final Color? color;

  /// Override color for the track. Defaults to a subtle glass surface color.
  final Color? trackColor;

  const LiquidProgressIndicator({
    super.key,
    this.value,
    this.variant = LiquidProgressVariant.linear,
    this.color,
    this.trackColor,
  });

  @override
  State<LiquidProgressIndicator> createState() =>
      _LiquidProgressIndicatorState();
}

class _LiquidProgressIndicatorState extends State<LiquidProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // For smooth interpolation of determinate values.
  double _currentValue = 0.0;
  double _targetValue = 0.0;
  double _startValue = 0.0;
  double _interpolationProgress = 1.0;

  static const _interpolationDuration = Duration(milliseconds: 400);
  static const _interpolationCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    final sanitized = _sanitizeValue(widget.value);
    if (sanitized != null) {
      _currentValue = sanitized;
      _targetValue = sanitized;
    } else {
      // Indeterminate mode: start continuous animation.
      _animationController.repeat();
    }

    _animationController.addListener(_onAnimationTick);
  }

  @override
  void didUpdateWidget(LiquidProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newSanitized = _sanitizeValue(widget.value);
    final oldSanitized = _sanitizeValue(oldWidget.value);

    if (widget.value == null && oldWidget.value != null) {
      // Switched to indeterminate mode.
      _animationController.repeat();
    } else if (widget.value != null && oldWidget.value == null) {
      // Switched to determinate mode.
      _animationController.stop();
      _animationController.value = 0.0;
      _startValue = _currentValue;
      _targetValue = newSanitized!;
      _interpolationProgress = 0.0;
      _animationController
        ..duration = _interpolationDuration
        ..forward(from: 0.0);
    } else if (newSanitized != oldSanitized && newSanitized != null) {
      // Determinate value changed — smooth interpolation.
      _startValue = _currentValue;
      _targetValue = newSanitized;
      _interpolationProgress = 0.0;
      _animationController
        ..duration = _interpolationDuration
        ..forward(from: 0.0);
    }
  }

  void _onAnimationTick() {
    if (widget.value != null) {
      // Determinate: interpolate toward target.
      final curved = _interpolationCurve.transform(
        _animationController.value.clamp(0.0, 1.0),
      );
      setState(() {
        _interpolationProgress = curved;
        _currentValue =
            _startValue + (_targetValue - _startValue) * _interpolationProgress;
      });
    } else {
      // Indeterminate: just trigger repaint for wave animation.
      setState(() {});
    }
  }

  @override
  void dispose() {
    _animationController.removeListener(_onAnimationTick);
    _animationController.dispose();
    super.dispose();
  }

  /// Sanitizes a progress value: clamps to [0.0, 1.0], treats NaN/infinity as 0.0.
  /// Returns null if input is null (indeterminate mode).
  static double? _sanitizeValue(double? value) {
    if (value == null) return null;
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glassTheme = LiquidGlassTheme.of(context);
    final fillColor =
        widget.color ?? theme.colorScheme.primary;
    final resolvedTrackColor = widget.trackColor ??
        (glassTheme?.surfaceTintColor ?? theme.colorScheme.surfaceContainerHighest)
            .withValues(alpha: glassTheme?.surfaceOpacity ?? 0.3);

    switch (widget.variant) {
      case LiquidProgressVariant.linear:
        return _LinearLiquidProgress(
          value: widget.value != null ? _currentValue : null,
          animationValue: _animationController.value,
          fillColor: fillColor,
          trackColor: resolvedTrackColor,
          glassTheme: glassTheme,
        );
      case LiquidProgressVariant.circular:
        return _CircularLiquidProgress(
          value: widget.value != null ? _currentValue : null,
          animationValue: _animationController.value,
          fillColor: fillColor,
          trackColor: resolvedTrackColor,
          glassTheme: glassTheme,
        );
    }
  }
}

/// Linear variant: horizontal bar with fluid wave motion on leading edge.
class _LinearLiquidProgress extends StatelessWidget {
  final double? value;
  final double animationValue;
  final Color fillColor;
  final Color trackColor;
  final LiquidGlassTheme? glassTheme;

  const _LinearLiquidProgress({
    required this.value,
    required this.animationValue,
    required this.fillColor,
    required this.trackColor,
    required this.glassTheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: CustomPaint(
          painter: _LinearLiquidPainter(
            value: value,
            animationValue: animationValue,
            fillColor: fillColor,
            trackColor: trackColor,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _LinearLiquidPainter extends CustomPainter {
  final double? value;
  final double animationValue;
  final Color fillColor;
  final Color trackColor;

  _LinearLiquidPainter({
    required this.value,
    required this.animationValue,
    required this.fillColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw track.
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.height / 2),
      ),
      trackPaint,
    );

    // Draw fill.
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    if (value != null) {
      // Determinate: fill to value with wave on leading edge.
      final fillWidth = size.width * value!;
      if (fillWidth <= 0) return;

      final path = Path();
      path.moveTo(0, 0);
      path.lineTo(fillWidth - 4, 0);

      // Fluid wave on leading edge.
      final waveAmplitude = size.height * 0.2;
      final wavePhase = animationValue * 2 * math.pi;
      for (double y = 0; y <= size.height; y += 1) {
        final waveOffset =
            math.sin(y / size.height * math.pi * 2 + wavePhase) *
                waveAmplitude;
        path.lineTo(fillWidth + waveOffset, y);
      }

      path.lineTo(0, size.height);
      path.close();

      canvas.drawPath(path, fillPaint);
    } else {
      // Indeterminate: sliding fill with wave motion.
      final startFraction = (animationValue * 1.5 - 0.5).clamp(0.0, 1.0);
      final endFraction = (animationValue * 1.5).clamp(0.0, 1.0);
      final startX = size.width * startFraction;
      final endX = size.width * endFraction;

      if (endX - startX <= 0) return;

      final path = Path();
      path.moveTo(startX, 0);

      // Wave on leading edge.
      final waveAmplitude = size.height * 0.3;
      final wavePhase = animationValue * 4 * math.pi;
      for (double y = 0; y <= size.height; y += 1) {
        final waveOffset =
            math.sin(y / size.height * math.pi * 2 + wavePhase) *
                waveAmplitude;
        path.lineTo(endX + waveOffset, y);
      }

      path.lineTo(startX, size.height);
      path.close();

      canvas.drawPath(path, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_LinearLiquidPainter oldDelegate) {
    return value != oldDelegate.value ||
        animationValue != oldDelegate.animationValue ||
        fillColor != oldDelegate.fillColor ||
        trackColor != oldDelegate.trackColor;
  }
}

/// Circular variant: ring with liquid surface wobble effect.
class _CircularLiquidProgress extends StatelessWidget {
  final double? value;
  final double animationValue;
  final Color fillColor;
  final Color trackColor;
  final LiquidGlassTheme? glassTheme;

  const _CircularLiquidProgress({
    required this.value,
    required this.animationValue,
    required this.fillColor,
    required this.trackColor,
    required this.glassTheme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _CircularLiquidPainter(
          value: value,
          animationValue: animationValue,
          fillColor: fillColor,
          trackColor: trackColor,
        ),
      ),
    );
  }
}

class _CircularLiquidPainter extends CustomPainter {
  final double? value;
  final double animationValue;
  final Color fillColor;
  final Color trackColor;

  _CircularLiquidPainter({
    required this.value,
    required this.animationValue,
    required this.fillColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 3;
    const strokeWidth = 4.0;

    // Draw track ring.
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw fill arc.
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (value != null) {
      // Determinate: arc sweep with wobble.
      final sweepAngle = 2 * math.pi * value!;
      if (sweepAngle <= 0) return;

      // Wobble effect: slight radius variation.
      final wobble = math.sin(animationValue * 2 * math.pi) * 0.5;
      fillPaint.strokeWidth = strokeWidth + wobble;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start from top.
        sweepAngle,
        false,
        fillPaint,
      );
    } else {
      // Indeterminate: rotating arc with varying length.
      final startAngle = animationValue * 2 * math.pi * 2 - math.pi / 2;
      final sweepAngle =
          math.pi * (0.5 + 0.5 * math.sin(animationValue * 2 * math.pi));

      // Wobble effect.
      final wobble = math.sin(animationValue * 4 * math.pi) * 0.8;
      fillPaint.strokeWidth = strokeWidth + wobble;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularLiquidPainter oldDelegate) {
    return value != oldDelegate.value ||
        animationValue != oldDelegate.animationValue ||
        fillColor != oldDelegate.fillColor ||
        trackColor != oldDelegate.trackColor;
  }
}
