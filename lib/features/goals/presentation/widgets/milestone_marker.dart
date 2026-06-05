import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Individual milestone indicator widget displayed on the progress bar.
///
/// Shows a small diamond/circle at the milestone position with different
/// visual states for reached vs unreached milestones. Plays a celebration
/// animation (scale + glow) when the milestone is newly reached.
///
/// Requirements: 5.2, 5.3
class MilestoneMarker extends StatelessWidget {
  const MilestoneMarker({
    super.key,
    required this.milestone,
    required this.isReached,
    required this.isNotified,
    this.color,
  });

  /// The milestone percentage (25, 50, 75, or 100).
  final int milestone;

  /// Whether the progress has reached this milestone threshold.
  final bool isReached;

  /// Whether the milestone notification has already been sent.
  /// When [isReached] is true and [isNotified] is false, the celebration
  /// animation plays (newly reached milestone).
  final bool isNotified;

  /// Optional color override for the reached state.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final markerColor = isReached
        ? (color ?? colorScheme.primary)
        : colorScheme.onSurface.withValues(alpha: 0.2);

    final markerSize = milestone == 100 ? 14.0 : 10.0;

    Widget marker = Container(
      width: markerSize,
      height: markerSize,
      decoration: BoxDecoration(
        color: isReached ? markerColor : Colors.transparent,
        border: Border.all(color: markerColor, width: isReached ? 2.0 : 1.5),
        shape: milestone == 100 ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: milestone != 100 ? BorderRadius.circular(3) : null,
        boxShadow: isReached
            ? [
                BoxShadow(
                  color: markerColor.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );

    // Celebration animation for newly reached milestones
    if (isReached && !isNotified) {
      marker = marker
          .animate(onPlay: (controller) => controller.forward())
          .scale(
            begin: const Offset(0.5, 0.5),
            end: const Offset(1.0, 1.0),
            duration: 400.ms,
            curve: Curves.elasticOut,
          )
          .then()
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.2, 1.2),
            duration: 200.ms,
            curve: Curves.easeOut,
          )
          .then()
          .scale(
            begin: const Offset(1.2, 1.2),
            end: const Offset(1.0, 1.0),
            duration: 200.ms,
            curve: Curves.easeIn,
          );
    }

    return Tooltip(message: '$milestone%', child: marker);
  }
}
