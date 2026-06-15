import 'dart:math';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/features/wallets/data/wallet_repository.dart';
import 'package:duasaku_app/features/wallets/domain/models/wallet_model.dart';
import 'package:duasaku_app/features/transactions/data/transaction_repository.dart';
import 'package:duasaku_app/features/transactions/domain/models/transaction_model.dart';
import 'package:duasaku_app/core/utils/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('SQLite Database Stress & Reliability Tests', () {
    late AppDatabase db;
    late WalletRepository walletRepo;
    late TransactionRepository txRepo;
    final rng = Random();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      walletRepo = WalletRepository(db);
      txRepo = TransactionRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Stress Test: 1000 Concurrent Transactions & Balance Consistency', () async {
      const numWallets = 5;
      const transactionsPerWallet = 200; // Total 1000 transactions
      final walletIds = <String>[];
      final expectedBalances = <String, double>{};

      // 1. Setup Wallets
      for (int i = 0; i < numWallets; i++) {
        final walletId = 'wallet_$i';
        walletIds.add(walletId);
        expectedBalances[walletId] = 0.0;

        final wallet = WalletModel(
          id: walletId,
          userId: 'stress_user',
          name: 'Wallet $i',
          type: 'Bank',
          balance: 0.0,
          createdAt: DateTime.now(),
        );
        final result = await walletRepo.createWallet(wallet);
        expect(result, isA<Success>());
      }

      // 2. Setup Category
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: 'cat_stress',
          userId: 'stress_user',
          name: 'Salary',
          type: 'income',
          createdAt: DateTime.now(),
        ),
      );

      // 3. Generate 1000 transactions concurrently
      final futures = <Future<Result<void, dynamic>>>[];
      for (int w = 0; w < numWallets; w++) {
        final walletId = walletIds[w];
        for (int t = 0; t < transactionsPerWallet; t++) {
          final isIncome = rng.nextBool();
          final amount = (rng.nextInt(1000) + 1).toDouble();
          
          if (isIncome) {
            expectedBalances[walletId] = expectedBalances[walletId]! + amount;
          } else {
            expectedBalances[walletId] = expectedBalances[walletId]! - amount;
          }

          final tx = TransactionModel(
            userId: 'stress_user',
            amount: amount,
            category: 'Salary',
            type: isIncome ? 'income' : 'expense',
            notes: 'Concurrent Stress Tx $t',
            walletId: walletId,
            createdAt: DateTime.now().add(Duration(milliseconds: t)),
          );

          futures.add(txRepo.insertTransaction(tx));
        }
      }

      // Execute all 1000 transactions concurrently in Dart
      final results = await Future.wait(futures);

      // Verify all transactions completed successfully
      for (final result in results) {
        expect(result, isA<Success>(), reason: 'Concurrent transaction insertion failed');
      }

      // 4. Verify wallet balances exactly match calculated expected values
      for (final walletId in walletIds) {
        final getResult = await db.select(db.wallets).get();
        final dbWallet = getResult.firstWhere((w) => w.id == walletId);
        expect(
          dbWallet.balance,
          equals(expectedBalances[walletId]),
          reason: 'Database balance mismatch for wallet $walletId after 200 operations',
        );
      }

      // Verify transaction table has exactly 1000 rows
      final txCountQuery = await db.select(db.transactions).get();
      expect(txCountQuery.length, equals(1000));
    });

    test('Reliability Test: Transaction Rollback on Error', () async {
      // 1. Setup Wallet with initial 500.0 balance
      const walletId = 'wallet_rollback';
      final wallet = WalletModel(
        id: walletId,
        userId: 'stress_user',
        name: 'Rollback Wallet',
        type: 'Bank',
        balance: 500.0,
        createdAt: DateTime.now(),
      );
      await walletRepo.createWallet(wallet);

      // 2. Setup Category
      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: 'cat_rollback',
          userId: 'stress_user',
          name: 'Food',
          type: 'expense',
          createdAt: DateTime.now(),
        ),
      );

      // 3. Attempt a failing transaction block
      // We will perform a manually controlled transaction that throws midway.
      try {
        await db.transaction(() async {
          // Update wallet balance to 300.0
          await (db.update(db.wallets)..where((w) => w.id.equals(walletId))).write(
            const WalletsCompanion(balance: Value(300.0)),
          );

          // Insert valid transaction row
          await db.into(db.transactions).insert(
            TransactionsCompanion.insert(
              userId: 'stress_user',
              walletId: const Value(walletId),
              categoryId: const Value('cat_rollback'),
              amount: 200.0,
              date: DateTime.now(),
              type: 'expense',
            ),
          );

          // Force failure
          throw Exception('Simulated crash during transaction block');
        });
      } catch (_) {
        // Exception caught, let's verify if changes were rolled back
      }

      // 4. Verify wallet balance remains 500.0
      final dbWallet = await (db.select(db.wallets)..where((w) => w.id.equals(walletId))).getSingle();
      expect(dbWallet.balance, equals(500.0), reason: 'Wallet balance was NOT rolled back after transaction crash');

      // Verify no transaction was written
      final txRows = await db.select(db.transactions).get();
      expect(txRows.length, equals(0), reason: 'Transaction table was NOT rolled back after transaction crash');
    });
  });
}
