import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/local_db/app_database.dart';
import '../../../../core/local_db/app_database_provider.dart';
import '../domain/models/budget_model.dart';
import '../domain/budget_repository_interface.dart';

final budgetRepositoryProvider = Provider<BudgetRepositoryInterface>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BudgetRepository(db);
});

class BudgetRepository implements BudgetRepositoryInterface {
  final AppDatabase _db;

  BudgetRepository(this._db);

  @override
  Future<List<BudgetModel>> getBudgets(String userId, String month) async {
    final query =
        _db.select(_db.budgets).join([
          innerJoin(
            _db.categories,
            _db.categories.id.equalsExp(_db.budgets.categoryId),
          ),
        ])..where(
          _db.budgets.userId.equals(userId) & _db.budgets.month.equals(month),
        );

    final rows = await query.get();
    return rows.map((row) {
      final b = row.readTable(_db.budgets);
      final c = row.readTable(_db.categories);
      return BudgetModel(
        id: b.id,
        userId: b.userId,
        category: c.name,
        amountLimit: b.amount,
        month: b.month,
        createdAt: b.createdAt,
      );
    }).toList();
  }

  @override
  Future<BudgetModel> setBudget(BudgetModel budget) async {
    final category =
        await (_db.select(_db.categories)..where(
              (c) =>
                  c.name.equals(budget.category) &
                  c.userId.equals(budget.userId),
            ))
            .getSingleOrNull();
    final categoryId = category?.id ?? 'food';

    // Look for existing budget for this month, categoryId, and userId to keep the same primary key ID
    final existing =
        await (_db.select(_db.budgets)..where(
              (b) =>
                  b.month.equals(budget.month) &
                  b.categoryId.equals(categoryId) &
                  b.userId.equals(budget.userId),
            ))
            .getSingleOrNull();

    final id = existing?.id ?? budget.id ?? const Uuid().v4();

    await _db
        .into(_db.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: id,
            userId: Value(budget.userId),
            categoryId: categoryId,
            amount: budget.amountLimit,
            month: budget.month,
            createdAt: budget.createdAt,
          ),
          mode: InsertMode.insertOrReplace,
        );

    return BudgetModel(
      id: id,
      userId: budget.userId,
      category: budget.category,
      amountLimit: budget.amountLimit,
      month: budget.month,
      createdAt: budget.createdAt,
    );
  }

  @override
  Future<void> deleteBudget(String id) async {
    await (_db.delete(_db.budgets)..where((b) => b.id.equals(id))).go();
  }

  @override
  Future<double?> getSuggestedBudget(String userId, String categoryId) async {
    final now = DateTime.now();
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);

    // Get total spending for this category in last 3 months
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.amount.sum()])
      ..where(
        _db.transactions.userId.equals(userId) &
            _db.transactions.categoryId.equals(categoryId) &
            _db.transactions.type.equals('expense') &
            _db.transactions.date.isBiggerOrEqualValue(threeMonthsAgo),
      );

    final result = await query.getSingleOrNull();
    final totalSpending = result?.read(_db.transactions.amount.sum());

    if (totalSpending == null || totalSpending == 0) {
      return null;
    }

    // Calculate average per month
    final monthsDiff =
        now.month -
        threeMonthsAgo.month +
        (now.year - threeMonthsAgo.year) * 12;
    final averagePerMonth = totalSpending / monthsDiff;

    // Round up to nearest 10k for cleaner suggestion
    return (averagePerMonth / 10000).ceil() * 10000.0;
  }
}
