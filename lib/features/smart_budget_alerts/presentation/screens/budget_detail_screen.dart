import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../transactions/providers/budget_provider.dart';
import '../../domain/models/budget_alert_model.dart';

/// Data class passed via GoRouter `extra` for projection info display.
class BudgetDetailExtra {
  final BudgetAlertModel alert;
  final bool showProjection;

  const BudgetDetailExtra({required this.alert, this.showProjection = false});
}

/// Budget detail screen navigated to from Alert Center.
///
/// Shows budget progress for a specific category with optional
/// projection information for prediction-type alerts.
class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.categoryId, this.extra});

  final String categoryId;
  final BudgetDetailExtra? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final budgetProgressAsync = ref.watch(budgetNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: Text('alert.budget_detail_title'.tr())),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: budgetProgressAsync.when(
              data: (budgets) {
                // Find the budget matching this categoryId by category name
                // The alert's categoryId maps to the categories table
                final matchingBudget = _findMatchingBudget(budgets);

                if (matchingBudget == null) {
                  return _buildNoBudgetState(context, isDark);
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBudgetCard(
                        context,
                        matchingBudget,
                        formatter,
                        isDark,
                        theme,
                      ),
                      if (extra != null) ...[
                        const SizedBox(height: 16),
                        _buildAlertInfoCard(
                          context,
                          extra!,
                          formatter,
                          isDark,
                          theme,
                        ),
                      ],
                      if (extra?.showProjection == true &&
                          extra?.alert.projectedOverspendDate != null) ...[
                        const SizedBox(height: 16),
                        _buildProjectionCard(
                          context,
                          extra!.alert,
                          isDark,
                          theme,
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'alert.error_loading'.tr(),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BudgetProgress? _findMatchingBudget(List<BudgetProgress> budgets) {
    // Try matching by category name from the alert
    final alertCategoryName = extra?.alert.categoryName;
    if (alertCategoryName != null) {
      final match = budgets.where(
        (bp) =>
            bp.budget.category.toLowerCase() == alertCategoryName.toLowerCase(),
      );
      if (match.isNotEmpty) return match.first;
    }

    // Fallback: try matching by categoryId if budget has an id field
    for (final bp in budgets) {
      if (bp.budget.id == categoryId) return bp;
    }

    return null;
  }

  Widget _buildNoBudgetState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: 16),
            Text(
              'alert.no_budget_found'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    BudgetProgress budgetProgress,
    NumberFormat formatter,
    bool isDark,
    ThemeData theme,
  ) {
    final isOver = budgetProgress.percentage >= 1.0;
    final progressColor = isOver ? Colors.red : Colors.green;
    final spent = budgetProgress.spent;
    final limit = budgetProgress.budget.amountLimit;
    final percentage = limit > 0 ? (spent / limit * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.category_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  budgetProgress.budget.category,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatter.format(spent),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isOver
                      ? Colors.red
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              Text(
                'alert.budget_of'.tr(args: [formatter.format(limit)]),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: budgetProgress.percentage,
              backgroundColor: progressColor.withValues(alpha: 0.1),
              color: progressColor,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'alert.budget_percentage'.tr(args: [percentage.toStringAsFixed(1)]),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          if (isOver) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'alert.budget_exceeded'.tr(
                  args: [formatter.format(spent - limit)],
                ),
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertInfoCard(
    BuildContext context,
    BudgetDetailExtra detailExtra,
    NumberFormat formatter,
    bool isDark,
    ThemeData theme,
  ) {
    final alert = detailExtra.alert;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'alert.alert_info_title'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.message,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          if (alert.overAmount != null && alert.overAmount! > 0) ...[
            const SizedBox(height: 8),
            Text(
              'alert.over_amount'.tr(
                args: [formatter.format(alert.overAmount)],
              ),
              style: const TextStyle(
                fontSize: 13,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectionCard(
    BuildContext context,
    BudgetAlertModel alert,
    bool isDark,
    ThemeData theme,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final overspendDate = alert.projectedOverspendDate!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up_rounded,
                color: Colors.orange.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'alert.projection_title'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'alert.projected_overspend_date'.tr(
              args: [dateFormat.format(overspendDate)],
            ),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'alert.projection_warning'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
