import 'dart:async';
import 'package:drift/drift.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/app_error.dart';
import '../domain/models/transaction_model.dart';
import '../domain/transaction_repository_interface.dart';
import '../domain/transaction_filters.dart';
import '../domain/transaction_events.dart';

class TransactionRepository implements TransactionRepositoryInterface {
  final AppDatabase _db;
  final StreamSink<TransactionEvent>? _eventSink;

  TransactionRepository(this._db, [this._eventSink]);

  @override
  Stream<List<TransactionModel>> fetchTransactions(String userId) {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);
    query.where(_db.transactions.userId.equals(userId));
    query.orderBy([OrderingTerm.desc(_db.transactions.date)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final tx = row.readTable(_db.transactions);

        return TransactionModel(
          id: tx.id,
          userId: tx.userId,
          amount: tx.amount,
          currency: tx.currency,
          categoryId: tx.categoryId ?? 'uncategorized',
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
  Future<Result<List<TransactionModel>, AppError>> getTransactionsOnce(
    String userId,
  ) async {
    try {
      final query = _db.select(_db.transactions).join([
        leftOuterJoin(
          _db.categories,
          _db.categories.id.equalsExp(_db.transactions.categoryId),
        ),
      ]);
      query.where(_db.transactions.userId.equals(userId));
      query.orderBy([OrderingTerm.desc(_db.transactions.date)]);

      final rows = await query.get();
      final list = rows.map((row) {
        final tx = row.readTable(_db.transactions);

        return TransactionModel(
          id: tx.id,
          userId: tx.userId,
          amount: tx.amount,
          currency: tx.currency,
          categoryId: tx.categoryId ?? 'uncategorized',
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

      return Success(list);
    } catch (e, stack) {
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Stream<List<TransactionModel>> fetchTransactionsFiltered(
    String userId,
    TransactionFilters filters,
    int limit,
  ) {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);

    // Base filter: user ID
    query.where(_db.transactions.userId.equals(userId));

    // Apply search query filter (notes OR category name)
    if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
      final searchLower = filters.searchQuery!.toLowerCase();
      query.where(
        _db.transactions.notes.lower().contains(searchLower) |
            _db.categories.name.lower().contains(searchLower),
      );
    }

    // Apply date range filters
    if (filters.startDate != null) {
      query.where(
        _db.transactions.date.isBiggerOrEqualValue(filters.startDate!),
      );
    }

    if (filters.endDate != null) {
      query.where(
        _db.transactions.date.isSmallerOrEqualValue(filters.endDate!),
      );
    }

    // Apply type filter
    if (filters.type != null) {
      query.where(_db.transactions.type.equals(filters.type!));
    }

    // Apply wallet filter (matches walletId, fromWalletId, or toWalletId)
    if (filters.walletId != null) {
      query.where(
        _db.transactions.walletId.equals(filters.walletId!) |
            _db.transactions.fromWalletId.equals(filters.walletId!) |
            _db.transactions.toWalletId.equals(filters.walletId!),
      );
    }

    // Apply amount range filters
    if (filters.minAmount != null) {
      query.where(
        _db.transactions.amount.isBiggerOrEqualValue(filters.minAmount!),
      );
    }

    if (filters.maxAmount != null) {
      query.where(
        _db.transactions.amount.isSmallerOrEqualValue(filters.maxAmount!),
      );
    }

    // Apply tag filter (transaction must have ALL specified tags)
    if (filters.tagIds != null && filters.tagIds!.isNotEmpty) {
      for (final tagId in filters.tagIds!) {
        query.where(
          _db.transactions.id.isInQuery(
            _db.selectOnly(_db.transactionTags)
              ..addColumns([_db.transactionTags.transactionId])
              ..where(_db.transactionTags.tagId.equals(tagId)),
          ),
        );
      }
    }

    // Order by date descending
    query.orderBy([OrderingTerm.desc(_db.transactions.date)]);

    // Apply dynamic limit for pagination
    query.limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) {
        final tx = row.readTable(_db.transactions);

        return TransactionModel(
          id: tx.id,
          userId: tx.userId,
          amount: tx.amount,
          currency: tx.currency,
          categoryId: tx.categoryId ?? 'uncategorized',
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
  Future<Result<void, AppError>> insertTransaction(
    TransactionModel transaction,
  ) async {
    try {
      late final String resolvedCategoryId;
      await _db.transaction(() async {
        // 1. Validate Category ID exists or resolve via Name
        var cat =
            await (_db.select(_db.categories)
                  ..where(
                    (c) =>
                        c.id.equals(transaction.categoryId) &
                        c.userId.equals(transaction.userId),
                  )
                  ..limit(1))
                .getSingleOrNull();

        cat ??= await (_db.select(_db.categories)
              ..where(
                (c) =>
                    c.name.equals(transaction.categoryId) &
                    c.userId.equals(transaction.userId),
              )
              ..limit(1))
            .getSingleOrNull();

        cat ??= await (_db.select(_db.categories)
              ..where(
                (c) =>
                    c.id.equals(transaction.categoryId.toLowerCase()) &
                    c.userId.equals(transaction.userId),
              )
              ..limit(1))
            .getSingleOrNull();

        if (cat == null) {
          throw AppError.validation(
            'Invalid category ID: ${transaction.categoryId}',
          );
        }

        resolvedCategoryId = cat.id;

        // 2. Insert Transaction into Drift DB
        await _db
            .into(_db.transactions)
            .insert(
              TransactionsCompanion.insert(
                userId: transaction.userId,
                walletId: Value(transaction.walletId),
                fromWalletId: Value(transaction.fromWalletId),
                toWalletId: Value(transaction.toWalletId),
                categoryId: Value(resolvedCategoryId),
                amount: transaction.amount,
                currency: Value(transaction.currency),
                notes: Value(transaction.notes),
                date: transaction.createdAt,
                type: transaction.type,
                latitude: Value(transaction.latitude),
                longitude: Value(transaction.longitude),
              ),
            );

        // 3. If no event sink (test mode), apply balance updates inline
        if (_eventSink == null) {
          await _applyBalanceChangesInline(
            transaction.copyWith(categoryId: resolvedCategoryId),
          );
        }
      });

      // Emit event for side-effect handlers (balance update, alerts, geofence)
      _eventSink?.add(
        TransactionCreated.now(
          transaction.copyWith(categoryId: resolvedCategoryId),
        ),
      );

      return const Success(null);
    } catch (e, stack) {
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> updateTransaction(
    TransactionModel transaction,
    TransactionModel oldTransaction,
  ) async {
    try {
      late final String resolvedCategoryId;
      await _db.transaction(() async {
        // 1. Validate Category ID exists or resolve via Name
        var cat =
            await (_db.select(_db.categories)
                  ..where(
                    (c) =>
                        c.id.equals(transaction.categoryId) &
                        c.userId.equals(transaction.userId),
                  )
                  ..limit(1))
                .getSingleOrNull();

        cat ??= await (_db.select(_db.categories)
              ..where(
                (c) =>
                    c.name.equals(transaction.categoryId) &
                    c.userId.equals(transaction.userId),
              )
              ..limit(1))
            .getSingleOrNull();

        cat ??= await (_db.select(_db.categories)
              ..where(
                (c) =>
                    c.id.equals(transaction.categoryId.toLowerCase()) &
                    c.userId.equals(transaction.userId),
              )
              ..limit(1))
            .getSingleOrNull();

        if (cat == null) {
          throw AppError.validation(
            'Invalid category ID: ${transaction.categoryId}',
          );
        }

        resolvedCategoryId = cat.id;

        // 2. Update the transaction row
        await (_db.update(
          _db.transactions,
        )..where((t) => t.id.equals(transaction.id!))).write(
          TransactionsCompanion(
            walletId: Value(transaction.walletId),
            fromWalletId: Value(transaction.fromWalletId),
            toWalletId: Value(transaction.toWalletId),
            categoryId: Value(resolvedCategoryId),
            amount: Value(transaction.amount),
            currency: Value(transaction.currency),
            notes: Value(transaction.notes),
            date: Value(transaction.createdAt),
            type: Value(transaction.type),
            latitude: Value(transaction.latitude),
            longitude: Value(transaction.longitude),
          ),
        );

        // 3. If no event sink (test mode), apply balance updates inline
        if (_eventSink == null) {
          await _revertBalanceChangesInline(oldTransaction);
          await _applyBalanceChangesInline(
            transaction.copyWith(categoryId: resolvedCategoryId),
          );
        }
      });

      // Emit event for side-effect handlers (balance revert + apply)
      _eventSink?.add(
        TransactionUpdated.now(
          transaction.copyWith(categoryId: resolvedCategoryId),
          oldTransaction,
        ),
      );

      return const Success(null);
    } catch (e, stack) {
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  @override
  Future<Result<void, AppError>> deleteTransaction(int id) async {
    try {
      // 1. Fetch transaction details before deletion (needed for event)
      final tx = await (_db.select(
        _db.transactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      if (tx == null) {
        return Failure(AppError.notFound('Transaction $id not found'));
      }

      // Convert to TransactionModel for event
      final transactionModel = TransactionModel(
        id: tx.id,
        userId: tx.userId,
        amount: tx.amount,
        categoryId: tx.categoryId ?? 'uncategorized',
        type: tx.type,
        notes: tx.notes ?? '',
        createdAt: tx.date,
        walletId: tx.walletId,
        fromWalletId: tx.fromWalletId,
        toWalletId: tx.toWalletId,
        latitude: tx.latitude,
        longitude: tx.longitude,
      );

      // 2. Delete the transaction
      await _db.transaction(() async {
        await (_db.delete(
          _db.transactions,
        )..where((t) => t.id.equals(id))).go();

        // If no event sink (test mode), revert balance inline
        if (_eventSink == null) {
          await _revertBalanceChangesInline(transactionModel);
        }
      });

      // 3. Emit event for side-effect handlers (balance revert)
      _eventSink?.add(TransactionDeleted.now(transactionModel));

      return const Success(null);
    } catch (e, stack) {
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  /// Apply balance changes inline (used when eventSink is null, e.g., in tests).
  Future<void> _applyBalanceChangesInline(TransactionModel transaction) async {
    if (transaction.type == 'transfer') {
      if (transaction.fromWalletId != null) {
        final fromWallet =
            await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(transaction.fromWalletId!)))
                .getSingleOrNull();
        if (fromWallet != null) {
          await (_db.update(
            _db.wallets,
          )..where((w) => w.id.equals(fromWallet.id))).write(
            WalletsCompanion(
              balance: Value(fromWallet.balance - transaction.amount),
            ),
          );
        }
      }
      if (transaction.toWalletId != null) {
        final toWallet =
            await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(transaction.toWalletId!)))
                .getSingleOrNull();
        if (toWallet != null) {
          await (_db.update(
            _db.wallets,
          )..where((w) => w.id.equals(toWallet.id))).write(
            WalletsCompanion(
              balance: Value(toWallet.balance + transaction.amount),
            ),
          );
        }
      }
    } else {
      if (transaction.walletId != null) {
        final wallet = await (_db.select(
          _db.wallets,
        )..where((w) => w.id.equals(transaction.walletId!))).getSingleOrNull();
        if (wallet != null) {
          final newBalance = transaction.type == 'income'
              ? wallet.balance + transaction.amount
              : wallet.balance - transaction.amount;
          await (_db.update(_db.wallets)..where((w) => w.id.equals(wallet.id)))
              .write(WalletsCompanion(balance: Value(newBalance)));
        }
      }
    }
  }

  /// Revert balance changes inline (used when eventSink is null, e.g., in tests).
  Future<void> _revertBalanceChangesInline(TransactionModel transaction) async {
    if (transaction.type == 'transfer') {
      if (transaction.fromWalletId != null) {
        final fromWallet =
            await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(transaction.fromWalletId!)))
                .getSingleOrNull();
        if (fromWallet != null) {
          await (_db.update(
            _db.wallets,
          )..where((w) => w.id.equals(fromWallet.id))).write(
            WalletsCompanion(
              balance: Value(fromWallet.balance + transaction.amount),
            ),
          );
        }
      }
      if (transaction.toWalletId != null) {
        final toWallet =
            await (_db.select(_db.wallets)
                  ..where((w) => w.id.equals(transaction.toWalletId!)))
                .getSingleOrNull();
        if (toWallet != null) {
          await (_db.update(
            _db.wallets,
          )..where((w) => w.id.equals(toWallet.id))).write(
            WalletsCompanion(
              balance: Value(toWallet.balance - transaction.amount),
            ),
          );
        }
      }
    } else {
      if (transaction.walletId != null) {
        final wallet = await (_db.select(
          _db.wallets,
        )..where((w) => w.id.equals(transaction.walletId!))).getSingleOrNull();
        if (wallet != null) {
          final revertedBalance = transaction.type == 'income'
              ? wallet.balance - transaction.amount
              : wallet.balance + transaction.amount;
          await (_db.update(_db.wallets)..where((w) => w.id.equals(wallet.id)))
              .write(WalletsCompanion(balance: Value(revertedBalance)));
        }
      }
    }
  }

  @override
  Future<double> getTotalSpendingForCategory(
    String userId,
    String categoryId,
    String budgetMonth,
  ) async {
    final monthStart = DateTime.parse('$budgetMonth-01');
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

    final sumExpr = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sumExpr])
      ..where(
        _db.transactions.userId.equals(userId) &
            _db.transactions.categoryId.equals(categoryId) &
            _db.transactions.type.equals('expense') &
            _db.transactions.date.isBiggerOrEqualValue(monthStart) &
            _db.transactions.date.isSmallerThanValue(monthEnd),
      );

    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0.0;
  }

  @override
  Future<double> getTotalSpendingAllCategories(
    String userId,
    String budgetMonth,
  ) async {
    final monthStart = DateTime.parse('$budgetMonth-01');
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

    final sumExpr = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([sumExpr])
      ..where(
        _db.transactions.userId.equals(userId) &
            _db.transactions.type.equals('expense') &
            _db.transactions.date.isBiggerOrEqualValue(monthStart) &
            _db.transactions.date.isSmallerThanValue(monthEnd),
      );

    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0.0;
  }
}
