import '../../../core/utils/result.dart';
import '../../../core/utils/app_error.dart';
import 'models/alert_preference_model.dart';

/// Abstract interface for alert preferences repository operations.
///
/// Manages user preferences for budget alerts including global settings,
/// per-category overrides, and quiet hours configuration.
///
/// Concrete implementations handle the actual data source (Drift, API, etc.).
/// Methods that can fail with expected errors return [Result<T, AppError>].
abstract class AlertPreferencesRepositoryInterface {
  /// Retrieves the global (non-category-specific) preferences for the user.
  Future<Result<AlertPreferenceModel, AppError>> getGlobalPreferences(
    String userId,
  );

  /// Retrieves category-specific preferences, or null if none are configured.
  Future<Result<AlertPreferenceModel?, AppError>> getCategoryPreferences(
    String userId,
    String categoryId,
  );

  /// Retrieves all preferences (global + per-category) for the user.
  Future<Result<List<AlertPreferenceModel>, AppError>> getAllPreferences(
    String userId,
  );

  /// Saves (inserts or updates) a preference record.
  Future<Result<void, AppError>> savePreferences(
    AlertPreferenceModel preferences,
  );

  /// Initializes default preferences for a new user.
  ///
  /// Defaults: thresholds [50, 75, 90, 100], predictions enabled,
  /// no quiet hours configured.
  Future<Result<void, AppError>> initializeDefaults(String userId);

  /// Watches the global preferences as a reactive stream.
  Stream<AlertPreferenceModel> watchGlobalPreferences(String userId);
}
