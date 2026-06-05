import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/result.dart';
import '../domain/alert_preferences_repository_interface.dart';
import '../domain/models/alert_preference_model.dart';

/// Drift-based implementation of [AlertPreferencesRepositoryInterface].
///
/// Handles persistence of alert preferences using the [BudgetAlertPreferences]
/// table. Thresholds are stored as JSON-encoded strings and quiet hours
/// as "HH:mm" formatted strings.
class AlertPreferencesRepository
    implements AlertPreferencesRepositoryInterface {
  final AppDatabase _db;

  AlertPreferencesRepository(this._db);

  @override
  Future<Result<AlertPreferenceModel, AppError>> getGlobalPreferences(
    String userId,
  ) async {
    try {
      final query = _db.select(_db.budgetAlertPreferences)
        ..where(
          (t) => t.userId.equals(userId) & t.categoryId.isNull(),
        );
      final row = await query.getSingleOrNull();
      if (row == null) {
        return Failure(
          AppError.notFound(
            'Global preferences not found for user $userId',
          ),
        );
      }
      return Success(_mapRowToModel(row));
    } catch (e, st) {
      return Failure(
        AppError.database(
          'Failed to get global preferences: $e',
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<AlertPreferenceModel?, AppError>> getCategoryPreferences(
    String userId,
    String categoryId,
  ) async {
    try {
      final query = _db.select(_db.budgetAlertPreferences)
        ..where(
          (t) =>
              t.userId.equals(userId) & t.categoryId.equals(categoryId),
        );
      final row = await query.getSingleOrNull();
      if (row == null) {
        return const Success(null);
      }
      return Success(_mapRowToModel(row));
    } catch (e, st) {
      return Failure(
        AppError.database(
          'Failed to get category preferences: $e',
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<List<AlertPreferenceModel>, AppError>> getAllPreferences(
    String userId,
  ) async {
    try {
      final query = _db.select(_db.budgetAlertPreferences)
        ..where((t) => t.userId.equals(userId));
      final rows = await query.get();
      return Success(rows.map(_mapRowToModel).toList());
    } catch (e, st) {
      return Failure(
        AppError.database(
          'Failed to get all preferences: $e',
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void, AppError>> savePreferences(
    AlertPreferenceModel preferences,
  ) async {
    try {
      final companion = _mapModelToCompanion(preferences);
      await _db.into(_db.budgetAlertPreferences).insertOnConflictUpdate(
            companion,
          );
      return const Success(null);
    } catch (e, st) {
      return Failure(
        AppError.database(
          'Failed to save preferences: $e',
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<Result<void, AppError>> initializeDefaults(String userId) async {
    try {
      final defaults = AlertPreferenceModel.defaults(userId);
      final companion = _mapModelToCompanion(defaults);
      await _db.into(_db.budgetAlertPreferences).insertOnConflictUpdate(
            companion,
          );
      return const Success(null);
    } catch (e, st) {
      return Failure(
        AppError.database(
          'Failed to initialize default preferences: $e',
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Stream<AlertPreferenceModel> watchGlobalPreferences(String userId) {
    final query = _db.select(_db.budgetAlertPreferences)
      ..where(
        (t) => t.userId.equals(userId) & t.categoryId.isNull(),
      );
    return query.watchSingle().map(_mapRowToModel);
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  /// Maps a Drift [BudgetAlertPreference] row to domain [AlertPreferenceModel].
  AlertPreferenceModel _mapRowToModel(BudgetAlertPreference row) {
    return AlertPreferenceModel(
      id: row.id,
      userId: row.userId,
      categoryId: row.categoryId,
      isEnabled: row.isEnabled,
      thresholds: _decodeThresholds(row.thresholds),
      predictionsEnabled: row.predictionsEnabled,
      quietHoursStart: row.quietHoursStart,
      quietHoursEnd: row.quietHoursEnd,
    );
  }

  /// Maps a domain [AlertPreferenceModel] to a Drift companion for insert/update.
  BudgetAlertPreferencesCompanion _mapModelToCompanion(
    AlertPreferenceModel model,
  ) {
    return BudgetAlertPreferencesCompanion(
      id: Value(model.id),
      userId: Value(model.userId),
      categoryId: Value(model.categoryId),
      isEnabled: Value(model.isEnabled),
      thresholds: Value(jsonEncode(model.thresholds)),
      predictionsEnabled: Value(model.predictionsEnabled),
      quietHoursStart: Value(model.quietHoursStart),
      quietHoursEnd: Value(model.quietHoursEnd),
    );
  }

  /// Decodes a JSON-encoded thresholds string (e.g. "[50,75,90,100]")
  /// into a [List<int>].
  List<int> _decodeThresholds(String encoded) {
    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded.cast<int>();
  }
}
