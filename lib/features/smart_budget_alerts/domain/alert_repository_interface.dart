import '../../../core/utils/result.dart';
import '../../../core/utils/app_error.dart';
import 'models/budget_alert_model.dart';

/// Abstract interface for budget alert repository operations.
///
/// Handles CRUD operations for alert records including read/unread
/// management and reactive streams for real-time UI updates.
///
/// Concrete implementations handle the actual data source (Drift, API, etc.).
/// Methods that can fail with expected errors return [Result<T, AppError>].
abstract class AlertRepositoryInterface {
  /// Retrieves a paginated list of alerts for the given user,
  /// ordered by [createdAt] descending.
  Future<Result<List<BudgetAlertModel>, AppError>> getAlerts(
    String userId, {
    int? limit,
    int? offset,
  });

  /// Watches all alerts for the given user as a reactive stream,
  /// ordered by [createdAt] descending.
  Stream<List<BudgetAlertModel>> watchAlerts(String userId);

  /// Returns the count of unread alerts for the given user.
  Future<Result<int, AppError>> getUnreadCount(String userId);

  /// Watches the unread alert count as a reactive stream.
  Stream<int> watchUnreadCount(String userId);

  /// Inserts a new alert record.
  Future<Result<void, AppError>> insertAlert(BudgetAlertModel alert);

  /// Marks the specified alerts as read.
  Future<Result<void, AppError>> markAsRead(List<String> alertIds);

  /// Marks all currently visible (unread) alerts as read for the user.
  Future<Result<void, AppError>> markAllVisibleAsRead(String userId);

  /// Deletes a single alert by its ID.
  Future<Result<void, AppError>> deleteAlert(String alertId);

  /// Deletes all read alerts for the given user.
  Future<Result<void, AppError>> deleteAllRead(String userId);
}
