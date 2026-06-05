// Feature: recurring-transactions, Property 1: Frequency/Interval Round-Trip
// Feature: recurring-transactions, Property 2: Custom Interval Validation Boundaries
// Feature: recurring-transactions, Property 3: Amount Validation Boundaries
// Feature: recurring-transactions, Property 4: Preview Dates Computation
// Feature: recurring-transactions, Property 8: End Date Enforcement
// Feature: recurring-transactions, Property 10: Next Execution Date Invariant
// Feature: recurring-transactions, Property 13: Progress Ring Computation

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

import 'package:duasaku_app/features/recurring_transactions/domain/models/frequency.dart';
import 'package:duasaku_app/features/recurring_transactions/domain/recurring_scheduler_logic.dart';

/// Custom generators for recurring transaction domain types.
extension FrequencyArbitrary on Any {
  /// Generates a random Frequency enum value.
  Generator<Frequency> get frequency =>
      any.intInRange(0, Frequency.values.length - 1).map(
            (index) => Frequency.values[index],
          );

  /// Generates a valid custom interval for a given frequency.
  Generator<int> validIntervalFor(Frequency freq) =>
      any.intInRange(1, freq.maxInterval);

  /// Generates a reasonable DateTime (year 2020–2030) for testing.
  Generator<DateTime> get reasonableDateTime =>
      any.intInRange(0, 3650).map((dayOffset) {
        // Base date: 2020-01-01, offset by 0–3650 days (~10 years)
        return DateTime(2020, 1, 1).add(Duration(days: dayOffset));
      });
}

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Property 1: Frequency/Interval Round-Trip
  // **Validates: Requirements 8.6**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 1: Frequency/Interval Round-Trip', () {
    // Daily: difference is exactly customInterval days
    Glados2(any.intInRange(1, 365), any.intInRange(0, 3650)).test(
      'daily frequency produces offset of exactly customInterval days',
      (customInterval, dayOffset) {
        final baseDate = DateTime(2020, 1, 1).add(Duration(days: dayOffset));

        final nextDate = RecurringSchedulerLogic.computeNextExecutionDate(
          currentExecutionDate: baseDate,
          frequency: Frequency.daily,
          customInterval: customInterval,
        );

        expect(nextDate, isNotNull);
        final diff = nextDate!.difference(baseDate).inDays;
        expect(diff, equals(customInterval));
      },
    );

    // Weekly: difference is exactly customInterval * 7 days
    Glados2(any.intInRange(1, 52), any.intInRange(0, 3650)).test(
      'weekly frequency produces offset of exactly customInterval * 7 days',
      (customInterval, dayOffset) {
        final baseDate = DateTime(2020, 1, 1).add(Duration(days: dayOffset));

        final nextDate = RecurringSchedulerLogic.computeNextExecutionDate(
          currentExecutionDate: baseDate,
          frequency: Frequency.weekly,
          customInterval: customInterval,
        );

        expect(nextDate, isNotNull);
        final diff = nextDate!.difference(baseDate).inDays;
        expect(diff, equals(customInterval * 7));
      },
    );

    // Monthly: month difference is exactly customInterval
    Glados2(any.intInRange(1, 12), any.intInRange(0, 3650)).test(
      'monthly frequency produces month offset of exactly customInterval',
      (customInterval, dayOffset) {
        final baseDate = DateTime(2020, 1, 1).add(Duration(days: dayOffset));

        final nextDate = RecurringSchedulerLogic.computeNextExecutionDate(
          currentExecutionDate: baseDate,
          frequency: Frequency.monthly,
          customInterval: customInterval,
        );

        expect(nextDate, isNotNull);

        // Calculate expected month difference accounting for year rollover
        final monthDiff = (nextDate!.year - baseDate.year) * 12 +
            (nextDate.month - baseDate.month);
        expect(monthDiff, equals(customInterval));

        // Day should be <= original day (clamped for shorter months)
        expect(nextDate.day, lessThanOrEqualTo(baseDate.day));
      },
    );

    // Yearly: year difference is exactly customInterval
    Glados2(any.intInRange(1, 10), any.intInRange(0, 3650)).test(
      'yearly frequency produces year offset of exactly customInterval',
      (customInterval, dayOffset) {
        final baseDate = DateTime(2020, 1, 1).add(Duration(days: dayOffset));

        final nextDate = RecurringSchedulerLogic.computeNextExecutionDate(
          currentExecutionDate: baseDate,
          frequency: Frequency.yearly,
          customInterval: customInterval,
        );

        expect(nextDate, isNotNull);
        final yearDiff = nextDate!.year - baseDate.year;
        expect(yearDiff, equals(customInterval));

        // Month should remain the same
        expect(nextDate.month, equals(baseDate.month));

        // Day should be <= original day (clamped for leap year edge cases)
        expect(nextDate.day, lessThanOrEqualTo(baseDate.day));
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 2: Custom Interval Validation Boundaries
  // **Validates: Requirements 1.2**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 2: Custom Interval Validation Boundaries', () {
    Glados2(
      any.intInRange(0, Frequency.values.length - 1),
      any.intInRange(-10, 400),
    ).test(
      'isValidCustomInterval accepts iff 1 <= interval <= frequency.maxInterval',
      (freqIndex, interval) {
        final freq = Frequency.values[freqIndex];
        final result =
            RecurringSchedulerLogic.isValidCustomInterval(freq, interval);
        final expected = interval >= 1 && interval <= freq.maxInterval;
        expect(result, equals(expected));
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 3: Amount Validation Boundaries
  // **Validates: Requirements 1.6**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 3: Amount Validation Boundaries', () {
    // Test with integers mapped to doubles for broad coverage
    Glados(any.intInRange(-100, 1100000000)).test(
      'isValidAmount accepts iff 0.01 <= amount <= 999999999.99',
      (amountCents) {
        // Convert to a double with cent precision
        final amount = amountCents / 100.0;
        final result = RecurringSchedulerLogic.isValidAmount(amount);
        final expected = amount >= 0.01 && amount <= 999999999.99;
        expect(result, equals(expected));
      },
    );

    // Edge cases: boundary values
    test('amount exactly 0.01 is valid', () {
      expect(RecurringSchedulerLogic.isValidAmount(0.01), isTrue);
    });

    test('amount exactly 999999999.99 is valid', () {
      expect(RecurringSchedulerLogic.isValidAmount(999999999.99), isTrue);
    });

    test('amount 0.0 is invalid', () {
      expect(RecurringSchedulerLogic.isValidAmount(0.0), isFalse);
    });

    test('amount 0.009 is invalid', () {
      expect(RecurringSchedulerLogic.isValidAmount(0.009), isFalse);
    });

    test('amount 1000000000.0 is invalid', () {
      expect(RecurringSchedulerLogic.isValidAmount(1000000000.0), isFalse);
    });

    test('negative amount is invalid', () {
      expect(RecurringSchedulerLogic.isValidAmount(-1.0), isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 4: Preview Dates Computation
  // **Validates: Requirements 1.5**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 4: Preview Dates Computation', () {
    Glados2(
      any.intInRange(0, Frequency.values.length - 1),
      any.intInRange(0, 1825),
    ).test(
      'computePreviewDates(count:5) returns exactly 5 strictly increasing dates',
      (freqIndex, dayOffset) {
        final freq = Frequency.values[freqIndex];
        // Use interval 1 to keep things simple and ensure 5 dates fit
        const customInterval = 1;
        final startDate = DateTime(2022, 1, 1).add(Duration(days: dayOffset));

        final dates = RecurringSchedulerLogic.computePreviewDates(
          startDate: startDate,
          frequency: freq,
          customInterval: customInterval,
          count: 5,
        );

        // Should return exactly 5 dates (no end date constraint)
        expect(dates.length, equals(5));

        // All dates must be strictly increasing
        for (var i = 1; i < dates.length; i++) {
          expect(
            dates[i].isAfter(dates[i - 1]),
            isTrue,
            reason:
                'Date at index $i (${dates[i]}) should be after date at index ${i - 1} (${dates[i - 1]})',
          );
        }

        // First date should be after startDate
        expect(dates[0].isAfter(startDate), isTrue);
      },
    );

    // Verify correct intervals between consecutive preview dates for daily
    Glados2(any.intInRange(1, 30), any.intInRange(0, 1000)).test(
      'daily preview dates have correct interval between consecutive dates',
      (customInterval, dayOffset) {
        final startDate = DateTime(2022, 1, 1).add(Duration(days: dayOffset));

        final dates = RecurringSchedulerLogic.computePreviewDates(
          startDate: startDate,
          frequency: Frequency.daily,
          customInterval: customInterval,
          count: 5,
        );

        expect(dates.length, equals(5));

        for (var i = 1; i < dates.length; i++) {
          final diff = dates[i].difference(dates[i - 1]).inDays;
          expect(diff, equals(customInterval));
        }
      },
    );

    // Verify correct intervals between consecutive preview dates for weekly
    Glados2(any.intInRange(1, 10), any.intInRange(0, 1000)).test(
      'weekly preview dates have correct interval between consecutive dates',
      (customInterval, dayOffset) {
        final startDate = DateTime(2022, 1, 1).add(Duration(days: dayOffset));

        final dates = RecurringSchedulerLogic.computePreviewDates(
          startDate: startDate,
          frequency: Frequency.weekly,
          customInterval: customInterval,
          count: 5,
        );

        expect(dates.length, equals(5));

        for (var i = 1; i < dates.length; i++) {
          final diff = dates[i].difference(dates[i - 1]).inDays;
          expect(diff, equals(customInterval * 7));
        }
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 8: End Date Enforcement
  // **Validates: Requirements 1.3, 1.4, 2.5**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 8: End Date Enforcement', () {
    // With end date: no computed next date exceeds endDate
    Glados2(
      any.intInRange(0, Frequency.values.length - 1),
      any.intInRange(0, 1000),
    ).test(
      'no computed next date exceeds endDate',
      (freqIndex, dayOffset) {
        final freq = Frequency.values[freqIndex];
        final baseDate = DateTime(2022, 1, 1).add(Duration(days: dayOffset));
        // End date is 5 days after base date — for daily with interval 1,
        // some dates will be within range, others won't
        final endDate = baseDate.add(const Duration(days: 5));

        final nextDate = RecurringSchedulerLogic.computeNextExecutionDate(
          currentExecutionDate: baseDate,
          frequency: freq,
          customInterval: 1,
          endDate: endDate,
        );

        // If a date is returned, it must not exceed endDate
        if (nextDate != null) {
          expect(
            nextDate.isAfter(endDate),
            isFalse,
            reason:
                'Next date $nextDate should not exceed end date $endDate',
          );
        }
      },
    );

    // Without end date: always produces a valid next date
    Glados2(
      any.intInRange(0, Frequency.values.length - 1),
      any.intInRange(0, 3650),
    ).test(
      'null endDate always produces a valid next date',
      (freqIndex, dayOffset) {
        final freq = Frequency.values[freqIndex];
        final baseDate = DateTime(2020, 1, 1).add(Duration(days: dayOffset));

        final nextDate = RecurringSchedulerLogic.computeNextExecutionDate(
          currentExecutionDate: baseDate,
          frequency: freq,
          customInterval: 1,
          endDate: null,
        );

        expect(nextDate, isNotNull);
      },
    );

    // Preview dates with end date: all returned dates are <= endDate
    Glados(any.intInRange(0, 1000)).test(
      'preview dates with endDate never exceed endDate',
      (dayOffset) {
        final startDate = DateTime(2022, 1, 1).add(Duration(days: dayOffset));
        final endDate = startDate.add(const Duration(days: 30));

        final dates = RecurringSchedulerLogic.computePreviewDates(
          startDate: startDate,
          frequency: Frequency.daily,
          customInterval: 7,
          count: 5,
          endDate: endDate,
        );

        for (final date in dates) {
          expect(
            date.isAfter(endDate),
            isFalse,
            reason: 'Preview date $date should not exceed end date $endDate',
          );
        }
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 10: Next Execution Date Invariant
  // **Validates: Requirements 8.4, 2.4**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 10: Next Execution Date Invariant', () {
    Glados3(
      any.intInRange(0, Frequency.values.length - 1),
      any.intInRange(1, 100),
      any.intInRange(0, 3650),
    ).test(
      'computeNextExecutionDate always returns date > input date (when not null)',
      (freqIndex, customInterval, dayOffset) {
        final freq = Frequency.values[freqIndex];
        // Clamp customInterval to valid range for the frequency
        final validInterval = customInterval.clamp(1, freq.maxInterval);
        final baseDate = DateTime(2020, 1, 1).add(Duration(days: dayOffset));

        final nextDate = RecurringSchedulerLogic.computeNextExecutionDate(
          currentExecutionDate: baseDate,
          frequency: freq,
          customInterval: validInterval,
        );

        expect(nextDate, isNotNull);
        expect(
          nextDate!.isAfter(baseDate),
          isTrue,
          reason:
              'Next date $nextDate must be strictly after base date $baseDate '
              '(freq=$freq, interval=$validInterval)',
        );
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 13: Progress Ring Computation
  // **Validates: Requirements 3.9**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 13: Progress Ring Computation', () {
    // Result is always in [0.0, 1.0] for valid inputs
    Glados2(any.intInRange(1, 365), any.intInRange(0, 100)).test(
      'progress ring value is always in [0.0, 1.0]',
      (totalDays, percentElapsed) {
        // Clamp percentElapsed to [0, 100]
        final pct = percentElapsed.clamp(0, 100);
        final lastExecution = DateTime(2023, 1, 1);
        final nextExecution =
            lastExecution.add(Duration(days: totalDays));
        final elapsedDays = (totalDays * pct) ~/ 100;
        final now = lastExecution.add(Duration(days: elapsedDays));

        final progress = RecurringSchedulerLogic.computeProgressRing(
          lastExecutionDate: lastExecution,
          nextExecutionDate: nextExecution,
          now: now,
        );

        expect(progress, greaterThanOrEqualTo(0.0));
        expect(progress, lessThanOrEqualTo(1.0));
      },
    );

    // When now == lastExecutionDate, progress should be 1.0
    test('progress is 1.0 when now equals lastExecutionDate', () {
      final lastExecution = DateTime(2023, 6, 1);
      final nextExecution = DateTime(2023, 7, 1);

      final progress = RecurringSchedulerLogic.computeProgressRing(
        lastExecutionDate: lastExecution,
        nextExecutionDate: nextExecution,
        now: lastExecution,
      );

      expect(progress, equals(1.0));
    });

    // When now == nextExecutionDate, progress should be 0.0
    test('progress is 0.0 when now equals nextExecutionDate', () {
      final lastExecution = DateTime(2023, 6, 1);
      final nextExecution = DateTime(2023, 7, 1);

      final progress = RecurringSchedulerLogic.computeProgressRing(
        lastExecutionDate: lastExecution,
        nextExecutionDate: nextExecution,
        now: nextExecution,
      );

      expect(progress, equals(0.0));
    });

    // Midpoint should be approximately 0.5
    test('progress is approximately 0.5 at midpoint', () {
      final lastExecution = DateTime(2023, 6, 1);
      final nextExecution = DateTime(2023, 6, 11); // 10 days total
      final midpoint = DateTime(2023, 6, 6); // 5 days elapsed

      final progress = RecurringSchedulerLogic.computeProgressRing(
        lastExecutionDate: lastExecution,
        nextExecutionDate: nextExecution,
        now: midpoint,
      );

      expect(progress, closeTo(0.5, 0.01));
    });

    // Progress decreases as time passes (monotonically decreasing)
    Glados(any.intInRange(2, 100)).test(
      'progress is monotonically decreasing as now advances',
      (totalDays) {
        final lastExecution = DateTime(2023, 1, 1);
        final nextExecution =
            lastExecution.add(Duration(days: totalDays));

        double? previousProgress;
        for (var day = 0; day <= totalDays; day++) {
          final now = lastExecution.add(Duration(days: day));
          final progress = RecurringSchedulerLogic.computeProgressRing(
            lastExecutionDate: lastExecution,
            nextExecutionDate: nextExecution,
            now: now,
          );

          if (previousProgress != null) {
            expect(
              progress,
              lessThanOrEqualTo(previousProgress),
              reason:
                  'Progress should decrease as time passes (day $day: $progress > previous: $previousProgress)',
            );
          }
          previousProgress = progress;
        }
      },
    );
  });
}
