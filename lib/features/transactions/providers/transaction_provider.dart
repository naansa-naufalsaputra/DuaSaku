import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter/services.dart';

import '../../../../core/local_db/app_database_provider.dart';
import '../../../core/local_db/app_database.dart';
import '../../../core/utils/result.dart';
import '../../../services/service_providers.dart';
import '../domain/transaction_parser_service_interface.dart';
import '../../../services/models/wallet_info.dart';
import '../../../services/models/category_info.dart';
import '../../../services/models/parsed_transaction.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_repository_interface.dart';
import '../domain/models/transaction_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallets/providers/wallet_provider.dart';
import '../../smart_budget_alerts/providers/alert_center_provider.dart';
import '../../smart_budget_alerts/services/budget_alert_evaluator.dart';
import 'category_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepositoryInterface>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return TransactionRepository(db);
});

class TransactionNotifier extends AsyncNotifier<List<TransactionModel>> {
  late TransactionRepositoryInterface _repository;
  late TransactionParserServiceInterface _parserService;
  StreamSubscription<List<TransactionModel>>? _subscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  Future<List<TransactionModel>> build() async {
    _repository = ref.watch(transactionRepositoryProvider);
    _parserService = ref.watch(transactionParserServiceProvider);
    final user = ref.watch(userProvider);
    if (user == null) {
      return [];
    }

    // Background sync on init
    // ignore: deprecated_member_use
    _repository.syncPendingTransactions();

    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (!results.contains(ConnectivityResult.none)) {
        // ignore: deprecated_member_use
        _repository.syncPendingTransactions();
        loadTransactions();
      }
    });

    ref.onDispose(() {
      _subscription?.cancel();
      _connectivitySubscription?.cancel();
    });

    final completer = Completer<List<TransactionModel>>();
    bool isFirst = true;

    _subscription?.cancel();
    _subscription = _repository
        .fetchTransactions(user.id)
        .listen(
          (data) {
            if (isFirst) {
              completer.complete(data);
              isFirst = false;
            } else {
              state = AsyncValue.data(data);
            }
          },
          onError: (e, stack) {
            if (isFirst) {
              completer.completeError(e, stack);
            } else {
              state = AsyncValue.error(e, stack);
            }
          },
        );

    return completer.future;
  }

  Future<void> loadTransactions() async {
    final user = ref.read(userProvider);
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }
    _subscription?.cancel();
    _subscription = _repository.fetchTransactions(user.id).listen((data) {
      state = AsyncValue.data(data);
    });
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    final result = await _repository.insertTransaction(transaction);
    switch (result) {
      case Success():
        await HapticFeedback.mediumImpact();
        await loadTransactions();
        // Fire-and-forget: trigger alert evaluation for expense transactions
        if (transaction.type == 'expense') {
          _triggerAlertEvaluationAfterInsert(transaction);
        }
      case Failure(:final error):
        // Preserve previous data while surfacing error via AsyncError state
        final previousData = state.valueOrNull ?? [];
        state = AsyncValue<List<TransactionModel>>.error(
          error,
          StackTrace.current,
        ).copyWithPrevious(AsyncData(previousData));
    }
  }

  Future<void> deleteTransaction(int id) async {
    // Capture transaction details before deletion for alert re-evaluation
    final previousState = state.valueOrNull;
    final deletedTx = previousState?.where((tx) => tx.id == id).firstOrNull;

    // Optimistic UI update
    if (previousState != null) {
      state = AsyncValue.data(
        previousState.where((tx) => tx.id != id).toList(),
      );
    }

    final result = await _repository.deleteTransaction(id);
    switch (result) {
      case Success():
        await loadTransactions();
        // Fire-and-forget: trigger alert re-evaluation for expense transactions
        if (deletedTx != null && deletedTx.type == 'expense') {
          _triggerAlertEvaluationAfterDelete(deletedTx);
        }
      case Failure(:final error):
        // Restore previous state first so Riverpod's internal copyWithPrevious
        // uses the correct previous data (not the optimistic removal state)
        state = AsyncData(previousState ?? []);
        state = AsyncValue<List<TransactionModel>>.error(
          error,
          StackTrace.current,
        ).copyWithPrevious(AsyncData(previousState ?? []));
    }
  }

  Future<ParsedTransaction> parseSmartText(String text) async {
    final user = ref.read(userProvider);
    if (user == null) throw Exception('User not authenticated');

    // Get wallets and categories for the parser service
    final wallets = ref.read(walletProvider).valueOrNull ?? [];
    final categories = ref.read(categoryNotifierProvider).valueOrNull ?? [];

    final walletInfos = wallets
        .map((w) => WalletInfo(id: w.id, name: w.name, type: w.type))
        .toList();
    final categoryInfos = categories
        .map((c) => CategoryInfo(name: c.name, type: c.type))
        .toList();

    return _parserService.parseTransaction(
      inputText: text,
      wallets: walletInfos,
      categories: categoryInfos,
    );
  }

  Future<void> createTransaction({
    required double amount,
    required String category,
    required String type,
    required String notes,
    String? walletId,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
  }) async {
    final user = ref.read(userProvider);
    if (user == null) throw Exception('User not authenticated');

    final newTransaction = TransactionModel(
      userId: user.id,
      amount: amount,
      category: category,
      type: type,
      notes: notes,
      walletId: walletId,
      createdAt: createdAt ?? DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );

    await addTransaction(newTransaction);
  }

  Future<void> createTransfer({
    required double amount,
    required String fromWalletId,
    required String toWalletId,
    required String notes,
    double? latitude,
    double? longitude,
  }) async {
    final user = ref.read(userProvider);
    if (user == null) throw Exception('User not authenticated');

    final newTransaction = TransactionModel(
      userId: user.id,
      amount: amount,
      category: 'Transfer',
      type: 'transfer',
      notes: notes,
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      createdAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
    );

    await addTransaction(newTransaction);
  }

  // ─── Alert Evaluation Helpers ───────────────────────────────────────────────

  /// Triggers alert evaluation after a new expense transaction is inserted.
  ///
  /// Resolves the category name to categoryId, then calls the evaluator.
  /// Fire-and-forget — errors are logged internally by the evaluator.
  void _triggerAlertEvaluationAfterInsert(TransactionModel transaction) {
    // Run asynchronously without awaiting to avoid blocking the UI
    Future<void>(() async {
      final user = ref.read(userProvider);
      if (user == null) return;

      final db = ref.read(appDatabaseProvider);
      final categoryId = await _resolveCategoryId(
        db,
        user.id,
        transaction.category,
      );
      if (categoryId == null) return;

      final budgetMonth = BudgetAlertEvaluator.getBudgetMonthForDate(
        transaction.createdAt,
      );

      final evaluator = ref.read(budgetAlertEvaluatorProvider);
      await evaluator.evaluateAfterExpenseInsert(
        userId: user.id,
        categoryId: categoryId,
        budgetMonth: budgetMonth,
      );
    });
  }

  /// Triggers alert re-evaluation after an expense transaction is deleted.
  ///
  /// Resolves the category name to categoryId, then calls the evaluator
  /// to reset thresholds where spending has dropped.
  void _triggerAlertEvaluationAfterDelete(TransactionModel transaction) {
    Future<void>(() async {
      final user = ref.read(userProvider);
      if (user == null) return;

      final db = ref.read(appDatabaseProvider);
      final categoryId = await _resolveCategoryId(
        db,
        user.id,
        transaction.category,
      );
      if (categoryId == null) return;

      final budgetMonth = BudgetAlertEvaluator.getBudgetMonthForDate(
        transaction.createdAt,
      );

      final evaluator = ref.read(budgetAlertEvaluatorProvider);
      await evaluator.evaluateAfterExpenseChange(
        userId: user.id,
        categoryId: categoryId,
        budgetMonth: budgetMonth,
      );
    });
  }

  /// Resolves a category name to its ID from the database.
  /// Returns null if the category is not found.
  Future<String?> _resolveCategoryId(
    AppDatabase db,
    String userId,
    String categoryName,
  ) async {
    final cat =
        await (db.select(db.categories)..where(
              (c) => c.name.equals(categoryName) & c.userId.equals(userId),
            ))
            .getSingleOrNull();
    return cat?.id;
  }
}

final transactionNotifierProvider =
    AsyncNotifierProvider<TransactionNotifier, List<TransactionModel>>(() {
      return TransactionNotifier();
    });
