import '../../../core/utils/result.dart';
import '../../../core/utils/app_error.dart';
import 'models/transaction_model.dart';
import 'transaction_filters.dart';

abstract class TransactionRepositoryInterface {
  Stream<List<TransactionModel>> fetchTransactions(String userId);
  
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
}
