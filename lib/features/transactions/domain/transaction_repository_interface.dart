import '../../../core/utils/result.dart';
import '../../../core/utils/app_error.dart';
import 'models/transaction_model.dart';

abstract class TransactionRepositoryInterface {
  Stream<List<TransactionModel>> fetchTransactions(String userId);
  Future<Result<void, AppError>> insertTransaction(TransactionModel transaction);
  Future<Result<void, AppError>> deleteTransaction(int id);
  /// No-op in offline-first architecture. Reserved for future cloud sync implementation.
  @Deprecated('No-op in offline-first architecture. Reserved for future cloud sync implementation.')
  Future<void> syncPendingTransactions();
}
