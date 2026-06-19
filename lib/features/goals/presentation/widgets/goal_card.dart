import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/models/goal_model.dart';
import 'goal_progress_bar.dart';

import '../../../../core/providers/settings_provider.dart';

/// Card widget displaying a goal summary with progress visualization.
///
/// Shows the goal name, icon, current/target amount (formatted as currency),
/// progress percentage, remaining days (if deadline exists), and an animated
/// progress bar with milestone markers.
///
/// Uses [ConsumerWidget] for Riverpod access (navigation).
///
/// Requirements: 2.2, 5.1, 5.2, 5.3
class GoalCard extends ConsumerWidget {
  const GoalCard({super.key, required this.goal, this.onTap});

  /// The goal model to display.
  final GoalModel goal;

  /// Callback when the card is tapped. If null, navigation is handled
  /// internally via GoRouter.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final goalColor = _parseColor(goal.color) ?? colorScheme.primary;
    final currencyFormat = ref.watch(currencyFormatterProvider);

    final progressPercent = (goal.progressPercentage * 100).toInt();
    final remainingDays = goal.remainingDays;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon + Name + Progress %
            Row(
              children: [
                // Goal icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: goalColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      goal.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name and remaining days
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (remainingDays != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          remainingDays >= 0
                              ? 'goals.remaining_days'.tr(
                                  args: [remainingDays.toString()],
                                )
                              : 'goals.overdue'.tr(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: remainingDays >= 0
                                ? colorScheme.onSurface.withValues(alpha: 0.6)
                                : colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Progress percentage badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: goalColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$progressPercent%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: goalColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar
            GoalProgressBar(
              progress: goal.progressPercentage,
              notifiedMilestones: goal.notifiedMilestones,
              color: goalColor,
            ),

            const SizedBox(height: 12),

            // Amount row: current / target
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormat.format(goal.currentAmount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: goalColor,
                  ),
                ),
                Text(
                  'goals.of_target'.tr(
                    args: [currencyFormat.format(goal.targetAmount)],
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Parses a hex color string (e.g. "FF6B6B" or "#FF6B6B") to a [Color].
  /// Returns null if parsing fails.
  Color? _parseColor(String colorHex) {
    if (colorHex.isEmpty) return null;
    try {
      String hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse('0x$hex'));
    } catch (_) {
      return null;
    }
  }
}
