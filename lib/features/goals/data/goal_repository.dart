import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import '../../../core/local_db/app_database.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/result.dart';
import '../domain/goal_repository_interface.dart';
import '../domain/models/goal_deposit_model.dart';
import '../domain/models/goal_model.dart';
import '../domain/models/goal_status.dart';
import 'goal_dao.dart';

/// Concrete implementation of [GoalRepositoryInterface] using Drift.
///
/// Maps between Drift companion/data classes and domain models,
/// wrapping all DAO calls in try-catch returning [Result<T, AppError>].
class GoalRepository implements GoalRepositoryInterface {
  final GoalDao _dao;

  GoalRepository(this._dao);

  // ---------------------------------------------------------------------------
  // Goal CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<Result<GoalModel, AppError>> createGoal(GoalModel goal) async {
    try {
      final companion = _goalModelToCompanion(goal);
      await _dao.insertGoal(companion);
      return Success(goal);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Result<GoalModel, AppError>> getGoal(String goalId) async {
    try {
      final row = await _dao.getGoalById(goalId);
      if (row == null) {
        return Failure(AppError.notFound('Goal not found: $goalId'));
      }
      return Success(_goalFromDrift(row));
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Result<void, AppError>> updateGoal(GoalModel goal) async {
    try {
      final companion = _goalModelToCompanion(goal);
      await _dao.updateGoal(companion);
      return const Success(null);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Result<void, AppError>> deleteGoal(String goalId) async {
    try {
      await _dao.deleteGoal(goalId);
      return const Success(null);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Goal queries
  // ---------------------------------------------------------------------------

  @override
  Stream<List<GoalModel>> watchGoals(String userId, {GoalStatus? status}) {
    return _dao
        .watchGoalsByUser(userId, status: status?.name)
        .map((rows) => rows.map(_goalFromDrift).toList());
  }

  @override
  Future<Result<List<GoalModel>, AppError>> getGoals(
    String userId, {
    GoalStatus? status,
  }) async {
    try {
      final rows = await _dao.getGoalsByUser(userId, status: status?.name);
      return Success(rows.map(_goalFromDrift).toList());
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Deposit operations
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void, AppError>> addDeposit(GoalDepositModel deposit) async {
    try {
      final companion = _depositModelToCompanion(deposit);
      await _dao.insertDeposit(companion);
      return const Success(null);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<GoalDepositModel>> watchDeposits(String goalId) {
    return _dao
        .watchDepositsByGoal(goalId)
        .map((rows) => rows.map(_depositFromDrift).toList());
  }

  @override
  Future<Result<List<GoalDepositModel>, AppError>> getDeposits(
    String goalId,
  ) async {
    try {
      final rows = await _dao.getDepositsByGoal(goalId);
      return Success(rows.map(_depositFromDrift).toList());
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Wallet linking
  // ---------------------------------------------------------------------------

  @override
  Future<Result<bool, AppError>> isWalletLinked(String walletId) async {
    try {
      final linked = await _dao.isWalletLinked(walletId);
      return Success(linked);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Result<GoalModel?, AppError>> getGoalByLinkedWallet(
    String walletId,
  ) async {
    try {
      final row = await _dao.getGoalByLinkedWallet(walletId);
      return Success(row != null ? _goalFromDrift(row) : null);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Completion
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void, AppError>> markCompleted(
    String goalId,
    DateTime completedAt,
  ) async {
    try {
      await _dao.markCompleted(goalId, completedAt);
      return const Success(null);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Result<void, AppError>> archiveGoal(String goalId) async {
    try {
      await _dao.archiveGoal(goalId);
      return const Success(null);
    } on SqliteException catch (e) {
      return Failure(AppError.database(e.message));
    } catch (e) {
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  /// Convert a Drift [Goal] data class to a domain [GoalModel].
  GoalModel _goalFromDrift(Goal row) {
    return GoalModel(
      id: row.id,
      userId: row.userId,
      name: row.name,
      targetAmount: row.targetAmount,
      currentAmount: row.currentAmount,
      deadline: row.deadline,
      icon: row.icon,
      color: row.color,
      linkedWalletId: row.linkedWalletId,
      trackingMode: TrackingMode.fromString(row.trackingMode),
      status: GoalStatus.fromString(row.status),
      completedAt: row.completedAt,
      notifiedMilestones: _parseMilestones(row.notifiedMilestones),
      createdAt: row.createdAt,
    );
  }

  /// Convert a domain [GoalModel] to a Drift [GoalsCompanion] for writes.
  GoalsCompanion _goalModelToCompanion(GoalModel goal) {
    return GoalsCompanion(
      id: Value(goal.id),
      userId: Value(goal.userId),
      name: Value(goal.name),
      targetAmount: Value(goal.targetAmount),
      currentAmount: Value(goal.currentAmount),
      deadline: Value(goal.deadline),
      icon: Value(goal.icon),
      color: Value(goal.color),
      linkedWalletId: Value(goal.linkedWalletId),
      trackingMode: Value(goal.trackingMode.name),
      status: Value(goal.status.name),
      completedAt: Value(goal.completedAt),
      notifiedMilestones: Value(_encodeMilestones(goal.notifiedMilestones)),
      createdAt: Value(goal.createdAt),
    );
  }

  /// Convert a Drift [GoalDeposit] data class to a domain [GoalDepositModel].
  GoalDepositModel _depositFromDrift(GoalDeposit row) {
    return GoalDepositModel(
      id: row.id,
      goalId: row.goalId,
      amount: row.amount,
      note: row.note,
      createdAt: row.createdAt,
    );
  }

  /// Convert a domain [GoalDepositModel] to a Drift [GoalDepositsCompanion].
  GoalDepositsCompanion _depositModelToCompanion(GoalDepositModel deposit) {
    return GoalDepositsCompanion(
      id: Value(deposit.id),
      goalId: Value(deposit.goalId),
      amount: Value(deposit.amount),
      note: Value(deposit.note),
      createdAt: Value(deposit.createdAt),
    );
  }

  /// Parse a comma-separated milestones string into a [Set<int>].
  Set<int> _parseMilestones(String value) {
    if (value.isEmpty) return {};
    return value
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => int.parse(s.trim()))
        .toSet();
  }

  /// Encode a [Set<int>] of milestones into a comma-separated string.
  String _encodeMilestones(Set<int> milestones) {
    if (milestones.isEmpty) return '';
    return milestones.join(',');
  }
}
