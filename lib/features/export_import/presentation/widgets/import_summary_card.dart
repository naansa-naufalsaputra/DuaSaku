import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/glass/glass_card.dart';
import '../../domain/models/import_preview.dart';

/// A glassmorphism card that displays a summary of data counts from an
/// [ImportPreview].
///
/// Shows icons and record counts for each data type in the backup file:
/// wallets, categories, transactions, budgets, goals, recurring transactions,
/// and budget alerts.
class ImportSummaryCard extends StatelessWidget {
  /// The import preview containing data counts.
  final ImportPreview preview;

  const ImportSummaryCard({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final items = _buildSummaryItems();

    return GlassCard(
      enableBlur: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'export_import.import.data_summary'.tr(),
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Grid of data type counts
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _SummaryItem(
                icon: item.icon,
                label: item.label,
                count: item.count,
                colorScheme: colorScheme,
                textTheme: textTheme,
              );
            },
          ),
        ],
      ),
    );
  }

  List<_SummaryData> _buildSummaryItems() {
    return [
      _SummaryData(
        icon: Icons.account_balance_wallet_outlined,
        label: 'export_import.data_type.wallets'.tr(),
        count: preview.walletCount,
      ),
      _SummaryData(
        icon: Icons.category_outlined,
        label: 'export_import.data_type.categories'.tr(),
        count: preview.categoryCount,
      ),
      _SummaryData(
        icon: Icons.receipt_long_outlined,
        label: 'export_import.data_type.transactions'.tr(),
        count: preview.transactionCount,
      ),
      _SummaryData(
        icon: Icons.pie_chart_outline,
        label: 'export_import.data_type.budgets'.tr(),
        count: preview.budgetCount,
      ),
      _SummaryData(
        icon: Icons.flag_outlined,
        label: 'export_import.data_type.goals'.tr(),
        count: preview.goalCount,
      ),
      _SummaryData(
        icon: Icons.repeat_outlined,
        label: 'export_import.data_type.recurring_transactions'.tr(),
        count: preview.recurringTransactionCount,
      ),
      _SummaryData(
        icon: Icons.notifications_outlined,
        label: 'export_import.data_type.budget_alerts'.tr(),
        count: preview.budgetAlertCount,
      ),
    ];
  }
}

class _SummaryData {
  final IconData icon;
  final String label;
  final int count;

  const _SummaryData({
    required this.icon,
    required this.label,
    required this.count,
  });
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
