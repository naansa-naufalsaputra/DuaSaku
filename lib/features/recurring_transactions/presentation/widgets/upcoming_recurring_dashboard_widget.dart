import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/recurring_transaction_model.dart';
import '../../providers/recurring_transaction_provider.dart';
import '../../../../core/providers/settings_provider.dart';

/// Dashboard widget displaying up to 5 upcoming recurring transactions
/// within 7 days on the home screen.
///
/// Hides the section entirely if no upcoming transactions exist within 7 days.
///
/// Requirements: 5.2, 5.3
class UpcomingRecurringDashboardWidget extends ConsumerWidget {
  const UpcomingRecurringDashboardWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingRecurringProvider);

    return upcomingAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final accentColor = isDark
            ? const Color(0xFF0A84FF)
            : const Color(0xFF007AFF);

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'recurring.upcoming_dashboard_title'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/recurring-transactions');
                      },
                      child: Text(
                        'common.see_all'.tr(),
                        style: TextStyle(
                          fontSize: 13,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Transaction items
              ...transactions.asMap().entries.map((entry) {
                final index = entry.key;
                final transaction = entry.value;
                return _UpcomingItem(transaction: transaction, isDark: isDark)
                    .animate()
                    .fadeIn(
                      delay: Duration(milliseconds: index * 50),
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .slideY(
                      begin: 0.05,
                      end: 0,
                      delay: Duration(milliseconds: index * 50),
                      duration: 300.ms,
                      curve: Curves.easeOutCubic,
                    );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ─── Upcoming Item Card ───────────────────────────────────────────────────────

class _UpcomingItem extends ConsumerWidget {
  const _UpcomingItem({required this.transaction, required this.isDark});

  final RecurringTransactionModel transaction;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? colorScheme.primary : colorScheme.error;

    final currencyFormat = ref.watch(currencyFormatterProvider);
    final dateFormat = DateFormat('dd MMM', 'id_ID');

    final name = transaction.notes ?? transaction.frequency.label;
    final formattedAmount =
        '${isIncome ? '+' : '-'}${currencyFormat.format(transaction.amount)}';
    final formattedDate = dateFormat.format(transaction.nextExecutionDate);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/recurring-transactions/${transaction.id}');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            // Leading icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: amountColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Name and date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white54 : Colors.black45,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              formattedAmount,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
