import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'milestone_marker.dart';

/// Animated progress bar widget with milestone markers at 25/50/75/100%.
///
/// Displays a linear progress bar that animates from 0 to the current progress
/// on first render. Milestone markers are positioned at their respective
/// percentage points along the bar.
///
/// Requirements: 5.1, 5.2, 5.3
class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.progress,
    required this.notifiedMilestones,
    this.color,
    this.height = 8.0,
  });

  /// Progress value between 0.0 and 1.0.
  final double progress;

  /// Set of milestones that have already been notified (25, 50, 75, 100).
  final Set<int> notifiedMilestones;

  /// Color for the progress bar fill. Falls back to theme primary if null.
  final Color? color;

  /// Height of the progress bar track.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final barColor = color ?? colorScheme.primary;
    final trackColor = colorScheme.onSurface.withValues(alpha: 0.08);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar with milestone markers overlay
        SizedBox(
          height: 24,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;

              return Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  // Track background
                  Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: trackColor,
                      borderRadius: BorderRadius.circular(height / 2),
                    ),
                  ),

                  // Animated fill
                  _AnimatedProgressFill(
                    progress: progress,
                    color: barColor,
                    height: height,
                  ),

                  // Milestone markers
                  for (final milestone in const [25, 50, 75, 100])
                    Positioned(
                      left:
                          (totalWidth * milestone / 100) -
                          (milestone == 100 ? 7 : 5),
                      child: MilestoneMarker(
                        milestone: milestone,
                        isReached: progress >= milestone / 100,
                        isNotified: notifiedMilestones.contains(milestone),
                        color: barColor,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Internal widget that handles the animated fill of the progress bar.
class _AnimatedProgressFill extends StatelessWidget {
  const _AnimatedProgressFill({
    required this.progress,
    required this.color,
    required this.height,
  });

  final double progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillWidth = constraints.maxWidth * progress.clamp(0.0, 1.0);

        return Container(
              height: height,
              width: fillWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.8), color],
                ),
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: progress > 0
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            )
            .animate(onPlay: (controller) => controller.forward())
            .scaleX(
              begin: 0.0,
              end: 1.0,
              alignment: Alignment.centerLeft,
              duration: 800.ms,
              curve: Curves.easeOutCubic,
            )
            .fadeIn(duration: 400.ms);
      },
    );
  }
}
