import '../../../core/utils/result.dart';
import '../../../core/utils/app_error.dart';
import 'models/alert_threshold_status_model.dart';

/// Abstract interface for alert threshold status repository operations.
///
/// Tracks which thresholds have been triggered for each category and
/// budget period to prevent duplicate alerts. Supports reset when
/// spending decreases or a new budget period begins.
///
/// Concrete implementations handle the actual data source (Drift, API, etc.).
/// Methods that can fail with expected errors return [Result<T, AppError>].
abstract class AlertThresholdStatusRepositoryInterface {
  /// Retrieves all triggered threshold statuses for a given user,
  /// category, and budget month.
  Future<Result<List<AlertThresholdStatusModel>, AppError>>
  getTriggeredThresholds(String userId, String categoryId, String budgetMonth);

  /// Records that a threshold has been triggered.
  Future<Result<void, AppError>> markThresholdTriggered(
    AlertThresholdStatusModel status,
  );

  /// Resets a specific threshold status (e.g., when spending drops
  /// below the threshold value after a transaction deletion).
  Future<Result<void, AppError>> resetThreshold(
    String userId,
    String categoryId,
    String budgetMonth,
    int thresholdValue,
  );

  /// Resets all threshold statuses for a user when a new budget
  /// period begins.
  Future<Result<void, AppError>> resetAllForNewPeriod(
    String userId,
    String budgetMonth,
  );
}
