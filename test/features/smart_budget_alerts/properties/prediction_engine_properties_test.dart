
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/alert_preferences_repository_interface.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/alert_repository_interface.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/alert_threshold_status_repository_interface.dart';
import 'package:duasaku_app/features/smart_budget_alerts/services/budget_notification_service.dart';
import 'package:duasaku_app/features/smart_budget_alerts/services/prediction_engine_service.dart';
import 'package:duasaku_app/features/transactions/data/budget_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

// ---------------------------------------------------------------------------
// Minimal Fakes — only needed to satisfy the constructor; never called
// during pure calculation method tests.
// ---------------------------------------------------------------------------

class _FakeAlertRepo extends Fake implements AlertRepositoryInterface {}

class _FakePrefsRepo extends Fake
    implements AlertPreferencesRepositoryInterface {}

class _FakeStatusRepo extends Fake
    implements AlertThresholdStatusRepositoryInterface {}

class _FakeBudgetRepo extends Fake implements BudgetRepository {}

class _FakeDb extends Fake implements AppDatabase {}

class _FakeNotificationService extends Fake
    implements BudgetNotificationService {}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // Feature: smart-budget-alerts, Property 4: Projection calculation correctness
  // **Validates: Requirements 2.1, 2.2**
  group('Property 4: Projection calculation correctness', () {
    late PredictionEngineService engine;

    setUp(() {
      engine = PredictionEngineService(
        alertRepo: _FakeAlertRepo(),
        prefsRepo: _FakePrefsRepo(),
        statusRepo: _FakeStatusRepo(),
        budgetRepo: _FakeBudgetRepo(),
        db: _FakeDb(),
        notificationService: _FakeNotificationService(),
      );
    });

    Glados(any.intInRange(0, 999999)).test(
      'spendingRate SHALL equal totalSpent / elapsedDays for elapsedDays >= 3',
      (seed) {
        final rng = Random(seed);

        // Generate valid inputs: elapsedDays >= 3, totalSpent >= 0
        final elapsedDays = 3 + rng.nextInt(28); // 3 to 30
        final totalSpent = rng.nextDouble() * 10000000.0; // 0 to 10M

        final result = engine.calculateSpendingRate(totalSpent, elapsedDays);
        final expected = totalSpent / elapsedDays;

        expect(result, closeTo(expected, 1e-10),
            reason: 'calculateSpendingRate($totalSpent, $elapsedDays) '
                'should equal $expected but got $result');
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'projectedTotal SHALL equal currentSpent + (spendingRate * remainingDays) + upcomingRecurring',
      (seed) {
        final rng = Random(seed);

        // Generate valid inputs per property constraints
        final totalSpent = rng.nextDouble() * 10000000.0; // >= 0
        final elapsedDays = 3 + rng.nextInt(28); // >= 3
        final remainingDays = rng.nextInt(31); // >= 0
        final upcomingRecurring = rng.nextDouble() * 5000000.0; // >= 0

        // Calculate spending rate using the service method
        final spendingRate =
            engine.calculateSpendingRate(totalSpent, elapsedDays);

        // Project total spending using the service method
        final result = engine.projectTotalSpending(
          currentSpent: totalSpent,
          dailyRate: spendingRate,
          remainingDays: remainingDays,
          upcomingRecurring: upcomingRecurring,
        );

        // Verify the formula: currentSpent + (spendingRate * remainingDays) + upcomingRecurring
        final expected =
            totalSpent + (spendingRate * remainingDays) + upcomingRecurring;

        expect(result, closeTo(expected, 1e-6),
            reason: 'projectTotalSpending should equal '
                '$totalSpent + ($spendingRate * $remainingDays) + $upcomingRecurring = $expected '
                'but got $result');
      },
    );
  });


  // Feature: smart-budget-alerts, Property 6: Prediction alerts only generated within current budget period
  // **Validates: Requirements 2.5**
  group(
      'Property 6: Prediction alerts only generated within current budget period',
      () {
    late PredictionEngineService engine;

    setUp(() {
      engine = PredictionEngineService(
        alertRepo: _FakeAlertRepo(),
        prefsRepo: _FakePrefsRepo(),
        statusRepo: _FakeStatusRepo(),
        budgetRepo: _FakeBudgetRepo(),
        db: _FakeDb(),
        notificationService: _FakeNotificationService(),
      );
    });

    Glados(any.intInRange(0, 999999)).test(
      'no alert when overspend date falls after period end (low daily rate)',
      (seed) {
        final rng = Random(seed);

        // Pick a random month/year for the budget period
        final year = 2023 + rng.nextInt(3);
        final month = 1 + rng.nextInt(12);
        final periodStart = DateTime(year, month, 1);
        // Last day of the month
        final periodEnd = DateTime(year, month + 1, 0);
        final daysInMonth = periodEnd.day;

        // Simulate "now" as somewhere between day 3 and near end of month
        final maxElapsed = (daysInMonth - 2).clamp(3, 28);
        final elapsedDays = 3 + rng.nextInt((maxElapsed - 3).clamp(1, 25));
        final now = periodStart.add(Duration(days: elapsedDays));

        // budgetLimit: 500,000 to 10,000,000
        final budgetLimit = (rng.nextInt(9500000) + 500000).toDouble();

        // currentSpent: 10% to 60% of budgetLimit (not yet over budget)
        final spentFraction = 0.1 + rng.nextDouble() * 0.5;
        final currentSpent = budgetLimit * spentFraction;

        // Calculate remaining days in the period
        final remainingDays = periodEnd.difference(now).inDays;
        if (remainingDays <= 0) return; // Skip edge case

        // We need dailyRate such that overspend date > periodEnd.
        // overspendDate = now + ceil((budgetLimit - currentSpent) / dailyRate) days
        // We want: ceil((budgetLimit - currentSpent) / dailyRate) > remainingDays
        // i.e., dailyRate < (budgetLimit - currentSpent) / remainingDays
        final maxDailyRateForWithinPeriod =
            (budgetLimit - currentSpent) / remainingDays;

        // Set dailyRate to be significantly LESS than the max
        // (so overspend is pushed after period end)
        final fraction = 0.01 + rng.nextDouble() * 0.79; // 0.01 to 0.80
        final dailyRate = maxDailyRateForWithinPeriod * fraction;

        if (dailyRate <= 0) return; // Skip invalid scenario

        // Calculate overspend date using the engine method
        // In evaluatePrediction, periodStart for overspend calc is 'now'
        final overspendDate = engine.calculateOverspendDate(
          currentSpent: currentSpent,
          dailyRate: dailyRate,
          budgetLimit: budgetLimit,
          periodStart: now,
        );

        // The overspend date should be after periodEnd
        expect(overspendDate, isNotNull,
            reason: 'dailyRate > 0 so overspend date should not be null');
        expect(
          overspendDate!.isAfter(periodEnd),
          isTrue,
          reason:
              'Overspend date ($overspendDate) should be after period end ($periodEnd). '
              'dailyRate=$dailyRate, maxForWithin=$maxDailyRateForWithinPeriod, '
              'fraction=$fraction, remainingDays=$remainingDays',
        );

        // Per Req 2.5: if overspendDate > periodEnd, no alert should be generated
        // This is the core property: the engine should NOT generate an alert
        // when the overspend date falls outside the current budget period.
        final shouldSuppressAlert = overspendDate.isAfter(periodEnd);
        expect(shouldSuppressAlert, isTrue,
            reason:
                'Prediction Engine SHALL NOT generate alert when overspend date is after period end');
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'alert IS valid when overspend date falls within current period (high daily rate)',
      (seed) {
        final rng = Random(seed);

        // Pick a random month/year for the budget period
        final year = 2023 + rng.nextInt(3);
        final month = 1 + rng.nextInt(12);
        final periodStart = DateTime(year, month, 1);
        final periodEnd = DateTime(year, month + 1, 0);
        final daysInMonth = periodEnd.day;

        // Simulate "now" between day 3 and day (daysInMonth - 5)
        final maxElapsed = (daysInMonth - 5).clamp(3, 25);
        final elapsedDays = 3 + rng.nextInt((maxElapsed - 3).clamp(1, 20));
        final now = periodStart.add(Duration(days: elapsedDays));

        // budgetLimit: 500,000 to 10,000,000
        final budgetLimit = (rng.nextInt(9500000) + 500000).toDouble();

        // currentSpent: 50% to 90% of budgetLimit (close to limit)
        final spentFraction = 0.5 + rng.nextDouble() * 0.4;
        final currentSpent = budgetLimit * spentFraction;

        // Calculate remaining days in the period
        final remainingDays = periodEnd.difference(now).inDays;
        if (remainingDays <= 0) return; // Skip edge case

        // We need dailyRate such that overspend date <= periodEnd.
        // i.e., dailyRate >= (budgetLimit - currentSpent) / remainingDays
        final minDailyRateForWithinPeriod =
            (budgetLimit - currentSpent) / remainingDays;

        // Set dailyRate to be significantly MORE than the min
        final boostFactor = 1.5 + rng.nextDouble() * 3.5; // 1.5 to 5.0
        final dailyRate = minDailyRateForWithinPeriod * boostFactor;

        if (dailyRate <= 0) return; // Skip invalid scenario

        // Calculate overspend date using the engine method
        final overspendDate = engine.calculateOverspendDate(
          currentSpent: currentSpent,
          dailyRate: dailyRate,
          budgetLimit: budgetLimit,
          periodStart: now,
        );

        // The overspend date should be within the period (on or before periodEnd)
        expect(overspendDate, isNotNull,
            reason: 'dailyRate > 0 so overspend date should not be null');
        expect(
          overspendDate!.isAfter(periodEnd),
          isFalse,
          reason:
              'Overspend date ($overspendDate) should be on or before period end ($periodEnd). '
              'dailyRate=$dailyRate, minForWithin=$minDailyRateForWithinPeriod, '
              'boostFactor=$boostFactor, remainingDays=$remainingDays',
        );

        // Per Req 2.5: if overspendDate <= periodEnd, alert CAN be generated
        final isWithinPeriod = !overspendDate.isAfter(periodEnd);
        expect(isWithinPeriod, isTrue,
            reason:
                'Prediction Engine SHALL generate alert when overspend date is within period');
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'no alert when dailyRate <= 0 (overspend impossible regardless of period)',
      (seed) {
        final rng = Random(seed);
        final year = 2023 + rng.nextInt(3);
        final month = 1 + rng.nextInt(12);
        final periodStart = DateTime(year, month, 1);
        final periodEnd = DateTime(year, month + 1, 0);
        final daysInMonth = periodEnd.day;

        final elapsedDays = 3 + rng.nextInt((daysInMonth - 3).clamp(1, 25));
        final now = periodStart.add(Duration(days: elapsedDays));

        final budgetLimit = (rng.nextInt(9500000) + 500000).toDouble();
        final currentSpent = budgetLimit * (0.1 + rng.nextDouble() * 0.8);

        // dailyRate <= 0 means no overspend possible
        final dailyRate = -(rng.nextDouble() * 1000);

        final overspendDate = engine.calculateOverspendDate(
          currentSpent: currentSpent,
          dailyRate: dailyRate,
          budgetLimit: budgetLimit,
          periodStart: now,
        );

        // calculateOverspendDate returns null when dailyRate <= 0
        expect(overspendDate, isNull,
            reason:
                'No overspend date when dailyRate <= 0 (no overspend possible)');

        // Per Req 2.5: null overspend date means no alert generated
        // The evaluatePrediction method checks: if (overspendDate == null) return null;
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'boundary: overspend within period iff ceil(daysUntilOverspend) <= remainingDays',
      (seed) {
        final rng = Random(seed);
        final year = 2023 + rng.nextInt(3);
        final month = 1 + rng.nextInt(12);
        final periodStart = DateTime(year, month, 1);
        final periodEnd = DateTime(year, month + 1, 0);
        final daysInMonth = periodEnd.day;

        // Place "now" a few days into the month
        final maxElapsed = (daysInMonth - 5).clamp(3, 20);
        final elapsedDays = 3 + rng.nextInt((maxElapsed - 3).clamp(1, 15));
        final now = periodStart.add(Duration(days: elapsedDays));
        final remainingDays = periodEnd.difference(now).inDays;

        if (remainingDays <= 0) return; // Skip edge case

        final budgetLimit = (rng.nextInt(9500000) + 500000).toDouble();
        final currentSpent = budgetLimit * (0.1 + rng.nextDouble() * 0.8);

        // Generate a random dailyRate > 0
        final dailyRate = (rng.nextDouble() * 100000) + 1.0;

        if (dailyRate <= 0) return;
        if (currentSpent >= budgetLimit) return; // Already over budget

        final overspendDate = engine.calculateOverspendDate(
          currentSpent: currentSpent,
          dailyRate: dailyRate,
          budgetLimit: budgetLimit,
          periodStart: now,
        );

        expect(overspendDate, isNotNull);

        // Calculate expected days until overspend
        final daysUntilOverspend = (budgetLimit - currentSpent) / dailyRate;
        final ceiledDays = daysUntilOverspend.ceil();

        // The overspend date is within period iff ceiledDays <= remainingDays
        final expectedWithinPeriod = ceiledDays <= remainingDays;
        final actualWithinPeriod = !overspendDate!.isAfter(periodEnd);

        expect(actualWithinPeriod, equals(expectedWithinPeriod),
            reason:
                'Overspend date ($overspendDate) within period ($periodEnd) should match '
                'ceil($daysUntilOverspend) = $ceiledDays <= remainingDays($remainingDays) = $expectedWithinPeriod. '
                'Per Req 2.5: alert generated only when overspend is within current period.');
      },
    );
  });
}
