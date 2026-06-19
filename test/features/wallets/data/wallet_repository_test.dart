import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/features/wallets/data/wallet_repository.dart';
import 'package:duasaku_app/features/wallets/domain/models/wallet_model.dart';
import 'package:duasaku_app/core/utils/result.dart';

void main() {
  late AppDatabase db;
  late WalletRepository repository;

  const String userId = 'local_user';
  const String walletId = 'wallet-test-1';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = WalletRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('WalletRepository Unit Tests', () {
    test(
      'createWallet and getWallets - successfully saves and retrieves wallet',
      () async {
        final wallet = WalletModel(
          id: walletId,
          userId: userId,
          name: 'Gopay',
          type: 'ewallet',
          balance: 150000.0,
          createdAt: DateTime.now(),
        );

        final createResult = await repository.createWallet(wallet);
        expect(createResult, isA<Success<void, dynamic>>());

        final getResult = await repository.getWallets(userId);
        expect(getResult, isA<Success<List<WalletModel>, dynamic>>());

        final wallets =
            (getResult as Success<List<WalletModel>, dynamic>).value;
        expect(wallets.length, equals(1));
        expect(wallets.first.id, equals(walletId));
        expect(wallets.first.name, equals('Gopay'));
        expect(wallets.first.balance, equals(150000.0));
      },
    );

    test(
      'updateWallet - updates name, type, and balance successfully',
      () async {
        final wallet = WalletModel(
          id: walletId,
          userId: userId,
          name: 'Gopay',
          type: 'ewallet',
          balance: 150000.0,
          createdAt: DateTime.now(),
        );
        await repository.createWallet(wallet);

        final updatedWallet = wallet.copyWith(
          name: 'Gopay Premium',
          balance: 200000.0,
        );

        final updateResult = await repository.updateWallet(updatedWallet);
        expect(updateResult, isA<Success<void, dynamic>>());

        final getResult = await repository.getWallets(userId);
        final wallets =
            (getResult as Success<List<WalletModel>, dynamic>).value;
        expect(wallets.first.name, equals('Gopay Premium'));
        expect(wallets.first.balance, equals(200000.0));
      },
    );

    test('deleteWallet - removes wallet successfully', () async {
      final wallet = WalletModel(
        id: walletId,
        userId: userId,
        name: 'Gopay',
        type: 'ewallet',
        balance: 150000.0,
        createdAt: DateTime.now(),
      );
      await repository.createWallet(wallet);

      final deleteResult = await repository.deleteWallet(walletId);
      expect(deleteResult, isA<Success<void, dynamic>>());

      final getResult = await repository.getWallets(userId);
      final wallets = (getResult as Success<List<WalletModel>, dynamic>).value;
      expect(wallets, isEmpty);
    });

    test('watchWallets - streams realtime updates', () async {
      final wallet = WalletModel(
        id: walletId,
        userId: userId,
        name: 'Gopay',
        type: 'ewallet',
        balance: 150000.0,
        createdAt: DateTime.now(),
      );

      final stream = repository.watchWallets(userId);

      expect(
        stream,
        emitsInOrder([
          isEmpty, // Initial empty list
          [
            predicate<WalletModel>(
              (w) => w.id == walletId && w.name == 'Gopay',
            ),
          ], // List after insert
        ]),
      );

      // Trigger insert after small delay so stream listener is active
      await Future.delayed(const Duration(milliseconds: 100));
      await repository.createWallet(wallet);
    });
  });
}
