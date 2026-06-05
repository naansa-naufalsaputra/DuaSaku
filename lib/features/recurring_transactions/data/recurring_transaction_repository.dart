import 'dart:developer' as developer;

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import '../../../core/local_db/app_database.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/result.dart';
import '../domain/models/execution_log_model.dart';
import '../domain/models/frequency.dart';
import '../domain/models/recurring_status.dart';
import '../domain/models/recurring_transaction_model.dart';
import '../domain/models/reminder_timing.dart';
import '../domain/recurring_transaction_repository_interface.dart';
import 'recurring_transaction_dao.dart';

/// Concrete implementation of [RecurringTransactionRepositoryInterface].
///
/// Uses [RecurringTransactionDao] for database operations and validates
/// wallet/category existence via direct [AppDatabase] table access.
class RecurringTransactionRepository
    implements RecurringTransactionRepositoryInterface {
  final AppDatabase _db;
  late final RecurringTransactionDao _dao;

  /// In-memory lock set for preventing concurrent execution of the same
  /// recurring transaction within a single isolate.
  final Set<String> _locks = {};

  RecurringTransactionRepository(this._db) {
    _dao = _db.recurringTransactionDao;
  }

  // ─── CRUD ───────────────────────────────────────────────────────────────────

  @override
  Future<Result<void, AppError>> create(RecurringTransactionModel model) async {
    try {
      // Validate wallet exists
      final wallet = await (_db.select(_db.wallets)
            ..where((w) => w.id.equals(model.walletId)))
          .getSingleOrNull();
      if (wallet == null) {
        return Failure(AppError.validation('Wallet not found'));
      }

      // Validate category exists
      final category = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(model.categoryId)))
          .getSingleOrNull();
      if (category == null) {
        return Failure(AppError.validation('Category not found'));
      }

      await _dao.insertRecurring(_modelToCompanion(model));
      return const Success(null);
    } on SqliteException catch (e, stack) {
      developer.log('Error creating recurring transaction', error: e);
      return Failure(AppError.database(e.message, stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> update(RecurringTransactionModel model) async {
    try {
      // Validate wallet exists
      final wallet = await (_db.select(_db.wallets)
            ..where((w) => w.id.equals(model.walletId)))
          .getSingleOrNull();
      if (wallet == null) {
        return Failure(AppError.validation('Wallet not found'));
      }

      // Validate category exists
      final category = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(model.categoryId)))
          .getSingleOrNull();
      if (category == null) {
        return Failure(AppError.validation('Category not found'));
      }

      await _dao.updateRecurring(_modelToCompanion(model));
      return const Success(null);
    } on SqliteException catch (e, stack) {
      developer.log('Error updating recurring transaction', error: e);
      return Failure(AppError.database(e.message, stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> delete(String id) async {
    try {
      await _dao.deleteRecurring(id);
      return const Success(null);
    } on SqliteException catch (e, stack) {
      developer.log('Error deleting recurring transaction', error: e);
      return Failure(AppError.database(e.message, stackTrace: stack));
    }
  }

  @override
  Future<Result<RecurringTransactionModel, AppError>> getById(
      String id) async {
    try {
      final row = await _dao.getById(id);
      if (row == null) {
        return Failure(AppError.notFound('Recurring transaction not found'));
      }
      return Success(_rowToModel(row));
    } on SqliteException catch (e, stack) {
      developer.log('Error fetching recurring transaction by id', error: e);
      return Failure(AppError.database(e.message, stackTrace: stack));
    }
  }

  // ─── Queries ────────────────────────────────────────────────────────────────

  @override
  Stream<List<RecurringTransactionModel>> watchAll(String userId) {
    return _dao.watchByUser(userId).map(
          (rows) => rows.map(_rowToModel).toList(),
        );
  }

  @override
  Future<List<RecurringTransactionModel>> getActive(String userId) async {
    final rows = await (_db.select(_db.recurringTransactions)
          ..where((t) =>
              t.userId.equals(userId) & t.status.equals('active')))
        .get();
    return rows.map(_rowToModel).toList();
  }

  @override
  Future<List<RecurringTransactionModel>> getDueForExecution(
      DateTime now) async {
    final rows = await _dao.getDueForExecution(now);
    return rows.map(_rowToModel).toList();
  }

  @override
  Future<List<RecurringTransactionModel>> getUpcoming(
    String userId,
    int days,
    int limit,
  ) async {
    final rows = await _dao.getUpcoming(userId, days, limit);
    return rows.map(_rowToModel).toList();
  }

  // ─── Execution State ────────────────────────────────────────────────────────

  @override
  Future<Result<void, AppError>> updateNextExecutionDate(
    String id,
    DateTime? nextDate,
  ) async {
    try {
      await (_db.update(_db.recurringTransactions)
            ..where((t) => t.id.equals(id)))
          .write(RecurringTransactionsCompanion(
        nextExecutionDate: nextDate != null
            ? Value(nextDate)
            : const Value.absent(),
      ));
      return const Success(null);
    } on SqliteException catch (e, stack) {
      developer.log('Error updating next execution date', error: e);
      return Failure(AppError.database(e.message, stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> updateStatus(
      String id, RecurringStatus status) async {
    try {
      await (_db.update(_db.recurringTransactions)
            ..where((t) => t.id.equals(id)))
          .write(RecurringTransactionsCompanion(
        status: Value(status.name),
      ));
      return const Success(null);
    } on SqliteException catch (e, stack) {
      developer.log('Error updating recurring transaction status', error: e);
      return Failure(AppError.database(e.message, stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> incrementRetryCount(String id) async {
    try {
      final row = await _dao.getById(id);
      if (row == null) {
        return Failure(AppError.notFound('Recurring transaction not found'));
      }
      await (_db.update(_db.recurringTransactions)
            ..where((t) => t.id.equals(id)))
          .write(RecurringTransactionsCompanion(
        retryCount: Value(row.retryCount + 1),
      ));
      return const Success(null);
    } on SqliteException catch (e, stack) {
      developer.log('Error incrementing retry count', error: e);
      return Failure(AppError.database(e.message, stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> resetRetryCount(String id) async {
    try {
      await (_db.update(_db.recurringTransactions)
            ..where((t) => t.id.equals(id)))
          .write(const RecurringTransactionsCompanion(
        retryCount: Value(0),
      ));
      return const Success(null);
    } on SqliteException catch (e, stack) {
      developer.log('Error resetting retry count', error: e);
      return Failure(AppError.database(e.message, stackTrace: stack));
    }
  }

  // ─── Execution Logs ─────────────────────────────────────────────────────────

  @override
  Future<Result<void, AppError>> insertExecutionLog(
      ExecutionLogModel log) async {
    try {
      await _dao.insertLog(RecurringExecutionLogsCompanion.insert(
        recurringTransactionId: log.recurringTransactionId,
        executedAt: log.executedAt,
        status: log.status,
        transactionId: log.transactionId != null
            ? Value(log.transactionId)
            : const Value.absent(),
        errorMessage: log.errorMessage != null
            ? Value(log.errorMessage)
            : const Value.absent(),
      ));
      return const Success(null);
    } on SqliteException catch (e, stack) {
      developer.log('Error inserting execution log', error: e);
      return Failure(AppError.database(e.message, stackTrace: stack));
    }
  }

  @override
  Future<List<ExecutionLogModel>> getExecutionLogs(
    String recurringTransactionId, {
    int? limit,
  }) async {
    final rows =
        await _dao.getLogsByRecurringId(recurringTransactionId, limit: limit);
    return rows.map(_logRowToModel).toList();
  }

  // ─── Locking ────────────────────────────────────────────────────────────────

  @override
  Future<bool> tryAcquireLock(String recurringTransactionId) async {
    if (_locks.contains(recurringTransactionId)) {
      return false;
    }
    _locks.add(recurringTransactionId);
    return true;
  }

  @override
  Future<void> releaseLock(String recurringTransactionId) async {
    _locks.remove(recurringTransactionId);
  }

  // ─── Conversion Helpers ─────────────────────────────────────────────────────

  /// Converts a Drift [RecurringTransaction] row to a domain model.
  RecurringTransactionModel _rowToModel(RecurringTransaction row) {
    return RecurringTransactionModel(
      id: row.id,
      userId: row.userId,
      walletId: row.walletId,
      categoryId: row.categoryId,
      amount: row.amount,
      type: row.type,
      frequency: Frequency.fromString(row.frequency),
      customInterval: row.customInterval,
      startDate: row.startDate,
      endDate: row.endDate,
      nextExecutionDate: row.nextExecutionDate,
      status: RecurringStatus.fromString(row.status),
      notes: row.notes,
      retryCount: row.retryCount,
      notifyBefore: row.notifyBefore,
      reminderTiming: ReminderTiming.fromString(row.reminderTiming),
      createdAt: row.createdAt,
    );
  }

  /// Converts a domain model to a Drift [RecurringTransactionsCompanion].
  RecurringTransactionsCompanion _modelToCompanion(
      RecurringTransactionModel model) {
    return RecurringTransactionsCompanion(
      id: Value(model.id),
      userId: Value(model.userId),
      walletId: Value(model.walletId),
      categoryId: Value(model.categoryId),
      amount: Value(model.amount),
      type: Value(model.type),
      frequency: Value(model.frequency.name),
      customInterval: Value(model.customInterval),
      startDate: Value(model.startDate),
      endDate: Value(model.endDate),
      nextExecutionDate: Value(model.nextExecutionDate),
      status: Value(model.status.name),
      notes: Value(model.notes),
      retryCount: Value(model.retryCount),
      notifyBefore: Value(model.notifyBefore),
      reminderTiming: Value(model.reminderTiming.toStorageString()),
      createdAt: Value(model.createdAt),
    );
  }

  /// Converts a Drift [RecurringExecutionLog] row to a domain model.
  ExecutionLogModel _logRowToModel(RecurringExecutionLog row) {
    return ExecutionLogModel(
      id: row.id,
      recurringTransactionId: row.recurringTransactionId,
      executedAt: row.executedAt,
      status: row.status,
      transactionId: row.transactionId,
      errorMessage: row.errorMessage,
    );
  }
}
