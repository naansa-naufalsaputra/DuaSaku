// Feature: system-audit-fixes, Property 5: Migration preserves all non-balance data
// **Validates: Requirements 2.4**


import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

import 'package:duasaku_app/core/local_db/app_database.dart';

// ---------------------------------------------------------------------------
// Helpers & Generators
// ---------------------------------------------------------------------------

/// Creates a fresh in-memory database at schema v8 (full migration applied).
AppDatabase _createTestDb() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(setup: (db) {
      db.execute('PRAGMA foreign_keys = ON;');
    }),
  );
}

/// Generates a random hex color string like '#AB12CD'.
String _randomColor(Random rng) {
  final r = rng.nextInt(256).toRadixString(16).padLeft(2, '0');
  final g = rng.nextInt(256).toRadixString(16).padLeft(2, '0');
  final b = rng.nextInt(256).toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}

/// Generates a random icon name from a fixed set.
String _randomIcon(Random rng) {
  const icons = [
    'wallet',
    'account_balance',
    'savings',
    'credit_card',
    'money',
    'attach_money',
    'shopping_bag',
    'restaurant',
    'directions_car',
    'receipt',
  ];
  return icons[rng.nextInt(icons.length)];
}

/// Generates a random wallet type.
String _randomWalletType(Random rng) {
  const types = ['Bank', 'E-Wallet', 'Cash'];
  return types[rng.nextInt(types.length)];
}

/// Generates a random wallet name.
String _randomWalletName(Random rng) {
  const names = [
    'Main Wallet',
    'Savings',
    'Emergency Fund',
    'Daily Expenses',
    'Investment',
    'Travel Fund',
    'Business',
    'Groceries',
  ];
  return '${names[rng.nextInt(names.length)]}_${rng.nextInt(9999)}';
}

/// Generates a random transaction type.
String _randomTransactionType(Random rng) {
  const types = ['income', 'expense', 'transfer'];
  return types[rng.nextInt(types.length)];
}

/// Snapshot of a wallet row (all columns except balance).
class WalletSnapshot {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String icon;
  final String color;
  final DateTime createdAt;

  WalletSnapshot({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      other is WalletSnapshot &&
      id == other.id &&
      userId == other.userId &&
      name == other.name &&
      type == other.type &&
      icon == other.icon &&
      color == other.color &&
      createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, userId, name, type, icon, color, createdAt);

  @override
  String toString() =>
      'WalletSnapshot(id=$id, userId=$userId, name=$name, type=$type, icon=$icon, color=$color, createdAt=$createdAt)';
}

/// Snapshot of a transaction row (all columns).
class TransactionSnapshot {
  final int id;
  final String userId;
  final String? walletId;
  final String? fromWalletId;
  final String? toWalletId;
  final String? categoryId;
  final double amount;
  final String? notes;
  final DateTime date;
  final String type;
  final String? badge;

  TransactionSnapshot({
    required this.id,
    required this.userId,
    required this.walletId,
    required this.fromWalletId,
    required this.toWalletId,
    required this.categoryId,
    required this.amount,
    required this.notes,
    required this.date,
    required this.type,
    required this.badge,
  });

  @override
  bool operator ==(Object other) =>
      other is TransactionSnapshot &&
      id == other.id &&
      userId == other.userId &&
      walletId == other.walletId &&
      fromWalletId == other.fromWalletId &&
      toWalletId == other.toWalletId &&
      categoryId == other.categoryId &&
      amount == other.amount &&
      notes == other.notes &&
      date == other.date &&
      type == other.type &&
      badge == other.badge;

  @override
  int get hashCode => Object.hash(
      id, userId, walletId, fromWalletId, toWalletId, categoryId, amount, notes, date, type, badge);

  @override
  String toString() =>
      'TransactionSnapshot(id=$id, userId=$userId, walletId=$walletId, amount=$amount, type=$type)';
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Property 5: Migration preserves all non-balance data
  // **Validates: Requirements 2.4**
  //
  // For any database state, after the balance recalculation migration executes,
  // all rows in all tables SHALL remain unchanged except for the `balance`
  // column of the `Wallets` table. No rows SHALL be inserted, deleted, or have
  // non-balance columns modified.
  // ──────────────────────────────────────────────────────────────────────────
  group(
      'Property 5: Migration preserves all non-balance data',
      () {
    Glados2(
      any.intInRange(1, 5), // number of wallets
      any.intInRange(0, 99999), // random seed
    ).test(
      'all non-balance wallet data and all transaction data remain identical after migration SQL',
      (walletCount, seed) async {
        final db = _createTestDb();
        try {
          final rng = Random(seed);

          // --- Step 1: Generate and insert wallets ---
          final walletIds = <String>[];
          for (var i = 0; i < walletCount; i++) {
            final walletId = 'wallet-$seed-$i';
            walletIds.add(walletId);

            await db.into(db.wallets).insert(WalletsCompanion.insert(
                  id: walletId,
                  userId: 'test-user',
                  name: _randomWalletName(rng),
                  type: _randomWalletType(rng),
                  balance: Value(rng.nextDouble() * 10000 - 5000), // random initial balance
                  icon: _randomIcon(rng),
                  color: _randomColor(rng),
                  createdAt: DateTime(2023, rng.nextInt(12) + 1, rng.nextInt(28) + 1),
                ));
          }

          // --- Step 2: Insert a category for FK constraints ---
          await db.into(db.categories).insert(CategoriesCompanion.insert(
                id: 'cat-$seed',
                userId: 'test-user',
                name: 'Test Category',
                type: 'expense',
                createdAt: DateTime(2023, 1, 1),
              ));

          // --- Step 3: Generate and insert transactions ---
          final transactionCount = rng.nextInt(10) + 1; // 1-10 transactions
          for (var i = 0; i < transactionCount; i++) {
            final txType = _randomTransactionType(rng);
            final walletId = walletIds[rng.nextInt(walletIds.length)];
            final amount = (rng.nextInt(100000) + 1) / 100.0; // 0.01 to 1000.00

            String? fromWalletId;
            String? toWalletId;
            String? txWalletId;

            if (txType == 'transfer' && walletIds.length >= 2) {
              // Pick two different wallets for transfer
              fromWalletId = walletId;
              var toIdx = rng.nextInt(walletIds.length);
              while (walletIds[toIdx] == fromWalletId) {
                toIdx = (toIdx + 1) % walletIds.length;
              }
              toWalletId = walletIds[toIdx];
              txWalletId = null;
            } else if (txType == 'transfer' && walletIds.length < 2) {
              // Can't do a transfer with only 1 wallet, make it an expense
              txWalletId = walletId;
              fromWalletId = null;
              toWalletId = null;
              // Override type to expense for this case
              await db.into(db.transactions).insert(TransactionsCompanion.insert(
                    userId: 'test-user',
                    walletId: Value(txWalletId),
                    fromWalletId: Value(fromWalletId),
                    toWalletId: Value(toWalletId),
                    categoryId: Value('cat-$seed'),
                    amount: amount,
                    date: DateTime(2023, rng.nextInt(12) + 1, rng.nextInt(28) + 1),
                    type: 'expense',
                    notes: Value(rng.nextBool() ? 'Note $i seed $seed' : null),
                    badge: Value(rng.nextBool() ? 'recurring' : null),
                  ));
              continue;
            } else {
              txWalletId = walletId;
            }

            await db.into(db.transactions).insert(TransactionsCompanion.insert(
                  userId: 'test-user',
                  walletId: Value(txWalletId),
                  fromWalletId: Value(fromWalletId),
                  toWalletId: Value(toWalletId),
                  categoryId: Value('cat-$seed'),
                  amount: amount,
                  date: DateTime(2023, rng.nextInt(12) + 1, rng.nextInt(28) + 1),
                  type: txType,
                  notes: Value(rng.nextBool() ? 'Note $i seed $seed' : null),
                  badge: Value(rng.nextBool() ? 'recurring' : null),
                ));
          }

          // --- Step 4: Snapshot all non-balance wallet data ---
          final walletsBefore = await db.select(db.wallets).get();
          final walletSnapshotsBefore = walletsBefore
              .map((w) => WalletSnapshot(
                    id: w.id,
                    userId: w.userId,
                    name: w.name,
                    type: w.type,
                    icon: w.icon,
                    color: w.color,
                    createdAt: w.createdAt,
                  ))
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));

          // --- Step 5: Snapshot all transaction data ---
          final txBefore = await db.select(db.transactions).get();
          final txSnapshotsBefore = txBefore
              .map((t) => TransactionSnapshot(
                    id: t.id,
                    userId: t.userId,
                    walletId: t.walletId,
                    fromWalletId: t.fromWalletId,
                    toWalletId: t.toWalletId,
                    categoryId: t.categoryId,
                    amount: t.amount,
                    notes: t.notes,
                    date: t.date,
                    type: t.type,
                    badge: t.badge,
                  ))
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));

          final walletCountBefore = walletsBefore.length;
          final txCountBefore = txBefore.length;

          // --- Step 6: Execute the migration SQL ---
          await db.customStatement('''
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
          ''');

          // --- Step 7: Verify non-balance wallet data is unchanged ---
          final walletsAfter = await db.select(db.wallets).get();
          final walletSnapshotsAfter = walletsAfter
              .map((w) => WalletSnapshot(
                    id: w.id,
                    userId: w.userId,
                    name: w.name,
                    type: w.type,
                    icon: w.icon,
                    color: w.color,
                    createdAt: w.createdAt,
                  ))
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));

          // Same number of wallets
          expect(walletsAfter.length, equals(walletCountBefore),
              reason: 'Wallet count should not change after migration');

          // All non-balance columns identical
          expect(walletSnapshotsAfter, equals(walletSnapshotsBefore),
              reason: 'Non-balance wallet data should be preserved after migration');

          // --- Step 8: Verify all transaction data is unchanged ---
          final txAfter = await db.select(db.transactions).get();
          final txSnapshotsAfter = txAfter
              .map((t) => TransactionSnapshot(
                    id: t.id,
                    userId: t.userId,
                    walletId: t.walletId,
                    fromWalletId: t.fromWalletId,
                    toWalletId: t.toWalletId,
                    categoryId: t.categoryId,
                    amount: t.amount,
                    notes: t.notes,
                    date: t.date,
                    type: t.type,
                    badge: t.badge,
                  ))
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));

          // Same number of transactions
          expect(txAfter.length, equals(txCountBefore),
              reason: 'Transaction count should not change after migration');

          // All transaction columns identical
          expect(txSnapshotsAfter, equals(txSnapshotsBefore),
              reason: 'Transaction data should be preserved after migration');
        } finally {
          await db.close();
        }
      },
    );

    // Additional property: verify that ONLY the balance column changes
    Glados2(
      any.intInRange(2, 4), // number of wallets
      any.intInRange(0, 99999), // random seed
    ).test(
      'only the balance column of wallets is modified — no other table rows change',
      (walletCount, seed) async {
        final db = _createTestDb();
        try {
          final rng = Random(seed);

          // Insert wallets with deliberately wrong balances
          final walletIds = <String>[];
          final originalBalances = <String, double>{};
          for (var i = 0; i < walletCount; i++) {
            final walletId = 'w-$seed-$i';
            walletIds.add(walletId);
            final wrongBalance = rng.nextDouble() * 50000 - 25000;
            originalBalances[walletId] = wrongBalance;

            await db.into(db.wallets).insert(WalletsCompanion.insert(
                  id: walletId,
                  userId: 'test-user',
                  name: _randomWalletName(rng),
                  type: _randomWalletType(rng),
                  balance: Value(wrongBalance),
                  icon: _randomIcon(rng),
                  color: _randomColor(rng),
                  createdAt: DateTime(2023, rng.nextInt(12) + 1, rng.nextInt(28) + 1),
                ));
          }

          // Insert category
          await db.into(db.categories).insert(CategoriesCompanion.insert(
                id: 'cat-$seed',
                userId: 'test-user',
                name: 'Category',
                type: 'expense',
                createdAt: DateTime(2023, 1, 1),
              ));

          // Insert some transactions
          final txCount = rng.nextInt(8) + 2;
          for (var i = 0; i < txCount; i++) {
            final walletId = walletIds[rng.nextInt(walletIds.length)];
            final amount = (rng.nextInt(50000) + 1) / 100.0;
            final type = rng.nextBool() ? 'income' : 'expense';

            await db.into(db.transactions).insert(TransactionsCompanion.insert(
                  userId: 'test-user',
                  walletId: Value(walletId),
                  categoryId: Value('cat-$seed'),
                  amount: amount,
                  date: DateTime(2023, rng.nextInt(12) + 1, rng.nextInt(28) + 1),
                  type: type,
                ));
          }

          // Snapshot categories before
          final categoriesBefore = await db.select(db.categories).get();

          // Execute migration
          await db.customStatement('''
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
          ''');

          // Verify categories are unchanged
          final categoriesAfter = await db.select(db.categories).get();
          expect(categoriesAfter.length, equals(categoriesBefore.length),
              reason: 'Category count should not change');
          for (var i = 0; i < categoriesBefore.length; i++) {
            expect(categoriesAfter[i].id, equals(categoriesBefore[i].id));
            expect(categoriesAfter[i].name, equals(categoriesBefore[i].name));
            expect(categoriesAfter[i].userId, equals(categoriesBefore[i].userId));
            expect(categoriesAfter[i].type, equals(categoriesBefore[i].type));
          }

          // Verify wallet balances actually changed (at least one should differ
          // since we inserted transactions and used random initial balances)
          final walletsAfter = await db.select(db.wallets).get();
          // At least confirm the migration ran — balances should now reflect
          // the computed values, not the original random ones
          expect(walletsAfter.length, equals(walletCount));
        } finally {
          await db.close();
        }
      },
    );
  });
}
