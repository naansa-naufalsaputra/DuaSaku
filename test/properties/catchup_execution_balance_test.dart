// Feature: system-audit-fixes, Property 2: Catch-up executions produce individual balance adjustments
// **Validates: Requirements 1.6**

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/core/background/recurring_executor.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a fresh in-memory database for testing.
AppDatabase _createTestDb() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON;');
      },
    ),
  );
}

/// Seeds a wallet with the given initial balance and returns the wallet ID.
Future<String> _seedWallet(
  AppDatabase db, {
  required String walletId,
  required double initialBalance,
}) async {
  await db
      .into(db.wallets)
      .insert(
        WalletsCompanion.insert(
          id: walletId,
          userId: 'test-user',
          name: 'Test Wallet',
          type: 'Cash',
          balance: Value(initialBalance),
          icon: 'wallet',
          color: '#000000',
          createdAt: DateTime(2024, 1, 1),
        ),
      );
  return walletId;
}

/// Seeds a category required for recurring transactions.
Future<String> _seedCategory(
  AppDatabase db, {
  required String categoryId,
  required String type,
}) async {
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: categoryId,
          userId: 'test-user',
          name: 'Test Category',
          type: type,
          createdAt: DateTime(2024, 1, 1),
        ),
      );
  return categoryId;
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Property 2: Catch-up executions produce individual balance adjustments
  // **Validates: Requirements 1.6**
  //
  // For any recurring transaction with N missed execution dates (where
  // 1 ≤ N ≤ 90) and for any positive amount, after catch-up execution
  // completes, the wallet balance SHALL equal
  // `initialBalance - (N × amount)` for expenses
  // (or `+ (N × amount)` for income), AND exactly N transaction rows
  // SHALL exist in the database for that recurring transaction.
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 2: Catch-up executions produce individual balance adjustments', () {
    // --- Expense catch-up: balance = initialBalance - (N × amount) ---
    Glados2(
      any.intInRange(1, 90), // N missed executions
      any.intInRange(
        100,
        500000,
      ), // amount in cents (to avoid floating point issues)
    ).test(
      'expense catch-up: wallet balance = initialBalance - (N × amount) and exactly N rows created',
      (missedCount, amountCents) async {
        final db = _createTestDb();
        try {
          final amount = amountCents / 100.0;
          // Initial balance large enough to cover all deductions
          final initialBalance = amount * missedCount + 10000.0;

          final walletId = await _seedWallet(
            db,
            walletId: 'wallet-catchup-expense',
            initialBalance: initialBalance,
          );
          final categoryId = await _seedCategory(
            db,
            categoryId: 'cat-catchup-expense',
            type: 'expense',
          );

          // Set nextExecutionDate N daily intervals in the past so the executor
          // will compute N missed executions when it runs "now".
          // Using daily frequency with customInterval=1 for simplicity.
          final now = DateTime(2024, 6, 15, 12, 0, 0);
          final nextExecutionDate = now.subtract(
            Duration(days: missedCount - 1),
          );

          await db
              .into(db.recurringTransactions)
              .insert(
                RecurringTransactionsCompanion.insert(
                  id: 'recurring-expense-catchup',
                  userId: 'test-user',
                  walletId: walletId,
                  categoryId: categoryId,
                  amount: amount,
                  type: 'expense',
                  frequency: 'daily',
                  startDate: DateTime(2024, 1, 1),
                  nextExecutionDate: nextExecutionDate,
                ),
              );

          // Execute the RecurringExecutor — it will detect missed dates
          // between nextExecutionDate and "now". Since we can't control
          // DateTime.now() inside the executor, we need to ensure the
          // nextExecutionDate is far enough in the past relative to actual now.
          //
          // Strategy: Set nextExecutionDate relative to actual DateTime.now()
          // so the executor's internal DateTime.now() call finds them due.
          final actualNow = DateTime.now();
          final actualNextExecDate = actualNow.subtract(
            Duration(days: missedCount - 1),
          );

          // Re-create with actual dates
          await (db.delete(
            db.recurringTransactions,
          )..where((t) => t.id.equals('recurring-expense-catchup'))).go();

          await db
              .into(db.recurringTransactions)
              .insert(
                RecurringTransactionsCompanion.insert(
                  id: 'recurring-expense-catchup',
                  userId: 'test-user',
                  walletId: walletId,
                  categoryId: categoryId,
                  amount: amount,
                  type: 'expense',
                  frequency: 'daily',
                  startDate: DateTime(2024, 1, 1),
                  nextExecutionDate: actualNextExecDate,
                ),
              );

          final executor = RecurringExecutor(db);
          await executor.execute();

          // Verify wallet balance = initialBalance - (N × amount)
          final wallet = await (db.select(
            db.wallets,
          )..where((w) => w.id.equals(walletId))).getSingle();

          final expectedBalance = initialBalance - (missedCount * amount);
          expect(
            wallet.balance,
            closeTo(expectedBalance, 0.01),
            reason:
                'Expense catch-up: expected $expectedBalance but got ${wallet.balance} '
                '(initial=$initialBalance, N=$missedCount, amount=$amount)',
          );

          // Verify exactly N transaction rows exist for this recurring transaction
          final transactions =
              await (db.select(db.transactions)..where(
                    (t) =>
                        t.walletId.equals(walletId) &
                        t.badge.equals('recurring'),
                  ))
                  .get();

          expect(
            transactions.length,
            equals(missedCount),
            reason:
                'Expected exactly $missedCount transaction rows but found '
                '${transactions.length}',
          );
        } finally {
          await db.close();
        }
      },
    );

    // --- Income catch-up: balance = initialBalance + (N × amount) ---
    Glados2(
      any.intInRange(1, 90), // N missed executions
      any.intInRange(100, 500000), // amount in cents
    ).test(
      'income catch-up: wallet balance = initialBalance + (N × amount) and exactly N rows created',
      (missedCount, amountCents) async {
        final db = _createTestDb();
        try {
          final amount = amountCents / 100.0;
          const initialBalance = 5000.0;

          final walletId = await _seedWallet(
            db,
            walletId: 'wallet-catchup-income',
            initialBalance: initialBalance,
          );
          final categoryId = await _seedCategory(
            db,
            categoryId: 'cat-catchup-income',
            type: 'income',
          );

          // Set nextExecutionDate N daily intervals in the past relative to
          // actual DateTime.now() so the executor finds them due.
          final actualNow = DateTime.now();
          final actualNextExecDate = actualNow.subtract(
            Duration(days: missedCount - 1),
          );

          await db
              .into(db.recurringTransactions)
              .insert(
                RecurringTransactionsCompanion.insert(
                  id: 'recurring-income-catchup',
                  userId: 'test-user',
                  walletId: walletId,
                  categoryId: categoryId,
                  amount: amount,
                  type: 'income',
                  frequency: 'daily',
                  startDate: DateTime(2024, 1, 1),
                  nextExecutionDate: actualNextExecDate,
                ),
              );

          final executor = RecurringExecutor(db);
          await executor.execute();

          // Verify wallet balance = initialBalance + (N × amount)
          final wallet = await (db.select(
            db.wallets,
          )..where((w) => w.id.equals(walletId))).getSingle();

          final expectedBalance = initialBalance + (missedCount * amount);
          expect(
            wallet.balance,
            closeTo(expectedBalance, 0.01),
            reason:
                'Income catch-up: expected $expectedBalance but got ${wallet.balance} '
                '(initial=$initialBalance, N=$missedCount, amount=$amount)',
          );

          // Verify exactly N transaction rows exist
          final transactions =
              await (db.select(db.transactions)..where(
                    (t) =>
                        t.walletId.equals(walletId) &
                        t.badge.equals('recurring'),
                  ))
                  .get();

          expect(
            transactions.length,
            equals(missedCount),
            reason:
                'Expected exactly $missedCount transaction rows but found '
                '${transactions.length}',
          );
        } finally {
          await db.close();
        }
      },
    );
  });
}
