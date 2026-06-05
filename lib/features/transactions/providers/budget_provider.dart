import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/budget_repository.dart';
import '../domain/models/budget_model.dart';
import 'transaction_provider.dart';

class BudgetProgress {
  final BudgetModel budget;
  final double spent;
  
  BudgetProgress({required this.budget, required this.spent});
  
  double get percentage {
    if (budget.amountLimit == 0) return 1.0;
    final p = spent / budget.amountLimit;
    return p > 1.0 ? 1.0 : p;
  }
}

final currentMonthProvider = Provider<String>((ref) {
  final now = DateTime.now();
  return DateFormat('yyyy-MM').format(now);
});

final budgetNotifierProvider = AsyncNotifierProvider<BudgetNotifier, List<BudgetProgress>>(BudgetNotifier.new);

class BudgetNotifier extends AsyncNotifier<List<BudgetProgress>> {
  @override
  FutureOr<List<BudgetProgress>> build() async {
    final user = ref.watch(userProvider);
    if (user == null) {
      return [];
    }

    // Watch transactions so budget progress updates automatically when a transaction is added/deleted!
    final transactionsAsync = ref.watch(transactionNotifierProvider);
    final transactions = transactionsAsync.value ?? [];
    
    final repo = ref.read(budgetRepositoryProvider);
    final month = ref.watch(currentMonthProvider);
    final budgets = await repo.getBudgets(user.id, month);
    
    return budgets.map((b) {
      final categoryTxs = transactions.where((tx) {
        final txMonth = DateFormat('yyyy-MM').format(tx.createdAt);
        return tx.category == b.category && tx.type.toLowerCase() == 'expense' && txMonth == month;
      });
      
      final totalSpent = categoryTxs.fold<double>(0.0, (sum, tx) => sum + tx.amount);
      return BudgetProgress(budget: b, spent: totalSpent);
    }).toList();
  }

  Future<void> loadBudgets() async {
    // We can just invalidate self or read from repo
    ref.invalidateSelf();
  }

  Future<void> setBudget(String category, double amountLimit) async {
    final repo = ref.read(budgetRepositoryProvider);
    final user = ref.read(userProvider);
    final month = ref.read(currentMonthProvider);
    
    if (user == null) return;

    final newBudget = BudgetModel(
      userId: user.id,
      category: category,
      amountLimit: amountLimit,
      month: month,
      createdAt: DateTime.now().toUtc(),
    );

    try {
      await repo.setBudget(newBudget);
      ref.invalidateSelf();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteBudget(String id) async {
    final repo = ref.read(budgetRepositoryProvider);
    try {
      await repo.deleteBudget(id);
      ref.invalidateSelf();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
