// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_dao.dart';

// ignore_for_file: type=lint
mixin _$GoalDaoMixin on DatabaseAccessor<AppDatabase> {
  $WalletsTable get wallets => attachedDatabase.wallets;
  $GoalsTable get goals => attachedDatabase.goals;
  $GoalDepositsTable get goalDeposits => attachedDatabase.goalDeposits;
  GoalDaoManager get managers => GoalDaoManager(this);
}

class GoalDaoManager {
  final _$GoalDaoMixin _db;
  GoalDaoManager(this._db);
  $$WalletsTableTableManager get wallets =>
      $$WalletsTableTableManager(_db.attachedDatabase, _db.wallets);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db.attachedDatabase, _db.goals);
  $$GoalDepositsTableTableManager get goalDeposits =>
      $$GoalDepositsTableTableManager(_db.attachedDatabase, _db.goalDeposits);
}
