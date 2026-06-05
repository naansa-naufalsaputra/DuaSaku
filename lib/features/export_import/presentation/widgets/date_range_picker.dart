import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/models/export_config.dart';

/// Preset options for the date range filter.
enum DateRangePreset {
  thisMonth,
  lastMonth,
  last3Months,
  thisYear,
  allTime,
  custom,
}

/// A widget that displays date range filter options as choice chips.
///
/// Shows preset options (This Month, Last Month, Last 3 Months, This Year,
/// All Time) and a Custom Range option that opens a date picker dialog.
/// Default selection is This Month.
class DateRangePickerWidget extends StatelessWidget {
  /// The currently active date range filter.
  final DateRangeFilter filter;

  /// Callback when the filter changes.
  final void Function(DateRangeFilter filter) onChanged;

  const DateRangePickerWidget({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentPreset = _presetFromFilter(filter);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: DateRangePreset.values.map((preset) {
          final isSelected = preset == currentPreset;
          return ChoiceChip(
            label: Text(_labelForPreset(preset)),
            selected: isSelected,
            onSelected: (_) => _onPresetSelected(context, preset),
            selectedColor: colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            backgroundColor: colorScheme.surface,
            side: BorderSide(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        }).toList(),
      ),
    );
  }

  DateRangePreset _presetFromFilter(DateRangeFilter filter) {
    return switch (filter) {
      ThisMonth() => DateRangePreset.thisMonth,
      LastMonth() => DateRangePreset.lastMonth,
      Last3Months() => DateRangePreset.last3Months,
      ThisYear() => DateRangePreset.thisYear,
      AllTime() => DateRangePreset.allTime,
      CustomRange() => DateRangePreset.custom,
    };
  }

  void _onPresetSelected(BuildContext context, DateRangePreset preset) {
    switch (preset) {
      case DateRangePreset.thisMonth:
        onChanged(const ThisMonth());
      case DateRangePreset.lastMonth:
        onChanged(const LastMonth());
      case DateRangePreset.last3Months:
        onChanged(const Last3Months());
      case DateRangePreset.thisYear:
        onChanged(const ThisYear());
      case DateRangePreset.allTime:
        onChanged(const AllTime());
      case DateRangePreset.custom:
        _showCustomRangePicker(context);
    }
  }

  Future<void> _showCustomRangePicker(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    // Default initial range: current month
    DateTime initialStart = now.copyWith(day: 1);
    DateTime initialEnd = now;

    // If already custom, use existing range
    if (filter is CustomRange) {
      final custom = filter as CustomRange;
      initialStart = custom.start;
      initialEnd = custom.end;
    }

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onChanged(CustomRange(start: picked.start, end: picked.end));
    }
  }

  String _labelForPreset(DateRangePreset preset) {
    return switch (preset) {
      DateRangePreset.thisMonth =>
        'export_import.date_range.this_month'.tr(),
      DateRangePreset.lastMonth =>
        'export_import.date_range.last_month'.tr(),
      DateRangePreset.last3Months =>
        'export_import.date_range.last_3_months'.tr(),
      DateRangePreset.thisYear =>
        'export_import.date_range.this_year'.tr(),
      DateRangePreset.allTime =>
        'export_import.date_range.all_time'.tr(),
      DateRangePreset.custom =>
        'export_import.date_range.custom'.tr(),
    };
  }
}
