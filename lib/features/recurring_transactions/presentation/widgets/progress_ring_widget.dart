import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Animated circular progress ring that displays days remaining until
/// the next recurring transaction execution.
///
/// Uses [CustomPainter] for the ring and [TweenAnimationBuilder] for
/// smooth animation when the progress value changes.
///
/// - [progress]: 0.0 (about to execute) to 1.0 (just executed).
/// - [daysRemaining]: number of days shown in the center label.
/// - [size]: diameter of the ring widget (default 48).
class ProgressRingWidget extends StatelessWidget {
  const ProgressRingWidget({
    super.key,
    required this.progress,
    required this.daysRemaining,
    this.size = 48,
  });

  /// Progress value from [computeProgressRing]: 1.0 = full ring (just
  /// executed), 0.0 = empty ring (about to execute).
  final double progress;

  /// Number of days remaining until next execution.
  final int daysRemaining;

  /// Diameter of the ring widget.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ringBackground = colorScheme.onSurface.withValues(alpha: 0.1);
    final ringForeground = colorScheme.primary;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, child) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: animatedProgress,
              backgroundColor: ringBackground,
              foregroundColor: ringForeground,
              strokeWidth: size * 0.1,
            ),
            child: child,
          ),
        );
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$daysRemaining',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: size * 0.22,
                height: 1,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'recurring.days_label'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: size * 0.15,
                height: 1.2,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that draws a circular progress ring.
///
/// The ring starts at the top (12 o'clock position) and sweeps clockwise.
class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color backgroundColor;
  final Color foregroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw background ring.
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw foreground progress arc.
    if (progress > 0) {
      final foregroundPaint = Paint()
        ..color = foregroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // Start from top (12 o'clock).
        sweepAngle,
        false,
        foregroundPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.foregroundColor != foregroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
