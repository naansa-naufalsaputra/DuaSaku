import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/widgets/glass/glass_button.dart';
import '../../domain/models/recurring_transaction_model.dart';
import '../../domain/models/recurring_status.dart';
import '../../domain/recurring_scheduler_logic.dart';
import '../../providers/recurring_transaction_provider.dart';
import 'progress_ring_widget.dart';

/// Card widget displaying a single recurring transaction with:
/// - Next execution date, frequency badge, amount (color-coded), status badge
/// - Progress ring showing days remaining proportion
/// - Scale bounce micro-interaction on tap
/// - Swipe-right for pause/resume with haptic feedback
/// - Swipe-left for delete with confirmation dialog
///
/// Requirements: 3.3, 3.4, 3.5, 3.6, 3.7, 3.9, 3.10, 6.5, 6.6, 6.7
class RecurringTransactionCard extends ConsumerWidget {
  const RecurringTransactionCard({
    super.key,
    required this.transaction,
  });

  final RecurringTransactionModel transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Compute progress ring value
    final now = DateTime.now();
    final lastExecution = transaction.startDate;
    final nextExecution = transaction.nextExecutionDate;
    final progress = RecurringSchedulerLogic.computeProgressRing(
      lastExecutionDate: lastExecution,
      nextExecutionDate: nextExecution,
      now: now,
    );
    final daysRemaining = nextExecution.difference(now).inDays;

    return Dismissible(
      key: ValueKey(transaction.id),
      // Swipe right → pause/resume
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _handlePauseResume(context, ref);
          return false; // Don't actually dismiss
        } else if (direction == DismissDirection.endToStart) {
          return _showDeleteConfirmation(context, ref);
        }
        return false;
      },
      // Only allow swipe if not completed
      direction: transaction.status == RecurringStatus.completed
          ? DismissDirection.none
          : DismissDirection.horizontal,
      movementDuration: const Duration(milliseconds: 250),
      // Swipe-right background (pause/resume)
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: transaction.status == RecurringStatus.active
            ? Colors.orange
            : Colors.green,
        icon: transaction.status == RecurringStatus.active
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
        label: transaction.status == RecurringStatus.active
            ? 'recurring.action_pause'.tr()
            : 'recurring.action_resume'.tr(),
      ),
      // Swipe-left background (delete)
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: colorScheme.error,
        icon: Icons.delete_rounded,
        label: 'recurring.action_delete'.tr(),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          // Navigate to detail view
        },
        child: _CardContent(
          transaction: transaction,
          progress: progress,
          daysRemaining: daysRemaining.clamp(0, 9999),
          isDark: isDark,
          colorScheme: colorScheme,
          theme: theme,
        )
            .animate(onPlay: (controller) => controller.forward())
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.0, 1.0),
              duration: 200.ms,
              curve: Curves.easeOutCubic,
            ),
      ),
    );
  }

  /// Handle pause/resume swipe action with haptic feedback.
  Future<void> _handlePauseResume(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final notifier =
        ref.read(recurringTransactionNotifierProvider.notifier);

    if (transaction.status == RecurringStatus.active) {
      await notifier.pause(transaction.id);
    } else if (transaction.status == RecurringStatus.paused) {
      await notifier.resume(transaction.id);
    }
  }

  /// Show delete confirmation dialog. Returns true if user confirms.
  Future<bool> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('recurring.delete_title'.tr()),
        content: Text('recurring.delete_message'.tr()),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          GlassButton(
            variant: GlassButtonVariant.text,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('recurring.cancel'.tr()),
          ),
          GlassButton(
            variant: GlassButtonVariant.text,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('recurring.delete_confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final notifier =
          ref.read(recurringTransactionNotifierProvider.notifier);
      await notifier.delete(transaction.id);
      return true;
    }
    return false;
  }
}

// ─── Card Content ─────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.transaction,
    required this.progress,
    required this.daysRemaining,
    required this.isDark,
    required this.colorScheme,
    required this.theme,
  });

  final RecurringTransactionModel transaction;
  final double progress;
  final int daysRemaining;
  final bool isDark;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final amountColor = isIncome
        ? colorScheme.primary
        : colorScheme.error;
    final statusColor = _getStatusColor(transaction.status);
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Row(
        children: [
          // Progress ring
          ProgressRingWidget(
            progress: progress,
            daysRemaining: daysRemaining,
            size: 48,
          ),
          const SizedBox(width: 12),
          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title / notes
                Text(
                  transaction.notes ?? 'recurring.unnamed'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Next execution date
                Text(
                  '${'recurring.next_execution'.tr()} ${dateFormat.format(transaction.nextExecutionDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? Colors.white60
                        : Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                // Badges row
                Row(
                  children: [
                    // Frequency badge
                    _Badge(
                      label: transaction.frequency.label,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    // Status badge
                    _Badge(
                      label: transaction.status.name,
                      color: statusColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount
          Text(
            '${isIncome ? '+' : '-'}${formatCurrency.format(transaction.amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(RecurringStatus status) {
    return switch (status) {
      RecurringStatus.active => Colors.green,
      RecurringStatus.paused => Colors.orange,
      RecurringStatus.completed => Colors.grey,
    };
  }
}

// ─── Badge Widget ─────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── Swipe Background ─────────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignment == Alignment.centerLeft
            ? [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ]
            : [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color, size: 24),
              ],
      ),
    );
  }
}
