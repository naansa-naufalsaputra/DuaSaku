import 'models/frequency.dart';

/// Pure Dart functions for recurring transaction scheduling calculations.
///
/// All methods are static and have no external dependencies — only pure Dart
/// and the domain [Frequency] enum. This makes them trivially testable.
class RecurringSchedulerLogic {
  RecurringSchedulerLogic._();

  /// Computes the next execution date given the current execution date,
  /// frequency, and custom interval.
  ///
  /// Returns `null` if the computed next date would exceed [endDate].
  ///
  /// Date arithmetic:
  /// - daily: adds [customInterval] days
  /// - weekly: adds [customInterval] × 7 days
  /// - monthly: adds [customInterval] months
  /// - yearly: adds [customInterval] years
  static DateTime? computeNextExecutionDate({
    required DateTime currentExecutionDate,
    required Frequency frequency,
    required int customInterval,
    DateTime? endDate,
  }) {
    final next = _addInterval(currentExecutionDate, frequency, customInterval);

    if (endDate != null && next.isAfter(endDate)) {
      return null;
    }

    return next;
  }

  /// Generates a list of [count] upcoming execution dates starting from
  /// [startDate], respecting [endDate] if provided.
  ///
  /// The returned list may contain fewer than [count] dates if [endDate]
  /// is reached before generating all dates.
  static List<DateTime> computePreviewDates({
    required DateTime startDate,
    required Frequency frequency,
    required int customInterval,
    required int count,
    DateTime? endDate,
  }) {
    final dates = <DateTime>[];
    var current = startDate;

    for (var i = 0; i < count; i++) {
      final next = _addInterval(current, frequency, customInterval);

      if (endDate != null && next.isAfter(endDate)) {
        break;
      }

      dates.add(next);
      current = next;
    }

    return dates;
  }

  /// Computes the progress ring value between 0.0 and 1.0.
  ///
  /// - Returns 1.0 when [now] equals [lastExecutionDate] (just executed).
  /// - Returns 0.0 when [now] equals [nextExecutionDate] (about to execute).
  /// - Values are clamped to [0.0, 1.0].
  static double computeProgressRing({
    required DateTime lastExecutionDate,
    required DateTime nextExecutionDate,
    required DateTime now,
  }) {
    final totalDuration = nextExecutionDate.difference(lastExecutionDate).inSeconds;

    if (totalDuration <= 0) {
      return 1.0;
    }

    final elapsed = now.difference(lastExecutionDate).inSeconds;
    final remaining = totalDuration - elapsed;
    final progress = remaining / totalDuration;

    return progress.clamp(0.0, 1.0);
  }

  /// Validates that [interval] is within the allowed bounds for [frequency].
  ///
  /// Accepts if and only if 1 ≤ [interval] ≤ [frequency.maxInterval].
  static bool isValidCustomInterval(Frequency frequency, int interval) {
    return interval >= 1 && interval <= frequency.maxInterval;
  }

  /// Validates that [amount] is within the allowed bounds.
  ///
  /// Accepts if and only if 0.01 ≤ [amount] ≤ 999,999,999.99.
  static bool isValidAmount(double amount) {
    return amount >= 0.01 && amount <= 999999999.99;
  }

  /// Computes all missed execution dates between [lastExecutionDate] and [now].
  ///
  /// Returns dates in chronological order (oldest first).
  /// Respects [endDate] and caps at [maxCatchUp] (default 90) executions.
  static List<DateTime> computeMissedExecutions({
    required DateTime lastExecutionDate,
    required Frequency frequency,
    required int customInterval,
    required DateTime now,
    DateTime? endDate,
    int maxCatchUp = 90,
  }) {
    final missed = <DateTime>[];
    var current = lastExecutionDate;

    for (var i = 0; i < maxCatchUp; i++) {
      final next = _addInterval(current, frequency, customInterval);

      // Stop if next date is in the future.
      if (next.isAfter(now)) {
        break;
      }

      // Stop if next date exceeds end date.
      if (endDate != null && next.isAfter(endDate)) {
        break;
      }

      missed.add(next);
      current = next;
    }

    return missed;
  }

  /// Adds the appropriate interval to [date] based on [frequency] and
  /// [customInterval].
  static DateTime _addInterval(
    DateTime date,
    Frequency frequency,
    int customInterval,
  ) {
    return switch (frequency) {
      Frequency.daily => date.add(Duration(days: customInterval)),
      Frequency.weekly => date.add(Duration(days: 7 * customInterval)),
      Frequency.monthly => _addMonths(date, customInterval),
      Frequency.yearly => _addYears(date, customInterval),
    };
  }

  /// Adds [months] to [date], clamping the day to the last day of the
  /// resulting month if necessary (e.g., Jan 31 + 1 month = Feb 28/29).
  static DateTime _addMonths(DateTime date, int months) {
    var newMonth = date.month + months;
    var newYear = date.year;

    // Normalize month overflow.
    newYear += (newMonth - 1) ~/ 12;
    newMonth = ((newMonth - 1) % 12) + 1;

    // Clamp day to last day of the target month.
    final maxDay = _daysInMonth(newYear, newMonth);
    final newDay = date.day > maxDay ? maxDay : date.day;

    return DateTime(
      newYear,
      newMonth,
      newDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  /// Adds [years] to [date], clamping the day for leap year edge cases
  /// (e.g., Feb 29 + 1 year = Feb 28).
  static DateTime _addYears(DateTime date, int years) {
    final newYear = date.year + years;
    final maxDay = _daysInMonth(newYear, date.month);
    final newDay = date.day > maxDay ? maxDay : date.day;

    return DateTime(
      newYear,
      date.month,
      newDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  /// Returns the number of days in the given [month] of [year].
  static int _daysInMonth(int year, int month) {
    // DateTime(year, month + 1, 0) gives the last day of [month].
    return DateTime(year, month + 1, 0).day;
  }
}
