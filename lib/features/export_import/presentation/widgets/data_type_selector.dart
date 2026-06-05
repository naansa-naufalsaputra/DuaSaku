import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/models/data_type.dart';

/// A checkbox list widget for selecting which [DataType]s to export.
///
/// Displays a list of [CheckboxListTile] widgets, one per [DataType] enum value.
/// Calls [onChanged] whenever a type is toggled.
class DataTypeSelector extends StatelessWidget {
  /// Currently selected data types.
  final Set<DataType> selectedTypes;

  /// Callback when a data type selection changes.
  final void Function(DataType type, bool selected) onChanged;

  const DataTypeSelector({
    super.key,
    required this.selectedTypes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: DataType.values.map((type) {
          final isSelected = selectedTypes.contains(type);
          return CheckboxListTile(
            title: Text(
              _labelForType(type),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
            value: isSelected,
            onChanged: (value) => onChanged(type, value ?? false),
            activeColor: colorScheme.primary,
            checkColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          );
        }).toList(),
      ),
    );
  }

  String _labelForType(DataType type) {
    return switch (type) {
      DataType.transactions => 'export_import.data_type.transactions'.tr(),
      DataType.wallets => 'export_import.data_type.wallets'.tr(),
      DataType.categories => 'export_import.data_type.categories'.tr(),
      DataType.budgets => 'export_import.data_type.budgets'.tr(),
      DataType.recurringTransactions =>
        'export_import.data_type.recurring_transactions'.tr(),
      DataType.goals => 'export_import.data_type.goals'.tr(),
      DataType.goalDeposits => 'export_import.data_type.goal_deposits'.tr(),
      DataType.budgetAlerts => 'export_import.data_type.budget_alerts'.tr(),
    };
  }
}
