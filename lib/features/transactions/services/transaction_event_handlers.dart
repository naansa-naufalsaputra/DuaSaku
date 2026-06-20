import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../wallets/domain/wallet_repository_interface.dart';
import '../../geofencing/services/geofence_sync_helper.dart';
import '../domain/transaction_events.dart';
import '../domain/models/transaction_model.dart';
import '../domain/transaction_repository_interface.dart';
import '../../smart_budget_alerts/services/budget_alert_evaluator.dart';

/// Handles side-effects triggered by transaction events.
///
/// Listens to the transaction event stream and performs:
/// - Wallet balance updates (apply/revert)
/// - Geofence hotspot synchronization
/// - Budget alert evaluation (future)
class TransactionEventHandlers {
  final WalletRepositoryInterface _walletRepo;
  final TransactionRepositoryInterface _transactionRepo;
  final BudgetAlertEvaluator _budgetEvaluator;

  TransactionEventHandlers(
    this._walletRepo,
    this._transactionRepo,
    this._budgetEvaluator,
  );

  /// Register handlers to listen to the event stream.
  void registerHandlers(Stream<TransactionEvent> eventStream) {
    eventStream.listen((event) {
      switch (event) {
        case TransactionCreated(:final transaction):
          _handleCreated(transaction);
        case TransactionUpdated(:final transaction, :final oldTransaction):
          _handleUpdated(transaction, oldTransaction);
        case TransactionDeleted(:final transaction):
          _handleDeleted(transaction);
      }
    });
  }

  /// Handle TransactionCreated event: apply balance changes.
  Future<void> _handleCreated(TransactionModel transaction) async {
    try {
      // 1. Update wallet balances
      if (transaction.type == 'transfer') {
        // Transfer: deduct from source, add to destination
        if (transaction.fromWalletId != null) {
          await _walletRepo.adjustBalance(
            transaction.fromWalletId!,
            -transaction.amount,
          );
        }
        if (transaction.toWalletId != null) {
          await _walletRepo.adjustBalance(
            transaction.toWalletId!,
            transaction.amount,
          );
        }
      } else {
        // Income/Expense: adjust primary wallet
        if (transaction.walletId != null) {
          final adjustment = transaction.type == 'income'
              ? transaction.amount
              : -transaction.amount;
          await _walletRepo.adjustBalance(transaction.walletId!, adjustment);
        }
      }

      // 2. Trigger geofence sync (async, non-blocking)
      unawaited(
        GeofenceSyncHelper.syncGeofenceHotspots(
          _transactionRepo,
          transaction.userId,
        ),
      );

      // 3. Evaluate budget alerts for expenses
      if (transaction.type == 'expense') {
        final budgetMonth = BudgetAlertEvaluator.getBudgetMonthForDate(
          transaction.createdAt,
        );
        unawaited(
          _budgetEvaluator.evaluateAfterExpenseInsert(
            userId: transaction.userId,
            categoryId: transaction.categoryId,
            budgetMonth: budgetMonth,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TransactionEventHandlers] Error handling created event: $e');
    }
  }

  /// Handle TransactionUpdated event: revert old balances, apply new balances.
  Future<void> _handleUpdated(
    TransactionModel transaction,
    TransactionModel oldTransaction,
  ) async {
    try {
      // 1. Revert old transaction balance effects
      await _revertBalanceChanges(oldTransaction);

      // 2. Apply new transaction balance effects
      await _applyBalanceChanges(transaction);

      // 3. Trigger geofence sync
      unawaited(
        GeofenceSyncHelper.syncGeofenceHotspots(
          _transactionRepo,
          transaction.userId,
        ),
      );

      // 4. Re-evaluate budget alerts
      if (transaction.type == 'expense' || oldTransaction.type == 'expense') {
        if (oldTransaction.type == 'expense') {
          final oldBudgetMonth = BudgetAlertEvaluator.getBudgetMonthForDate(
            oldTransaction.createdAt,
          );
          unawaited(
            _budgetEvaluator.evaluateAfterExpenseChange(
              userId: oldTransaction.userId,
              categoryId: oldTransaction.categoryId,
              budgetMonth: oldBudgetMonth,
            ),
          );
        }

        if (transaction.type == 'expense' &&
            (transaction.categoryId != oldTransaction.categoryId ||
                transaction.amount != oldTransaction.amount ||
                transaction.createdAt != oldTransaction.createdAt)) {
          final newBudgetMonth = BudgetAlertEvaluator.getBudgetMonthForDate(
            transaction.createdAt,
          );
          unawaited(
            _budgetEvaluator.evaluateAfterExpenseInsert(
              userId: transaction.userId,
              categoryId: transaction.categoryId,
              budgetMonth: newBudgetMonth,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[TransactionEventHandlers] Error handling updated event: $e');
    }
  }

  /// Handle TransactionDeleted event: revert balance changes.
  Future<void> _handleDeleted(TransactionModel transaction) async {
    try {
      // 1. Revert balance changes
      await _revertBalanceChanges(transaction);

      // 2. Trigger geofence sync
      unawaited(
        GeofenceSyncHelper.syncGeofenceHotspots(
          _transactionRepo,
          transaction.userId,
        ),
      );

      // 3. Re-evaluate budget alerts
      if (transaction.type == 'expense') {
        final budgetMonth = BudgetAlertEvaluator.getBudgetMonthForDate(
          transaction.createdAt,
        );
        unawaited(
          _budgetEvaluator.evaluateAfterExpenseChange(
            userId: transaction.userId,
            categoryId: transaction.categoryId,
            budgetMonth: budgetMonth,
          ),
        );
      }
    } catch (e) {
      debugPrint('[TransactionEventHandlers] Error handling deleted event: $e');
    }
  }

  /// Apply balance changes for a transaction.
  Future<void> _applyBalanceChanges(TransactionModel transaction) async {
    if (transaction.type == 'transfer') {
      if (transaction.fromWalletId != null) {
        await _walletRepo.adjustBalance(
          transaction.fromWalletId!,
          -transaction.amount,
        );
      }
      if (transaction.toWalletId != null) {
        await _walletRepo.adjustBalance(
          transaction.toWalletId!,
          transaction.amount,
        );
      }
    } else {
      if (transaction.walletId != null) {
        final adjustment = transaction.type == 'income'
            ? transaction.amount
            : -transaction.amount;
        await _walletRepo.adjustBalance(transaction.walletId!, adjustment);
      }
    }
  }

  /// Revert balance changes for a transaction (opposite of apply).
  Future<void> _revertBalanceChanges(TransactionModel transaction) async {
    if (transaction.type == 'transfer') {
      // Revert transfer: add back to source, subtract from destination
      if (transaction.fromWalletId != null) {
        await _walletRepo.adjustBalance(
          transaction.fromWalletId!,
          transaction.amount,
        );
      }
      if (transaction.toWalletId != null) {
        await _walletRepo.adjustBalance(
          transaction.toWalletId!,
          -transaction.amount,
        );
      }
    } else {
      // Revert income/expense: opposite adjustment
      if (transaction.walletId != null) {
        final adjustment = transaction.type == 'income'
            ? -transaction.amount
            : transaction.amount;
        await _walletRepo.adjustBalance(transaction.walletId!, adjustment);
      }
    }
  }
}
