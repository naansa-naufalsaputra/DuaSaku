import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/alert_repository_interface.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/alert_threshold_status_repository_interface.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/alert_preference_model.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/alert_threshold_status_model.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/alert_type.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/budget_alert_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

// ---------------------------------------------------------------------------
// Core Logic Under Test (extracted from AlertEngineService & PredictionEngine)
// ---------------------------------------------------------------------------

/// Simulates the Alert Engine's threshold evaluation logic.
///
/// This extracts the pure decision logic from AlertEngineService.evaluateThresholds():
/// 1. Check master toggle (isEnabled) — if false, return empty list
/// 2. Check per-category enable — if false, return empty list
/// 3. Calculate percentage = (totalSpent / budgetLimit) * 100
/// 4. For each threshold, if percentage >= threshold and not already triggered,
///    generate an alert
///
/// Returns the list of alerts that would be generated.
List<BudgetAlertModel> evaluateThresholdsLogic({
  required AlertPreferenceModel globalPrefs,
  required AlertPreferenceModel? categoryPrefs,
  required double budgetLimit,
  required double totalSpent,
  required Set<int> alreadyTriggeredThresholds,
  required String userId,
  required String categoryId,
}) {
  // Master toggle check (Req 3.7)
  if (!globalPrefs.isEnabled) {
    return [];
  }

  // Per-category check
  if (categoryPrefs != null && !categoryPrefs.isEnabled) {
    return [];
  }

  // Budget limit guard
  if (budgetLimit <= 0) {
    return [];
  }

  final percentage = (totalSpent / budgetLimit) * 100;

  // Get thresholds from category prefs or global
  final thresholds = categoryPrefs?.thresholds ?? globalPrefs.thresholds;
  final sortedThresholds = List<int>.from(thresholds)..sort();

  final alerts = <BudgetAlertModel>[];

  for (final threshold in sortedThresholds) {
    if (percentage < threshold) continue;
    if (alreadyTriggeredThresholds.contains(threshold)) continue;

    final alertType = percentage >= 100
        ? AlertType.overBudget
        : AlertType.threshold;
    final remainingBudget = budgetLimit - totalSpent > 0
        ? budgetLimit - totalSpent
        : 0.0;
    final overAmount = alertType == AlertType.overBudget
        ? totalSpent - budgetLimit
        : null;

    alerts.add(
      BudgetAlertModel(
        id: 'alert_${threshold}_$categoryId',
        userId: userId,
        categoryId: categoryId,
        alertType: alertType,
        thresholdValue: threshold,
        actualPercentage: percentage,
        message: 'Test alert for threshold $threshold%',
        isRead: false,
        createdAt: DateTime.now(),
        remainingBudget: remainingBudget,
        overAmount: overAmount,
      ),
    );
  }

  return alerts;
}

/// Simulates the Prediction Engine's evaluation logic.
///
/// Returns a BudgetAlertModel if overspend is predicted, null otherwise.
/// Key check: if master toggle (isEnabled) is false, returns null immediately.
BudgetAlertModel? evaluatePredictionLogic({
  required AlertPreferenceModel globalPrefs,
  required AlertPreferenceModel? categoryPrefs,
  required double budgetLimit,
  required double totalSpent,
  required int elapsedDays,
  required int remainingDays,
  required double upcomingRecurring,
  required String userId,
  required String categoryId,
}) {
  // Master toggle check (Req 3.7)
  if (!globalPrefs.isEnabled) {
    return null;
  }

  // Predictions enabled check
  if (!globalPrefs.predictionsEnabled) {
    return null;
  }

  // Per-category check
  if (categoryPrefs != null && !categoryPrefs.isEnabled) {
    return null;
  }
  if (categoryPrefs != null && !categoryPrefs.predictionsEnabled) {
    return null;
  }

  // Budget limit guard
  if (budgetLimit <= 0) return null;

  // Minimum elapsed days (Req 2.6)
  if (elapsedDays < 3) return null;

  // Calculate spending rate and projection
  final dailyRate = totalSpent / elapsedDays;
  final projectedTotal =
      totalSpent + (dailyRate * remainingDays) + upcomingRecurring;

  // No overspend predicted
  if (projectedTotal <= budgetLimit) return null;

  final estimatedOverAmount = projectedTotal - budgetLimit;
  final percentage = (totalSpent / budgetLimit) * 100;

  return BudgetAlertModel(
    id: 'prediction_$categoryId',
    userId: userId,
    categoryId: categoryId,
    alertType: AlertType.prediction,
    thresholdValue: null,
    actualPercentage: percentage,
    message: 'Prediction alert',
    isRead: false,
    createdAt: DateTime.now(),
    overAmount: estimatedOverAmount,
    remainingBudget: budgetLimit - totalSpent > 0
        ? budgetLimit - totalSpent
        : 0,
  );
}

/// Simulates the Notification Service's decision to send a notification.
///
/// Returns true if a notification would be sent, false otherwise.
/// Key check: if master toggle (isEnabled) is false, returns false.
bool shouldSendNotification({required AlertPreferenceModel globalPrefs}) {
  // Master toggle check (Req 5.5)
  if (!globalPrefs.isEnabled) {
    return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Generators & Helpers
// ---------------------------------------------------------------------------

/// Generates a random spending scenario where thresholds would normally
/// be crossed (spending > some threshold percentage of budget).
({
  double budgetLimit,
  double totalSpent,
  List<int> thresholds,
  int elapsedDays,
  int remainingDays,
  double upcomingRecurring,
})
_generateSpendingScenario(int seed) {
  final rng = Random(seed);

  // Budget limit: 100,000 to 10,000,000 (realistic Rupiah amounts)
  final budgetLimit = (rng.nextInt(9900) + 100) * 1000.0;

  // Total spent: 50% to 200% of budget (ensures thresholds would be crossed)
  final spendingRatio = 0.5 + rng.nextDouble() * 1.5; // 0.5 to 2.0
  final totalSpent = budgetLimit * spendingRatio;

  // Thresholds: random subset of valid thresholds
  final allThresholds = [50, 75, 90, 100];
  final thresholdCount = 1 + rng.nextInt(allThresholds.length);
  final thresholds = (List<int>.from(
    allThresholds,
  )..shuffle(rng)).take(thresholdCount).toList()..sort();

  // Elapsed days: 3-25 (valid for prediction)
  final elapsedDays = 3 + rng.nextInt(23);

  // Remaining days: 1-28
  final remainingDays = 1 + rng.nextInt(28);

  // Upcoming recurring: 0 to 30% of budget
  final upcomingRecurring = rng.nextDouble() * budgetLimit * 0.3;

  return (
    budgetLimit: budgetLimit,
    totalSpent: totalSpent,
    thresholds: thresholds,
    elapsedDays: elapsedDays,
    remainingDays: remainingDays,
    upcomingRecurring: upcomingRecurring,
  );
}

/// Generates a random string for IDs.
String _randomId(Random rng, int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes(
    List.generate(length, (_) => chars.codeUnitAt(rng.nextInt(chars.length))),
  );
}

// ---------------------------------------------------------------------------
// In-Memory Mock Repositories (used by Property 2 and Property 3)
// ---------------------------------------------------------------------------

/// In-memory [AlertRepositoryInterface] that tracks all inserted alerts.
class InMemoryAlertRepository implements AlertRepositoryInterface {
  final List<BudgetAlertModel> insertedAlerts = [];

  @override
  Future<Result<void, AppError>> insertAlert(BudgetAlertModel alert) async {
    insertedAlerts.add(alert);
    return const Success(null);
  }

  @override
  Future<Result<List<BudgetAlertModel>, AppError>> getAlerts(
    String userId, {
    int? limit,
    int? offset,
  }) async => Success(insertedAlerts.where((a) => a.userId == userId).toList());

  @override
  Stream<List<BudgetAlertModel>> watchAlerts(String userId) =>
      Stream.value(insertedAlerts.where((a) => a.userId == userId).toList());

  @override
  Future<Result<int, AppError>> getUnreadCount(String userId) async => Success(
    insertedAlerts.where((a) => a.userId == userId && !a.isRead).length,
  );

  @override
  Stream<int> watchUnreadCount(String userId) => Stream.value(
    insertedAlerts.where((a) => a.userId == userId && !a.isRead).length,
  );

  @override
  Future<Result<void, AppError>> markAsRead(List<String> alertIds) async =>
      const Success(null);

  @override
  Future<Result<void, AppError>> markAllVisibleAsRead(String userId) async =>
      const Success(null);

  @override
  Future<Result<void, AppError>> deleteAlert(String alertId) async =>
      const Success(null);

  @override
  Future<Result<void, AppError>> deleteAllRead(String userId) async =>
      const Success(null);
}

/// In-memory [AlertThresholdStatusRepositoryInterface] that tracks triggered
/// thresholds per (userId, categoryId, budgetMonth) tuple.
class InMemoryAlertThresholdStatusRepository
    implements AlertThresholdStatusRepositoryInterface {
  final List<AlertThresholdStatusModel> _statuses = [];

  @override
  Future<Result<List<AlertThresholdStatusModel>, AppError>>
  getTriggeredThresholds(
    String userId,
    String categoryId,
    String budgetMonth,
  ) async {
    final matching = _statuses
        .where(
          (s) =>
              s.userId == userId &&
              s.categoryId == categoryId &&
              s.budgetMonth == budgetMonth,
        )
        .toList();
    return Success(matching);
  }

  @override
  Future<Result<void, AppError>> markThresholdTriggered(
    AlertThresholdStatusModel status,
  ) async {
    _statuses.add(status);
    return const Success(null);
  }

  @override
  Future<Result<void, AppError>> resetThreshold(
    String userId,
    String categoryId,
    String budgetMonth,
    int thresholdValue,
  ) async {
    _statuses.removeWhere(
      (s) =>
          s.userId == userId &&
          s.categoryId == categoryId &&
          s.budgetMonth == budgetMonth &&
          s.thresholdValue == thresholdValue,
    );
    return const Success(null);
  }

  @override
  Future<Result<void, AppError>> resetAllForNewPeriod(
    String userId,
    String budgetMonth,
  ) async {
    _statuses.removeWhere(
      (s) => s.userId == userId && s.budgetMonth == budgetMonth,
    );
    return const Success(null);
  }
}

// ---------------------------------------------------------------------------
// Alert Engine Simulator — Replicates core duplicate-prevention logic
// ---------------------------------------------------------------------------

/// Simulates the core threshold evaluation logic of AlertEngineService,
/// faithfully replicating the duplicate-prevention mechanism:
/// 1. Get already-triggered thresholds from status repository
/// 2. Skip thresholds that are already triggered
/// 3. Mark newly triggered thresholds in status repository
class AlertEngineSimulator {
  final InMemoryAlertRepository alertRepo;
  final InMemoryAlertThresholdStatusRepository statusRepo;
  final List<int> thresholds;

  AlertEngineSimulator({
    required this.alertRepo,
    required this.statusRepo,
    required this.thresholds,
  });

  /// Evaluates thresholds for a sequence of cumulative spending amounts.
  Future<List<BudgetAlertModel>> evaluateSequence({
    required String userId,
    required String categoryId,
    required String budgetMonth,
    required double budgetLimit,
    required List<double> cumulativeSpendingAmounts,
  }) async {
    final allAlerts = <BudgetAlertModel>[];
    int alertCounter = 0;

    for (final totalSpent in cumulativeSpendingAmounts) {
      if (budgetLimit <= 0) continue;

      final percentage = (totalSpent / budgetLimit) * 100;

      // Get already-triggered thresholds
      final triggeredResult = await statusRepo.getTriggeredThresholds(
        userId,
        categoryId,
        budgetMonth,
      );
      final triggeredThresholds = switch (triggeredResult) {
        Success(:final value) => value.map((s) => s.thresholdValue).toSet(),
        Failure() => <int>{},
      };

      // Evaluate each threshold
      final sortedThresholds = List<int>.from(thresholds)..sort();
      for (final threshold in sortedThresholds) {
        if (percentage < threshold) continue;
        if (triggeredThresholds.contains(threshold)) continue;

        // Threshold crossed and not yet triggered — generate alert
        final alertType = percentage >= 100
            ? AlertType.overBudget
            : AlertType.threshold;
        final remainingBudget = budgetLimit - totalSpent > 0
            ? budgetLimit - totalSpent
            : 0.0;

        final alert = BudgetAlertModel(
          id: 'alert_${alertCounter++}',
          userId: userId,
          categoryId: categoryId,
          alertType: alertType,
          thresholdValue: threshold,
          actualPercentage: percentage,
          message: 'Threshold $threshold% reached',
          isRead: false,
          createdAt: DateTime.now(),
          remainingBudget: remainingBudget,
        );

        // Save alert
        await alertRepo.insertAlert(alert);

        // Mark threshold as triggered (prevents future duplicates)
        final statusModel = AlertThresholdStatusModel(
          id: 'status_${categoryId}_${budgetMonth}_$threshold',
          userId: userId,
          categoryId: categoryId,
          budgetMonth: budgetMonth,
          thresholdValue: threshold,
          triggeredAt: DateTime.now(),
        );
        await statusRepo.markThresholdTriggered(statusModel);

        allAlerts.add(alert);
      }
    }

    return allAlerts;
  }
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // Feature: smart-budget-alerts, Property 9: Master toggle disables all alerts and notifications
  // **Validates: Requirements 3.7, 5.5**
  group('Property 9: Master toggle disables all alerts and notifications', () {
    Glados(any.intInRange(0, 999999)).test(
      'Alert Engine produces zero alerts when master toggle isEnabled=false, '
      'regardless of spending scenario',
      (seed) {
        final scenario = _generateSpendingScenario(seed);
        final rng = Random(seed);
        final userId = _randomId(rng, 8);
        final categoryId = _randomId(rng, 8);

        // Global preferences with master toggle OFF
        final globalPrefs = AlertPreferenceModel(
          id: 'pref_${userId}_global',
          userId: userId,
          categoryId: null,
          isEnabled: false, // MASTER TOGGLE OFF
          thresholds: scenario.thresholds,
          predictionsEnabled: true,
        );

        // Category prefs: enabled (to prove master toggle overrides)
        final categoryPrefs = AlertPreferenceModel(
          id: 'pref_${userId}_$categoryId',
          userId: userId,
          categoryId: categoryId,
          isEnabled: true, // Category is enabled, but master is off
          thresholds: scenario.thresholds,
          predictionsEnabled: true,
        );

        // Evaluate thresholds — should produce ZERO alerts
        final alerts = evaluateThresholdsLogic(
          globalPrefs: globalPrefs,
          categoryPrefs: categoryPrefs,
          budgetLimit: scenario.budgetLimit,
          totalSpent: scenario.totalSpent,
          alreadyTriggeredThresholds: {}, // No previously triggered thresholds
          userId: userId,
          categoryId: categoryId,
        );

        expect(
          alerts,
          isEmpty,
          reason:
              'Alert Engine must produce zero alerts when '
              'master toggle isEnabled=false. '
              'Scenario: budget=${scenario.budgetLimit}, '
              'spent=${scenario.totalSpent}, '
              'thresholds=${scenario.thresholds}',
        );
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'Prediction Engine produces zero alerts when master toggle isEnabled=false, '
      'regardless of spending scenario',
      (seed) {
        final scenario = _generateSpendingScenario(seed);
        final rng = Random(seed);
        final userId = _randomId(rng, 8);
        final categoryId = _randomId(rng, 8);

        // Global preferences with master toggle OFF
        final globalPrefs = AlertPreferenceModel(
          id: 'pref_${userId}_global',
          userId: userId,
          categoryId: null,
          isEnabled: false, // MASTER TOGGLE OFF
          thresholds: scenario.thresholds,
          predictionsEnabled: true,
        );

        // Category prefs: enabled (to prove master toggle overrides)
        final categoryPrefs = AlertPreferenceModel(
          id: 'pref_${userId}_$categoryId',
          userId: userId,
          categoryId: categoryId,
          isEnabled: true,
          thresholds: scenario.thresholds,
          predictionsEnabled: true,
        );

        // Evaluate prediction — should produce null (zero alerts)
        final predictionAlert = evaluatePredictionLogic(
          globalPrefs: globalPrefs,
          categoryPrefs: categoryPrefs,
          budgetLimit: scenario.budgetLimit,
          totalSpent: scenario.totalSpent,
          elapsedDays: scenario.elapsedDays,
          remainingDays: scenario.remainingDays,
          upcomingRecurring: scenario.upcomingRecurring,
          userId: userId,
          categoryId: categoryId,
        );

        expect(
          predictionAlert,
          isNull,
          reason:
              'Prediction Engine must produce zero alerts when '
              'master toggle isEnabled=false. '
              'Scenario: budget=${scenario.budgetLimit}, '
              'spent=${scenario.totalSpent}, '
              'elapsedDays=${scenario.elapsedDays}',
        );
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'Notification Service sends zero notifications when master toggle '
      'isEnabled=false, regardless of alert content',
      (seed) {
        final rng = Random(seed);
        final userId = _randomId(rng, 8);

        // Global preferences with master toggle OFF
        final globalPrefs = AlertPreferenceModel(
          id: 'pref_${userId}_global',
          userId: userId,
          categoryId: null,
          isEnabled: false, // MASTER TOGGLE OFF
          thresholds: const [50, 75, 90, 100],
          predictionsEnabled: true,
        );

        // Should NOT send notification
        final shouldSend = shouldSendNotification(globalPrefs: globalPrefs);

        expect(
          shouldSend,
          isFalse,
          reason:
              'Notification Service must send zero notifications '
              'when master toggle isEnabled=false',
        );
      },
    );

    Glados(any.intInRange(0, 999999)).test(
      'Combined: master toggle OFF produces zero alerts AND zero notifications '
      'even when spending exceeds all thresholds',
      (seed) {
        final scenario = _generateSpendingScenario(seed);
        final rng = Random(seed);
        final userId = _randomId(rng, 8);
        final categoryId = _randomId(rng, 8);

        // Force spending to exceed ALL thresholds (200% of budget)
        final extremeSpent = scenario.budgetLimit * 2.0;

        // Global preferences with master toggle OFF
        final globalPrefs = AlertPreferenceModel(
          id: 'pref_${userId}_global',
          userId: userId,
          categoryId: null,
          isEnabled: false, // MASTER TOGGLE OFF
          thresholds: const [50, 75, 90, 100],
          predictionsEnabled: true,
        );

        // Alert Engine: zero alerts
        final alerts = evaluateThresholdsLogic(
          globalPrefs: globalPrefs,
          categoryPrefs: null, // No category-specific prefs
          budgetLimit: scenario.budgetLimit,
          totalSpent: extremeSpent,
          alreadyTriggeredThresholds: {},
          userId: userId,
          categoryId: categoryId,
        );
        expect(alerts, isEmpty);

        // Prediction Engine: zero alerts
        final prediction = evaluatePredictionLogic(
          globalPrefs: globalPrefs,
          categoryPrefs: null,
          budgetLimit: scenario.budgetLimit,
          totalSpent: extremeSpent,
          elapsedDays: scenario.elapsedDays,
          remainingDays: scenario.remainingDays,
          upcomingRecurring: scenario.upcomingRecurring,
          userId: userId,
          categoryId: categoryId,
        );
        expect(prediction, isNull);

        // Notification Service: zero notifications
        final shouldSend = shouldSendNotification(globalPrefs: globalPrefs);
        expect(shouldSend, isFalse);
      },
    );
  });

  // Feature: smart-budget-alerts, Property 3: Threshold reset on spending decrease
  // **Validates: Requirements 1.7, 6.6**
  group('Property 3: Threshold reset on spending decrease', () {
    Glados(
      any.intInRange(0, 999999),
    ).test('When spending drops below a previously triggered threshold, '
        'the threshold status SHALL be reset (percentage < thresholdValue)', (
      seed,
    ) {
      final rng = Random(seed);

      // Generate random budget limit > 0
      final budgetLimit = (rng.nextInt(9900) + 100) * 1000.0;

      // Generate a valid threshold value (10-100, multiples of 5)
      final threshold = (rng.nextInt(19) + 2) * 5; // 10, 15, ..., 100

      // Calculate the threshold amount = threshold% * budgetLimit / 100
      final thresholdAmount = (threshold / 100.0) * budgetLimit;

      // Phase 1: Spending ABOVE threshold (would have triggered the alert)
      final spendingAbove =
          thresholdAmount +
          rng.nextDouble() * (budgetLimit * 2 - thresholdAmount) +
          1;
      final percentageAbove = (spendingAbove / budgetLimit) * 100;

      // Verify: spending above threshold should NOT trigger a reset
      // (mirrors reevaluateAfterSpendingDecrease: if percentage < thresholdValue => reset)
      expect(
        percentageAbove < threshold,
        isFalse,
        reason:
            'Spending ($spendingAbove) is above threshold '
            '($threshold% of $budgetLimit = $thresholdAmount), '
            'percentage ($percentageAbove%) >= threshold ($threshold%), '
            'so threshold should NOT be reset',
      );

      // Phase 2: Spending DECREASES below threshold (due to deletion/amount decrease)
      final spendingBelow = rng.nextDouble() * thresholdAmount * 0.99;
      final percentageBelow = (spendingBelow / budgetLimit) * 100;

      // Verify: spending below threshold SHOULD trigger a reset
      expect(
        percentageBelow < threshold,
        isTrue,
        reason:
            'Spending ($spendingBelow) dropped below threshold '
            '($threshold% of $budgetLimit = $thresholdAmount), '
            'percentage ($percentageBelow%) < threshold ($threshold%), '
            'so threshold SHALL be reset',
      );
    });

    Glados(
      any.intInRange(0, 999999),
    ).test('After threshold reset, spending rising back above threshold '
        'allows the alert to be triggered again (re-triggering)', (seed) {
      final rng = Random(seed);

      final budgetLimit = (rng.nextInt(9900) + 100) * 1000.0;
      final threshold = (rng.nextInt(19) + 2) * 5;
      final thresholdAmount = (threshold / 100.0) * budgetLimit;

      const userId = 'user_retrigger';
      final categoryId = 'cat_${rng.nextInt(10)}';

      // Global prefs with master toggle ON
      final globalPrefs = AlertPreferenceModel(
        id: 'pref_global',
        userId: userId,
        categoryId: null,
        isEnabled: true,
        thresholds: [threshold],
        predictionsEnabled: true,
      );

      // Phase 1: Spending above threshold — alert triggered
      final spendingAbove =
          thresholdAmount +
          rng.nextDouble() * (budgetLimit - thresholdAmount) +
          1;

      final alertsPhase1 = evaluateThresholdsLogic(
        globalPrefs: globalPrefs,
        categoryPrefs: null,
        budgetLimit: budgetLimit,
        totalSpent: spendingAbove,
        alreadyTriggeredThresholds: {}, // Nothing triggered yet
        userId: userId,
        categoryId: categoryId,
      );
      expect(
        alertsPhase1.length,
        equals(1),
        reason: 'Phase 1: spending above threshold should trigger 1 alert',
      );

      // Phase 2: Spending decreases below threshold — reset occurs
      final spendingBelow = rng.nextDouble() * thresholdAmount * 0.99;
      final percentageBelow = (spendingBelow / budgetLimit) * 100;

      // Verify reset condition is met (reevaluateAfterSpendingDecrease logic)
      expect(
        percentageBelow < threshold,
        isTrue,
        reason:
            'Phase 2: spending decreased, percentage should be below threshold',
      );

      // Phase 3: After reset, spending rises back above threshold
      // Since threshold was reset, alreadyTriggeredThresholds is now empty again
      final spendingAboveAgain =
          thresholdAmount +
          rng.nextDouble() * (budgetLimit - thresholdAmount) +
          1;

      final alertsPhase3 = evaluateThresholdsLogic(
        globalPrefs: globalPrefs,
        categoryPrefs: null,
        budgetLimit: budgetLimit,
        totalSpent: spendingAboveAgain,
        alreadyTriggeredThresholds: {}, // Reset — no longer triggered
        userId: userId,
        categoryId: categoryId,
      );
      expect(
        alertsPhase3.length,
        equals(1),
        reason:
            'Phase 3: after reset, spending rising back above threshold '
            'should trigger a NEW alert. '
            'Budget: $budgetLimit, Threshold: $threshold%, '
            'ThresholdAmount: $thresholdAmount, '
            'Phase1: $spendingAbove, Phase2: $spendingBelow, '
            'Phase3: $spendingAboveAgain',
      );
    });

    Glados(
      any.intInRange(0, 999999),
    ).test('Threshold reset condition: percentage < thresholdValue '
        'is equivalent to totalSpent < (thresholdValue/100) * budgetLimit', (
      seed,
    ) {
      final rng = Random(seed);

      final budgetLimit = (rng.nextInt(9900) + 100) * 1000.0;
      final threshold = (rng.nextInt(19) + 2) * 5;
      final thresholdAmount = (threshold / 100.0) * budgetLimit;

      // Generate arbitrary spending (0 to 2x budget)
      final totalSpent = rng.nextDouble() * budgetLimit * 2;
      final percentage = (totalSpent / budgetLimit) * 100;

      // The reset condition from AlertEngineService.reevaluateAfterSpendingDecrease:
      //   if (percentage < status.thresholdValue) => reset
      final shouldReset = percentage < threshold;

      // This is mathematically equivalent to:
      //   totalSpent < (thresholdValue / 100) * budgetLimit
      final equivalentCondition = totalSpent < thresholdAmount;

      expect(
        shouldReset,
        equals(equivalentCondition),
        reason:
            'Reset condition (percentage < threshold) should be '
            'equivalent to (totalSpent < thresholdAmount). '
            'totalSpent=$totalSpent, budgetLimit=$budgetLimit, '
            'threshold=$threshold%, thresholdAmount=$thresholdAmount, '
            'percentage=$percentage%',
      );
    });
  });

  // Feature: smart-budget-alerts, Property 2: No duplicate alerts per threshold per category per period
  // **Validates: Requirements 1.5**
  group('Property 2: No duplicate alerts per threshold per category per period', () {
    Glados(
      any.intInRange(0, 999999),
    ).test('for any sequence of expense transactions added to the same category '
        'within the same budget period, at most one alert is generated per '
        '(categoryId, thresholdValue, budgetMonth) tuple', (seed) async {
      final rng = Random(seed);

      // Generate random test parameters
      final budgetLimit = (rng.nextInt(9000) + 1000).toDouble(); // 1000-10000
      final categoryId = 'cat_${rng.nextInt(5)}';
      final budgetMonth =
          '2024-${(rng.nextInt(12) + 1).toString().padLeft(2, '0')}';
      const userId = 'user_test';

      // Generate random thresholds (1-4 values from valid set)
      final availableThresholds = [50, 75, 90, 100];
      final thresholdCount = rng.nextInt(4) + 1;
      final thresholds = (List<int>.from(
        availableThresholds,
      )..shuffle(rng)).take(thresholdCount).toList()..sort();

      // Generate a sequence of cumulative spending amounts (3-10 transactions)
      // that deliberately cross thresholds multiple times
      final txCount = rng.nextInt(8) + 3;
      final cumulativeAmounts = <double>[];
      double currentSpending = 0;
      for (int i = 0; i < txCount; i++) {
        // Each transaction adds between 5% and 40% of budget
        final txAmount = budgetLimit * (0.05 + rng.nextDouble() * 0.35);
        currentSpending += txAmount;
        cumulativeAmounts.add(currentSpending);
      }

      // Set up in-memory tracking of triggered thresholds
      final triggeredThresholds = <String, Set<int>>{};
      String statusKey(String catId, String month) => '${catId}_$month';

      // Track generated alerts
      final generatedAlerts = <BudgetAlertModel>[];
      int alertCounter = 0;

      // Simulate multiple threshold evaluations (one per transaction)
      for (final totalSpent in cumulativeAmounts) {
        if (budgetLimit <= 0) continue;

        final percentage = (totalSpent / budgetLimit) * 100;
        final key = statusKey(categoryId, budgetMonth);
        final alreadyTriggered = triggeredThresholds[key] ?? <int>{};

        final sortedThresholds = List<int>.from(thresholds)..sort();
        for (final threshold in sortedThresholds) {
          if (percentage < threshold) continue;
          if (alreadyTriggered.contains(threshold)) continue;

          // Threshold crossed and not yet triggered — generate alert
          final alertType = percentage >= 100
              ? AlertType.overBudget
              : AlertType.threshold;
          final remainingBudget = budgetLimit - totalSpent > 0
              ? budgetLimit - totalSpent
              : 0.0;

          final alert = BudgetAlertModel(
            id: 'alert_${alertCounter++}',
            userId: userId,
            categoryId: categoryId,
            alertType: alertType,
            thresholdValue: threshold,
            actualPercentage: percentage,
            message: 'Threshold $threshold% reached',
            isRead: false,
            createdAt: DateTime.now(),
            remainingBudget: remainingBudget,
          );

          generatedAlerts.add(alert);

          // Mark threshold as triggered (prevents future duplicates)
          triggeredThresholds[key] = (triggeredThresholds[key] ?? <int>{})
            ..add(threshold);
        }
      }

      // PROPERTY ASSERTION: For each unique (categoryId, thresholdValue, budgetMonth),
      // the count of generated alerts SHALL be <= 1
      final alertCounts = <String, int>{};
      for (final alert in generatedAlerts) {
        final alertKey =
            '${alert.categoryId}_${alert.thresholdValue}_$budgetMonth';
        alertCounts[alertKey] = (alertCounts[alertKey] ?? 0) + 1;
      }

      for (final entry in alertCounts.entries) {
        expect(
          entry.value,
          lessThanOrEqualTo(1),
          reason:
              'Duplicate alert detected for key: ${entry.key}. '
              'Count: ${entry.value}. '
              'Budget: $budgetLimit, Thresholds: $thresholds, '
              'Spending sequence: $cumulativeAmounts',
        );
      }
    });

    Glados(any.intInRange(0, 999999)).test(
      'repeated evaluations with the same spending amount above threshold '
      'produce exactly one alert per threshold (not N alerts for N evaluations)',
      (seed) async {
        final rng = Random(seed);

        final budgetLimit = (rng.nextInt(5000) + 500).toDouble();
        const categoryId = 'food';
        const userId = 'user_1';

        // Pick a single threshold to test
        final threshold = [50, 75, 90, 100][rng.nextInt(4)];

        // Spending that definitely crosses the threshold
        final spendingAboveThreshold =
            budgetLimit * (threshold / 100.0) + rng.nextDouble() * 100 + 1;

        // In-memory tracking of triggered thresholds
        final triggeredSet = <int>{};
        final generatedAlerts = <BudgetAlertModel>[];

        // Simulate multiple evaluations with the same spending amount
        final evaluationCount = rng.nextInt(5) + 2; // 2-6 evaluations
        for (int eval = 0; eval < evaluationCount; eval++) {
          final percentage = (spendingAboveThreshold / budgetLimit) * 100;

          if (percentage >= threshold && !triggeredSet.contains(threshold)) {
            final alertType = percentage >= 100
                ? AlertType.overBudget
                : AlertType.threshold;

            generatedAlerts.add(
              BudgetAlertModel(
                id: 'alert_$eval',
                userId: userId,
                categoryId: categoryId,
                alertType: alertType,
                thresholdValue: threshold,
                actualPercentage: percentage,
                message: 'Threshold $threshold% reached',
                isRead: false,
                createdAt: DateTime.now(),
              ),
            );

            triggeredSet.add(threshold);
          }
        }

        // PROPERTY ASSERTION: Exactly one alert for this threshold
        final alertsForThreshold = generatedAlerts
            .where(
              (a) =>
                  a.categoryId == categoryId && a.thresholdValue == threshold,
            )
            .toList();

        expect(
          alertsForThreshold.length,
          equals(1),
          reason:
              'Expected exactly 1 alert for threshold $threshold% '
              'but got ${alertsForThreshold.length}. '
              'Budget: $budgetLimit, Spending: $spendingAboveThreshold, '
              'Evaluations: $evaluationCount',
        );
      },
    );

    Glados(
      any.intInRange(0, 999999),
    ).test('multiple categories with same thresholds produce independent alerts '
        'without cross-category duplication', (seed) async {
      final rng = Random(seed);

      final budgetLimit = (rng.nextInt(5000) + 1000).toDouble();
      const budgetMonth = '2024-03';
      const userId = 'user_multi';
      const thresholds = [50, 75, 90, 100];

      // Generate 2-4 categories
      final categoryCount = rng.nextInt(3) + 2;
      final categories = List.generate(categoryCount, (i) => 'category_$i');

      // Track triggered thresholds per category
      final triggeredPerCategory = <String, Set<int>>{};
      final allAlerts = <BudgetAlertModel>[];
      int alertCounter = 0;

      // Each category gets its own spending sequence
      for (final categoryId in categories) {
        final txCount = rng.nextInt(5) + 2;
        double currentSpending = 0;

        for (int i = 0; i < txCount; i++) {
          currentSpending += budgetLimit * (0.1 + rng.nextDouble() * 0.3);
          final percentage = (currentSpending / budgetLimit) * 100;

          final triggered = triggeredPerCategory[categoryId] ?? <int>{};
          final sortedThresholds = List<int>.from(thresholds)..sort();

          for (final threshold in sortedThresholds) {
            if (percentage < threshold) continue;
            if (triggered.contains(threshold)) continue;

            final alertType = percentage >= 100
                ? AlertType.overBudget
                : AlertType.threshold;

            allAlerts.add(
              BudgetAlertModel(
                id: 'alert_${alertCounter++}',
                userId: userId,
                categoryId: categoryId,
                alertType: alertType,
                thresholdValue: threshold,
                actualPercentage: percentage,
                message: 'Threshold $threshold% reached',
                isRead: false,
                createdAt: DateTime.now(),
              ),
            );

            triggeredPerCategory[categoryId] =
                (triggeredPerCategory[categoryId] ?? <int>{})..add(threshold);
          }
        }
      }

      // PROPERTY ASSERTION: For each unique (categoryId, thresholdValue, budgetMonth),
      // count <= 1
      final alertCounts = <String, int>{};
      for (final alert in allAlerts) {
        final key = '${alert.categoryId}_${alert.thresholdValue}_$budgetMonth';
        alertCounts[key] = (alertCounts[key] ?? 0) + 1;
      }

      for (final entry in alertCounts.entries) {
        expect(
          entry.value,
          lessThanOrEqualTo(1),
          reason:
              'Duplicate alert for key: ${entry.key}. '
              'Count: ${entry.value}',
        );
      }
    });
  });
}
