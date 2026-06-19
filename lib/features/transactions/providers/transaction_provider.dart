import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter/services.dart';

import '../../../../core/local_db/app_database_provider.dart';
import '../../../../core/providers/event_bus_provider.dart';
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
import '../domain/transaction_filters.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallets/providers/wallet_provider.dart';
import '../../smart_budget_alerts/providers/alert_center_provider.dart';
import '../../smart_budget_alerts/services/budget_alert_evaluator.dart';
import 'category_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepositoryInterface>((
  ref,
) {
  final db = ref.watch(appDatabaseProvider);
  final eventSink = ref.watch(transactionEventSinkProvider);
  return TransactionRepository(db, eventSink);
});

class TransactionNotifier extends AsyncNotifier<List<TransactionModel>> {
  static const int pageSize = 50;
  
  late TransactionRepositoryInterface _repository;
  late TransactionParserServiceInterface _parserService;
  StreamSubscription<List<TransactionModel>>? _subscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // Filter and pagination state
  TransactionFilters _currentFilters = const TransactionFilters();
  int _currentLimit = pageSize;
  bool _isLoadingMore = false;
  
  // Soft-delete state for undo functionality
  TransactionModel? _deletedTransactionStash;
  Timer? _deleteTimer;

  @override
  Future<List<TransactionModel>> build() async {
    _repository = ref.watch(transactionRepositoryProvider);
    _parserService = ref.watch(transactionParserServiceProvider);
    final user = ref.watch(userProvider);
    if (user == null) {
      return [];
    }

    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (!results.contains(ConnectivityResult.none)) {
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
        .fetchTransactionsFiltered(user.id, _currentFilters, _currentLimit)
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
    _subscription = _repository
        .fetchTransactionsFiltered(user.id, _currentFilters, _currentLimit)
        .listen((data) {
      state = AsyncValue.data(data);
    });
  }
  
  void applyFilters(TransactionFilters filters) {
    _currentFilters = filters;
    _currentLimit = pageSize; // Reset to initial page size
    ref.invalidateSelf();
  }
  
  void clearFilters() {
    _currentFilters = const TransactionFilters();
    _currentLimit = pageSize; // Reset to initial page size
    ref.invalidateSelf();
  }
  
  void loadMoreTransactions() {
    if (_isLoadingMore) return;
    
    state.whenData((currentTransactions) {
      // Check if we have full page (means more data exists)
      if (currentTransactions.length < _currentLimit) {
        // Already showing all data
        return;
      }
      
      _isLoadingMore = true;
      
      // Increment limit by pageSize
      _currentLimit += pageSize;
      
      // Rebuild stream with new limit (triggers new query)
      ref.invalidateSelf();
      
      _isLoadingMore = false;
    });
  }
  
  bool get hasMorePages {
    return state.whenOrNull(
      data: (transactions) => transactions.length >= _currentLimit,
    ) ?? false;
  }
  
  bool get isLoadingMore => _isLoadingMore;

  Future<void> addTransaction(TransactionModel transaction) async {
    final result = await _repository.insertTransaction(transaction);
    switch (result) {
      case Success():
        await HapticFeedback.mediumImpact();
        await loadTransactions();
        // Evaluasi budget alert ditangani secara reaktif oleh TransactionEventHandlers
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
        // Evaluasi budget alert ditangani secara reaktif oleh TransactionEventHandlers
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

  /// Soft-delete transaction with 5-second undo window
  /// Returns the deleted transaction for SnackBar display
  Future<TransactionModel?> softDeleteTransaction(int id) async {
    // Cancel any existing delete timer
    _deleteTimer?.cancel();
    
    final previousState = state.valueOrNull;
    final deletedTx = previousState?.where((tx) => tx.id == id).firstOrNull;
    
    if (deletedTx == null) return null;
    
    // Stash the transaction
    _deletedTransactionStash = deletedTx;
    
    // Optimistic UI update (remove from list)
    if (previousState != null) {
      state = AsyncValue.data(
        previousState.where((tx) => tx.id != id).toList(),
      );
    }
    
    // Start 5-second timer for permanent delete
    _deleteTimer = Timer(const Duration(seconds: 5), () async {
      await _permanentlyDelete(id, deletedTx);
    });
    
    return deletedTx;
  }

  /// Undo soft-delete (cancel timer and restore transaction)
  Future<void> undoDelete() async {
    _deleteTimer?.cancel();
    
    final stashed = _deletedTransactionStash;
    if (stashed == null) return;
    
    // Restore to list at original chronological position
    final currentList = state.valueOrNull ?? [];
    final restoredList = [...currentList, stashed]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort by date descending
    
    state = AsyncValue.data(restoredList);
    _deletedTransactionStash = null;
  }

  /// Permanent delete (called after 5-second timeout)
  Future<void> _permanentlyDelete(int id, TransactionModel deletedTx) async {
    final result = await _repository.deleteTransaction(id);
    switch (result) {
      case Success():
        _deletedTransactionStash = null;
        await loadTransactions();
        // Evaluasi budget alert ditangani secara reaktif oleh TransactionEventHandlers
      case Failure(:final error):
        // Restore on failure
        final currentList = state.valueOrNull ?? [];
        final restoredList = [...currentList, deletedTx]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = AsyncValue.data(restoredList);
        _deletedTransactionStash = null;
        
        // Show error
        state = AsyncValue<List<TransactionModel>>.error(
          error,
          StackTrace.current,
        ).copyWithPrevious(AsyncData(restoredList));
    }
  }

  Future<void> updateTransaction(
    TransactionModel transaction,
    TransactionModel oldTransaction,
  ) async {
    final result = await _repository.updateTransaction(transaction, oldTransaction);
    switch (result) {
      case Success():
        await loadTransactions();
        // Evaluasi budget alert ditangani secara reaktif oleh TransactionEventHandlers
      case Failure(:final error):
        final previousData = state.valueOrNull ?? [];
        state = AsyncValue<List<TransactionModel>>.error(
          error,
          StackTrace.current,
        ).copyWithPrevious(AsyncData(previousData));
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
      categoryId: category,
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
      categoryId: 'transfer',
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
}

final transactionNotifierProvider =
    AsyncNotifierProvider<TransactionNotifier, List<TransactionModel>>(() {
      return TransactionNotifier();
    });
