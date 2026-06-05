// Feature: system-audit-fixes, Property 3: RecurringExecutor and TransactionRepository produce equivalent balance changes
// **Validates: Requirements 1.7**

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/core/background/recurring_executor.dart';
import 'package:duasaku_app/features/transactions/data/transaction_repository.dart';
import 'package:duasaku_app/features/transactions/domain/models/transaction_model.dart';

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

/// Seeds a category required for transactions.
Future<String> _seedCategory(
  AppDatabase db, {
  required String categoryId,
}) async {
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: categoryId,
          userId: 'test-user',
          name: 'Test Category',
          type: 'expense',
          createdAt: DateTime(2024, 1, 1),
        ),
      );
  return categoryId;
}

/// Seeds a recurring transaction and returns its ID.
Future<String> _seedRecurringTransaction(
  AppDatabase db, {
  required String id,
  required String walletId,
  required String categoryId,
  required double amount,
  required String type,
  required DateTime nextExecutionDate,
}) async {
  await db
      .into(db.recurringTransactions)
      .insert(
        RecurringTransactionsCompanion.insert(
          id: id,
          userId: 'test-user',
          walletId: walletId,
          categoryId: categoryId,
          amount: amount,
          type: type,
          frequency: 'monthly',
          startDate: DateTime(2024, 1, 1),
          nextExecutionDate: nextExecutionDate,
        ),
      );
  return id;
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Property 3: RecurringExecutor and TransactionRepository produce equivalent
  // balance changes
  // **Validates: Requirements 1.7**
  //
  // For any valid transaction parameters (type ∈ {income, expense}, amount > 0,
  // valid walletId), the wallet balance delta produced by
  // RecurringExecutor._createTransactionWithBalanceUpdate() SHALL be identical
  // to the wallet balance delta produced by TransactionRepository.insertTransaction()
  // with the same parameters.
  // ──────────────────────────────────────────────────────────────────────────
  group(
    'Property 3: RecurringExecutor and TransactionRepository produce equivalent balance changes',
    () {
      // --- Income equivalence ---
      Glados2(
        any.doubleInRange(0, 100000), // initial balance
        any.doubleInRange(0.01, 50000), // positive transaction amount
      ).test(
        'income: RecurringExecutor and TransactionRepository produce identical balance delta',
        (initialBalance, amount) async {
          // Database 1: RecurringExecutor path
          final dbExecutor = _createTestDb();
          // Database 2: TransactionRepository path
          final dbRepo = _createTestDb();

          try {
            const walletId = 'wallet-income';
            const categoryId = 'cat-income';

            // --- Set up identical databases ---
            await _seedWallet(
              dbExecutor,
              walletId: walletId,
              initialBalance: initialBalance,
            );
            await _seedCategory(dbExecutor, categoryId: categoryId);

            await _seedWallet(
              dbRepo,
              walletId: walletId,
              initialBalance: initialBalance,
            );
            await _seedCategory(dbRepo, categoryId: categoryId);

            // --- Execute via RecurringExecutor ---
            await _seedRecurringTransaction(
              dbExecutor,
              id: 'recurring-income',
              walletId: walletId,
              categoryId: categoryId,
              amount: amount,
              type: 'income',
              nextExecutionDate: DateTime.now().subtract(
                const Duration(hours: 1),
              ),
            );

            final executor = RecurringExecutor(dbExecutor);
            await executor.execute();

            // --- Execute via TransactionRepository ---
            final repo = TransactionRepository(dbRepo);
            final transaction = TransactionModel(
              userId: 'test-user',
              amount: amount,
              category: 'Test Category',
              type: 'income',
              notes: '',
              createdAt: DateTime(2024, 1, 15),
              walletId: walletId,
            );
            await repo.insertTransaction(transaction);

            // --- Compare wallet balances ---
            final walletExecutor = await (dbExecutor.select(
              dbExecutor.wallets,
            )..where((w) => w.id.equals(walletId))).getSingle();
            final walletRepo = await (dbRepo.select(
              dbRepo.wallets,
            )..where((w) => w.id.equals(walletId))).getSingle();

            // Both should produce the same balance delta from the same initial balance
            final deltaExecutor = walletExecutor.balance - initialBalance;
            final deltaRepo = walletRepo.balance - initialBalance;

            expect(
              deltaExecutor,
              closeTo(deltaRepo, 0.001),
              reason:
                  'Income balance delta mismatch: executor=$deltaExecutor, repo=$deltaRepo '
                  '(initial=$initialBalance, amount=$amount)',
            );

            // Also verify the absolute balance is correct
            expect(
              walletExecutor.balance,
              closeTo(initialBalance + amount, 0.001),
              reason: 'Executor balance should be initialBalance + amount',
            );
            expect(
              walletRepo.balance,
              closeTo(initialBalance + amount, 0.001),
              reason: 'Repo balance should be initialBalance + amount',
            );
          } finally {
            await dbExecutor.close();
            await dbRepo.close();
          }
        },
      );

      // --- Expense equivalence ---
      Glados2(
        any.doubleInRange(0, 100000), // initial balance
        any.doubleInRange(0.01, 50000), // positive transaction amount
      ).test(
        'expense: RecurringExecutor and TransactionRepository produce identical balance delta',
        (initialBalance, amount) async {
          // Database 1: RecurringExecutor path
          final dbExecutor = _createTestDb();
          // Database 2: TransactionRepository path
          final dbRepo = _createTestDb();

          try {
            const walletId = 'wallet-expense';
            const categoryId = 'cat-expense';

            // --- Set up identical databases ---
            await _seedWallet(
              dbExecutor,
              walletId: walletId,
              initialBalance: initialBalance,
            );
            await _seedCategory(dbExecutor, categoryId: categoryId);

            await _seedWallet(
              dbRepo,
              walletId: walletId,
              initialBalance: initialBalance,
            );
            await _seedCategory(dbRepo, categoryId: categoryId);

            // --- Execute via RecurringExecutor ---
            await _seedRecurringTransaction(
              dbExecutor,
              id: 'recurring-expense',
              walletId: walletId,
              categoryId: categoryId,
              amount: amount,
              type: 'expense',
              nextExecutionDate: DateTime.now().subtract(
                const Duration(hours: 1),
              ),
            );

            final executor = RecurringExecutor(dbExecutor);
            await executor.execute();

            // --- Execute via TransactionRepository ---
            final repo = TransactionRepository(dbRepo);
            final transaction = TransactionModel(
              userId: 'test-user',
              amount: amount,
              category: 'Test Category',
              type: 'expense',
              notes: '',
              createdAt: DateTime(2024, 1, 15),
              walletId: walletId,
            );
            await repo.insertTransaction(transaction);

            // --- Compare wallet balances ---
            final walletExecutor = await (dbExecutor.select(
              dbExecutor.wallets,
            )..where((w) => w.id.equals(walletId))).getSingle();
            final walletRepo = await (dbRepo.select(
              dbRepo.wallets,
            )..where((w) => w.id.equals(walletId))).getSingle();

            // Both should produce the same balance delta from the same initial balance
            final deltaExecutor = walletExecutor.balance - initialBalance;
            final deltaRepo = walletRepo.balance - initialBalance;

            expect(
              deltaExecutor,
              closeTo(deltaRepo, 0.001),
              reason:
                  'Expense balance delta mismatch: executor=$deltaExecutor, repo=$deltaRepo '
                  '(initial=$initialBalance, amount=$amount)',
            );

            // Also verify the absolute balance is correct
            expect(
              walletExecutor.balance,
              closeTo(initialBalance - amount, 0.001),
              reason: 'Executor balance should be initialBalance - amount',
            );
            expect(
              walletRepo.balance,
              closeTo(initialBalance - amount, 0.001),
              reason: 'Repo balance should be initialBalance - amount',
            );
          } finally {
            await dbExecutor.close();
            await dbRepo.close();
          }
        },
      );

      // --- Transfer equivalence (database-level comparison) ---
      // Note: RecurringExecutor does not currently support transfer-type recurring
      // transactions (throws StateError). This test validates the balance adjustment
      // logic at the database level, comparing what the executor WOULD do for
      // transfers with what TransactionRepository does.
      Glados2(
        any.doubleInRange(0, 100000), // initial source balance
        any.doubleInRange(0.01, 50000), // positive transaction amount
      ).test(
        'transfer: database-level balance adjustment matches TransactionRepository',
        (initialSourceBalance, amount) async {
          final initialDestBalance = initialSourceBalance * 0.5;

          // Database 1: Replicate executor transfer logic at DB level
          final dbExecutor = _createTestDb();
          // Database 2: TransactionRepository path
          final dbRepo = _createTestDb();

          try {
            const sourceWalletId = 'wallet-source';
            const destWalletId = 'wallet-dest';
            const categoryId = 'cat-transfer';

            // --- Set up identical databases ---
            await _seedWallet(
              dbExecutor,
              walletId: sourceWalletId,
              initialBalance: initialSourceBalance,
            );
            await _seedWallet(
              dbExecutor,
              walletId: destWalletId,
              initialBalance: initialDestBalance,
            );
            await _seedCategory(dbExecutor, categoryId: categoryId);

            await _seedWallet(
              dbRepo,
              walletId: sourceWalletId,
              initialBalance: initialSourceBalance,
            );
            await _seedWallet(
              dbRepo,
              walletId: destWalletId,
              initialBalance: initialDestBalance,
            );
            await _seedCategory(dbRepo, categoryId: categoryId);

            // --- Execute via executor-equivalent DB logic ---
            // Replicates what _createTransactionWithBalanceUpdate would do for
            // transfers if it were fully implemented (decrease source, increase dest)
            await dbExecutor.transaction(() async {
              await dbExecutor
                  .into(dbExecutor.transactions)
                  .insert(
                    TransactionsCompanion.insert(
                      userId: 'test-user',
                      walletId: const Value(sourceWalletId),
                      fromWalletId: const Value(sourceWalletId),
                      toWalletId: const Value(destWalletId),
                      categoryId: const Value(categoryId),
                      amount: amount,
                      date: DateTime(2024, 1, 15),
                      type: 'transfer',
                    ),
                  );

              // Decrease source wallet
              final sourceWallet = await (dbExecutor.select(
                dbExecutor.wallets,
              )..where((w) => w.id.equals(sourceWalletId))).getSingle();
              await (dbExecutor.update(
                dbExecutor.wallets,
              )..where((w) => w.id.equals(sourceWalletId))).write(
                WalletsCompanion(balance: Value(sourceWallet.balance - amount)),
              );

              // Increase destination wallet
              final destWallet = await (dbExecutor.select(
                dbExecutor.wallets,
              )..where((w) => w.id.equals(destWalletId))).getSingle();
              await (dbExecutor.update(
                dbExecutor.wallets,
              )..where((w) => w.id.equals(destWalletId))).write(
                WalletsCompanion(balance: Value(destWallet.balance + amount)),
              );
            });

            // --- Execute via TransactionRepository ---
            final repo = TransactionRepository(dbRepo);
            final transaction = TransactionModel(
              userId: 'test-user',
              amount: amount,
              category: 'Test Category',
              type: 'transfer',
              notes: '',
              createdAt: DateTime(2024, 1, 15),
              fromWalletId: sourceWalletId,
              toWalletId: destWalletId,
            );
            await repo.insertTransaction(transaction);

            // --- Compare wallet balances ---
            final sourceExecutor = await (dbExecutor.select(
              dbExecutor.wallets,
            )..where((w) => w.id.equals(sourceWalletId))).getSingle();
            final destExecutor = await (dbExecutor.select(
              dbExecutor.wallets,
            )..where((w) => w.id.equals(destWalletId))).getSingle();

            final sourceRepo = await (dbRepo.select(
              dbRepo.wallets,
            )..where((w) => w.id.equals(sourceWalletId))).getSingle();
            final destRepo = await (dbRepo.select(
              dbRepo.wallets,
            )..where((w) => w.id.equals(destWalletId))).getSingle();

            // Source wallet delta should be identical
            final sourceDeltaExecutor =
                sourceExecutor.balance - initialSourceBalance;
            final sourceDeltaRepo = sourceRepo.balance - initialSourceBalance;

            expect(
              sourceDeltaExecutor,
              closeTo(sourceDeltaRepo, 0.001),
              reason:
                  'Transfer source delta mismatch: executor=$sourceDeltaExecutor, '
                  'repo=$sourceDeltaRepo (initial=$initialSourceBalance, amount=$amount)',
            );

            // Destination wallet delta should be identical
            final destDeltaExecutor = destExecutor.balance - initialDestBalance;
            final destDeltaRepo = destRepo.balance - initialDestBalance;

            expect(
              destDeltaExecutor,
              closeTo(destDeltaRepo, 0.001),
              reason:
                  'Transfer dest delta mismatch: executor=$destDeltaExecutor, '
                  'repo=$destDeltaRepo (initial=$initialDestBalance, amount=$amount)',
            );
          } finally {
            await dbExecutor.close();
            await dbRepo.close();
          }
        },
      );
    },
  );
}
