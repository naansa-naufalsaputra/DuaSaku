import 'data_type.dart';

/// Configuration for a CSV export operation.
class ExportConfig {
  final Set<DataType> selectedTypes;
  final DateRangeFilter dateRange;

  const ExportConfig({
    required this.selectedTypes,
    required this.dateRange,
  });
}

/// Sealed class representing date range filter options for CSV export.
sealed class DateRangeFilter {
  const DateRangeFilter();

  /// Start date of the filter range (inclusive). Null means no lower bound.
  DateTime? get startDate;

  /// End date of the filter range (inclusive). Null means no upper bound.
  DateTime? get endDate;
}

/// No date filtering — export all records.
class AllTime extends DateRangeFilter {
  const AllTime();

  @override
  DateTime? get startDate => null;

  @override
  DateTime? get endDate => null;
}

/// Filter to the current calendar month.
class ThisMonth extends DateRangeFilter {
  const ThisMonth();

  @override
  DateTime? get startDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  @override
  DateTime? get endDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
  }
}

/// Filter to the previous calendar month.
class LastMonth extends DateRangeFilter {
  const LastMonth();

  @override
  DateTime? get startDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 1, 1);
  }

  @override
  DateTime? get endDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 0, 23, 59, 59, 999);
  }
}

/// Filter to the last 3 months from today.
class Last3Months extends DateRangeFilter {
  const Last3Months();

  @override
  DateTime? get startDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 3, now.day);
  }

  @override
  DateTime? get endDate => DateTime.now();
}

/// Filter to the current calendar year.
class ThisYear extends DateRangeFilter {
  const ThisYear();

  @override
  DateTime? get startDate {
    final now = DateTime.now();
    return DateTime(now.year, 1, 1);
  }

  @override
  DateTime? get endDate {
    final now = DateTime.now();
    return DateTime(now.year, 12, 31, 23, 59, 59, 999);
  }
}

/// Custom date range with user-specified start and end dates.
class CustomRange extends DateRangeFilter {
  final DateTime start;
  final DateTime end;

  const CustomRange({
    required this.start,
    required this.end,
  });

  @override
  DateTime? get startDate => start;

  @override
  DateTime? get endDate => end;
}
