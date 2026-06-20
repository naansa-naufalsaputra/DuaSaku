import 'package:uuid/uuid.dart';

import '../../../core/utils/result.dart';
import '../../transactions/domain/budget_repository_interface.dart';
import '../../transactions/domain/transaction_repository_interface.dart';
import '../../recurring_transactions/domain/recurring_transaction_repository_interface.dart';
import '../domain/alert_preferences_repository_interface.dart';
import '../domain/alert_repository_interface.dart';
import '../domain/alert_threshold_status_repository_interface.dart';
import '../domain/models/alert_type.dart';
import '../domain/models/budget_alert_model.dart';
import 'budget_notification_service.dart';

/// Service responsible for predicting budget overspend based on spending trends
/// and upcoming recurring transactions.
///
/// The Prediction Engine calculates daily spending rate, projects total spending
/// for the remainder of the budget period, and generates alerts when overspend
/// is predicted within the current period.
class PredictionEngineService {
  final AlertRepositoryInterface _alertRepo;
  final AlertPreferencesRepositoryInterface _prefsRepo;
  // ignore: unused_field
  final AlertThresholdStatusRepositoryInterface _statusRepo;
  final BudgetRepositoryInterface _budgetRepo;
  final TransactionRepositoryInterface _transactionRepo;
  final RecurringTransactionRepositoryInterface _recurringRepo;
  final BudgetNotificationService _notificationService;

  PredictionEngineService({
    required this._alertRepo,
    required this._prefsRepo,
    required this._statusRepo,
    required this._budgetRepo,
    required this._transactionRepo,
    required this._recurringRepo,
    required this._notificationService,
  });

  /// Calculates the daily spending rate for a category.
  ///
  /// Returns 0.0 if [elapsedDays] <= 0 to guard against division by zero.
  double calculateSpendingRate(double totalSpent, int elapsedDays) {
    if (elapsedDays <= 0) return 0.0;
    return totalSpent / elapsedDays;
  }

  /// Projects total spending by end of period including upcoming recurring
  /// transactions.
  ///
  /// Formula: currentSpent + (dailyRate * remainingDays) + upcomingRecurring
  double projectTotalSpending({
    required double currentSpent,
    required double dailyRate,
    required int remainingDays,
    required double upcomingRecurring,
  }) {
    return currentSpent + (dailyRate * remainingDays) + upcomingRecurring;
  }

  /// Calculates the projected date when cumulative spending exceeds the budget
  /// limit.
  ///
  /// Returns null if [dailyRate] <= 0 (no overspend possible at current rate).
  /// If the budget is already exceeded (days <= 0), returns [periodStart].
  DateTime? calculateOverspendDate({
    required double currentSpent,
    required double dailyRate,
    required double budgetLimit,
    required DateTime periodStart,
  }) {
    if (dailyRate <= 0) return null;

    final daysUntilOverspend = (budgetLimit - currentSpent) / dailyRate;

    if (daysUntilOverspend <= 0) {
      // Budget already exceeded
      return periodStart;
    }

    return periodStart.add(Duration(days: daysUntilOverspend.ceil()));
  }

  /// Orchestrates prediction calculation for a given category and budget month.
  ///
  /// Returns a [BudgetAlertModel] if overspend is predicted within the current
  /// period, or null if:
  /// - No budget is configured for the category/month
  /// - Master toggle or predictions are disabled
  /// - Elapsed days < 3 (not enough data, Req 2.6)
  /// - Projected spending does not exceed budget limit
  /// - Overspend date is after end of current period (Req 2.5)
  Future<BudgetAlertModel?> evaluatePrediction({
    required String userId,
    required String categoryId,
    required String budgetMonth,
  }) async {
    // 1. Get budget for category+month — if none, return null silently (Req 6.4)
    final budgetRow = await _budgetRepo.getBudgetByCategoryAndMonth(
      userId,
      categoryId,
      budgetMonth,
    );

    if (budgetRow == null) return null;

    final budgetLimit = budgetRow.amountLimit;

    // 2. Check master toggle and predictions enabled in preferences
    final prefsResult = await _prefsRepo.getGlobalPreferences(userId);
    switch (prefsResult) {
      case Success(:final value):
        if (!value.isEnabled) return null; // Master toggle off
        if (!value.predictionsEnabled) return null; // Predictions disabled
      case Failure():
        return null; // Can't load preferences, skip silently
    }

    // Also check category-specific preferences
    final categoryPrefsResult = await _prefsRepo.getCategoryPreferences(
      userId,
      categoryId,
    );
    switch (categoryPrefsResult) {
      case Success(:final value):
        if (value != null && !value.isEnabled) return null;
        if (value != null && !value.predictionsEnabled) return null;
      case Failure():
        break; // Continue with global preferences
    }

    // 3. Get total spending for category+month
    final totalSpent = await _getTotalSpendingForCategory(
      userId: userId,
      categoryId: categoryId,
      budgetMonth: budgetMonth,
    );

    // 4. Calculate elapsed days since period start (1st of budgetMonth)
    final periodStart = _parseBudgetMonth(budgetMonth);
    final now = DateTime.now();
    final elapsedDays = now.difference(periodStart).inDays;

    // Req 2.6: If elapsed days < 3, return null (not enough data)
    if (elapsedDays < 3) return null;

    // 5. Calculate remaining days in the month
    final periodEnd = DateTime(periodStart.year, periodStart.month + 1, 0);
    final remainingDays = periodEnd.difference(now).inDays;

    // 6. Fetch upcoming recurring transactions for this category in remaining period
    final upcomingRecurring = await _getUpcomingRecurringAmount(
      userId: userId,
      categoryId: categoryId,
      periodEnd: periodEnd,
    );

    // 7. Calculate spending rate and project total spending
    final dailyRate = calculateSpendingRate(totalSpent, elapsedDays);
    final projectedTotal = projectTotalSpending(
      currentSpent: totalSpent,
      dailyRate: dailyRate,
      remainingDays: remainingDays,
      upcomingRecurring: upcomingRecurring,
    );

    // 8. If projected total <= budget limit, return null (no overspend predicted)
    if (projectedTotal <= budgetLimit) return null;

    // 9. Calculate overspend date
    final overspendDate = calculateOverspendDate(
      currentSpent: totalSpent,
      dailyRate: dailyRate,
      budgetLimit: budgetLimit,
      periodStart: now,
    );

    // Req 2.5: If overspend date is after end of current period, return null
    if (overspendDate == null) return null;
    if (overspendDate.isAfter(periodEnd)) return null;

    // 10. Generate prediction alert
    final estimatedOverAmount = projectedTotal - budgetLimit;
    final percentage = (totalSpent / budgetLimit) * 100;

    final alert = BudgetAlertModel(
      id: const Uuid().v4(),
      userId: userId,
      categoryId: categoryId,
      alertType: AlertType.prediction,
      thresholdValue: null,
      actualPercentage: percentage,
      message:
          'Pengeluaran diprediksi melampaui budget sebesar Rp ${estimatedOverAmount.toStringAsFixed(0)} pada ${_formatDate(overspendDate)}',
      isRead: false,
      createdAt: DateTime.now(),
      projectedOverspendDate: overspendDate,
      overAmount: estimatedOverAmount,
      remainingBudget: budgetLimit - totalSpent > 0
          ? budgetLimit - totalSpent
          : 0,
    );

    // 11. Save alert to DB
    await _alertRepo.insertAlert(alert);

    // 12. Send notification
    try {
      await _notificationService.sendAlertNotification(
        alert: alert,
        userId: userId,
      );
    } catch (_) {
      // Notification failure should not prevent alert from being saved
    }

    return alert;
  }

  /// Queries total expense spending for a category in a given budget month.
  Future<double> _getTotalSpendingForCategory({
    required String userId,
    required String categoryId,
    required String budgetMonth,
  }) async {
    return _transactionRepo.getTotalSpendingForCategory(
      userId,
      categoryId,
      budgetMonth,
    );
  }

  /// Fetches the total amount of upcoming recurring expense transactions
  /// for a specific category within the remaining budget period.
  Future<double> _getUpcomingRecurringAmount({
    required String userId,
    required String categoryId,
    required DateTime periodEnd,
  }) async {
    final now = DateTime.now();
    final upcomingTransactions = await _recurringRepo.getUpcomingByCategory(
      userId,
      categoryId,
      now,
      periodEnd,
    );
    return upcomingTransactions.fold<double>(0.0, (sum, tx) => sum + tx.amount);
  }

  /// Parses a budget month string ('YYYY-MM') into a DateTime representing
  /// the first day of that month.
  DateTime _parseBudgetMonth(String budgetMonth) {
    final parts = budgetMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    return DateTime(year, month, 1);
  }

  /// Formats a DateTime to a human-readable date string.
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
