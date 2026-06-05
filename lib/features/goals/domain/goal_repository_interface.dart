import '../../../core/utils/result.dart';
import '../../../core/utils/app_error.dart';
import 'models/goal_model.dart';
import 'models/goal_deposit_model.dart';
import 'models/goal_status.dart';

/// Abstract interface for goal repository operations.
/// Concrete implementations handle the actual data source (Drift, API, etc.).
///
/// Methods that can fail with expected errors (DB constraint violations,
/// not-found, validation) return [Result<T, AppError>] instead of throwing
/// exceptions. Stream-based watch queries are used for real-time UI updates.
abstract class GoalRepositoryInterface {
  // Goal CRUD
  Future<Result<GoalModel, AppError>> createGoal(GoalModel goal);
  Future<Result<GoalModel, AppError>> getGoal(String goalId);
  Future<Result<void, AppError>> updateGoal(GoalModel goal);
  Future<Result<void, AppError>> deleteGoal(String goalId);

  // Goal queries
  Stream<List<GoalModel>> watchGoals(String userId, {GoalStatus? status});
  Future<Result<List<GoalModel>, AppError>> getGoals(
    String userId, {
    GoalStatus? status,
  });

  // Deposit operations
  Future<Result<void, AppError>> addDeposit(GoalDepositModel deposit);
  Stream<List<GoalDepositModel>> watchDeposits(String goalId);
  Future<Result<List<GoalDepositModel>, AppError>> getDeposits(String goalId);

  // Wallet linking
  Future<Result<bool, AppError>> isWalletLinked(String walletId);
  Future<Result<GoalModel?, AppError>> getGoalByLinkedWallet(String walletId);

  // Completion
  Future<Result<void, AppError>> markCompleted(
    String goalId,
    DateTime completedAt,
  );
  Future<Result<void, AppError>> archiveGoal(String goalId);
}
