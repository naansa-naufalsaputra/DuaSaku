import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../domain/models/execution_log_model.dart';
import '../../domain/models/recurring_status.dart';
import '../../domain/models/recurring_transaction_model.dart';
import '../../domain/recurring_scheduler_logic.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../widgets/edit_recurring_bottom_sheet.dart';

/// Provider for execution logs of a specific recurring transaction.
/// Returns the last 5 execution logs for the timeline display.
final executionLogsProvider = FutureProvider.autoDispose
    .family<List<ExecutionLogModel>, String>((ref, recurringId) async {
  final repo = ref.watch(recurringTransactionRepositoryProvider);
  return repo.getExecutionLogs(recurringId, limit: 5);
});

/// Detail screen for a single recurring transaction.
///
/// Displays full transaction details, execution timeline (past + upcoming),
/// and provides edit/pause/resume actions.
///
/// Uses Hero transition from the list card for smooth navigation.
class RecurringTransactionDetailScreen extends ConsumerWidget {
  const RecurringTransactionDetailScreen({
    super.key,
    required this.recurringTransactionId,
  });

  final String recurringTransactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transactionAsync =
        ref.watch(recurringTransactionByIdProvider(recurringTransactionId));

    // Handle fallback: if transaction is not found (deleted), redirect to list with message.
    // This handles the case when a notification is tapped for a deleted recurring transaction.
    ref.listen<AsyncValue<RecurringTransactionModel?>>(
      recurringTransactionByIdProvider(recurringTransactionId),
      (previous, next) {
        if (next is AsyncData<RecurringTransactionModel?> &&
            next.value == null) {
          // Transaction not found (deleted) — navigate to list and show message
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              final router = GoRouter.of(context);
              router.go('/recurring-transactions');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('recurring.deleted_fallback_message'.tr()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text('recurring.detail_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'recurring.btn_edit'.tr(),
            onPressed: () {
              HapticFeedback.lightImpact();
              final transaction = transactionAsync.valueOrNull;
              if (transaction != null) {
                EditRecurringBottomSheet.show(context, transaction);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: transactionAsync.when(
              data: (transaction) {
                if (transaction == null) {
                  return _NotFoundState(isDark: isDark, theme: theme);
                }
                return _DetailContent(
                  transaction: transaction,
                  isDark: isDark,
                  theme: theme,
                  recurringTransactionId: recurringTransactionId,
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'recurring.error_loading'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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
              'recurring.not_found'.tr(),
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
  final RecurringTransactionModel transaction;
  final bool isDark;
  final ThemeData theme;
  final String recurringTransactionId;

  const _DetailContent({
    required this.transaction,
    required this.isDark,
    required this.theme,
    required this.recurringTransactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final isIncome = transaction.isIncome;
    final amountColor = isIncome
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card with amount
          Hero(
            tag: 'recurring_card_${transaction.id}',
            child: Material(
              color: Colors.transparent,
              child: _AmountCard(
                transaction: transaction,
                currencyFormat: currencyFormat,
                amountColor: amountColor,
                isDark: isDark,
                theme: theme,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Status and action buttons
          _StatusSection(
            transaction: transaction,
            isDark: isDark,
            theme: theme,
            recurringTransactionId: recurringTransactionId,
          ),
          const SizedBox(height: 20),

          // Execution Timeline
          _ExecutionTimelineSection(
            transaction: transaction,
            isDark: isDark,
            theme: theme,
            recurringTransactionId: recurringTransactionId,
          ),
          const SizedBox(height: 20),

          // Details section
          _DetailsSection(
            transaction: transaction,
            dateFormat: dateFormat,
            currencyFormat: currencyFormat,
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
}

// ─── Amount Card (Hero element) ───────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  final RecurringTransactionModel transaction;
  final NumberFormat currencyFormat;
  final Color amountColor;
  final bool isDark;
  final ThemeData theme;

  const _AmountCard({
    required this.transaction,
    required this.currencyFormat,
    required this.amountColor,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.6)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: amountColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Type icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: amountColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: amountColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          // Amount
          Text(
            '${isIncome ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
            style: TextStyle(
              color: amountColor,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Name/notes
          Text(
            transaction.notes ?? transaction.frequency.label,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Type label
          Text(
            isIncome
                ? 'recurring.type_income'.tr()
                : 'recurring.type_expense'.tr(),
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Section ───────────────────────────────────────────────────────────

class _StatusSection extends ConsumerWidget {
  final RecurringTransactionModel transaction;
  final bool isDark;
  final ThemeData theme;
  final String recurringTransactionId;

  const _StatusSection({
    required this.transaction,
    required this.isDark,
    required this.theme,
    required this.recurringTransactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor(transaction.status);
    final statusLabel = _getStatusLabel(transaction.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.6)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Pause/Resume button
          if (transaction.status != RecurringStatus.completed)
            _PauseResumeButton(
              transaction: transaction,
              recurringTransactionId: recurringTransactionId,
              isDark: isDark,
              theme: theme,
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

  String _getStatusLabel(RecurringStatus status) {
    return switch (status) {
      RecurringStatus.active => 'recurring.status_active'.tr(),
      RecurringStatus.paused => 'recurring.status_paused'.tr(),
      RecurringStatus.completed => 'recurring.status_completed'.tr(),
    };
  }
}

// ─── Pause/Resume Button ──────────────────────────────────────────────────────

class _PauseResumeButton extends ConsumerWidget {
  final RecurringTransactionModel transaction;
  final String recurringTransactionId;
  final bool isDark;
  final ThemeData theme;

  const _PauseResumeButton({
    required this.transaction,
    required this.recurringTransactionId,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = transaction.status == RecurringStatus.active;

    return FilledButton.icon(
      onPressed: () async {
        HapticFeedback.lightImpact();
        final notifier =
            ref.read(recurringTransactionNotifierProvider.notifier);
        if (isActive) {
          await notifier.pause(recurringTransactionId);
        } else {
          await notifier.resume(recurringTransactionId);
        }
      },
      icon: Icon(
        isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
        size: 18,
      ),
      label: Text(
        isActive
            ? 'recurring.btn_pause'.tr()
            : 'recurring.btn_resume'.tr(),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: isActive
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.green.withValues(alpha: 0.15),
        foregroundColor: isActive ? Colors.orange : Colors.green,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}

// ─── Execution Timeline Section ───────────────────────────────────────────────

class _ExecutionTimelineSection extends ConsumerWidget {
  final RecurringTransactionModel transaction;
  final bool isDark;
  final ThemeData theme;
  final String recurringTransactionId;

  const _ExecutionTimelineSection({
    required this.transaction,
    required this.isDark,
    required this.theme,
    required this.recurringTransactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(executionLogsProvider(recurringTransactionId));

    // Compute upcoming dates (max 5)
    final upcomingDates = RecurringSchedulerLogic.computePreviewDates(
      startDate: transaction.nextExecutionDate,
      frequency: transaction.frequency,
      customInterval: transaction.customInterval,
      count: 5,
      endDate: transaction.endDate,
    );

    // Include the next execution date itself as the first upcoming
    final allUpcoming = [transaction.nextExecutionDate, ...upcomingDates];
    final displayUpcoming =
        allUpcoming.length > 5 ? allUpcoming.sublist(0, 5) : allUpcoming;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.6)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.execution_timeline'.tr(),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Past executions
          logsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'recurring.no_past_executions'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              return Column(
                children: logs.reversed.map((log) {
                  return _TimelineItem(
                    date: log.executedAt,
                    isPast: true,
                    isSuccess: log.isSuccess,
                    isDark: isDark,
                    theme: theme,
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
          ),

          // Divider between past and upcoming
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'recurring.upcoming'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),

          // Upcoming executions
          if (transaction.status == RecurringStatus.completed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'recurring.completed_no_upcoming'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Column(
              children: displayUpcoming.map((date) {
                return _TimelineItem(
                  date: date,
                  isPast: false,
                  isSuccess: true,
                  isDark: isDark,
                  theme: theme,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ─── Timeline Item ────────────────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  final DateTime date;
  final bool isPast;
  final bool isSuccess;
  final bool isDark;
  final ThemeData theme;

  const _TimelineItem({
    required this.date,
    required this.isPast,
    required this.isSuccess,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final dotColor = isPast
        ? (isSuccess ? Colors.green : Colors.red)
        : theme.colorScheme.primary.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Timeline dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: isPast
                  ? null
                  : Border.all(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Date text
          Expanded(
            child: Text(
              dateFormat.format(date),
              style: TextStyle(
                color: isPast
                    ? (isDark ? Colors.white70 : Colors.black54)
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 13,
                fontWeight: isPast ? FontWeight.normal : FontWeight.w500,
              ),
            ),
          ),
          // Status indicator for past items
          if (isPast)
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              size: 16,
              color: isSuccess ? Colors.green : Colors.red,
            ),
          // Scheduled indicator for upcoming items
          if (!isPast)
            Icon(
              Icons.schedule_rounded,
              size: 16,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
  }
}

// ─── Details Section ──────────────────────────────────────────────────────────

class _DetailsSection extends StatelessWidget {
  final RecurringTransactionModel transaction;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;
  final bool isDark;
  final ThemeData theme;

  const _DetailsSection({
    required this.transaction,
    required this.dateFormat,
    required this.currencyFormat,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final frequencyLabel = _buildFrequencyLabel();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surface.withValues(alpha: 0.6)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.details_section'.tr(),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            label: 'recurring.detail_amount'.tr(),
            value: currencyFormat.format(transaction.amount),
            isDark: isDark,
            theme: theme,
          ),
          _DetailRow(
            label: 'recurring.detail_type'.tr(),
            value: transaction.isIncome
                ? 'recurring.type_income'.tr()
                : 'recurring.type_expense'.tr(),
            isDark: isDark,
            theme: theme,
          ),
          _DetailRow(
            label: 'recurring.detail_frequency'.tr(),
            value: frequencyLabel,
            isDark: isDark,
            theme: theme,
          ),
          if (transaction.customInterval > 1)
            _DetailRow(
              label: 'recurring.detail_interval'.tr(),
              value: '${transaction.customInterval}',
              isDark: isDark,
              theme: theme,
            ),
          _DetailRow(
            label: 'recurring.detail_start_date'.tr(),
            value: dateFormat.format(transaction.startDate),
            isDark: isDark,
            theme: theme,
          ),
          if (transaction.endDate != null)
            _DetailRow(
              label: 'recurring.detail_end_date'.tr(),
              value: dateFormat.format(transaction.endDate!),
              isDark: isDark,
              theme: theme,
            ),
          _DetailRow(
            label: 'recurring.detail_next_execution'.tr(),
            value: dateFormat.format(transaction.nextExecutionDate),
            isDark: isDark,
            theme: theme,
          ),
          _DetailRow(
            label: 'recurring.detail_status'.tr(),
            value: transaction.status.name,
            isDark: isDark,
            theme: theme,
          ),
          if (transaction.notes != null && transaction.notes!.isNotEmpty)
            _DetailRow(
              label: 'recurring.detail_notes'.tr(),
              value: transaction.notes!,
              isDark: isDark,
              theme: theme,
            ),
          _DetailRow(
            label: 'recurring.detail_created_at'.tr(),
            value: dateFormat.format(transaction.createdAt),
            isDark: isDark,
            theme: theme,
            isLast: true,
          ),
        ],
      ),
    );
  }

  String _buildFrequencyLabel() {
    final base = transaction.frequency.label;
    if (transaction.customInterval > 1) {
      return '${'recurring.every'.tr()} ${transaction.customInterval} $base';
    }
    return base;
  }
}

// ─── Detail Row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final ThemeData theme;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
    required this.theme,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
