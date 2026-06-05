import 'package:drift/drift.dart';
import '../../../core/local_db/app_database.dart';

part 'goal_dao.g.dart';

@DriftAccessor(tables: [Goals, GoalDeposits])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  /// Insert a new goal.
  Future<void> insertGoal(GoalsCompanion entry) {
    return into(goals).insert(entry);
  }

  /// Get a single goal by ID.
  Future<Goal?> getGoalById(String id) {
    return (select(goals)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Update an existing goal.
  Future<void> updateGoal(GoalsCompanion entry) {
    return (update(
      goals,
    )..where((t) => t.id.equals(entry.id.value))).write(entry);
  }

  /// Delete a goal by ID (cascade deletes associated deposits).
  Future<void> deleteGoal(String id) {
    return (delete(goals)..where((t) => t.id.equals(id))).go();
  }

  /// Watch all goals for a user, with optional status filter,
  /// ordered by createdAt descending (newest first).
  Stream<List<Goal>> watchGoalsByUser(String userId, {String? status}) {
    final query = select(goals)
      ..where((t) {
        final conditions = <Expression<bool>>[t.userId.equals(userId)];
        if (status != null) {
          conditions.add(t.status.equals(status));
        }
        return Expression.and(conditions);
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  /// Get all goals for a user, with optional status filter,
  /// ordered by createdAt descending (newest first).
  Future<List<Goal>> getGoalsByUser(String userId, {String? status}) {
    final query = select(goals)
      ..where((t) {
        final conditions = <Expression<bool>>[t.userId.equals(userId)];
        if (status != null) {
          conditions.add(t.status.equals(status));
        }
        return Expression.and(conditions);
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.get();
  }

  /// Insert a new deposit record.
  Future<void> insertDeposit(GoalDepositsCompanion entry) {
    return into(goalDeposits).insert(entry);
  }

  /// Watch all deposits for a goal, ordered by createdAt descending.
  Stream<List<GoalDeposit>> watchDepositsByGoal(String goalId) {
    return (select(goalDeposits)
          ..where((t) => t.goalId.equals(goalId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Get all deposits for a goal, ordered by createdAt descending.
  Future<List<GoalDeposit>> getDepositsByGoal(String goalId) {
    return (select(goalDeposits)
          ..where((t) => t.goalId.equals(goalId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get a goal by its linked wallet ID (only active goals).
  Future<Goal?> getGoalByLinkedWallet(String walletId) {
    return (select(goals)..where(
          (t) => t.linkedWalletId.equals(walletId) & t.status.equals('active'),
        ))
        .getSingleOrNull();
  }

  /// Check if a wallet is already linked to an active goal.
  Future<bool> isWalletLinked(String walletId) async {
    final goal = await getGoalByLinkedWallet(walletId);
    return goal != null;
  }

  /// Mark a goal as completed with the given completion timestamp.
  Future<void> markCompleted(String goalId, DateTime completedAt) {
    return (update(goals)..where((t) => t.id.equals(goalId))).write(
      GoalsCompanion(
        status: const Value('completed'),
        completedAt: Value(completedAt),
      ),
    );
  }

  /// Archive a goal (set status to 'archived').
  Future<void> archiveGoal(String goalId) {
    return (update(goals)..where((t) => t.id.equals(goalId))).write(
      const GoalsCompanion(status: Value('archived')),
    );
  }
}
