import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/local_db/app_database_provider.dart';
import '../domain/insights_repository_interface.dart';

final insightsRepositoryProvider = Provider<InsightsRepositoryInterface>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return InsightsRepository(db);
});

class InsightsRepository implements InsightsRepositoryInterface {
  final AppDatabase _db;

  InsightsRepository(this._db);

  @override
  Future<String> getFinancialAdvice() async {
    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final query = _db.select(_db.transactions).join([
        leftOuterJoin(
          _db.categories,
          _db.categories.id.equalsExp(_db.transactions.categoryId),
        ),
      ])..where(_db.transactions.date.isBiggerOrEqualValue(firstDayOfMonth));

      final rows = await query.get();

      if (rows.isEmpty) {
        return "💡 Belum ada data transaksi bulan ini. Yuk, mulai catat pemasukan dan pengeluaranmu!";
      }

      double totalIncome = 0;
      double totalExpense = 0;
      final Map<String, double> categoryExpenses = {};

      for (final row in rows) {
        final tx = row.readTable(_db.transactions);
        final cat = row.readTableOrNull(_db.categories);
        final categoryName = cat?.name ?? 'Uncategorized';

        if (tx.type == 'income') {
          totalIncome += tx.amount;
        } else if (tx.type == 'expense') {
          totalExpense += tx.amount;
          categoryExpenses[categoryName] =
              (categoryExpenses[categoryName] ?? 0) + tx.amount;
        }
      }

      final List<String> insights = [];

      // 1. Expense Ratio Alert
      if (totalIncome > 0) {
        final ratio = totalExpense / totalIncome;
        if (ratio > 0.8) {
          insights.add(
            "⚠️ Peringatan: Pengeluaranmu sudah mencapai ${(ratio * 100).toStringAsFixed(0)}% dari total pemasukan! Kurangi pengeluaran non-esensial agar tidak defisit.",
          );
        } else if (totalExpense > totalIncome) {
          insights.add(
            "⚠️ Peringatan: Pengeluaranmu bulan ini sudah melebihi total pemasukan! Segera evaluasi anggaran belanja Anda.",
          );
        } else {
          final savingsRatio =
              ((totalIncome - totalExpense) / totalIncome) * 100;
          insights.add(
            "✅ Bagus! Kamu berhasil menyisihkan ${savingsRatio.toStringAsFixed(0)}% dari pemasukanmu bulan ini sebagai tabungan.",
          );
        }
      } else if (totalExpense > 0) {
        insights.add(
          "⚠️ Perhatian: Kamu memiliki pengeluaran sebesar Rp ${totalExpense.toStringAsFixed(0)} tanpa adanya catatan pemasukan bulan ini.",
        );
      }

      // 2. Highest Expense Category Highlight
      if (categoryExpenses.isNotEmpty) {
        final highestExpense = categoryExpenses.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        insights.add(
          "📊 Pengeluaran terbesarmu bulan ini ada di kategori *${highestExpense.key}* sebesar Rp ${highestExpense.value.toStringAsFixed(0)}. Yuk, coba direm!",
        );
      }

      // 3. Summary info
      insights.add(
        "ℹ️ Ringkasan: Total Pemasukan Rp ${totalIncome.toStringAsFixed(0)} | Total Pengeluaran Rp ${totalExpense.toStringAsFixed(0)}",
      );

      return insights.join("\n\n");
    } catch (e) {
      return "Gagal memuat saran keuangan: $e";
    }
  }
}
