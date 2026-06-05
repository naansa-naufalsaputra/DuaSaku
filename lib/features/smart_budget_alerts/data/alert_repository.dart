import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/alert_repository_interface.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/alert_type.dart';
import 'package:duasaku_app/features/smart_budget_alerts/domain/models/budget_alert_model.dart';

/// Concrete Drift-based implementation of [AlertRepositoryInterface].
///
/// Performs CRUD operations on the [BudgetAlerts] table and provides
/// reactive streams for real-time UI updates via Drift's `.watch()`.
class AlertRepository implements AlertRepositoryInterface {
  final AppDatabase _db;

  AlertRepository(this._db);

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  /// Maps a Drift [BudgetAlert] row to a domain [BudgetAlertModel].
  BudgetAlertModel _mapRowToModel(BudgetAlert row) {
    return BudgetAlertModel(
      id: row.id,
      userId: row.userId,
      categoryId: row.categoryId ?? '',
      alertType: AlertType.fromJson(row.alertType),
      thresholdValue: row.thresholdValue,
      actualPercentage: row.actualPercentage,
      message: row.message,
      isRead: row.isRead,
      createdAt: row.createdAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<BudgetAlertModel>, AppError>> getAlerts(
    String userId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final query = _db.select(_db.budgetAlerts)
        ..where((tbl) => tbl.userId.equals(userId))
        ..orderBy([
          (tbl) => OrderingTerm.desc(tbl.createdAt),
        ]);

      if (limit != null) {
        query.limit(limit, offset: offset);
      }

      final rows = await query.get();
      return Success(rows.map(_mapRowToModel).toList());
    } on Exception catch (e, stack) {
      developer.log('Error fetching alerts from Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Stream<List<BudgetAlertModel>> watchAlerts(String userId) {
    final query = _db.select(_db.budgetAlerts)
      ..where((tbl) => tbl.userId.equals(userId))
      ..orderBy([
        (tbl) => OrderingTerm.desc(tbl.createdAt),
      ]);

    return query.watch().map(
      (rows) => rows.map(_mapRowToModel).toList(),
    );
  }

  @override
  Future<Result<int, AppError>> getUnreadCount(String userId) async {
    try {
      final count = countAll();
      final query = _db.selectOnly(_db.budgetAlerts)
        ..addColumns([count])
        ..where(
          _db.budgetAlerts.userId.equals(userId) &
              _db.budgetAlerts.isRead.equals(false),
        );

      final row = await query.getSingle();
      final result = row.read(count) ?? 0;
      return Success(result);
    } on Exception catch (e, stack) {
      developer.log('Error fetching unread count from Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Stream<int> watchUnreadCount(String userId) {
    final count = countAll();
    final query = _db.selectOnly(_db.budgetAlerts)
      ..addColumns([count])
      ..where(
        _db.budgetAlerts.userId.equals(userId) &
            _db.budgetAlerts.isRead.equals(false),
      );

    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void, AppError>> insertAlert(BudgetAlertModel alert) async {
    try {
      await _db.into(_db.budgetAlerts).insert(
        BudgetAlertsCompanion.insert(
          id: alert.id,
          userId: alert.userId,
          categoryId: Value(alert.categoryId.isEmpty ? null : alert.categoryId),
          alertType: alert.alertType.toJson(),
          thresholdValue: Value(alert.thresholdValue),
          actualPercentage: alert.actualPercentage,
          message: alert.message,
          isRead: Value(alert.isRead),
          createdAt: alert.createdAt,
        ),
      );
      return const Success(null);
    } on Exception catch (e, stack) {
      developer.log('Error inserting alert into Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> markAsRead(List<String> alertIds) async {
    try {
      await (_db.update(_db.budgetAlerts)
            ..where((tbl) => tbl.id.isIn(alertIds)))
          .write(const BudgetAlertsCompanion(isRead: Value(true)));
      return const Success(null);
    } on Exception catch (e, stack) {
      developer.log('Error marking alerts as read in Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> markAllVisibleAsRead(String userId) async {
    try {
      await (_db.update(_db.budgetAlerts)
            ..where(
              (tbl) =>
                  tbl.userId.equals(userId) & tbl.isRead.equals(false),
            ))
          .write(const BudgetAlertsCompanion(isRead: Value(true)));
      return const Success(null);
    } on Exception catch (e, stack) {
      developer.log('Error marking all alerts as read in Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> deleteAlert(String alertId) async {
    try {
      await (_db.delete(_db.budgetAlerts)
            ..where((tbl) => tbl.id.equals(alertId)))
          .go();
      return const Success(null);
    } on Exception catch (e, stack) {
      developer.log('Error deleting alert from Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> deleteAllRead(String userId) async {
    try {
      await (_db.delete(_db.budgetAlerts)
            ..where(
              (tbl) =>
                  tbl.userId.equals(userId) & tbl.isRead.equals(true),
            ))
          .go();
      return const Success(null);
    } on Exception catch (e, stack) {
      developer.log('Error deleting read alerts from Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }
}
