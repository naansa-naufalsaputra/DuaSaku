import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../features/recurring_transactions/data/recurring_transaction_dao.dart';
import '../../features/recurring_transactions/domain/models/frequency.dart';
import '../../features/recurring_transactions/domain/recurring_scheduler_logic.dart';
import '../../features/recurring_transactions/services/recurring_notification_service.dart';
import '../../features/smart_budget_alerts/services/budget_alert_evaluator.dart';
import '../local_db/app_database.dart';

/// Handles recurring transaction execution in background isolate.
///
/// This class does NOT use Riverpod — it takes [AppDatabase] directly,
/// suitable for background isolate execution where providers are unavailable.
///
/// Execution flow:
/// 1. Query due transactions (active + nextExecutionDate <= now)
/// 2. For each: acquire lock → execute (with catch-up) → release lock
/// 3. On success: create transaction, log execution, update next date
/// 4. On failure: retry logic (max 3 for DB errors), immediate pause otherwise
class RecurringExecutor {
  final AppDatabase _db;
  late final RecurringTransactionDao _dao;

  /// Optional notification service for showing execution results.
  /// May be null in environments where flutter_local_notifications
  /// is not available (e.g., test isolates without Flutter engine).
  final RecurringNotificationService? _notificationService;

  /// Budget alert evaluator for triggering alert evaluation after
  /// recurring transaction execution.
  late final BudgetAlertEvaluator _alertEvaluator;

  /// In-memory lock set to prevent concurrent execution of the same
  /// recurring transaction within this isolate.
  final Set<String> _activeLocks = {};

  RecurringExecutor(this._db, {this._notificationService}) {
    _dao = _db.recurringTransactionDao;
    _alertEvaluator = BudgetAlertEvaluator.fromDatabase(_db);
  }

  /// Main entry point called from callbackDispatcher.
  /// Returns true if all operations completed (even if individual ones failed).
  Future<bool> execute() async {
    final now = DateTime.now();
    final dueTransactions = await _getDueTransactions(now);

    debugPrint(
      '[RecurringExecutor] Found ${dueTransactions.length} due transactions',
    );

    for (final recurring in dueTransactions) {
      if (!_tryLock(recurring.id)) {
        debugPrint(
          '[RecurringExecutor] Skipping ${recurring.id} — already locked',
        );
        continue;
      }

      try {
        await _executeRecurring(recurring, now);
      } catch (e) {
        debugPrint(
          '[RecurringExecutor] Unhandled error for ${recurring.id}: $e',
        );
      } finally {
        _releaseLock(recurring.id);
      }
    }

    return true;
  }

  // ─── Private Methods ──────────────────────────────────────────────────────

  /// Get all active recurring transactions that are due for execution.
  Future<List<RecurringTransaction>> _getDueTransactions(DateTime now) {
    return _dao.getDueForExecution(now);
  }

  /// Execute a single recurring transaction, handling catch-up for missed dates.
  Future<void> _executeRecurring(
    RecurringTransaction recurring,
    DateTime now,
  ) async {
    try {
      // Handle catch-up: compute missed executions and execute chronologically
      await _handleCatchUp(recurring, now);
    } on StateError catch (e) {
      // Wallet not found — non-retryable, pause immediately
      debugPrint(
        '[RecurringExecutor] Wallet not found for ${recurring.id}: $e',
      );
      await _handleFailure(recurring, 'other_error', e.message);
    } on SqliteException catch (e) {
      debugPrint('[RecurringExecutor] Database error for ${recurring.id}: $e');
      await _handleFailure(recurring, 'database_error', e.message);
    } catch (e) {
      debugPrint('[RecurringExecutor] Non-DB error for ${recurring.id}: $e');
      await _handleFailure(recurring, 'other_error', e.toString());
    }
  }

  /// Compute missed executions and execute each chronologically (max 90).
  ///
  /// Uses [RecurringSchedulerLogic.computeMissedExecutions] to determine
  /// all dates that should have been executed between the last execution
  /// (nextExecutionDate represents the next pending one) and now.
  Future<void> _handleCatchUp(
    RecurringTransaction recurring,
    DateTime now,
  ) async {
    final frequency = Frequency.fromString(recurring.frequency);

    // Compute all missed execution dates.
    // The "lastExecutionDate" for missed computation is the date just before
    // the current nextExecutionDate (i.e., one interval back from nextExecutionDate).
    // However, since nextExecutionDate IS the first pending date, we use it
    // as the starting point and include it if it's <= now.
    final missedDates = <DateTime>[];

    // Start from the current nextExecutionDate and compute forward
    var current = recurring.nextExecutionDate;
    for (var i = 0; i < 90; i++) {
      if (current.isAfter(now)) break;
      if (recurring.endDate != null && current.isAfter(recurring.endDate!)) {
        break;
      }
      missedDates.add(current);

      final next = RecurringSchedulerLogic.computeNextExecutionDate(
        currentExecutionDate: current,
        frequency: frequency,
        customInterval: recurring.customInterval,
        endDate: recurring.endDate,
      );
      if (next == null) break;
      current = next;
    }

    if (missedDates.isEmpty) return;

    debugPrint(
      '[RecurringExecutor] Executing ${missedDates.length} missed '
      'transactions for ${recurring.id}',
    );

    // Execute each missed date chronologically
    for (final executionDate in missedDates) {
      // Idempotency check: verify no execution log exists for this date
      if (await _hasExistingExecution(recurring.id, executionDate)) {
        debugPrint(
          '[RecurringExecutor] Skipping duplicate execution for '
          '${recurring.id} at $executionDate',
        );
        continue;
      }

      final transactionId = await _createTransactionWithBalanceUpdate(
        recurring,
        executionDate,
      );
      await _logExecution(
        recurringId: recurring.id,
        transactionId: transactionId,
        status: 'success',
        executedAt: executionDate,
      );
    }

    // After all executions, update the next execution date
    await _updateNextDate(recurring, missedDates.last);

    // Reset retry count on success
    await (_db.update(_db.recurringTransactions)
          ..where((t) => t.id.equals(recurring.id)))
        .write(const RecurringTransactionsCompanion(retryCount: Value(0)));

    // Trigger budget alert evaluation for expense recurring transactions
    if (recurring.type == 'expense') {
      await _triggerAlertEvaluation(recurring, missedDates.last);
    }

    // Send success notification
    await _notifyExecutionSuccess(recurring);
  }

  /// Creates a transaction and adjusts wallet balance atomically.
  ///
  /// Wraps the transaction insert AND the balance adjustment in a single
  /// Drift `transaction()` block to ensure atomicity. If any step fails
  /// (e.g., wallet not found), the entire operation is rolled back.
  ///
  /// Budget tracking integration (Requirements 5.4, 5.5):
  /// The budget system computes actuals dynamically by querying the Transactions
  /// table — summing expense amounts by category and month. Since this method
  /// inserts the transaction with the correct categoryId, type, and date,
  /// budget tracking is automatically updated when the BudgetNotifier rebuilds.
  /// No separate budget "actual" field needs incrementing.
  /// If no budget is configured for the category/month, the transaction is still
  /// created without affecting budget tracking (Requirement 5.5).
  Future<int> _createTransactionWithBalanceUpdate(
    RecurringTransaction recurring,
    DateTime executionDate,
  ) async {
    return await _db.transaction(() async {
      // 1. Insert transaction
      final id = await _db
          .into(_db.transactions)
          .insert(
            TransactionsCompanion.insert(
              userId: recurring.userId,
              walletId: Value(recurring.walletId),
              categoryId: Value(recurring.categoryId),
              amount: recurring.amount,
              notes: Value(recurring.notes),
              date: executionDate,
              type: recurring.type,
              badge: const Value('recurring'),
            ),
          );

      // 2. Adjust wallet balance based on type
      if (recurring.type == 'transfer') {
        await _adjustTransferBalances(recurring);
      } else {
        await _adjustWalletBalance(
          walletId: recurring.walletId,
          amount: recurring.amount,
          type: recurring.type,
        );
      }

      return id;
    });
  }

  /// Insert an execution log entry into RecurringExecutionLogs.
  Future<void> _logExecution({
    required String recurringId,
    required int? transactionId,
    required String status,
    required DateTime executedAt,
    String? errorMessage,
  }) async {
    await _dao.insertLog(
      RecurringExecutionLogsCompanion.insert(
        recurringTransactionId: recurringId,
        executedAt: executedAt,
        status: status,
        transactionId: transactionId != null
            ? Value(transactionId)
            : const Value.absent(),
        errorMessage: errorMessage != null
            ? Value(errorMessage)
            : const Value.absent(),
      ),
    );
  }

  /// Compute and set the next execution date after the last executed date.
  /// If the next date exceeds endDate, set status to 'completed'.
  Future<void> _updateNextDate(
    RecurringTransaction recurring,
    DateTime lastExecutedDate,
  ) async {
    final frequency = Frequency.fromString(recurring.frequency);

    final nextDate = RecurringSchedulerLogic.computeNextExecutionDate(
      currentExecutionDate: lastExecutedDate,
      frequency: frequency,
      customInterval: recurring.customInterval,
      endDate: recurring.endDate,
    );

    if (nextDate == null) {
      // End date reached — mark as completed
      debugPrint(
        '[RecurringExecutor] ${recurring.id} completed — end date reached',
      );
      await (_db.update(
        _db.recurringTransactions,
      )..where((t) => t.id.equals(recurring.id))).write(
        RecurringTransactionsCompanion(
          status: const Value('completed'),
          nextExecutionDate: Value(lastExecutedDate),
        ),
      );
    } else {
      await (_db.update(
        _db.recurringTransactions,
      )..where((t) => t.id.equals(recurring.id))).write(
        RecurringTransactionsCompanion(nextExecutionDate: Value(nextDate)),
      );
    }
  }

  /// Handle execution failure with retry logic.
  ///
  /// - Database errors (SqliteException): increment retryCount, pause at 3
  /// - Other errors (wallet/category not found): pause immediately
  Future<void> _handleFailure(
    RecurringTransaction recurring,
    String errorType,
    String errorMessage,
  ) async {
    // Log the failed execution
    await _logExecution(
      recurringId: recurring.id,
      transactionId: null,
      status: 'failed',
      executedAt: DateTime.now(),
      errorMessage: errorMessage,
    );

    if (errorType == 'database_error') {
      final newRetryCount = recurring.retryCount + 1;
      if (newRetryCount >= 3) {
        // Max retries reached — pause the recurring transaction
        debugPrint(
          '[RecurringExecutor] ${recurring.id} paused — max retries reached',
        );
        await (_db.update(
          _db.recurringTransactions,
        )..where((t) => t.id.equals(recurring.id))).write(
          const RecurringTransactionsCompanion(
            status: Value('paused'),
            retryCount: Value(3),
          ),
        );

        // Notify failure when paused due to max retries
        await _notifyExecutionFailure(recurring, 'Max retries exceeded');
      } else {
        // Increment retry count
        await (_db.update(
          _db.recurringTransactions,
        )..where((t) => t.id.equals(recurring.id))).write(
          RecurringTransactionsCompanion(retryCount: Value(newRetryCount)),
        );
      }
    } else {
      // Non-database errors: pause immediately
      debugPrint(
        '[RecurringExecutor] ${recurring.id} paused — non-retryable error: '
        '$errorMessage',
      );
      await (_db.update(_db.recurringTransactions)
            ..where((t) => t.id.equals(recurring.id)))
          .write(const RecurringTransactionsCompanion(status: Value('paused')));

      // Notify failure for non-retryable errors
      await _notifyExecutionFailure(recurring, errorType);
    }
  }

  /// Check if an execution log already exists for the given recurring
  /// transaction and execution date (idempotency guard).
  Future<bool> _hasExistingExecution(
    String recurringId,
    DateTime executionDate,
  ) async {
    final logs =
        await ((_db.select(_db.recurringExecutionLogs)..where(
              (l) =>
                  l.recurringTransactionId.equals(recurringId) &
                  l.executedAt.equals(executionDate) &
                  l.status.equals('success'),
            ))
            .get());
    return logs.isNotEmpty;
  }

  // ─── Alert Evaluation ────────────────────────────────────────────────────────

  /// Triggers budget alert evaluation after a recurring expense transaction
  /// is executed. Uses the last execution date to determine the budget month.
  ///
  /// Fire-and-forget — errors are logged but do not affect the execution flow.
  Future<void> _triggerAlertEvaluation(
    RecurringTransaction recurring,
    DateTime executionDate,
  ) async {
    try {
      final budgetMonth = DateFormat('yyyy-MM').format(executionDate);

      await _alertEvaluator.evaluateAfterExpenseInsert(
        userId: recurring.userId,
        categoryId: recurring.categoryId,
        budgetMonth: budgetMonth,
      );
    } catch (e) {
      debugPrint(
        '[RecurringExecutor] Alert evaluation failed for ${recurring.id}: $e',
      );
    }
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  /// Send a success notification after recurring transaction execution.
  /// Looks up the wallet name from the database for the notification body.
  Future<void> _notifyExecutionSuccess(RecurringTransaction recurring) async {
    if (_notificationService == null) return;

    try {
      final walletName = await _getWalletName(recurring.walletId);
      final transactionName = recurring.notes ?? 'Recurring Transaction';

      await _notificationService.showExecutionSuccess(
        recurringTransactionId: recurring.id,
        transactionName: transactionName,
        amount: recurring.amount,
        walletName: walletName,
      );
    } catch (e) {
      // Notification failure should not break execution flow
      debugPrint('[RecurringExecutor] Failed to send success notification: $e');
    }
  }

  /// Send a failure notification when a recurring transaction execution fails.
  Future<void> _notifyExecutionFailure(
    RecurringTransaction recurring,
    String errorCategory,
  ) async {
    if (_notificationService == null) return;

    try {
      final transactionName = recurring.notes ?? 'Recurring Transaction';

      await _notificationService.showExecutionFailure(
        recurringTransactionId: recurring.id,
        transactionName: transactionName,
        errorCategory: errorCategory,
      );
    } catch (e) {
      // Notification failure should not break execution flow
      debugPrint('[RecurringExecutor] Failed to send failure notification: $e');
    }
  }

  // ─── Wallet Balance Adjustment ─────────────────────────────────────────────

  /// Adjusts a single wallet's balance for income/expense transactions.
  ///
  /// Queries the wallet by [walletId], throws [StateError] if not found,
  /// then updates the balance: income adds [amount], expense subtracts [amount].
  ///
  /// Must be called within a `_db.transaction()` block to ensure atomicity.
  Future<void> _adjustWalletBalance({
    required String walletId,
    required double amount,
    required String type,
  }) async {
    final wallet = await (_db.select(
      _db.wallets,
    )..where((w) => w.id.equals(walletId))).getSingleOrNull();

    if (wallet == null) {
      throw StateError('Wallet $walletId not found');
    }

    final newBalance = type == 'income'
        ? wallet.balance + amount
        : wallet.balance - amount;

    await (_db.update(_db.wallets)..where((w) => w.id.equals(walletId))).write(
      WalletsCompanion(balance: Value(newBalance)),
    );
  }

  /// Adjusts wallet balances for transfer-type recurring transactions.
  ///
  /// Decreases the source wallet (walletId) balance and increases the
  /// destination wallet (toWalletId) balance by the transaction amount.
  /// Throws [StateError] if either wallet is not found.
  ///
  /// Must be called within a `_db.transaction()` block to ensure atomicity.
  Future<void> _adjustTransferBalances(RecurringTransaction recurring) async {
    // Decrease source wallet (walletId serves as fromWalletId for recurring transfers)
    final sourceWallet = await (_db.select(
      _db.wallets,
    )..where((w) => w.id.equals(recurring.walletId))).getSingleOrNull();

    if (sourceWallet == null) {
      throw StateError('Source wallet ${recurring.walletId} not found');
    }

    await (_db.update(
      _db.wallets,
    )..where((w) => w.id.equals(recurring.walletId))).write(
      WalletsCompanion(balance: Value(sourceWallet.balance - recurring.amount)),
    );

    // Increase destination wallet
    // Note: RecurringTransactions table currently does not have a toWalletId
    // column. When transfer-type recurring transactions are supported, the
    // destination wallet ID should be retrieved from the recurring transaction.
    // For now, this path is unreachable since recurring transactions only
    // support 'income' and 'expense' types. If somehow reached, the transaction
    // block will roll back the source wallet change above.
    throw StateError(
      'Transfer recurring transaction ${recurring.id} has no destination wallet configured',
    );
  }

  // ─── Notifications ─────────────────────────────────────────────────────────

  /// Look up the wallet name from the Wallets table.
  Future<String> _getWalletName(String walletId) async {
    final wallet = await (_db.select(
      _db.wallets,
    )..where((w) => w.id.equals(walletId))).getSingleOrNull();
    return wallet?.name ?? 'Unknown Wallet';
  }

  // ─── Locking ──────────────────────────────────────────────────────────────

  /// Try to acquire an in-memory lock for a recurring transaction.
  bool _tryLock(String id) {
    if (_activeLocks.contains(id)) return false;
    _activeLocks.add(id);
    return true;
  }

  /// Release the in-memory lock for a recurring transaction.
  void _releaseLock(String id) {
    _activeLocks.remove(id);
  }
}
