import 'package:duasaku_app/features/smart_budget_alerts/domain/models/alert_preference_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

// ---------------------------------------------------------------------------
// Pure Logic Under Test
// ---------------------------------------------------------------------------
// This function replicates the quiet hours detection logic that
// BudgetNotificationService.isQuietHoursActive() implements.
// We test the PROPERTIES of this pure function directly.

/// Represents a time of day as (hour, minute) for testability without Flutter.
class TimeOfDayValue {
  final int hour;
  final int minute;

  const TimeOfDayValue(this.hour, this.minute);

  /// Total minutes since midnight for comparison.
  int get totalMinutes => hour * 60 + minute;

  /// Parses "HH:mm" format string.
  factory TimeOfDayValue.parse(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDayValue(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Formats as "HH:mm" string.
  String toTimeString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  String toString() => toTimeString();
}

/// Pure implementation of quiet hours detection logic.
///
/// Returns true if [currentTime] falls within the quiet hours range
/// defined by [start] and [end].
///
/// Handles two cases:
/// 1. Same-day range (start < end): active when start <= current < end
/// 2. Midnight-spanning range (start >= end): active when current >= start OR current < end
bool isQuietHoursActive({
  required TimeOfDayValue currentTime,
  required TimeOfDayValue start,
  required TimeOfDayValue end,
}) {
  final currentMinutes = currentTime.totalMinutes;
  final startMinutes = start.totalMinutes;
  final endMinutes = end.totalMinutes;

  if (startMinutes < endMinutes) {
    // Same-day range: e.g., 09:00 - 17:00
    return currentMinutes >= startMinutes && currentMinutes < endMinutes;
  } else if (startMinutes > endMinutes) {
    // Midnight-spanning range: e.g., 22:00 - 07:00
    return currentMinutes >= startMinutes || currentMinutes < endMinutes;
  } else {
    // start == end: no quiet hours range (zero-length window)
    return false;
  }
}

/// Overload that works with AlertPreferenceModel and a given current time.
/// This mirrors how BudgetNotificationService.isQuietHoursActive() would work.
bool isQuietHoursActiveFromPrefs(
  AlertPreferenceModel prefs,
  TimeOfDayValue currentTime,
) {
  if (!prefs.hasQuietHours) return false;

  final start = TimeOfDayValue.parse(prefs.quietHoursStart!);
  final end = TimeOfDayValue.parse(prefs.quietHoursEnd!);

  return isQuietHoursActive(currentTime: currentTime, start: start, end: end);
}

// ---------------------------------------------------------------------------
// Test Data Generation
// ---------------------------------------------------------------------------

/// Generates a random TimeOfDayValue (hour 0-23, minute 0-59).
TimeOfDayValue _randomTime(Random rng) {
  return TimeOfDayValue(rng.nextInt(24), rng.nextInt(60));
}

/// Generates a "HH:mm" string from random hour/minute.
String _randomTimeString(Random rng) {
  return _randomTime(rng).toTimeString();
}

/// Generates a tuple of (currentTime, start, end) for same-day range testing.
/// Ensures start < end (same-day range).
({TimeOfDayValue currentTime, TimeOfDayValue start, TimeOfDayValue end})
_generateSameDayScenario(int seed) {
  final rng = Random(seed);

  // Generate start and end ensuring start < end (in total minutes)
  final startMinutes = rng.nextInt(1439); // 0 to 1438 (leave room for end)
  final endMinutes =
      startMinutes + 1 + rng.nextInt(1439 - startMinutes); // start+1 to 1439

  final start = TimeOfDayValue(startMinutes ~/ 60, startMinutes % 60);
  final end = TimeOfDayValue(endMinutes ~/ 60, endMinutes % 60);
  final currentTime = _randomTime(rng);

  return (currentTime: currentTime, start: start, end: end);
}

/// Generates a tuple for midnight-spanning range testing.
/// Ensures start > end (spans midnight).
({TimeOfDayValue currentTime, TimeOfDayValue start, TimeOfDayValue end})
_generateMidnightSpanScenario(int seed) {
  final rng = Random(seed);

  // Generate start and end ensuring start > end (midnight span)
  // e.g., start=22:00, end=07:00
  final endMinutes = rng.nextInt(1439); // 0 to 1438
  final startMinutes =
      endMinutes + 1 + rng.nextInt(1439 - endMinutes); // end+1 to 1439

  final start = TimeOfDayValue(startMinutes ~/ 60, startMinutes % 60);
  final end = TimeOfDayValue(endMinutes ~/ 60, endMinutes % 60);
  final currentTime = _randomTime(rng);

  return (currentTime: currentTime, start: start, end: end);
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // Feature: smart-budget-alerts, Property 8: Quiet hours detection
  // **Validates: Requirements 3.4**
  group('Property 8: Quiet hours detection', () {
    // -----------------------------------------------------------------------
    // Sub-property: Same-day range correctness
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'same-day range: isQuietHoursActive returns true iff start <= currentTime < end',
      (seed) {
        final scenario = _generateSameDayScenario(seed);
        final currentTime = scenario.currentTime;
        final start = scenario.start;
        final end = scenario.end;

        // Precondition: same-day range (start < end in total minutes)
        assert(start.totalMinutes < end.totalMinutes);

        final result = isQuietHoursActive(
          currentTime: currentTime,
          start: start,
          end: end,
        );

        final currentMinutes = currentTime.totalMinutes;
        final startMinutes = start.totalMinutes;
        final endMinutes = end.totalMinutes;

        final expectedActive =
            currentMinutes >= startMinutes && currentMinutes < endMinutes;

        expect(
          result,
          equals(expectedActive),
          reason:
              'For same-day range $start-$end, '
              'currentTime=$currentTime (${currentTime.totalMinutes} min), '
              'expected active=$expectedActive but got $result',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Midnight-spanning range correctness
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'midnight-spanning range: isQuietHoursActive returns true iff currentTime >= start OR currentTime < end',
      (seed) {
        final scenario = _generateMidnightSpanScenario(seed);
        final currentTime = scenario.currentTime;
        final start = scenario.start;
        final end = scenario.end;

        // Precondition: midnight-spanning range (start > end in total minutes)
        assert(start.totalMinutes > end.totalMinutes);

        final result = isQuietHoursActive(
          currentTime: currentTime,
          start: start,
          end: end,
        );

        final currentMinutes = currentTime.totalMinutes;
        final startMinutes = start.totalMinutes;
        final endMinutes = end.totalMinutes;

        final expectedActive =
            currentMinutes >= startMinutes || currentMinutes < endMinutes;

        expect(
          result,
          equals(expectedActive),
          reason:
              'For midnight-spanning range $start-$end, '
              'currentTime=$currentTime (${currentTime.totalMinutes} min), '
              'expected active=$expectedActive but got $result',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Equal start and end means no quiet hours
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'when start == end, isQuietHoursActive always returns false',
      (seed) {
        final rng = Random(seed);
        final time = _randomTime(rng);
        final startEnd = _randomTime(rng);

        final result = isQuietHoursActive(
          currentTime: time,
          start: startEnd,
          end: startEnd,
        );

        expect(
          result,
          isFalse,
          reason:
              'When start == end ($startEnd), quiet hours should never be '
              'active regardless of currentTime ($time)',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: No quiet hours configured returns false
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'when quiet hours are not configured (null), isQuietHoursActiveFromPrefs returns false',
      (seed) {
        final rng = Random(seed);
        final currentTime = _randomTime(rng);

        const prefs = AlertPreferenceModel(
          id: 'pref_test',
          userId: 'user_test',
          quietHoursStart: null,
          quietHoursEnd: null,
        );

        final result = isQuietHoursActiveFromPrefs(prefs, currentTime);

        expect(
          result,
          isFalse,
          reason:
              'When quiet hours are not configured, '
              'isQuietHoursActive should always return false',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Integration with AlertPreferenceModel
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'isQuietHoursActiveFromPrefs correctly uses AlertPreferenceModel quiet hours fields',
      (seed) {
        final rng = Random(seed);
        final currentTime = _randomTime(rng);
        final startStr = _randomTimeString(rng);
        final endStr = _randomTimeString(rng);

        final prefs = AlertPreferenceModel(
          id: 'pref_test_$seed',
          userId: 'user_test',
          quietHoursStart: startStr,
          quietHoursEnd: endStr,
        );

        final result = isQuietHoursActiveFromPrefs(prefs, currentTime);

        // Verify against direct calculation
        final start = TimeOfDayValue.parse(startStr);
        final end = TimeOfDayValue.parse(endStr);
        final expectedResult = isQuietHoursActive(
          currentTime: currentTime,
          start: start,
          end: end,
        );

        expect(
          result,
          equals(expectedResult),
          reason:
              'isQuietHoursActiveFromPrefs should produce same result as '
              'direct isQuietHoursActive call for start=$startStr, end=$endStr, '
              'currentTime=$currentTime',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Boundary — currentTime exactly at start is active
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'currentTime exactly at quietHoursStart is always within quiet hours (when range is non-zero)',
      (seed) {
        final rng = Random(seed);

        // Generate a non-zero range
        final startMinutes = rng.nextInt(1440);
        int endMinutes;
        do {
          endMinutes = rng.nextInt(1440);
        } while (endMinutes == startMinutes);

        final start = TimeOfDayValue(startMinutes ~/ 60, startMinutes % 60);
        final end = TimeOfDayValue(endMinutes ~/ 60, endMinutes % 60);

        // currentTime == start
        final result = isQuietHoursActive(
          currentTime: start,
          start: start,
          end: end,
        );

        expect(
          result,
          isTrue,
          reason:
              'currentTime at start ($start) should always be within '
              'quiet hours for range $start-$end',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Boundary — currentTime exactly at end is NOT active
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'currentTime exactly at quietHoursEnd is NOT within quiet hours (exclusive end)',
      (seed) {
        final rng = Random(seed);

        // Generate a same-day range to test exclusive end clearly
        final startMinutes = rng.nextInt(1439);
        final endMinutes = startMinutes + 1 + rng.nextInt(1439 - startMinutes);

        final start = TimeOfDayValue(startMinutes ~/ 60, startMinutes % 60);
        final end = TimeOfDayValue(endMinutes ~/ 60, endMinutes % 60);

        // currentTime == end (should be outside quiet hours)
        final result = isQuietHoursActive(
          currentTime: end,
          start: start,
          end: end,
        );

        expect(
          result,
          isFalse,
          reason:
              'currentTime at end ($end) should NOT be within '
              'quiet hours for same-day range $start-$end (end is exclusive)',
        );
      },
    );
  });
}
