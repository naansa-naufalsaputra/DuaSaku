import 'dart:async';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/app_error.dart';
import '../../geofencing/services/geofence_sync_helper.dart';
import '../domain/models/transaction_model.dart';
import '../domain/transaction_repository_interface.dart';

class TransactionRepository implements TransactionRepositoryInterface {
  final AppDatabase _db;

  TransactionRepository(this._db);

  @override
  Stream<List<TransactionModel>> fetchTransactions(String userId) {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ]);
    query.where(_db.transactions.userId.equals(userId));
    query.orderBy([OrderingTerm.desc(_db.transactions.date)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final tx = row.readTable(_db.transactions);
        final cat = row.readTableOrNull(_db.categories);

        return TransactionModel(
          id: tx.id,
          userId: tx.userId,
          amount: tx.amount,
          category: cat?.name ?? 'Uncategorized',
          type: tx.type,
          notes: tx.notes ?? '',
          createdAt: tx.date,
          walletId: tx.walletId,
          fromWalletId: tx.fromWalletId,
          toWalletId: tx.toWalletId,
          latitude: tx.latitude,
          longitude: tx.longitude,
        );
      }).toList();
    });
  }

  @override
  Future<Result<void, AppError>> insertTransaction(TransactionModel transaction) async {
    try {
      await _db.transaction(() async {
        // 1. Resolve Category ID by Name
        final cat = await (_db.select(_db.categories)
              ..where((c) => c.name.equals(transaction.category) & c.userId.equals(transaction.userId)))
            .getSingleOrNull();

        String categoryId;
        if (cat != null) {
          categoryId = cat.id;
        } else {
          // Create new category on the fly if it doesn't exist
          categoryId = const Uuid().v4();
          await _db.into(_db.categories).insert(
                CategoriesCompanion.insert(
                  id: categoryId,
                  userId: transaction.userId,
                  name: transaction.category,
                  icon: const Value('category'),
                  color: const Value('#9E9E9E'),
                  type: transaction.type == 'transfer' ? 'expense' : transaction.type,
                  createdAt: DateTime.now(),
                ),
              );
        }

        // 2. Insert Transaction into Drift DB
        await _db.into(_db.transactions).insert(
              TransactionsCompanion.insert(
                userId: transaction.userId,
                walletId: Value(transaction.walletId),
                fromWalletId: Value(transaction.fromWalletId),
                toWalletId: Value(transaction.toWalletId),
                categoryId: Value(categoryId),
                amount: transaction.amount,
                notes: Value(transaction.notes),
                date: transaction.createdAt,
                type: transaction.type,
                latitude: Value(transaction.latitude),
                longitude: Value(transaction.longitude),
              ),
            );

        // 3. Adjust Wallet Balances locally
        if (transaction.type == 'transfer') {
          if (transaction.fromWalletId != null) {
            final fromWallet = await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(transaction.fromWalletId!)))
                .getSingleOrNull();
            if (fromWallet != null) {
              await (_db.update(_db.wallets)..where((w) => w.id.equals(fromWallet.id))).write(
                WalletsCompanion(balance: Value(fromWallet.balance - transaction.amount)),
              );
            }
          }
          if (transaction.toWalletId != null) {
            final toWallet = await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(transaction.toWalletId!)))
                .getSingleOrNull();
            if (toWallet != null) {
              await (_db.update(_db.wallets)..where((w) => w.id.equals(toWallet.id))).write(
                WalletsCompanion(balance: Value(toWallet.balance + transaction.amount)),
              );
            }
          }
        } else {
          if (transaction.walletId != null) {
            final wallet = await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(transaction.walletId!)))
                .getSingleOrNull();
            if (wallet != null) {
              final double newBalance = transaction.type == 'income'
                  ? wallet.balance + transaction.amount
                  : wallet.balance - transaction.amount;
              await (_db.update(_db.wallets)..where((w) => w.id.equals(wallet.id))).write(
                WalletsCompanion(balance: Value(newBalance)),
              );
            }
          }
        }
      });

      // Asynchronously trigger geofence clustering sync on transaction insertion
      unawaited(GeofenceSyncHelper.syncGeofenceHotspots(_db, transaction.userId));

      return const Success(null);
    } catch (e, stack) {
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> deleteTransaction(int id) async {
    try {
      await _db.transaction(() async {
        // 1. Fetch transaction details to revert wallet updates
        final tx = await (_db.select(_db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (tx == null) return;

        // 2. Revert Wallet Balances
        if (tx.type == 'transfer') {
          if (tx.fromWalletId != null) {
            final fromWallet = await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(tx.fromWalletId!)))
                .getSingleOrNull();
            if (fromWallet != null) {
              await (_db.update(_db.wallets)..where((w) => w.id.equals(fromWallet.id))).write(
                WalletsCompanion(balance: Value(fromWallet.balance + tx.amount)),
              );
            }
          }
          if (tx.toWalletId != null) {
            final toWallet = await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(tx.toWalletId!)))
                .getSingleOrNull();
            if (toWallet != null) {
              await (_db.update(_db.wallets)..where((w) => w.id.equals(toWallet.id))).write(
                WalletsCompanion(balance: Value(toWallet.balance - tx.amount)),
              );
            }
          }
        } else {
          if (tx.walletId != null) {
            final wallet = await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(tx.walletId!)))
                .getSingleOrNull();
            if (wallet != null) {
              final double revertedBalance = tx.type == 'income'
                  ? wallet.balance - tx.amount
                  : wallet.balance + tx.amount;
              await (_db.update(_db.wallets)..where((w) => w.id.equals(wallet.id))).write(
                WalletsCompanion(balance: Value(revertedBalance)),
              );
            }
          }
        }

        // 3. Delete the transaction
        await (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
      });
      return const Success(null);
    } catch (e, stack) {
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  /// Intentional no-op for offline-first architecture.
  /// Reserved for future cloud sync implementation when online mode is added.
  @override
  @Deprecated('No-op in offline-first architecture. Reserved for future cloud sync implementation.')
  Future<void> syncPendingTransactions() async {
    // No-op for offline-first architecture
  }
}
