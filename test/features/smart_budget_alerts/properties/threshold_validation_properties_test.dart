import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/features/smart_budget_alerts/providers/alert_preferences_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

// ---------------------------------------------------------------------------
// Property 7: Threshold value validation
// **Validates: Requirements 3.2**
//
// For any integer value provided as a custom threshold:
// - Values in the set {10, 15, 20, 25, ..., 95, 100} (multiples of 5 between
//   10 and 100 inclusive) SHALL be accepted
// - All other values SHALL be rejected
// ---------------------------------------------------------------------------

/// The set of all valid threshold values.
final Set<int> validThresholds = {for (int v = 10; v <= 100; v += 5) v};

/// Checks if a value is a valid threshold per the specification.
bool isValidThreshold(int value) {
  return value >= 10 && value <= 100 && value % 5 == 0;
}

void main() {
  // Feature: smart-budget-alerts, Property 7: Threshold value validation
  // **Validates: Requirements 3.2**
  group('Property 7: Threshold value validation', () {
    // -----------------------------------------------------------------------
    // Sub-property: Valid threshold values are accepted
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'valid threshold values (multiples of 5 in [10, 100]) are accepted (return null)',
      (seed) {
        final rng = Random(seed);

        // Pick a random valid threshold from the valid set
        final validList = validThresholds.toList();
        final value = validList[rng.nextInt(validList.length)];

        final result = AlertPreferencesNotifier.validateThresholds([value]);

        expect(
          result,
          isNull,
          reason:
              'Threshold value $value is valid (multiple of 5, '
              '10 <= $value <= 100) and should be accepted (return null)',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Invalid threshold values are rejected
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'invalid threshold values (not in valid set) are rejected (return AppError)',
      (seed) {
        final rng = Random(seed);

        // Generate a random integer that is NOT in the valid set.
        // Strategy: pick from a wide range and reject if it happens to be valid.
        int value;
        do {
          // Range -100 to 200 covers below-minimum, above-maximum, and
          // non-multiples-of-5 within range.
          value = rng.nextInt(301) - 100; // -100 to 200
        } while (isValidThreshold(value));

        final result = AlertPreferencesNotifier.validateThresholds([value]);

        expect(
          result,
          isNotNull,
          reason:
              'Threshold value $value is invalid and should be '
              'rejected (return non-null AppError)',
        );
        expect(
          result,
          isA<ValidationError>(),
          reason: 'Rejected threshold should produce a ValidationError',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Arbitrary integer classification matches spec
    // -----------------------------------------------------------------------
    Glados(any.intInRange(-200, 300)).test(
      'for any integer, validateThresholds returns null iff value is in {10, 15, ..., 95, 100}',
      (value) {
        final result = AlertPreferencesNotifier.validateThresholds([value]);

        if (isValidThreshold(value)) {
          expect(
            result,
            isNull,
            reason:
                'Value $value is a valid threshold (multiple of 5, '
                '10 <= $value <= 100) — validation should return null',
          );
        } else {
          expect(
            result,
            isNotNull,
            reason:
                'Value $value is NOT a valid threshold — '
                'validation should return an AppError',
          );
          expect(
            result,
            isA<ValidationError>(),
            reason: 'Invalid threshold $value should produce a ValidationError',
          );
        }
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Lists with all valid values are accepted
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'a list of all-valid thresholds is accepted (return null)',
      (seed) {
        final rng = Random(seed);
        final validList = validThresholds.toList();

        // Generate a random-length list (1 to 6 elements) of valid values
        final length = 1 + rng.nextInt(6);
        final thresholds = List.generate(
          length,
          (_) => validList[rng.nextInt(validList.length)],
        );

        final result = AlertPreferencesNotifier.validateThresholds(thresholds);

        expect(
          result,
          isNull,
          reason:
              'All values in $thresholds are valid thresholds — '
              'validation should return null',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Lists with at least one invalid value are rejected
    // -----------------------------------------------------------------------
    Glados(any.intInRange(0, 999999)).test(
      'a list containing at least one invalid threshold is rejected',
      (seed) {
        final rng = Random(seed);
        final validList = validThresholds.toList();

        // Generate a list with some valid values and inject one invalid value
        final length = 1 + rng.nextInt(5);
        final thresholds = List.generate(
          length,
          (_) => validList[rng.nextInt(validList.length)],
        );

        // Generate an invalid value
        int invalidValue;
        do {
          invalidValue = rng.nextInt(301) - 100;
        } while (isValidThreshold(invalidValue));

        // Insert the invalid value at a random position
        final insertIndex = rng.nextInt(thresholds.length + 1);
        thresholds.insert(insertIndex, invalidValue);

        final result = AlertPreferencesNotifier.validateThresholds(thresholds);

        expect(
          result,
          isNotNull,
          reason:
              'List $thresholds contains invalid value $invalidValue — '
              'validation should return non-null AppError',
        );
        expect(
          result,
          isA<ValidationError>(),
          reason: 'Invalid threshold in list should produce a ValidationError',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Sub-property: Empty list is accepted (no invalid values)
    // -----------------------------------------------------------------------
    test('empty threshold list is accepted (vacuously valid)', () {
      final result = AlertPreferencesNotifier.validateThresholds([]);

      expect(
        result,
        isNull,
        reason:
            'An empty list has no invalid values, so validation '
            'should return null',
      );
    });

    // -----------------------------------------------------------------------
    // Sub-property: Boundary values — exactly 10 and 100 are valid
    // -----------------------------------------------------------------------
    test('boundary values 10 and 100 are accepted', () {
      expect(
        AlertPreferencesNotifier.validateThresholds([10]),
        isNull,
        reason: '10 is the minimum valid threshold',
      );
      expect(
        AlertPreferencesNotifier.validateThresholds([100]),
        isNull,
        reason: '100 is the maximum valid threshold',
      );
    });

    // -----------------------------------------------------------------------
    // Sub-property: Values just outside boundaries are rejected
    // -----------------------------------------------------------------------
    test('boundary-adjacent values 5 and 105 are rejected', () {
      expect(
        AlertPreferencesNotifier.validateThresholds([5]),
        isA<ValidationError>(),
        reason: '5 is below the minimum valid threshold of 10',
      );
      expect(
        AlertPreferencesNotifier.validateThresholds([105]),
        isA<ValidationError>(),
        reason: '105 is above the maximum valid threshold of 100',
      );
    });
  });
}
