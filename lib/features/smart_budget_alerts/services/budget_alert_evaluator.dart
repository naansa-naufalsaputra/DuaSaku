import 'dart:developer' as developer;

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/local_db/app_database.dart';
import '../data/alert_preferences_repository.dart';
import '../data/alert_repository.dart';
import '../data/alert_threshold_status_repository.dart';
import 'alert_engine_service.dart';
import 'budget_notification_service.dart';
import 'prediction_engine_service.dart';
import '../../../features/transactions/data/budget_repository.dart';

/// Orchestrates budget alert evaluation after transaction changes.
///
/// This class provides a unified interface for triggering alert evaluation
/// from both Riverpod providers (manual transactions) and background
/// isolates (recurring transactions). It handles:
/// - Threshold evaluation after expense insert
/// - Prediction evaluation after expense insert
/// - Overall budget evaluation after expense insert
/// - Re-evaluation after expense delete/update
/// - Period reset at start of new budget month
class BudgetAlertEvaluator {
  final AlertEngineService _alertEngine;
  final PredictionEngineService _predictionEngine;
  final AlertThresholdStatusRepository _statusRepo;

  /// SharedPreferences key for tracking the last evaluated budget month.
  static const String _lastEvaluatedMonthKey =
      'budget_alert_last_evaluated_month';

  BudgetAlertEvaluator({
    required this._alertEngine,
    required this._predictionEngine,
    required this._statusRepo,
  });

  /// Factory constructor that creates a [BudgetAlertEvaluator] from an
  /// [AppDatabase] instance. Useful in background isolates where Riverpod
  /// is not available.
  factory BudgetAlertEvaluator.fromDatabase(AppDatabase db) {
    final alertRepo = AlertRepository(db);
    final prefsRepo = AlertPreferencesRepository(db);
    final statusRepo = AlertThresholdStatusRepository(db);
    final budgetRepo = BudgetRepository(db);
    final notificationService = BudgetNotificationService();

    final alertEngine = AlertEngineService(
      alertRepo: alertRepo,
      prefsRepo: prefsRepo,
      statusRepo: statusRepo,
      db: db,
      notificationService: notificationService,
    );

    final predictionEngine = PredictionEngineService(
      alertRepo: alertRepo,
      prefsRepo: prefsRepo,
      statusRepo: statusRepo,
      budgetRepo: budgetRepo,
      db: db,
      notificationService: notificationService,
    );

    return BudgetAlertEvaluator(
      alertEngine: alertEngine,
      predictionEngine: predictionEngine,
      statusRepo: statusRepo,
    );
  }

  /// Evaluates alerts after a new expense transaction is inserted.
  ///
  /// Triggers threshold evaluation, prediction evaluation, and overall
  /// budget evaluation. Also checks for period reset if a new month
  /// has started.
  ///
  /// This method is fire-and-forget — errors are logged but not propagated
  /// to avoid blocking the transaction flow.
  Future<void> evaluateAfterExpenseInsert({
    required String userId,
    required String categoryId,
    required String budgetMonth,
  }) async {
    try {
      // Check for period reset before evaluation
      await _checkAndResetPeriodIfNeeded(userId, budgetMonth);

      // Evaluate category-specific thresholds
      await _alertEngine.evaluateThresholds(
        userId: userId,
        categoryId: categoryId,
        budgetMonth: budgetMonth,
      );

      // Evaluate prediction for this category
      await _predictionEngine.evaluatePrediction(
        userId: userId,
        categoryId: categoryId,
        budgetMonth: budgetMonth,
      );

      // Evaluate overall monthly budget thresholds
      await _alertEngine.evaluateOverallThresholds(
        userId: userId,
        budgetMonth: budgetMonth,
      );
    } catch (e, stack) {
      developer.log(
        'Error evaluating alerts after expense insert: $e',
        name: 'BudgetAlertEvaluator',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Re-evaluates alerts after an expense transaction is deleted or updated.
  ///
  /// Resets threshold statuses where spending has dropped below previously
  /// triggered thresholds.
  ///
  /// If [oldCategoryId] is provided (category changed), also re-evaluates
  /// the old category.
  Future<void> evaluateAfterExpenseChange({
    required String userId,
    required String categoryId,
    required String budgetMonth,
    String? oldCategoryId,
  }) async {
    try {
      // Re-evaluate the affected category
      await _alertEngine.reevaluateAfterSpendingDecrease(
        userId: userId,
        categoryId: categoryId,
        budgetMonth: budgetMonth,
      );

      // If category changed, also re-evaluate the old category
      if (oldCategoryId != null && oldCategoryId != categoryId) {
        await _alertEngine.reevaluateAfterSpendingDecrease(
          userId: userId,
          categoryId: oldCategoryId,
          budgetMonth: budgetMonth,
        );
      }
    } catch (e, stack) {
      developer.log(
        'Error evaluating alerts after expense change: $e',
        name: 'BudgetAlertEvaluator',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Checks if a new budget month has started and resets all threshold
  /// statuses if needed.
  ///
  /// Compares the current budget month against the last evaluated month
  /// stored in SharedPreferences. If they differ, resets all threshold
  /// statuses for the previous month.
  Future<void> _checkAndResetPeriodIfNeeded(
    String userId,
    String currentBudgetMonth,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMonth = prefs.getString(_lastEvaluatedMonthKey);

      if (lastMonth == null) {
        // First time — just store the current month
        await prefs.setString(_lastEvaluatedMonthKey, currentBudgetMonth);
        return;
      }

      if (lastMonth != currentBudgetMonth) {
        // New month detected — reset all threshold statuses for the old month
        developer.log(
          'New budget month detected ($lastMonth → $currentBudgetMonth). '
          'Resetting threshold statuses.',
          name: 'BudgetAlertEvaluator',
        );

        await _statusRepo.resetAllForNewPeriod(userId, lastMonth);
        await prefs.setString(_lastEvaluatedMonthKey, currentBudgetMonth);
      }
    } catch (e, stack) {
      developer.log(
        'Error checking period reset: $e',
        name: 'BudgetAlertEvaluator',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Returns the current budget month in 'YYYY-MM' format.
  static String getCurrentBudgetMonth() {
    return DateFormat('yyyy-MM').format(DateTime.now());
  }

  /// Returns the budget month for a given date in 'YYYY-MM' format.
  static String getBudgetMonthForDate(DateTime date) {
    return DateFormat('yyyy-MM').format(date);
  }
}
