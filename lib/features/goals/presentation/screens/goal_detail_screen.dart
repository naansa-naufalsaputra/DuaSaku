import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../domain/models/goal_deposit_model.dart';
import '../../domain/models/goal_model.dart';
import '../../domain/models/goal_status.dart';
import '../../providers/goal_provider.dart';
import '../widgets/deposit_history_tile.dart';
import '../widgets/goal_progress_bar.dart';

import '../../../../core/providers/settings_provider.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// StreamProvider that watches deposits for a specific goal.
/// StreamProvider that watches deposits for a specific goal.
final goalDepositsProvider = StreamProvider.autoDispose
    .family<List<GoalDepositModel>, String>((ref, goalId) {
      final repository = ref.watch(goalRepositoryProvider);
      return repository.watchDeposits(goalId);
    });

/// Provider that finds a specific goal by ID from the goal list.
final goalByIdProvider = Provider.autoDispose.family<GoalModel?, String>((
  ref,
  goalId,
) {
  final goalsAsync = ref.watch(goalNotifierProvider);
  return goalsAsync.valueOrNull?.where((g) => g.id == goalId).firstOrNull;
});

// ---------------------------------------------------------------------------
// GoalDetailScreen
// ---------------------------------------------------------------------------

/// Detail screen for a single financial goal.
///
/// Displays full progress visualization with milestone markers, deposit
/// history list, and action buttons (Add Deposit, Edit, Archive, Delete).
/// Shows a celebration animation when the goal is 100% complete.
///
/// Requirements: 2.5, 5.1, 5.2, 5.4
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  /// The ID of the goal to display.
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goal = ref.watch(goalByIdProvider(goalId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: Text('goals.detail_title'.tr())),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: goal == null
                ? _NotFoundState(isDark: isDark, theme: theme)
                : _DetailContent(goal: goal, isDark: isDark, theme: theme),
          ),
        ],
      ),
    );
  }
}

// ─── Not Found State ──────────────────────────────────────────────────────────

class _NotFoundState extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _NotFoundState({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'goals.detail_title'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Content ───────────────────────────────────────────────────────────

class _DetailContent extends ConsumerWidget {
  final GoalModel goal;
  final bool isDark;
  final ThemeData theme;

  const _DetailContent({
    required this.goal,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = theme.colorScheme;
    final goalColor = _parseColor(goal.color) ?? colorScheme.primary;
    final currencyFormat = ref.watch(currencyFormatterProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            [
                  // Goal header card
                  _GoalHeaderCard(
                    goal: goal,
                    goalColor: goalColor,
                    currencyFormat: currencyFormat,
                    isDark: isDark,
                    theme: theme,
                  ),
                  const SizedBox(height: 20),

                  // Progress section
                  _ProgressSection(
                    goal: goal,
                    goalColor: goalColor,
                    isDark: isDark,
                    theme: theme,
                  ),
                  const SizedBox(height: 20),

                  // Celebration animation for completed goals
                  if (goal.progressPercentage >= 1.0)
                    _CelebrationSection(
                      goalColor: goalColor,
                      isDark: isDark,
                      theme: theme,
                    ),

                  if (goal.progressPercentage >= 1.0)
                    const SizedBox(height: 20),

                  // Action buttons
                  _ActionButtonsSection(
                    goal: goal,
                    goalColor: goalColor,
                    isDark: isDark,
                    theme: theme,
                  ),
                  const SizedBox(height: 20),

                  // Deposit history
                  _DepositHistorySection(
                    goal: goal,
                    goalColor: goalColor,
                    isDark: isDark,
                    theme: theme,
                  ),
                ]
                .animate(interval: 80.ms)
                .fadeIn(duration: 300.ms, curve: Curves.easeOutCubic)
                .slideY(
                  begin: 0.05,
                  end: 0,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
      ),
    );
  }

  /// Parses a hex color string (e.g. "FF6B6B" or "#FF6B6B") to a [Color].
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

// ─── Goal Header Card ─────────────────────────────────────────────────────────

class _GoalHeaderCard extends StatelessWidget {
  final GoalModel goal;
  final Color goalColor;
  final NumberFormat currencyFormat;
  final bool isDark;
  final ThemeData theme;

  const _GoalHeaderCard({
    required this.goal,
    required this.goalColor,
    required this.currencyFormat,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final remainingDays = goal.remainingDays;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.6)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goalColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Goal icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: goalColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(goal.icon, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(height: 16),

          // Goal name
          Text(
            goal.name,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Amount: current / target
          Text(
            currencyFormat.format(goal.currentAmount),
            style: TextStyle(
              color: goalColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'goals.of_target'.tr(
              args: [currencyFormat.format(goal.targetAmount)],
            ),
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // Status and deadline info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Tracking mode badge
              _InfoBadge(
                icon: goal.trackingMode == TrackingMode.wallet
                    ? Icons.account_balance_wallet_rounded
                    : Icons.touch_app_rounded,
                label: goal.trackingMode == TrackingMode.wallet
                    ? 'goals.tracking_wallet'.tr()
                    : 'goals.tracking_manual'.tr(),
                color: goalColor,
                isDark: isDark,
                theme: theme,
              ),
              const SizedBox(width: 8),
              // Deadline badge
              _InfoBadge(
                icon: Icons.calendar_today_rounded,
                label: remainingDays != null
                    ? (remainingDays >= 0
                          ? 'goals.detail_remaining'.tr(
                              args: [remainingDays.toString()],
                            )
                          : 'goals.overdue'.tr())
                    : 'goals.detail_no_deadline'.tr(),
                color: remainingDays != null && remainingDays < 0
                    ? theme.colorScheme.error
                    : goalColor,
                isDark: isDark,
                theme: theme,
              ),
            ],
          ),

          // Completed at info
          if (goal.isCompleted && goal.completedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'goals.detail_completed_at'.tr(
                args: [
                  DateFormat('dd MMM yyyy', 'id_ID').format(goal.completedAt!),
                ],
              ),
              style: TextStyle(
                color: Colors.green.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Info Badge ───────────────────────────────────────────────────────────────

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final ThemeData theme;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress Section ─────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final GoalModel goal;
  final Color goalColor;
  final bool isDark;
  final ThemeData theme;

  const _ProgressSection({
    required this.goal,
    required this.goalColor,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final progressPercent = (goal.progressPercentage * 100).toInt();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.6)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'goals.progress_percentage'.tr(
                  args: [progressPercent.toString()],
                ),
                style: TextStyle(
                  color: goalColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (goal.status == GoalStatus.completed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'goals.tab_completed'.tr(),
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GoalProgressBar(
            progress: goal.progressPercentage,
            notifiedMilestones: goal.notifiedMilestones,
            color: goalColor,
            height: 10.0,
          ),
        ],
      ),
    );
  }
}

// ─── Celebration Section ──────────────────────────────────────────────────────

class _CelebrationSection extends StatelessWidget {
  final Color goalColor;
  final bool isDark;
  final ThemeData theme;

  const _CelebrationSection({
    required this.goalColor,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.6)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withValues(alpha: 0.05),
            goalColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        children: [
          // Celebration icon with animation
          const Icon(Icons.emoji_events_rounded, size: 48, color: Colors.amber)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.1, 1.1),
                duration: 1000.ms,
                curve: Curves.easeInOut,
              )
              .shimmer(
                duration: 2000.ms,
                color: Colors.amber.withValues(alpha: 0.3),
              ),
          const SizedBox(height: 12),
          const Text('🎉', style: TextStyle(fontSize: 32))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .shake(hz: 2, duration: 1500.ms),
          const SizedBox(height: 8),
          Text(
            'goals.notification_completion'.tr(args: ['']).trim(),
            style: TextStyle(
              color: Colors.amber.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Action Buttons Section ───────────────────────────────────────────────────

class _ActionButtonsSection extends ConsumerWidget {
  final GoalModel goal;
  final Color goalColor;
  final bool isDark;
  final ThemeData theme;

  const _ActionButtonsSection({
    required this.goal,
    required this.goalColor,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.6)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Add Deposit button (only for active manual goals)
          if (goal.status == GoalStatus.active &&
              goal.trackingMode == TrackingMode.manual)
            _ActionButton(
              icon: Icons.add_rounded,
              label: 'goals.deposit_title'.tr(),
              color: goalColor,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/goals/${goal.id}/deposit', extra: goal);
              },
            ),

          // Edit button
          if (goal.status == GoalStatus.active)
            _ActionButton(
              icon: Icons.edit_rounded,
              label: 'goals.action_edit'.tr(),
              color: colorScheme.primary,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/goals/${goal.id}/edit', extra: goal);
              },
            ),

          // Archive button (only for active goals)
          if (goal.status == GoalStatus.active)
            _ActionButton(
              icon: Icons.archive_rounded,
              label: 'goals.action_archive'.tr(),
              color: Colors.orange,
              onPressed: () {
                HapticFeedback.lightImpact();
                _showArchiveConfirmation(context, ref);
              },
            ),

          // Delete button
          _ActionButton(
            icon: Icons.delete_rounded,
            label: 'goals.action_delete'.tr(),
            color: colorScheme.error,
            onPressed: () {
              HapticFeedback.lightImpact();
              _showDeleteConfirmation(context, ref);
            },
          ),
        ],
      ),
    );
  }

  void _showArchiveConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('goals.confirm_archive_title'.tr()),
        content: Text('goals.confirm_archive_message'.tr()),
        actions: [
          GlassButton(
            variant: GlassButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('goals.confirm_delete_no'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref
                  .read(goalNotifierProvider.notifier)
                  .archiveGoal(goal.id);
              if (context.mounted) {
                context.pop();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('goals.action_archive'.tr()),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('goals.confirm_delete_title'.tr()),
        content: Text('goals.confirm_delete_message'.tr()),
        actions: [
          GlassButton(
            variant: GlassButtonVariant.text,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('goals.confirm_delete_no'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(goalNotifierProvider.notifier).deleteGoal(goal.id);
              if (context.mounted) {
                context.pop();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: Text('goals.confirm_delete_yes'.tr()),
          ),
        ],
      ),
    );
  }
}

// ─── Action Button ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

// ─── Deposit History Section ──────────────────────────────────────────────────

class _DepositHistorySection extends ConsumerWidget {
  final GoalModel goal;
  final Color goalColor;
  final bool isDark;
  final ThemeData theme;

  const _DepositHistorySection({
    required this.goal,
    required this.goalColor,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = theme.colorScheme;
    final depositsAsync = ref.watch(goalDepositsProvider(goal.id));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.6)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'goals.detail_deposit_history'.tr(),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          depositsAsync.when(
            data: (deposits) {
              if (deposits.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 32,
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'goals.detail_no_deposits'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Sort deposits by date (newest first)
              final sortedDeposits = List<GoalDepositModel>.from(deposits)
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return Column(
                children: sortedDeposits.asMap().entries.map((entry) {
                  final index = entry.key;
                  final deposit = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < sortedDeposits.length - 1 ? 8 : 0,
                    ),
                    child: DepositHistoryTile(
                      deposit: deposit,
                      goalColor: goalColor,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'goals.error_loading'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
