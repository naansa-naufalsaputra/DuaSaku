import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/core/services/balance_integrity/balance_integrity_service.dart';

void main() {
  late AppDatabase db;
  late BalanceIntegrityService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BalanceIntegrityService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BalanceIntegrityService Unit Tests', () {
    test('checkAllWallets returns empty map when no discrepancies', () async {
      // Create a wallet with accurate balance
      await db
          .into(db.wallets)
          .insert(
            WalletsCompanion.insert(
              id: 'wallet-1',
              userId: 'test-user',
              name: 'Test Wallet',
              type: 'Cash',
              balance: const Value(1000.0),
              icon: 'wallet',
              color: '#000000',
              createdAt: DateTime(2024, 1, 1),
            ),
          );

      // Add matching transaction
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              userId: 'test-user',
              walletId: const Value('wallet-1'),
              amount: 1000.0,
              date: DateTime(2024, 1, 1),
              type: 'income',
            ),
          );

      final discrepancies = await service.checkAllWallets();
      expect(discrepancies, isEmpty);
    });

    test(
      'checkAllWallets detects discrepancy between stored and computed balance',
      () async {
        // Create wallet with incorrect balance (1000 stored but should be 500)
        await db
            .into(db.wallets)
            .insert(
              WalletsCompanion.insert(
                id: 'wallet-2',
                userId: 'test-user',
                name: 'Test Wallet 2',
                type: 'Cash',
                balance: const Value(1000.0),
                icon: 'wallet',
                color: '#000000',
                createdAt: DateTime(2024, 1, 1),
              ),
            );

        // Add transaction that makes balance 500
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: 'test-user',
                walletId: const Value('wallet-2'),
                amount: 500.0,
                date: DateTime(2024, 1, 1),
                type: 'income',
              ),
            );

        final discrepancies = await service.checkAllWallets();
        expect(discrepancies.length, equals(1));

        final discrepancy = discrepancies['wallet-2'];
        expect(discrepancy, isNotNull);
        expect(discrepancy!.storedBalance, equals(1000.0));
        expect(discrepancy.computedBalance, equals(500.0));
        expect(discrepancy.difference, equals(500.0));
        expect(discrepancy.isSignificant, isTrue);
      },
    );

    test(
      'checkAllWallets ignores minor discrepancies below threshold',
      () async {
        // Create wallet with small discrepancy (0.005 difference)
        await db
            .into(db.wallets)
            .insert(
              WalletsCompanion.insert(
                id: 'wallet-3',
                userId: 'test-user',
                name: 'Test Wallet 3',
                type: 'Cash',
                balance: const Value(1000.005),
                icon: 'wallet',
                color: '#000000',
                createdAt: DateTime(2024, 1, 1),
              ),
            );

        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: 'test-user',
                walletId: const Value('wallet-3'),
                amount: 1000.0,
                date: DateTime(2024, 1, 1),
                type: 'income',
              ),
            );

        final discrepancies = await service.checkAllWallets();
        expect(discrepancies, isEmpty);
      },
    );

    test('repairWallet fixes balance discrepancy', () async {
      // Create wallet with incorrect balance
      await db
          .into(db.wallets)
          .insert(
            WalletsCompanion.insert(
              id: 'wallet-4',
              userId: 'test-user',
              name: 'Test Wallet 4',
              type: 'Cash',
              balance: const Value(2000.0),
              icon: 'wallet',
              color: '#000000',
              createdAt: DateTime(2024, 1, 1),
            ),
          );

      // Add transaction that makes balance 1500
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              userId: 'test-user',
              walletId: const Value('wallet-4'),
              amount: 1500.0,
              date: DateTime(2024, 1, 1),
              type: 'income',
            ),
          );

      // Verify discrepancy exists
      final discrepancies = await service.checkAllWallets();
      expect(discrepancies.length, equals(1));
      expect(discrepancies['wallet-4']!.difference.abs(), greaterThan(0.01));

      // Repair wallet
      await service.repairWallet('wallet-4');

      // Verify balance is now correct
      final wallet = await (db.select(
        db.wallets,
      )..where((w) => w.id.equals('wallet-4'))).getSingle();
      expect(wallet.balance, closeTo(1500.0, 0.01));
    });

    test('repairAllDiscrepancies fixes multiple wallets', () async {
      // Create two wallets with incorrect balances
      await db
          .into(db.wallets)
          .insert(
            WalletsCompanion.insert(
              id: 'wallet-5',
              userId: 'test-user',
              name: 'Wallet 5',
              type: 'Cash',
              balance: const Value(1000.0),
              icon: 'wallet',
              color: '#000000',
              createdAt: DateTime(2024, 1, 1),
            ),
          );
      await db
          .into(db.wallets)
          .insert(
            WalletsCompanion.insert(
              id: 'wallet-6',
              userId: 'test-user',
              name: 'Wallet 6',
              type: 'Cash',
              balance: const Value(2000.0),
              icon: 'wallet',
              color: '#000000',
              createdAt: DateTime(2024, 1, 1),
            ),
          );

      // Add transactions that make balances different
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              userId: 'test-user',
              walletId: const Value('wallet-5'),
              amount: 500.0,
              date: DateTime(2024, 1, 1),
              type: 'income',
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              userId: 'test-user',
              walletId: const Value('wallet-6'),
              amount: 1000.0,
              date: DateTime(2024, 1, 1),
              type: 'income',
            ),
          );

      // Get discrepancies
      final discrepancies = await service.checkAllWallets();
      expect(discrepancies.length, equals(2));

      // Repair all
      final repairedCount = await service.repairAllDiscrepancies(discrepancies);
      expect(repairedCount, equals(2));

      // Verify balances are now correct
      final wallets = await db.select(db.wallets).get();
      for (final wallet in wallets) {
        if (wallet.id == 'wallet-5') {
          expect(wallet.balance, closeTo(500.0, 0.01));
        }
        if (wallet.id == 'wallet-6') {
          expect(wallet.balance, closeTo(1000.0, 0.01));
        }
      }
    });

    test(
      '_computeBalance correctly calculates balance with all transaction types',
      () async {
        // Create wallet
        await db
            .into(db.wallets)
            .insert(
              WalletsCompanion.insert(
                id: 'wallet-7',
                userId: 'test-user',
                name: 'Wallet 7',
                type: 'Cash',
                balance: const Value(0.0),
                icon: 'wallet',
                color: '#000000',
                createdAt: DateTime(2024, 1, 1),
              ),
            );

        // Add multiple transaction types
        // income: +1000
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: 'test-user',
                walletId: const Value('wallet-7'),
                amount: 1000.0,
                date: DateTime(2024, 1, 1),
                type: 'income',
              ),
            );
        // expense: -300
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: 'test-user',
                walletId: const Value('wallet-7'),
                amount: 300.0,
                date: DateTime(2024, 1, 2),
                type: 'expense',
              ),
            );
        // transfer to wallet: +500
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: 'test-user',
                toWalletId: const Value('wallet-7'),
                amount: 500.0,
                date: DateTime(2024, 1, 3),
                type: 'transfer',
              ),
            );
        // transfer from wallet: -200
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: 'test-user',
                fromWalletId: const Value('wallet-7'),
                amount: 200.0,
                date: DateTime(2024, 1, 4),
                type: 'transfer',
              ),
            );

        // Calculate balance: 1000 - 300 + 500 - 200 = 1000
        final computed = await (service as dynamic)._computeBalance('wallet-7');
        expect(computed, closeTo(1000.0, 0.01));
      },
    );

    test('checkAllWallets handles empty database gracefully', () async {
      final discrepancies = await service.checkAllWallets();
      expect(discrepancies, isEmpty);
    });
  });
}
