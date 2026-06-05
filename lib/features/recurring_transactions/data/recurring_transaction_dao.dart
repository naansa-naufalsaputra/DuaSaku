import 'package:drift/drift.dart';
import '../../../core/local_db/app_database.dart';

part 'recurring_transaction_dao.g.dart';

@DriftAccessor(tables: [RecurringTransactions, RecurringExecutionLogs])
class RecurringTransactionDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringTransactionDaoMixin {
  RecurringTransactionDao(super.db);

  /// Watch all recurring transactions for a user, ordered by nextExecutionDate ascending.
  Stream<List<RecurringTransaction>> watchByUser(String userId) {
    return (select(recurringTransactions)
          ..where((t) => t.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.asc(t.nextExecutionDate)]))
        .watch();
  }

  /// Get active recurring transactions that are due for execution.
  /// Selects where status = 'active' AND nextExecutionDate <= [now].
  Future<List<RecurringTransaction>> getDueForExecution(DateTime now) {
    return (select(recurringTransactions)..where(
          (t) =>
              t.status.equals('active') &
              t.nextExecutionDate.isSmallerOrEqualValue(now),
        ))
        .get();
  }

  /// Get upcoming active recurring transactions within [days] days,
  /// limited to [limit] results, sorted ascending by nextExecutionDate.
  Future<List<RecurringTransaction>> getUpcoming(
    String userId,
    int days,
    int limit,
  ) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return (select(recurringTransactions)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.status.equals('active') &
                t.nextExecutionDate.isSmallerOrEqualValue(cutoff) &
                t.nextExecutionDate.isBiggerOrEqualValue(now),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.nextExecutionDate)])
          ..limit(limit))
        .get();
  }

  /// Insert a new recurring transaction.
  Future<void> insertRecurring(RecurringTransactionsCompanion entry) {
    return into(recurringTransactions).insert(entry);
  }

  /// Update an existing recurring transaction.
  Future<void> updateRecurring(RecurringTransactionsCompanion entry) {
    return (update(
      recurringTransactions,
    )..where((t) => t.id.equals(entry.id.value))).write(entry);
  }

  /// Delete a recurring transaction by ID.
  Future<void> deleteRecurring(String id) {
    return (delete(recurringTransactions)..where((t) => t.id.equals(id))).go();
  }

  /// Get a single recurring transaction by ID.
  Future<RecurringTransaction?> getById(String id) {
    return (select(
      recurringTransactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert an execution log entry.
  Future<void> insertLog(RecurringExecutionLogsCompanion entry) {
    return into(recurringExecutionLogs).insert(entry);
  }

  /// Get execution logs for a recurring transaction, ordered by executedAt descending.
  /// Optionally limited to [limit] results.
  Future<List<RecurringExecutionLog>> getLogsByRecurringId(
    String id, {
    int? limit,
  }) {
    final query = select(recurringExecutionLogs)
      ..where((t) => t.recurringTransactionId.equals(id))
      ..orderBy([(t) => OrderingTerm.desc(t.executedAt)]);
    if (limit != null) {
      query.limit(limit);
    }
    return query.get();
  }
}
