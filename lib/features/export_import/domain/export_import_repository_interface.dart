import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/core/utils/result.dart';

/// Abstract interface for export/import database operations.
///
/// Provides raw data access for all 11 tables (as plain Maps),
/// name resolution maps for CSV enrichment, and a destructive
/// full-backup restore operation.
///
/// This interface is pure Dart — no Drift or Flutter dependencies.
abstract class ExportImportRepositoryInterface {
  // ---------------------------------------------------------------------------
  // Read operations for export
  // ---------------------------------------------------------------------------

  /// Returns all wallets for [userId] as raw maps.
  Future<Result<List<Map<String, dynamic>>, AppError>> getWalletsRaw(
    String userId,
  );

  /// Returns all categories for [userId] as raw maps.
  Future<Result<List<Map<String, dynamic>>, AppError>> getCategoriesRaw(
    String userId,
  );

  /// Returns transactions for [userId] as raw maps.
  /// Optionally filtered by [startDate] and [endDate].
  Future<Result<List<Map<String, dynamic>>, AppError>> getTransactionsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Returns budgets for [userId] as raw maps.
  /// Optionally filtered by [startDate] and [endDate].
  Future<Result<List<Map<String, dynamic>>, AppError>> getBudgetsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Returns recurring transactions for [userId] as raw maps.
  /// Optionally filtered by [startDate] and [endDate].
  Future<Result<List<Map<String, dynamic>>, AppError>> getRecurringTransactionsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Returns recurring execution logs for [userId] as raw maps.
  Future<Result<List<Map<String, dynamic>>, AppError>> getRecurringExecutionLogsRaw(
    String userId,
  );

  /// Returns goals for [userId] as raw maps.
  /// Optionally filtered by [startDate] and [endDate].
  Future<Result<List<Map<String, dynamic>>, AppError>> getGoalsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Returns goal deposits for [userId] as raw maps.
  /// Optionally filtered by [startDate] and [endDate].
  Future<Result<List<Map<String, dynamic>>, AppError>> getGoalDepositsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Returns budget alerts for [userId] as raw maps.
  /// Optionally filtered by [startDate] and [endDate].
  Future<Result<List<Map<String, dynamic>>, AppError>> getBudgetAlertsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Returns budget alert preferences for [userId] as raw maps.
  Future<Result<List<Map<String, dynamic>>, AppError>> getBudgetAlertPreferencesRaw(
    String userId,
  );

  /// Returns budget alert threshold status for [userId] as raw maps.
  Future<Result<List<Map<String, dynamic>>, AppError>> getBudgetAlertThresholdStatusRaw(
    String userId,
  );

  // ---------------------------------------------------------------------------
  // Resolved name maps for CSV enrichment
  // ---------------------------------------------------------------------------

  /// Returns a map of wallet ID → wallet name for [userId].
  Future<Result<Map<String, String>, AppError>> getWalletNameMap(
    String userId,
  );

  /// Returns a map of category ID → category name for [userId].
  Future<Result<Map<String, String>, AppError>> getCategoryNameMap(
    String userId,
  );

  // ---------------------------------------------------------------------------
  // Destructive restore operation
  // ---------------------------------------------------------------------------

  /// Restores a full backup by replacing all existing data.
  ///
  /// [data] is a map of table name → list of row maps.
  /// This operation is destructive and runs within a single database
  /// transaction for atomicity.
  Future<Result<void, AppError>> restoreFullBackup(
    Map<String, List<Map<String, dynamic>>> data,
  );
}
