import 'package:drift/drift.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/app_error.dart';
import '../domain/models/wallet_model.dart';
import '../domain/wallet_repository_interface.dart';
import 'dart:developer' as developer;

class WalletRepository implements WalletRepositoryInterface {
  final AppDatabase _db;

  WalletRepository(this._db);

  @override
  Future<Result<List<WalletModel>, AppError>> getWallets(String userId) async {
    try {
      final rows = await (_db.select(
        _db.wallets,
      )..where((tbl) => tbl.userId.equals(userId))).get();
      return Success(
        rows
            .map(
              (w) => WalletModel(
                id: w.id,
                userId: w.userId,
                name: w.name,
                type: w.type,
                balance: w.balance,
                currency: w.currency,
                createdAt: w.createdAt,
              ),
            )
            .toList(),
      );
    } catch (e, stack) {
      developer.log('Error fetching wallets from Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Stream<List<WalletModel>> watchWallets(String userId) {
    return (_db.select(
      _db.wallets,
    )..where((tbl) => tbl.userId.equals(userId))).watch().map((rows) {
      return rows
          .map(
            (w) => WalletModel(
              id: w.id,
              userId: w.userId,
              name: w.name,
              type: w.type,
              balance: w.balance,
              currency: w.currency,
              createdAt: w.createdAt,
            ),
          )
          .toList();
    });
  }

  @override
  Future<Result<void, AppError>> createWallet(WalletModel wallet) async {
    try {
      await _db
          .into(_db.wallets)
          .insert(
            WalletsCompanion.insert(
              id: wallet.id,
              userId: wallet.userId,
              name: wallet.name,
              type: wallet.type,
              balance: Value(wallet.balance),
              currency: Value(wallet.currency),
              icon: 'account_balance_wallet',
              color: '#6200EE',
              createdAt: wallet.createdAt,
            ),
          );
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error creating wallet in Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> updateWallet(WalletModel wallet) async {
    try {
      await (_db.update(
        _db.wallets,
      )..where((t) => t.id.equals(wallet.id))).write(
        WalletsCompanion(
          name: Value(wallet.name),
          type: Value(wallet.type),
          balance: Value(wallet.balance),
          currency: Value(wallet.currency),
        ),
      );
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error updating wallet in Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> deleteWallet(String walletId) async {
    try {
      await (_db.delete(_db.wallets)..where((t) => t.id.equals(walletId))).go();
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error deleting wallet from Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<void> adjustBalance(String walletId, double amount) async {
    final wallet = await (_db.select(_db.wallets)
          ..where((t) => t.id.equals(walletId)))
        .getSingleOrNull();

    if (wallet == null) {
      throw StateError('Wallet not found: $walletId');
    }

    await (_db.update(_db.wallets)..where((t) => t.id.equals(walletId)))
        .write(WalletsCompanion(
      balance: Value(wallet.balance + amount),
    ));
  }
}
