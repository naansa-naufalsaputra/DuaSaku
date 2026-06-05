// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_transaction_dao.dart';

// ignore_for_file: type=lint
mixin _$RecurringTransactionDaoMixin on DatabaseAccessor<AppDatabase> {
  $WalletsTable get wallets => attachedDatabase.wallets;
  $CategoriesTable get categories => attachedDatabase.categories;
  $RecurringTransactionsTable get recurringTransactions =>
      attachedDatabase.recurringTransactions;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $RecurringExecutionLogsTable get recurringExecutionLogs =>
      attachedDatabase.recurringExecutionLogs;
  RecurringTransactionDaoManager get managers =>
      RecurringTransactionDaoManager(this);
}

class RecurringTransactionDaoManager {
  final _$RecurringTransactionDaoMixin _db;
  RecurringTransactionDaoManager(this._db);
  $$WalletsTableTableManager get wallets =>
      $$WalletsTableTableManager(_db.attachedDatabase, _db.wallets);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$RecurringTransactionsTableTableManager get recurringTransactions =>
      $$RecurringTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.recurringTransactions,
      );
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$RecurringExecutionLogsTableTableManager get recurringExecutionLogs =>
      $$RecurringExecutionLogsTableTableManager(
        _db.attachedDatabase,
        _db.recurringExecutionLogs,
      );
}
