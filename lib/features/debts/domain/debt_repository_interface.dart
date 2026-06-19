import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import 'models/debt_model.dart';

abstract class DebtRepositoryInterface {
  /// Get all debts for user
  Future<Result<List<DebtModel>, AppError>> getDebts(String userId);

  /// Get debt by ID
  Future<Result<DebtModel?, AppError>> getDebtById(String debtId);

  /// Get debts by status
  Future<Result<List<DebtModel>, AppError>> getDebtsByStatus(
    String userId,
    String status,
  );

  /// Get overdue debts
  Future<Result<List<DebtModel>, AppError>> getOverdueDebts(String userId);

  /// Create debt/loan
  Future<Result<void, AppError>> createDebt(DebtModel debt);

  /// Update debt
  Future<Result<void, AppError>> updateDebt(DebtModel debt);

  /// Delete debt
  Future<Result<void, AppError>> deleteDebt(String debtId);

  /// Add payment to debt
  Future<Result<void, AppError>> addPayment(
    String debtId,
    DebtPaymentModel payment,
  );

  /// Get payment history for debt
  Future<Result<List<DebtPaymentModel>, AppError>> getPaymentHistory(
    String debtId,
  );

  /// Watch all debts (reactive)
  Stream<List<DebtModel>> watchDebts(String userId);

  /// Watch debts by status (reactive)
  Stream<List<DebtModel>> watchDebtsByStatus(String userId, String status);
}
