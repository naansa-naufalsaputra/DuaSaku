import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/export_import/domain/export_import_repository_interface.dart';

/// Concrete implementation of [ExportImportRepositoryInterface] using Drift.
///
/// Uses raw SQL via `customSelect` to return data as plain Maps,
/// and `customStatement` for bulk insert/delete during restore.
class ExportImportRepository implements ExportImportRepositoryInterface {
  final AppDatabase _db;

  ExportImportRepository(this._db);

  // ---------------------------------------------------------------------------
  // Read operations for export
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getWalletsRaw(
    String userId,
  ) async {
    try {
      final rows = await _db.customSelect(
        'SELECT * FROM wallets WHERE user_id = ?',
        variables: [Variable.withString(userId)],
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching wallets raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getCategoriesRaw(
    String userId,
  ) async {
    try {
      final rows = await _db.customSelect(
        'SELECT * FROM categories WHERE user_id = ?',
        variables: [Variable.withString(userId)],
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching categories raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getTransactionsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = StringBuffer('SELECT * FROM transactions WHERE user_id = ?');
      final variables = <Variable>[Variable.withString(userId)];

      if (startDate != null) {
        query.write(' AND date >= ?');
        variables.add(Variable.withInt(startDate.millisecondsSinceEpoch ~/ 1000));
      }
      if (endDate != null) {
        query.write(' AND date <= ?');
        variables.add(Variable.withInt(endDate.millisecondsSinceEpoch ~/ 1000));
      }

      final rows = await _db.customSelect(
        query.toString(),
        variables: variables,
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching transactions raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getBudgetsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = StringBuffer('SELECT * FROM budgets WHERE user_id = ?');
      final variables = <Variable>[Variable.withString(userId)];

      if (startDate != null) {
        query.write(' AND created_at >= ?');
        variables.add(Variable.withInt(startDate.millisecondsSinceEpoch ~/ 1000));
      }
      if (endDate != null) {
        query.write(' AND created_at <= ?');
        variables.add(Variable.withInt(endDate.millisecondsSinceEpoch ~/ 1000));
      }

      final rows = await _db.customSelect(
        query.toString(),
        variables: variables,
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching budgets raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getRecurringTransactionsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = StringBuffer(
        'SELECT * FROM recurring_transactions WHERE user_id = ?',
      );
      final variables = <Variable>[Variable.withString(userId)];

      if (startDate != null) {
        query.write(' AND created_at >= ?');
        variables.add(Variable.withInt(startDate.millisecondsSinceEpoch ~/ 1000));
      }
      if (endDate != null) {
        query.write(' AND created_at <= ?');
        variables.add(Variable.withInt(endDate.millisecondsSinceEpoch ~/ 1000));
      }

      final rows = await _db.customSelect(
        query.toString(),
        variables: variables,
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching recurring transactions raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getRecurringExecutionLogsRaw(
    String userId,
  ) async {
    try {
      // Join with recurring_transactions to filter by userId
      final rows = await _db.customSelect(
        '''SELECT rel.* FROM recurring_execution_logs rel
           INNER JOIN recurring_transactions rt ON rel.recurring_transaction_id = rt.id
           WHERE rt.user_id = ?''',
        variables: [Variable.withString(userId)],
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching recurring execution logs raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getGoalsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = StringBuffer('SELECT * FROM goals WHERE user_id = ?');
      final variables = <Variable>[Variable.withString(userId)];

      if (startDate != null) {
        query.write(' AND created_at >= ?');
        variables.add(Variable.withInt(startDate.millisecondsSinceEpoch ~/ 1000));
      }
      if (endDate != null) {
        query.write(' AND created_at <= ?');
        variables.add(Variable.withInt(endDate.millisecondsSinceEpoch ~/ 1000));
      }

      final rows = await _db.customSelect(
        query.toString(),
        variables: variables,
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching goals raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getGoalDepositsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = StringBuffer(
        '''SELECT gd.* FROM goal_deposits gd
           INNER JOIN goals g ON gd.goal_id = g.id
           WHERE g.user_id = ?''',
      );
      final variables = <Variable>[Variable.withString(userId)];

      if (startDate != null) {
        query.write(' AND gd.created_at >= ?');
        variables.add(Variable.withInt(startDate.millisecondsSinceEpoch ~/ 1000));
      }
      if (endDate != null) {
        query.write(' AND gd.created_at <= ?');
        variables.add(Variable.withInt(endDate.millisecondsSinceEpoch ~/ 1000));
      }

      final rows = await _db.customSelect(
        query.toString(),
        variables: variables,
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching goal deposits raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getBudgetAlertsRaw(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final query = StringBuffer(
        'SELECT * FROM budget_alerts WHERE user_id = ?',
      );
      final variables = <Variable>[Variable.withString(userId)];

      if (startDate != null) {
        query.write(' AND created_at >= ?');
        variables.add(Variable.withInt(startDate.millisecondsSinceEpoch ~/ 1000));
      }
      if (endDate != null) {
        query.write(' AND created_at <= ?');
        variables.add(Variable.withInt(endDate.millisecondsSinceEpoch ~/ 1000));
      }

      final rows = await _db.customSelect(
        query.toString(),
        variables: variables,
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching budget alerts raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getBudgetAlertPreferencesRaw(
    String userId,
  ) async {
    try {
      final rows = await _db.customSelect(
        'SELECT * FROM budget_alert_preferences WHERE user_id = ?',
        variables: [Variable.withString(userId)],
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching budget alert preferences raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>, AppError>> getBudgetAlertThresholdStatusRaw(
    String userId,
  ) async {
    try {
      final rows = await _db.customSelect(
        'SELECT * FROM budget_alert_threshold_status WHERE user_id = ?',
        variables: [Variable.withString(userId)],
      ).get();
      return Success(rows.map((row) => row.data).toList());
    } catch (e, stack) {
      developer.log('Error fetching budget alert threshold status raw', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  // ---------------------------------------------------------------------------
  // Resolved name maps for CSV enrichment
  // ---------------------------------------------------------------------------

  @override
  Future<Result<Map<String, String>, AppError>> getWalletNameMap(
    String userId,
  ) async {
    try {
      final rows = await _db.customSelect(
        'SELECT id, name FROM wallets WHERE user_id = ?',
        variables: [Variable.withString(userId)],
      ).get();
      final map = <String, String>{};
      for (final row in rows) {
        map[row.data['id'] as String] = row.data['name'] as String;
      }
      return Success(map);
    } catch (e, stack) {
      developer.log('Error fetching wallet name map', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<Map<String, String>, AppError>> getCategoryNameMap(
    String userId,
  ) async {
    try {
      final rows = await _db.customSelect(
        'SELECT id, name FROM categories WHERE user_id = ?',
        variables: [Variable.withString(userId)],
      ).get();
      final map = <String, String>{};
      for (final row in rows) {
        map[row.data['id'] as String] = row.data['name'] as String;
      }
      return Success(map);
    } catch (e, stack) {
      developer.log('Error fetching category name map', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  // ---------------------------------------------------------------------------
  // Destructive restore operation
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void, AppError>> restoreFullBackup(
    Map<String, List<Map<String, dynamic>>> data,
  ) async {
    try {
      await _db.transaction(() async {
        // 1. Delete all existing data in reverse FK order
        await _deleteAllTables();

        // 2. Insert data in FK-respecting order
        await _insertTableData('wallets', data['wallets'] ?? []);
        await _insertTableData('categories', data['categories'] ?? []);
        await _insertTableData('transactions', data['transactions'] ?? []);
        await _insertTableData('budgets', data['budgets'] ?? []);
        await _insertTableData('recurring_transactions', data['recurringTransactions'] ?? []);
        await _insertTableData('recurring_execution_logs', data['recurringExecutionLogs'] ?? []);
        await _insertTableData('goals', data['goals'] ?? []);
        await _insertTableData('goal_deposits', data['goalDeposits'] ?? []);
        await _insertTableData('budget_alerts', data['budgetAlerts'] ?? []);
        await _insertTableData('budget_alert_preferences', data['budgetAlertPreferences'] ?? []);
        await _insertTableData('budget_alert_threshold_status', data['budgetAlertThresholdStatus'] ?? []);
      });
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error restoring full backup', error: e);
      return Failure(AppError.database(
        'Restore failed: ${e.toString()}',
        stackTrace: stack,
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Deletes all data from all tables in reverse FK order.
  Future<void> _deleteAllTables() async {
    // Reverse FK order: dependent tables first
    const tables = [
      'budget_alert_threshold_status',
      'budget_alert_preferences',
      'budget_alerts',
      'goal_deposits',
      'goals',
      'recurring_execution_logs',
      'recurring_transactions',
      'budgets',
      'transactions',
      'categories',
      'wallets',
    ];

    for (final table in tables) {
      await _db.customStatement('DELETE FROM $table');
    }
  }

  /// Inserts rows into the specified table using raw SQL.
  Future<void> _insertTableData(
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;

    for (final row in rows) {
      final columns = row.keys.toList();
      final placeholders = List.filled(columns.length, '?').join(', ');
      final columnNames = columns.map(_toSnakeCase).join(', ');

      final variables = columns.map((col) {
        final value = row[col];
        if (value == null) return const Variable(null);
        if (value is int) return Variable.withInt(value);
        if (value is double) return Variable.withReal(value);
        if (value is bool) return Variable.withBool(value);
        return Variable.withString(value.toString());
      }).toList();

      await _db.customInsert(
        'INSERT INTO $tableName ($columnNames) VALUES ($placeholders)',
        variables: variables,
      );
    }
  }

  /// Converts a camelCase key to snake_case for database column names.
  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }
}
