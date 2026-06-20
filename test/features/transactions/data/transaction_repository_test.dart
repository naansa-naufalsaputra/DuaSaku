import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/features/transactions/data/transaction_repository.dart';
import 'package:duasaku_app/features/transactions/domain/models/transaction_model.dart';
import 'package:duasaku_app/core/utils/result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late TransactionRepository repository;

  const String userId = 'local_user';
  const String walletId = 'wallet-1';
  const String toWalletId = 'wallet-2';
  const String categoryId = 'category-food';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepository(db);

    // Seed Category
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: categoryId,
            userId: userId,
            name: 'Food',
            type: 'expense',
            icon: const Value('restaurant'),
            color: const Value('#FF5722'),
            createdAt: DateTime.now(),
          ),
        );

    // Seed Wallet 1
    await db
        .into(db.wallets)
        .insert(
          WalletsCompanion.insert(
            id: walletId,
            userId: userId,
            name: 'Cash',
            type: 'cash',
            icon: 'wallet',
            color: '#000000',
            balance: const Value(1000.0),
            createdAt: DateTime.now(),
          ),
        );

    // Seed Wallet 2
    await db
        .into(db.wallets)
        .insert(
          WalletsCompanion.insert(
            id: toWalletId,
            userId: userId,
            name: 'Bank',
            type: 'bank',
            icon: 'wallet',
            color: '#000000',
            balance: const Value(500.0),
            createdAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionRepository Unit Tests', () {
    test('insertTransaction - expense deducts from wallet balance', () async {
      final tx = TransactionModel(
        userId: userId,
        amount: 200.0,
        categoryId: categoryId,
        type: 'expense',
        notes: 'Makan siang',
        walletId: walletId,
        createdAt: DateTime.now(),
      );

      final result = await repository.insertTransaction(tx);
      expect(result, isA<Success<void, dynamic>>());

      final wallet = await (db.select(
        db.wallets,
      )..where((w) => w.id.equals(walletId))).getSingle();
      expect(wallet.balance, equals(800.0)); // 1000 - 200
    });

    test('insertTransaction - income adds to wallet balance', () async {
      final tx = TransactionModel(
        userId: userId,
        amount: 300.0,
        categoryId: categoryId,
        type: 'income',
        notes: 'Bonus',
        walletId: walletId,
        createdAt: DateTime.now(),
      );

      final result = await repository.insertTransaction(tx);
      expect(result, isA<Success<void, dynamic>>());

      final wallet = await (db.select(
        db.wallets,
      )..where((w) => w.id.equals(walletId))).getSingle();
      expect(wallet.balance, equals(1300.0)); // 1000 + 300
    });

    test(
      'insertTransaction - transfer moves amount from wallet to wallet',
      () async {
        final tx = TransactionModel(
          userId: userId,
          amount: 100.0,
          categoryId: categoryId,
          type: 'transfer',
          notes: 'Pindah saldo',
          fromWalletId: walletId,
          toWalletId: toWalletId,
          createdAt: DateTime.now(),
        );

        final result = await repository.insertTransaction(tx);
        expect(result, isA<Success<void, dynamic>>());

        final source = await (db.select(
          db.wallets,
        )..where((w) => w.id.equals(walletId))).getSingle();
        final destination = await (db.select(
          db.wallets,
        )..where((w) => w.id.equals(toWalletId))).getSingle();

        expect(source.balance, equals(900.0)); // 1000 - 100
        expect(destination.balance, equals(600.0)); // 500 + 100
      },
    );

    test('deleteTransaction - expense reverts balance (adds back)', () async {
      // 1. Insert transaction
      final tx = TransactionModel(
        userId: userId,
        amount: 200.0,
        categoryId: categoryId,
        type: 'expense',
        notes: 'Makan siang',
        walletId: walletId,
        createdAt: DateTime.now(),
      );
      await repository.insertTransaction(tx);

      // Verify intermediate balance
      var wallet = await (db.select(
        db.wallets,
      )..where((w) => w.id.equals(walletId))).getSingle();
      expect(wallet.balance, equals(800.0));

      // 2. Fetch transaction id to delete it
      final insertedTx = await db.select(db.transactions).getSingle();

      // 3. Delete transaction
      final result = await repository.deleteTransaction(insertedTx.id);
      expect(result, isA<Success<void, dynamic>>());

      // 4. Verify balance is restored
      wallet = await (db.select(
        db.wallets,
      )..where((w) => w.id.equals(walletId))).getSingle();
      expect(wallet.balance, equals(1000.0));
    });

    test('updateTransaction - correctly reverts and applies changes', () async {
      // 1. Insert transaction
      final oldTx = TransactionModel(
        userId: userId,
        amount: 200.0,
        categoryId: categoryId,
        type: 'expense',
        notes: 'Makan siang',
        walletId: walletId,
        createdAt: DateTime.now(),
      );
      await repository.insertTransaction(oldTx);

      // Retrieve inserted transaction with ID
      final insertedTxRow = await db.select(db.transactions).getSingle();
      final oldTxWithId = oldTx.copyWith(id: insertedTxRow.id);

      // 2. Prepare new transaction with updated values
      final newTx = oldTxWithId.copyWith(
        amount: 400.0, // increased amount
        notes: 'Makan siang mewah',
      );

      // 3. Perform update
      final result = await repository.updateTransaction(newTx, oldTxWithId);
      expect(result, isA<Success<void, dynamic>>());

      // 4. Verify updated details
      final updatedTxRow = await db.select(db.transactions).getSingle();
      expect(updatedTxRow.amount, equals(400.0));
      expect(updatedTxRow.notes, equals('Makan siang mewah'));

      // 5. Verify balance adjustment: Revert old (-200) -> 1000, apply new (-400) -> 600
      final wallet = await (db.select(
        db.wallets,
      )..where((w) => w.id.equals(walletId))).getSingle();
      expect(wallet.balance, equals(600.0));
    });

    test('insertTransaction - resolves category by name and case-insensitive ID', () async {
      const String customCatId = 'custom-ent';
      const String customCatName = 'Entertainment';

      // Seed unique custom category
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: customCatId,
              userId: userId,
              name: customCatName,
              type: 'expense',
              icon: const Value('movie'),
              color: const Value('#9C27B0'),
              createdAt: DateTime.now(),
            ),
          );

      // Test category name resolution ('Entertainment')
      final txByName = TransactionModel(
        userId: userId,
        amount: 100.0,
        categoryId: customCatName, // This matches c.name
        type: 'expense',
        notes: 'Test name resolution',
        walletId: walletId,
        createdAt: DateTime.now(),
      );

      final result1 = await repository.insertTransaction(txByName);
      expect(result1, isA<Success<void, dynamic>>());

      final insertedTx1 = await (db.select(db.transactions)
            ..where((t) => t.notes.equals('Test name resolution')))
          .getSingle();
      expect(insertedTx1.categoryId, equals(customCatId));

      // Test category ID case-insensitive resolution ('CUSTOM-ENT')
      final txByLowerId = TransactionModel(
        userId: userId,
        amount: 100.0,
        categoryId: 'CUSTOM-ENT', // This matches c.id when lowercased
        type: 'expense',
        notes: 'Test ID lowercase resolution',
        walletId: walletId,
        createdAt: DateTime.now(),
      );

      final result2 = await repository.insertTransaction(txByLowerId);
      expect(result2, isA<Success<void, dynamic>>());

      final insertedTx2 = await (db.select(db.transactions)
            ..where((t) => t.notes.equals('Test ID lowercase resolution')))
          .getSingle();
      expect(insertedTx2.categoryId, equals(customCatId));
    });
  });
}

