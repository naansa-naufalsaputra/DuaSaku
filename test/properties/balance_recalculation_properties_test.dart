// Feature: system-audit-fixes, Property 4: Balance recalculation formula correctness
// **Validates: Requirements 2.1, 2.3**

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

import 'package:duasaku_app/core/local_db/app_database.dart';

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

/// The migration SQL that recalculates wallet balances.
/// This is the exact SQL from the schema v8 migration in app_database.dart.
const String _balanceRecalcSql = '''
  UPDATE wallets SET balance = (
    SELECT COALESCE(
      (SELECT SUM(amount) FROM transactions
       WHERE type = 'income' AND wallet_id = wallets.id), 0)
      -
      COALESCE(
      (SELECT SUM(amount) FROM transactions
       WHERE type = 'expense' AND wallet_id = wallets.id), 0)
      +
      COALESCE(
      (SELECT SUM(amount) FROM transactions
       WHERE type = 'transfer' AND to_wallet_id = wallets.id), 0)
      -
      COALESCE(
      (SELECT SUM(amount) FROM transactions
       WHERE type = 'transfer' AND from_wallet_id = wallets.id), 0)
  )
''';

/// Generates a random transaction type.
String _randomTxType(Random rng) {
  const types = ['income', 'expense', 'transfer'];
  return types[rng.nextInt(types.length)];
}

/// Computes the expected balance for a wallet based on the formula:
/// SUM(income to wallet) - SUM(expense from wallet)
/// + SUM(transfers into wallet) - SUM(transfers out of wallet)
double _computeExpectedBalance(String walletId, List<_TestTx> transactions) {
  double balance = 0.0;

  for (final tx in transactions) {
    if (tx.type == 'income' && tx.walletId == walletId) {
      balance += tx.amount;
    } else if (tx.type == 'expense' && tx.walletId == walletId) {
      balance -= tx.amount;
    } else if (tx.type == 'transfer') {
      if (tx.toWalletId == walletId) {
        balance += tx.amount;
      }
      if (tx.fromWalletId == walletId) {
        balance -= tx.amount;
      }
    }
  }

  return balance;
}

/// Internal representation of a test transaction.
class _TestTx {
  final String type;
  final double amount;
  final String? walletId;
  final String? fromWalletId;
  final String? toWalletId;

  _TestTx({
    required this.type,
    required this.amount,
    this.walletId,
    this.fromWalletId,
    this.toWalletId,
  });
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Property 4: Balance recalculation formula correctness
  // **Validates: Requirements 2.1, 2.3**
  //
  // For any set of wallets and for any transaction history containing income,
  // expense, and transfer transactions, after the balance recalculation
  // migration executes, each wallet's balance SHALL equal:
  // SUM(income to wallet) - SUM(expense from wallet)
  // + SUM(transfers into wallet) - SUM(transfers out of wallet)
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 4: Balance recalculation formula correctness', () {
    Glados2(
      any.intInRange(1, 5), // number of wallets
      any.intInRange(0, 99999), // random seed for scenario generation
    ).test(
      'after migration SQL, each wallet balance equals SUM(income) - SUM(expense) + SUM(transfers in) - SUM(transfers out)',
      (walletCount, seed) async {
        final db = _createTestDb();
        try {
          final rng = Random(seed);

          // --- Step 1: Generate and insert wallets with arbitrary initial balances ---
          final walletIds = <String>[];
          for (var i = 0; i < walletCount; i++) {
            final walletId = 'wallet-$seed-$i';
            walletIds.add(walletId);

            // Arbitrary initial balance (should be overwritten by migration)
            final initialBalance = rng.nextDouble() * 20000 - 10000;

            await db
                .into(db.wallets)
                .insert(
                  WalletsCompanion.insert(
                    id: walletId,
                    userId: 'test-user',
                    name: 'Wallet $i',
                    type: 'Cash',
                    balance: Value(initialBalance),
                    icon: 'wallet',
                    color: '#000000',
                    createdAt: DateTime(2024, 1, 1),
                  ),
                );
          }

          // --- Step 2: Generate and insert random transactions ---
          final txCount = rng.nextInt(15) + 1; // 1-15 transactions
          final testTransactions = <_TestTx>[];

          for (var i = 0; i < txCount; i++) {
            final txType = _randomTxType(rng);
            // Amount: positive value between 1.0 and 5000.0
            final amount = (rng.nextInt(500000) + 100) / 100.0;

            String? walletId;
            String? fromWalletId;
            String? toWalletId;

            if (txType == 'transfer' && walletIds.length >= 2) {
              // Pick two different wallets for transfer
              final fromIdx = rng.nextInt(walletIds.length);
              var toIdx = rng.nextInt(walletIds.length);
              while (toIdx == fromIdx) {
                toIdx = (toIdx + 1) % walletIds.length;
              }
              fromWalletId = walletIds[fromIdx];
              toWalletId = walletIds[toIdx];
            } else if (txType == 'transfer' && walletIds.length < 2) {
              // Can't do transfer with 1 wallet, fall back to income
              walletId = walletIds[0];
              testTransactions.add(
                _TestTx(type: 'income', amount: amount, walletId: walletId),
              );
              await db
                  .into(db.transactions)
                  .insert(
                    TransactionsCompanion.insert(
                      userId: 'test-user',
                      walletId: Value(walletId),
                      amount: amount,
                      date: DateTime(2024, 1, i + 1),
                      type: 'income',
                    ),
                  );
              continue;
            } else {
              // income or expense
              walletId = walletIds[rng.nextInt(walletIds.length)];
            }

            testTransactions.add(
              _TestTx(
                type: txType,
                amount: amount,
                walletId: walletId,
                fromWalletId: fromWalletId,
                toWalletId: toWalletId,
              ),
            );

            await db
                .into(db.transactions)
                .insert(
                  TransactionsCompanion.insert(
                    userId: 'test-user',
                    walletId: Value(walletId),
                    fromWalletId: Value(fromWalletId),
                    toWalletId: Value(toWalletId),
                    amount: amount,
                    date: DateTime(2024, 1, i + 1),
                    type: txType,
                  ),
                );
          }

          // --- Step 3: Execute the migration SQL ---
          await db.customStatement(_balanceRecalcSql);

          // --- Step 4: Verify each wallet's balance matches the expected formula ---
          for (final walletId in walletIds) {
            final wallet = await (db.select(
              db.wallets,
            )..where((w) => w.id.equals(walletId))).getSingle();

            final expectedBalance = _computeExpectedBalance(
              walletId,
              testTransactions,
            );

            expect(
              wallet.balance,
              closeTo(expectedBalance, 0.01),
              reason:
                  'Wallet $walletId: expected $expectedBalance but got ${wallet.balance}. '
                  'Transactions: ${testTransactions.length}',
            );
          }
        } finally {
          await db.close();
        }
      },
    );

    // Edge case: wallets with zero transactions get balance set to zero
    // (Validates Requirement 2.3)
    Glados(
      any.intInRange(1, 5),
      ExploreConfig(numRuns: 100),
    ).test('wallets with zero transactions get balance set to zero', (
      walletCount,
    ) async {
      final db = _createTestDb();
      try {
        // Insert wallets with non-zero initial balances
        for (var i = 0; i < walletCount; i++) {
          await db
              .into(db.wallets)
              .insert(
                WalletsCompanion.insert(
                  id: 'wallet-empty-$i',
                  userId: 'test-user',
                  name: 'Empty Wallet $i',
                  type: 'Cash',
                  balance: Value((i + 1) * 1000.0),
                  icon: 'wallet',
                  color: '#000000',
                  createdAt: DateTime(2024, 1, 1),
                ),
              );
        }

        // No transactions inserted

        // Execute the migration SQL
        await db.customStatement(_balanceRecalcSql);

        // Verify all wallets have balance = 0
        final wallets = await db.select(db.wallets).get();
        for (final wallet in wallets) {
          expect(
            wallet.balance,
            closeTo(0.0, 0.001),
            reason:
                'Wallet ${wallet.id} should have balance 0 with no transactions, '
                'but got ${wallet.balance}',
          );
        }
      } finally {
        await db.close();
      }
    });
  });
}
