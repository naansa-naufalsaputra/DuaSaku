import 'package:duasaku_app/features/smart_budget_alerts/domain/models/alert_preference_model.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/alert_type.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/budget_alert_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

// ---------------------------------------------------------------------------
// Custom Generators & Helpers
// ---------------------------------------------------------------------------

/// Generates a random non-empty alphanumeric string of given length.
String _randomString(Random rng, int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

/// Generates a random AlertType value.
AlertType _randomAlertType(Random rng) {
  return AlertType.values[rng.nextInt(AlertType.values.length)];
}

/// Generates a random DateTime within a reasonable range.
DateTime _randomDateTime(Random rng) {
  return DateTime(
    2020 + rng.nextInt(5), // 2020-2024
    1 + rng.nextInt(12), // month 1-12
    1 + rng.nextInt(28), // day 1-28
    rng.nextInt(24), // hour
    rng.nextInt(60), // minute
    rng.nextInt(60), // second
  );
}

/// Generates a random BudgetAlertModel with all fields populated.
BudgetAlertModel _generateBudgetAlertModel(int seed) {
  final rng = Random(seed);
  final alertType = _randomAlertType(rng);

  // thresholdValue: null for prediction, valid int for threshold/overBudget
  final int? thresholdValue;
  if (alertType == AlertType.prediction) {
    thresholdValue = null;
  } else {
    thresholdValue = (rng.nextInt(20) + 1) * 5; // 5, 10, ..., 100
  }

  final actualPercentage = rng.nextDouble() * 200.0; // 0-200%
  final createdAt = _randomDateTime(rng);

  // Computed fields: randomly include or exclude
  final String? categoryName = rng.nextBool()
      ? _randomString(rng, 5 + rng.nextInt(10))
      : null;
  final double? remainingBudget = rng.nextBool()
      ? rng.nextDouble() * 1000000.0
      : null;
  final double? overAmount =
      (alertType == AlertType.overBudget && rng.nextBool())
      ? rng.nextDouble() * 500000.0
      : null;
  final DateTime? projectedOverspendDate =
      (alertType == AlertType.prediction && rng.nextBool())
      ? _randomDateTime(rng)
      : null;

  return BudgetAlertModel(
    id: _randomString(rng, 10 + rng.nextInt(10)),
    userId: _randomString(rng, 8),
    categoryId: _randomString(rng, 8),
    alertType: alertType,
    thresholdValue: thresholdValue,
    actualPercentage: actualPercentage,
    message: _randomString(rng, 10 + rng.nextInt(50)),
    isRead: rng.nextBool(),
    createdAt: createdAt,
    categoryName: categoryName,
    remainingBudget: remainingBudget,
    overAmount: overAmount,
    projectedOverspendDate: projectedOverspendDate,
  );
}

/// Generates a random AlertPreferenceModel with all fields populated.
AlertPreferenceModel _generateAlertPreferenceModel(int seed) {
  final rng = Random(seed);

  // Generate random thresholds (1-6 values, each 10-100 multiples of 5)
  final thresholdCount = 1 + rng.nextInt(6);
  final thresholds = List.generate(
    thresholdCount,
    (_) => (rng.nextInt(19) + 2) * 5, // 10, 15, ..., 100
  )..sort();

  // Quiet hours: either both null or both set
  final hasQuietHours = rng.nextBool();
  final String? quietHoursStart;
  final String? quietHoursEnd;
  if (hasQuietHours) {
    quietHoursStart =
        '${rng.nextInt(24).toString().padLeft(2, '0')}:${rng.nextInt(60).toString().padLeft(2, '0')}';
    quietHoursEnd =
        '${rng.nextInt(24).toString().padLeft(2, '0')}:${rng.nextInt(60).toString().padLeft(2, '0')}';
  } else {
    quietHoursStart = null;
    quietHoursEnd = null;
  }

  return AlertPreferenceModel(
    id: _randomString(rng, 10 + rng.nextInt(10)),
    userId: _randomString(rng, 8),
    categoryId: rng.nextBool() ? _randomString(rng, 8) : null,
    isEnabled: rng.nextBool(),
    thresholds: thresholds,
    predictionsEnabled: rng.nextBool(),
    quietHoursStart: quietHoursStart,
    quietHoursEnd: quietHoursEnd,
  );
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // Feature: smart-budget-alerts, Property 13: BudgetAlertModel serialization round-trip
  // **Validates: Requirements 7.6**
  group('Property 13: BudgetAlertModel serialization round-trip', () {
    Glados(any.intInRange(0, 999999)).test(
      'BudgetAlertModel.fromJson(model.toJson()) == model for all valid instances',
      (seed) {
        final original = _generateBudgetAlertModel(seed);
        final json = original.toJson();
        final restored = BudgetAlertModel.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.userId, equals(original.userId));
        expect(restored.categoryId, equals(original.categoryId));
        expect(restored.alertType, equals(original.alertType));
        expect(restored.thresholdValue, equals(original.thresholdValue));
        expect(
          restored.actualPercentage,
          closeTo(original.actualPercentage, 1e-10),
        );
        expect(restored.message, equals(original.message));
        expect(restored.isRead, equals(original.isRead));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.categoryName, equals(original.categoryName));
        if (original.remainingBudget != null) {
          expect(
            restored.remainingBudget,
            closeTo(original.remainingBudget!, 1e-10),
          );
        } else {
          expect(restored.remainingBudget, isNull);
        }
        if (original.overAmount != null) {
          expect(restored.overAmount, closeTo(original.overAmount!, 1e-10));
        } else {
          expect(restored.overAmount, isNull);
        }
        expect(
          restored.projectedOverspendDate,
          equals(original.projectedOverspendDate),
        );

        // Also verify full equality via == operator
        expect(restored, equals(original));
      },
    );
  });

  // Feature: smart-budget-alerts, Property 14: AlertPreferenceModel serialization round-trip
  // **Validates: Requirements 7.7**
  group('Property 14: AlertPreferenceModel serialization round-trip', () {
    Glados(any.intInRange(0, 999999)).test(
      'AlertPreferenceModel.fromJson(model.toJson()) == model for all valid instances',
      (seed) {
        final original = _generateAlertPreferenceModel(seed);
        final json = original.toJson();
        final restored = AlertPreferenceModel.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.userId, equals(original.userId));
        expect(restored.categoryId, equals(original.categoryId));
        expect(restored.isEnabled, equals(original.isEnabled));
        expect(restored.thresholds, equals(original.thresholds));
        expect(
          restored.predictionsEnabled,
          equals(original.predictionsEnabled),
        );
        expect(restored.quietHoursStart, equals(original.quietHoursStart));
        expect(restored.quietHoursEnd, equals(original.quietHoursEnd));

        // Also verify full equality via == operator
        expect(restored, equals(original));
      },
    );
  });
}
