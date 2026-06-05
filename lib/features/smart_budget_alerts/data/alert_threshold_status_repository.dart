import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:uuid/uuid.dart';

import '../../../core/local_db/app_database.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/result.dart';
import '../domain/alert_threshold_status_repository_interface.dart';
import '../domain/models/alert_threshold_status_model.dart';

/// Concrete Drift-based implementation of [AlertThresholdStatusRepositoryInterface].
///
/// Tracks which thresholds have been triggered per (userId, categoryId,
/// budgetMonth, thresholdValue) to prevent duplicate alerts. Supports
/// reset when spending decreases or a new budget period begins.
class AlertThresholdStatusRepository
    implements AlertThresholdStatusRepositoryInterface {
  final AppDatabase _db;
  final Uuid _uuid;

  AlertThresholdStatusRepository(this._db, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<AlertThresholdStatusModel>, AppError>>
      getTriggeredThresholds(
    String userId,
    String categoryId,
    String budgetMonth,
  ) async {
    try {
      final query = _db.select(_db.budgetAlertThresholdStatus)
        ..where(
          (t) =>
              t.userId.equals(userId) &
              t.categoryId.equals(categoryId) &
              t.budgetMonth.equals(budgetMonth),
        );
      final rows = await query.get();
      return Success(rows.map(_fromDrift).toList());
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void, AppError>> markThresholdTriggered(
    AlertThresholdStatusModel status,
  ) async {
    try {
      final companion = BudgetAlertThresholdStatusCompanion.insert(
        id: status.id.isEmpty ? _uuid.v4() : status.id,
        userId: status.userId,
        categoryId: status.categoryId,
        budgetMonth: status.budgetMonth,
        thresholdValue: status.thresholdValue,
        triggeredAt: status.triggeredAt,
      );
      await _db.into(_db.budgetAlertThresholdStatus).insert(companion);
      return const Success(null);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Result<void, AppError>> resetThreshold(
    String userId,
    String categoryId,
    String budgetMonth,
    int thresholdValue,
  ) async {
    try {
      final statement = _db.delete(_db.budgetAlertThresholdStatus)
        ..where(
          (t) =>
              t.userId.equals(userId) &
              t.categoryId.equals(categoryId) &
              t.budgetMonth.equals(budgetMonth) &
              t.thresholdValue.equals(thresholdValue),
        );
      await statement.go();
      return const Success(null);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Result<void, AppError>> resetAllForNewPeriod(
    String userId,
    String budgetMonth,
  ) async {
    try {
      final statement = _db.delete(_db.budgetAlertThresholdStatus)
        ..where(
          (t) =>
              t.userId.equals(userId) &
              t.budgetMonth.equals(budgetMonth),
        );
      await statement.go();
      return const Success(null);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  /// Converts a Drift [BudgetAlertThresholdStatusData] row to a domain model.
  AlertThresholdStatusModel _fromDrift(BudgetAlertThresholdStatusData row) {
    return AlertThresholdStatusModel(
      id: row.id,
      userId: row.userId,
      categoryId: row.categoryId,
      budgetMonth: row.budgetMonth,
      thresholdValue: row.thresholdValue,
      triggeredAt: row.triggeredAt,
    );
  }
}
