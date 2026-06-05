import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/result.dart';
import '../domain/alert_preferences_repository_interface.dart';
import '../domain/alert_repository_interface.dart';
import '../domain/alert_threshold_status_repository_interface.dart';
import '../domain/models/alert_preference_model.dart';
import '../domain/models/alert_threshold_status_model.dart';
import '../domain/models/alert_type.dart';
import '../domain/models/budget_alert_model.dart';
import 'budget_notification_service.dart';

/// Service responsible for evaluating budget thresholds and generating alerts.
///
/// The Alert Engine is triggered after each expense transaction (manual or
/// recurring) and checks whether spending has crossed any configured
/// threshold. It respects the master toggle, per-category enable/disable,
/// and prevents duplicate alerts via threshold status tracking.
class AlertEngineService {
  final AlertRepositoryInterface _alertRepo;
  final AlertPreferencesRepositoryInterface _prefsRepo;
  final AlertThresholdStatusRepositoryInterface _statusRepo;
  final AppDatabase _db;
  final BudgetNotificationService _notificationService;
  final Uuid _uuid;

  AlertEngineService({
    required this._alertRepo,
    required this._prefsRepo,
    required this._statusRepo,
    required this._db,
    required this._notificationService,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Evaluates all thresholds for a given category after a transaction change.
  ///
  /// Returns a list of newly triggered alerts. Returns an empty list if:
  /// - No budget is configured for the category+month (Req 6.4)
  /// - Master toggle is disabled (Req 3.7)
  /// - Per-category alerts are disabled
  Future<Result<List<BudgetAlertModel>, AppError>> evaluateThresholds({
    required String userId,
    required String categoryId,
    required String budgetMonth,
  }) async {
    // 1. Get budget for category+month
    final budget = await _getBudgetForCategory(userId, categoryId, budgetMonth);
    if (budget == null) {
      // No budget configured — skip silently (Req 6.4)
      return const Success([]);
    }

    // 2. Check master toggle (global preferences)
    final globalPrefsResult = await _prefsRepo.getGlobalPreferences(userId);
    switch (globalPrefsResult) {
      case Success(:final value):
        if (!value.isEnabled) {
          return const Success([]);
        }
      case Failure(:final error):
        // If global prefs not found, initialize defaults and continue
        if (error is NotFoundError) {
          await _prefsRepo.initializeDefaults(userId);
        } else {
          return Failure(error);
        }
    }

    // 3. Check per-category preferences
    final categoryPrefsResult = await _prefsRepo.getCategoryPreferences(
      userId,
      categoryId,
    );
    AlertPreferenceModel? categoryPrefs;
    switch (categoryPrefsResult) {
      case Success(:final value):
        categoryPrefs = value;
      case Failure(:final error):
        return Failure(error);
    }

    // If category-specific prefs exist and are disabled, skip
    if (categoryPrefs != null && !categoryPrefs.isEnabled) {
      return const Success([]);
    }

    // 4. Get total spending for category+month
    final totalSpent = await _getTotalSpendingForCategory(
      userId,
      categoryId,
      budgetMonth,
    );

    // 5. Calculate percentage
    final budgetLimit = budget.amount;
    if (budgetLimit <= 0) {
      return const Success([]);
    }
    final percentage = (totalSpent / budgetLimit) * 100;

    // 6. Get configured thresholds from preferences
    final thresholds =
        categoryPrefs?.thresholds ?? await _getGlobalThresholds(userId);

    // 7. Get already-triggered thresholds
    final triggeredResult = await _statusRepo.getTriggeredThresholds(
      userId,
      categoryId,
      budgetMonth,
    );
    final Set<int> triggeredThresholds;
    switch (triggeredResult) {
      case Success(:final value):
        triggeredThresholds = value.map((s) => s.thresholdValue).toSet();
      case Failure(:final error):
        return Failure(error);
    }

    // 8. Evaluate each threshold
    final newAlerts = <BudgetAlertModel>[];
    final sortedThresholds = List<int>.from(thresholds)..sort();

    for (final threshold in sortedThresholds) {
      if (percentage < threshold) continue;
      if (triggeredThresholds.contains(threshold)) continue;

      // Threshold crossed and not yet triggered
      final alertType = percentage >= 100
          ? AlertType.overBudget
          : AlertType.threshold;
      final remainingBudget = budgetLimit - totalSpent > 0
          ? budgetLimit - totalSpent
          : 0.0;
      final overAmount = alertType == AlertType.overBudget
          ? totalSpent - budgetLimit
          : null;

      final message = _buildAlertMessage(
        alertType: alertType,
        threshold: threshold,
        percentage: percentage,
        remainingBudget: remainingBudget,
        overAmount: overAmount,
      );

      final alert = BudgetAlertModel(
        id: _uuid.v4(),
        userId: userId,
        categoryId: categoryId,
        alertType: alertType,
        thresholdValue: threshold,
        actualPercentage: percentage,
        message: message,
        isRead: false,
        createdAt: DateTime.now(),
        remainingBudget: remainingBudget,
        overAmount: overAmount,
      );

      // Save alert to DB
      final insertResult = await _alertRepo.insertAlert(alert);
      switch (insertResult) {
        case Success():
          break;
        case Failure(:final error):
          developer.log(
            'Failed to insert alert: ${error.message}',
            name: 'AlertEngineService',
          );
          continue;
      }

      // Mark threshold as triggered
      final statusModel = AlertThresholdStatusModel(
        id: _uuid.v4(),
        userId: userId,
        categoryId: categoryId,
        budgetMonth: budgetMonth,
        thresholdValue: threshold,
        triggeredAt: DateTime.now(),
      );
      final markResult = await _statusRepo.markThresholdTriggered(statusModel);
      switch (markResult) {
        case Success():
          break;
        case Failure(:final error):
          developer.log(
            'Failed to mark threshold triggered: ${error.message}',
            name: 'AlertEngineService',
          );
      }

      // Send notification
      await _notificationService.sendAlertNotification(
        alert: alert,
        userId: userId,
      );

      newAlerts.add(alert);
    }

    return Success(newAlerts);
  }

  /// Evaluates overall monthly budget thresholds (cross-category).
  ///
  /// Aggregates ALL spending across categories against the overall monthly
  /// budget. Uses 'overall' as the categoryId for threshold status tracking.
  Future<Result<List<BudgetAlertModel>, AppError>> evaluateOverallThresholds({
    required String userId,
    required String budgetMonth,
  }) async {
    // 1. Check master toggle
    final globalPrefsResult = await _prefsRepo.getGlobalPreferences(userId);
    AlertPreferenceModel globalPrefs;
    switch (globalPrefsResult) {
      case Success(:final value):
        if (!value.isEnabled) {
          return const Success([]);
        }
        globalPrefs = value;
      case Failure(:final error):
        if (error is NotFoundError) {
          await _prefsRepo.initializeDefaults(userId);
          globalPrefs = AlertPreferenceModel.defaults(userId);
        } else {
          return Failure(error);
        }
    }

    // 2. Get overall budget (sum of all category budgets for the month)
    final overallBudgetLimit = await _getOverallBudgetLimit(
      userId,
      budgetMonth,
    );
    if (overallBudgetLimit == null || overallBudgetLimit <= 0) {
      return const Success([]);
    }

    // 3. Get total spending across all categories
    final totalSpent = await _getTotalSpendingAllCategories(
      userId,
      budgetMonth,
    );

    // 4. Calculate percentage
    final percentage = (totalSpent / overallBudgetLimit) * 100;

    // 5. Get thresholds from global preferences
    final thresholds = globalPrefs.thresholds;

    // 6. Get already-triggered thresholds for 'overall'
    const overallCategoryId = 'overall';
    final triggeredResult = await _statusRepo.getTriggeredThresholds(
      userId,
      overallCategoryId,
      budgetMonth,
    );
    final Set<int> triggeredThresholds;
    switch (triggeredResult) {
      case Success(:final value):
        triggeredThresholds = value.map((s) => s.thresholdValue).toSet();
      case Failure(:final error):
        return Failure(error);
    }

    // 7. Evaluate each threshold
    final newAlerts = <BudgetAlertModel>[];
    final sortedThresholds = List<int>.from(thresholds)..sort();

    for (final threshold in sortedThresholds) {
      if (percentage < threshold) continue;
      if (triggeredThresholds.contains(threshold)) continue;

      final alertType = percentage >= 100
          ? AlertType.overBudget
          : AlertType.threshold;
      final remainingBudget = overallBudgetLimit - totalSpent > 0
          ? overallBudgetLimit - totalSpent
          : 0.0;
      final overAmount = alertType == AlertType.overBudget
          ? totalSpent - overallBudgetLimit
          : null;

      final message = _buildOverallAlertMessage(
        alertType: alertType,
        threshold: threshold,
        percentage: percentage,
        remainingBudget: remainingBudget,
        overAmount: overAmount,
      );

      final alert = BudgetAlertModel(
        id: _uuid.v4(),
        userId: userId,
        categoryId: overallCategoryId,
        alertType: alertType,
        thresholdValue: threshold,
        actualPercentage: percentage,
        message: message,
        isRead: false,
        createdAt: DateTime.now(),
        remainingBudget: remainingBudget,
        overAmount: overAmount,
      );

      // Save alert to DB
      final insertResult = await _alertRepo.insertAlert(alert);
      switch (insertResult) {
        case Success():
          break;
        case Failure(:final error):
          developer.log(
            'Failed to insert overall alert: ${error.message}',
            name: 'AlertEngineService',
          );
          continue;
      }

      // Mark threshold as triggered
      final statusModel = AlertThresholdStatusModel(
        id: _uuid.v4(),
        userId: userId,
        categoryId: overallCategoryId,
        budgetMonth: budgetMonth,
        thresholdValue: threshold,
        triggeredAt: DateTime.now(),
      );
      final markResult = await _statusRepo.markThresholdTriggered(statusModel);
      switch (markResult) {
        case Success():
          break;
        case Failure(:final error):
          developer.log(
            'Failed to mark overall threshold triggered: ${error.message}',
            name: 'AlertEngineService',
          );
      }

      // Send notification
      await _notificationService.sendAlertNotification(
        alert: alert,
        userId: userId,
      );

      newAlerts.add(alert);
    }

    return Success(newAlerts);
  }

  /// Re-evaluates thresholds after transaction deletion/update.
  ///
  /// Recalculates total spending for the category+month and resets
  /// threshold statuses where spending has dropped below the threshold
  /// percentage of the budget limit.
  Future<Result<void, AppError>> reevaluateAfterSpendingDecrease({
    required String userId,
    required String categoryId,
    required String budgetMonth,
  }) async {
    // 1. Get budget for category+month
    final budget = await _getBudgetForCategory(userId, categoryId, budgetMonth);
    if (budget == null) {
      // No budget configured — nothing to reevaluate
      return const Success(null);
    }

    final budgetLimit = budget.amount;
    if (budgetLimit <= 0) {
      return const Success(null);
    }

    // 2. Recalculate total spending
    final totalSpent = await _getTotalSpendingForCategory(
      userId,
      categoryId,
      budgetMonth,
    );
    final percentage = (totalSpent / budgetLimit) * 100;

    // 3. Get all triggered thresholds for this category+month
    final triggeredResult = await _statusRepo.getTriggeredThresholds(
      userId,
      categoryId,
      budgetMonth,
    );
    final List<AlertThresholdStatusModel> triggeredStatuses;
    switch (triggeredResult) {
      case Success(:final value):
        triggeredStatuses = value;
      case Failure(:final error):
        return Failure(error);
    }

    // 4. Reset thresholds where spending is now below threshold
    for (final status in triggeredStatuses) {
      if (percentage < status.thresholdValue) {
        final resetResult = await _statusRepo.resetThreshold(
          userId,
          categoryId,
          budgetMonth,
          status.thresholdValue,
        );
        switch (resetResult) {
          case Success():
            break;
          case Failure(:final error):
            developer.log(
              'Failed to reset threshold ${status.thresholdValue}: ${error.message}',
              name: 'AlertEngineService',
            );
        }
      }
    }

    return const Success(null);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fetches the budget row for a specific category and month.
  /// Returns null if no budget is configured.
  Future<Budget?> _getBudgetForCategory(
    String userId,
    String categoryId,
    String budgetMonth,
  ) async {
    final query = _db.select(_db.budgets)
      ..where(
        (b) =>
            b.userId.equals(userId) &
            b.categoryId.equals(categoryId) &
            b.month.equals(budgetMonth),
      );
    return query.getSingleOrNull();
  }

  /// Calculates total expense spending for a category in a given month.
  ///
  /// Queries the Transactions table for expense-type transactions matching
  /// the categoryId and whose date falls within the budget month.
  Future<double> _getTotalSpendingForCategory(
    String userId,
    String categoryId,
    String budgetMonth,
  ) async {
    final monthStart = DateTime.parse('$budgetMonth-01');
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

    final sumExpr = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sumExpr])
      ..where(
        _db.transactions.userId.equals(userId) &
            _db.transactions.categoryId.equals(categoryId) &
            _db.transactions.type.equals('expense') &
            _db.transactions.date.isBiggerOrEqualValue(monthStart) &
            _db.transactions.date.isSmallerThanValue(monthEnd),
      );

    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0.0;
  }

  /// Calculates total expense spending across ALL categories for a month.
  Future<double> _getTotalSpendingAllCategories(
    String userId,
    String budgetMonth,
  ) async {
    final monthStart = DateTime.parse('$budgetMonth-01');
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

    final sumExpr = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sumExpr])
      ..where(
        _db.transactions.userId.equals(userId) &
            _db.transactions.type.equals('expense') &
            _db.transactions.date.isBiggerOrEqualValue(monthStart) &
            _db.transactions.date.isSmallerThanValue(monthEnd),
      );

    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0.0;
  }

  /// Gets the overall budget limit (sum of all category budgets for the month).
  Future<double?> _getOverallBudgetLimit(
    String userId,
    String budgetMonth,
  ) async {
    final sumExpr = _db.budgets.amount.sum();
    final query = _db.selectOnly(_db.budgets)
      ..addColumns([sumExpr])
      ..where(
        _db.budgets.userId.equals(userId) &
            _db.budgets.month.equals(budgetMonth),
      );

    final row = await query.getSingle();
    return row.read(sumExpr);
  }

  /// Gets the global thresholds from preferences, falling back to defaults.
  Future<List<int>> _getGlobalThresholds(String userId) async {
    final result = await _prefsRepo.getGlobalPreferences(userId);
    switch (result) {
      case Success(:final value):
        return value.thresholds;
      case Failure():
        return const [50, 75, 90, 100];
    }
  }

  /// Builds a human-readable alert message for a category threshold alert.
  String _buildAlertMessage({
    required AlertType alertType,
    required int threshold,
    required double percentage,
    required double remainingBudget,
    double? overAmount,
  }) {
    if (alertType == AlertType.overBudget) {
      return 'Pengeluaran telah melampaui budget! '
          'Kelebihan: Rp ${overAmount?.toStringAsFixed(0) ?? '0'}';
    }
    return 'Pengeluaran telah mencapai $threshold% dari budget. '
        'Sisa budget: Rp ${remainingBudget.toStringAsFixed(0)}';
  }

  /// Builds a human-readable alert message for an overall budget alert.
  String _buildOverallAlertMessage({
    required AlertType alertType,
    required int threshold,
    required double percentage,
    required double remainingBudget,
    double? overAmount,
  }) {
    if (alertType == AlertType.overBudget) {
      return 'Total pengeluaran bulanan telah melampaui budget keseluruhan! '
          'Kelebihan: Rp ${overAmount?.toStringAsFixed(0) ?? '0'}';
    }
    return 'Total pengeluaran bulanan telah mencapai $threshold% dari budget keseluruhan. '
        'Sisa budget: Rp ${remainingBudget.toStringAsFixed(0)}';
  }
}
