import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/providers/budget_provider.dart';

class InsightsState {
  final AsyncValue<String?> aiAdvice;

  InsightsState({this.aiAdvice = const AsyncValue.data(null)});

  InsightsState copyWith({AsyncValue<String?>? aiAdvice}) {
    return InsightsState(aiAdvice: aiAdvice ?? this.aiAdvice);
  }
}

final insightsProvider = NotifierProvider<InsightsNotifier, InsightsState>(() {
  return InsightsNotifier();
});

class InsightsNotifier extends Notifier<InsightsState> {
  @override
  InsightsState build() {
    return InsightsState();
  }

  Future<void> generateAiAnalysis() async {
    state = state.copyWith(aiAdvice: const AsyncValue.loading());

    try {
      // Small delay for micro-animation loading effect
      await Future.delayed(const Duration(milliseconds: 600));

      final transactionsAsync = ref.read(transactionNotifierProvider);
      final transactions = transactionsAsync.value ?? [];
      final budgetsAsync = ref.read(budgetNotifierProvider);
      final budgets = budgetsAsync.value ?? [];

      final formatCurrency = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );

      // Calculations
      double totalIncome = 0;
      double totalExpense = 0;
      final Map<String, double> categoryExpenses = {};

      for (final t in transactions) {
        if (t.type == 'income') {
          totalIncome += t.amount;
        } else if (t.type == 'expense') {
          totalExpense += t.amount;
          categoryExpenses[t.category] =
              (categoryExpenses[t.category] ?? 0) + t.amount;
        }
      }

      final List<String> tips = [];

      // Check budgets
      final List<Map<String, dynamic>> exceededBudgets = [];
      final List<Map<String, dynamic>> warningBudgets = [];

      for (final b in budgets) {
        final limit = b.budget.amountLimit;
        final spent = b.spent;
        final category = b.budget.category;

        if (spent > limit) {
          exceededBudgets.add({
            'category': category,
            'spent': spent,
            'limit': limit,
          });
        } else if (spent >= 0.8 * limit) {
          warningBudgets.add({
            'category': category,
            'spent': spent,
            'limit': limit,
          });
        }
      }

      // 1. Budget warnings
      if (exceededBudgets.isNotEmpty) {
        final eb = exceededBudgets.first;
        tips.add(
          "⚠️ Anggaran **${eb['category']}** telah melebihi batas (terpakai ${formatCurrency.format(eb['spent'])} dari ${formatCurrency.format(eb['limit'])}). Sebaiknya kurangi pengeluaran untuk kategori ini.",
        );
      } else if (warningBudgets.isNotEmpty) {
        final wb = warningBudgets.first;
        tips.add(
          "⚠️ Anggaran **${wb['category']}** sudah mendekati batas (terpakai ${formatCurrency.format(wb['spent'])} dari ${formatCurrency.format(wb['limit'])}). Tetap hemat dan batasi pengeluaran kategori ini.",
        );
      }

      // 2. Income vs Expense
      if (totalExpense > totalIncome && totalIncome > 0) {
        tips.add(
          "📈 Total pengeluaran bulan ini (${formatCurrency.format(totalExpense)}) melebihi pemasukan Anda (${formatCurrency.format(totalIncome)}). Tinjau kembali daftar prioritas belanja Anda untuk menghindari defisit.",
        );
      } else if (totalExpense > 0 && totalIncome > 0) {
        final savingsRate = ((totalIncome - totalExpense) / totalIncome) * 100;
        if (savingsRate < 20) {
          tips.add(
            "💡 Tingkat tabungan Anda bulan ini adalah ${savingsRate.toStringAsFixed(1)}%. Usahakan untuk menyisihkan minimal 20% pemasukan (${formatCurrency.format(totalIncome * 0.2)}) demi dana darurat.",
          );
        } else {
          tips.add(
            "✅ Keuangan Anda bulan ini cukup sehat! Pemasukan (${formatCurrency.format(totalIncome)}) lebih besar dari pengeluaran (${formatCurrency.format(totalExpense)}). Pertahankan kebiasaan baik ini.",
          );
        }
      }

      // 3. Highest spending category
      if (categoryExpenses.isNotEmpty) {
        final sortedCategories = categoryExpenses.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topCategory = sortedCategories.first;
        tips.add(
          "🔍 Kategori pengeluaran terbesar Anda adalah **${topCategory.key}** sebesar ${formatCurrency.format(topCategory.value)}. Coba periksa apakah ada pos pengeluaran yang bisa dipangkas.",
        );
      }

      // Fallback tips if not enough data
      if (tips.length < 3) {
        tips.add(
          "💡 Gunakan fitur **Impian (Goals)** untuk merencanakan pembelian besar secara bertahap agar arus kas harian Anda tidak terganggu.",
        );
      }
      if (tips.length < 3) {
        tips.add(
          "💡 Biasakan mencatat transaksi segera setelah terjadi agar analisis pengeluaran Anda tetap akurat dan terpantau.",
        );
      }

      // Limit to 3 points as requested
      final advice = tips.take(3).map((t) => "• $t").join("\n\n");

      state = state.copyWith(aiAdvice: AsyncValue.data(advice));
    } catch (e, st) {
      state = state.copyWith(aiAdvice: AsyncValue.error(e, st));
    }
  }
}
