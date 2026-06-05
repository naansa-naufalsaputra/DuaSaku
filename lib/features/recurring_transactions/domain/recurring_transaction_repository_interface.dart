import '../../../core/utils/app_error.dart';
import '../../../core/utils/result.dart';
import 'models/execution_log_model.dart';
import 'models/recurring_status.dart';
import 'models/recurring_transaction_model.dart';

/// Abstract interface for recurring transaction data operations.
///
/// Concrete implementations reside in the data layer and handle
/// Drift database operations. This interface uses only pure Dart types
/// (domain models, Result pattern) — no external package dependencies.
abstract class RecurringTransactionRepositoryInterface {
  // ─── CRUD ───────────────────────────────────────────────────────────────────

  /// Create a new recurring transaction.
  /// Validates wallet and category existence before persisting.
  Future<Result<void, AppError>> create(RecurringTransactionModel model);

  /// Update an existing recurring transaction template.
  /// Does not affect historical transactions already executed.
  Future<Result<void, AppError>> update(RecurringTransactionModel model);

  /// Delete a recurring transaction by ID.
  /// Historical transactions in the Transactions table are preserved.
  Future<Result<void, AppError>> delete(String id);

  /// Get a single recurring transaction by ID.
  Future<Result<RecurringTransactionModel, AppError>> getById(String id);

  // ─── Queries ────────────────────────────────────────────────────────────────

  /// Watch all recurring transactions for a user (realtime stream).
  Stream<List<RecurringTransactionModel>> watchAll(String userId);

  /// Get all active recurring transactions for a user.
  Future<List<RecurringTransactionModel>> getActive(String userId);

  /// Get all recurring transactions that are due for execution
  /// (status = active AND nextExecutionDate <= [now]).
  Future<List<RecurringTransactionModel>> getDueForExecution(DateTime now);

  /// Get upcoming recurring transactions within [days] days from now,
  /// limited to [limit] results, sorted by nextExecutionDate ascending.
  Future<List<RecurringTransactionModel>> getUpcoming(
    String userId,
    int days,
    int limit,
  );

  // ─── Execution State ────────────────────────────────────────────────────────

  /// Update the next execution date for a recurring transaction.
  /// Pass null to indicate no further executions (completed).
  Future<Result<void, AppError>> updateNextExecutionDate(
    String id,
    DateTime? nextDate,
  );

  /// Update the status of a recurring transaction.
  Future<Result<void, AppError>> updateStatus(String id, RecurringStatus status);

  /// Increment the retry count for a recurring transaction (on DB error).
  Future<Result<void, AppError>> incrementRetryCount(String id);

  /// Reset the retry count to 0 (after successful execution).
  Future<Result<void, AppError>> resetRetryCount(String id);

  // ─── Execution Logs ─────────────────────────────────────────────────────────

  /// Insert a new execution log entry.
  Future<Result<void, AppError>> insertExecutionLog(ExecutionLogModel log);

  /// Get execution logs for a recurring transaction, optionally limited.
  Future<List<ExecutionLogModel>> getExecutionLogs(
    String recurringTransactionId, {
    int? limit,
  });

  // ─── Locking (concurrent execution prevention) ──────────────────────────────

  /// Try to acquire an execution lock for a recurring transaction.
  /// Returns true if lock was acquired, false if already locked.
  Future<bool> tryAcquireLock(String recurringTransactionId);

  /// Release the execution lock for a recurring transaction.
  Future<void> releaseLock(String recurringTransactionId);
}
