import '../../../core/utils/result.dart';
import '../../../core/utils/app_error.dart';
import 'models/transaction_model.dart';
import 'transaction_filters.dart';

abstract class TransactionRepositoryInterface {
  Stream<List<TransactionModel>> fetchTransactions(String userId);

  /// Fetch all transactions for a user once (one-off read).
  Future<Result<List<TransactionModel>, AppError>> getTransactionsOnce(
    String userId,
  );

  /// Fetch transactions with filters and dynamic limit for pagination
  Stream<List<TransactionModel>> fetchTransactionsFiltered(
    String userId,
    TransactionFilters filters,
    int limit,
  );

  Future<Result<void, AppError>> insertTransaction(
    TransactionModel transaction,
  );
  Future<Result<void, AppError>> deleteTransaction(int id);
  Future<Result<void, AppError>> updateTransaction(
    TransactionModel transaction,
    TransactionModel oldTransaction,
  );

  /// Get total spending for a category in a given month.
  Future<double> getTotalSpendingForCategory(
    String userId,
    String categoryId,
    String budgetMonth,
  );

  /// Get total spending across all categories in a given month.
  Future<double> getTotalSpendingAllCategories(
    String userId,
    String budgetMonth,
  );
}
