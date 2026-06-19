import 'dart:async';
import 'package:drift/drift.dart';
import '../../local_db/app_database.dart';
import 'balance_discrepancy.dart';

/// Service responsible for detecting and repairing wallet balance drift.
///
/// Periodically verifies integrity between stored wallet balance and
/// computed transaction totals using the same formula as schema v8 migration.
class BalanceIntegrityService {
  final AppDatabase _db;

  BalanceIntegrityService(this._db);

  /// Checks all wallets for balance discrepancies.
  ///
  /// Returns map of wallet ID to discrepancy if difference > 0.01 IDR.
  /// Runs computation in single database transaction for consistency.
  Future<Map<String, BalanceDiscrepancy>> checkAllWallets() async {
    final discrepancies = <String, BalanceDiscrepancy>{};

    await _db.transaction(() async {
      // Get all wallets
      final wallets = await _db.select(_db.wallets).get();

      for (final wallet in wallets) {
        final computed = await _computeBalance(wallet.id);
        final stored = wallet.balance;
        final difference = stored - computed;

        if (difference.abs() > 0.01) {
          discrepancies[wallet.id] = BalanceDiscrepancy(
            walletId: wallet.id,
            walletName: wallet.name,
            storedBalance: stored,
            computedBalance: computed,
            difference: difference,
            detectedAt: DateTime.now(),
          );
        }
      }
    });

    return discrepancies;
  }

  /// Computes wallet balance from transaction history using same formula
  /// as schema v8 migration:
  /// SUM(income to wallet) - SUM(expense from wallet)
  /// + SUM(transfers into wallet) - SUM(transfers out of wallet)
  Future<double> _computeBalance(String walletId) async {
    // Query using Drift's type-safe API
    final incomeQuery = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.amount.sum()])
      ..where(_db.transactions.type.equals('income'))
      ..where(_db.transactions.walletId.equals(walletId));

    final expenseQuery = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.amount.sum()])
      ..where(_db.transactions.type.equals('expense'))
      ..where(_db.transactions.walletId.equals(walletId));

    final transferInQuery = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.amount.sum()])
      ..where(_db.transactions.type.equals('transfer'))
      ..where(_db.transactions.toWalletId.equals(walletId));

    final transferOutQuery = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.amount.sum()])
      ..where(_db.transactions.type.equals('transfer'))
      ..where(_db.transactions.fromWalletId.equals(walletId));

    // Execute queries in parallel
    final results = await Future.wait([
      incomeQuery.getSingle(),
      expenseQuery.getSingle(),
      transferInQuery.getSingle(),
      transferOutQuery.getSingle(),
    ]);

    final incomeSum = results[0].read(_db.transactions.amount.sum()) ?? 0.0;
    final expenseSum = results[1].read(_db.transactions.amount.sum()) ?? 0.0;
    final transferInSum = results[2].read(_db.transactions.amount.sum()) ?? 0.0;
    final transferOutSum =
        results[3].read(_db.transactions.amount.sum()) ?? 0.0;

    final computed = incomeSum - expenseSum + transferInSum - transferOutSum;
    return computed;
  }

  /// Repairs balance for specific wallet by updating to computed value.
  ///
  /// Uses atomic transaction to ensure consistency. Logs repair operation.
  Future<void> repairWallet(String walletId) async {
    await _db.transaction(() async {
      final computed = await _computeBalance(walletId);

      await (_db.update(_db.wallets)..where((w) => w.id.equals(walletId)))
          .write(WalletsCompanion(balance: Value(computed)));
    });
  }

  /// Repairs all detected discrepancies in batch.
  ///
  /// Returns number of wallets repaired. Uses single transaction for atomicity.
  Future<int> repairAllDiscrepancies(
    Map<String, BalanceDiscrepancy> discrepancies,
  ) async {
    if (discrepancies.isEmpty) {
      return 0;
    }

    int repairedCount = 0;
    await _db.transaction(() async {
      for (final discrepancy in discrepancies.values) {
        if (discrepancy.isSignificant) {
          await (_db.update(
            _db.wallets,
          )..where((w) => w.id.equals(discrepancy.walletId))).write(
            WalletsCompanion(balance: Value(discrepancy.computedBalance)),
          );
          repairedCount++;
        }
      }
    });

    return repairedCount;
  }
}
