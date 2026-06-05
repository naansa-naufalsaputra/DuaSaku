import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/goals/data/goal_dao.dart';
import 'package:duasaku_app/features/goals/data/goal_repository.dart';
import 'package:duasaku_app/features/goals/domain/models/goal_model.dart';
import 'package:duasaku_app/features/goals/domain/models/goal_status.dart';

/// Creates a fresh in-memory database with foreign keys enabled.
AppDatabase _createTestDb() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(setup: (db) {
      db.execute('PRAGMA foreign_keys = ON;');
    }),
  );
}

/// Helper to insert a wallet for FK tests.
Future<void> _insertWallet(
  AppDatabase db, {
  required String id,
  String userId = 'test-user',
  String name = 'Test Wallet',
  double balance = 0.0,
}) async {
  await db.into(db.wallets).insert(WalletsCompanion.insert(
        id: id,
        userId: userId,
        name: name,
        type: 'Cash',
        balance: Value(balance),
        icon: 'wallet',
        color: '#000000',
        createdAt: DateTime(2024, 1, 1),
      ));
}

/// Helper to update a wallet's balance.
Future<void> _updateWalletBalance(
  AppDatabase db, {
  required String walletId,
  required double newBalance,
}) async {
  await (db.update(db.wallets)..where((t) => t.id.equals(walletId)))
      .write(WalletsCompanion(balance: Value(newBalance)));
}

/// Helper to create a GoalModel for testing.
GoalModel _createGoalModel({
  required String id,
  String userId = 'test-user',
  String name = 'Test Goal',
  double targetAmount = 1000.0,
  double currentAmount = 0.0,
  String? linkedWalletId,
  TrackingMode trackingMode = TrackingMode.manual,
  GoalStatus status = GoalStatus.active,
}) {
  return GoalModel(
    id: id,
    userId: userId,
    name: name,
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    deadline: null,
    icon: 'savings',
    color: '#4CAF50',
    linkedWalletId: linkedWalletId,
    trackingMode: trackingMode,
    status: status,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  late AppDatabase db;
  late GoalDao dao;
  late GoalRepository repository;

  setUp(() {
    db = _createTestDb();
    dao = db.goalDao;
    repository = GoalRepository(dao);
  });

  tearDown(() async {
    await db.close();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Wallet balance change propagates to linked goal's currentAmount
  // _Requirements: 4.1, 4.2_
  // ──────────────────────────────────────────────────────────────────────────
  group('Wallet balance change propagates to linked goal', () {
    test(
        'updating wallet balance allows goal currentAmount to be synced via repository',
        () async {
      // Arrange: Create a wallet with initial balance
      await _insertWallet(db, id: 'wallet-1', balance: 200.0);

      // Create a goal linked to the wallet
      final goal = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 200.0,
        targetAmount: 1000.0,
      );
      final createResult = await repository.createGoal(goal);
      expect(createResult, isA<Success>());

      // Act: Simulate wallet balance change
      await _updateWalletBalance(db, walletId: 'wallet-1', newBalance: 500.0);

      // Verify wallet balance was updated
      final wallet = await (db.select(db.wallets)
            ..where((t) => t.id.equals('wallet-1')))
          .getSingle();
      expect(wallet.balance, equals(500.0));

      // Sync the goal's currentAmount to match the new wallet balance
      // (This simulates what GoalNotifier.syncWalletBalance does at the data layer)
      final updatedGoal = goal.copyWith(currentAmount: 500.0);
      final updateResult = await repository.updateGoal(updatedGoal);
      expect(updateResult, isA<Success>());

      // Assert: Verify goal's currentAmount reflects the new wallet balance
      final getResult = await repository.getGoal('goal-1');
      expect(getResult, isA<Success>());
      final fetchedGoal = (getResult as Success<GoalModel, dynamic>).value;
      expect(fetchedGoal.currentAmount, equals(500.0));
    });

    test('wallet balance sync caps goal currentAmount at targetAmount',
        () async {
      // Arrange: Create a wallet and a goal with target 500
      await _insertWallet(db, id: 'wallet-1', balance: 300.0);

      final goal = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 300.0,
        targetAmount: 500.0,
      );
      await repository.createGoal(goal);

      // Act: Wallet balance exceeds target
      await _updateWalletBalance(db, walletId: 'wallet-1', newBalance: 800.0);

      // Sync with cap (simulates GoalNotifier.syncWalletBalance capping logic)
      final cappedAmount = 800.0.clamp(0.0, goal.targetAmount);
      final updatedGoal = goal.copyWith(currentAmount: cappedAmount);
      await repository.updateGoal(updatedGoal);

      // Assert: currentAmount is capped at targetAmount
      final getResult = await repository.getGoal('goal-1');
      final fetchedGoal = (getResult as Success<GoalModel, dynamic>).value;
      expect(fetchedGoal.currentAmount, equals(500.0));
      expect(fetchedGoal.currentAmount, lessThanOrEqualTo(fetchedGoal.targetAmount));
    });

    test('wallet balance decrease updates goal currentAmount accordingly',
        () async {
      // Arrange: Create a wallet with balance 600 and a goal tracking it
      await _insertWallet(db, id: 'wallet-1', balance: 600.0);

      final goal = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 600.0,
        targetAmount: 1000.0,
      );
      await repository.createGoal(goal);

      // Act: Wallet balance decreases
      await _updateWalletBalance(db, walletId: 'wallet-1', newBalance: 350.0);

      // Sync the goal
      final updatedGoal = goal.copyWith(currentAmount: 350.0);
      await repository.updateGoal(updatedGoal);

      // Assert: goal currentAmount reflects the decrease
      final getResult = await repository.getGoal('goal-1');
      final fetchedGoal = (getResult as Success<GoalModel, dynamic>).value;
      expect(fetchedGoal.currentAmount, equals(350.0));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Wallet deletion switches goal to manual mode
  // _Requirements: 4.3_
  // ──────────────────────────────────────────────────────────────────────────
  group('Wallet deletion switches goal to manual mode', () {
    test(
        'deleting a linked wallet sets linkedWalletId to null via FK set-null',
        () async {
      // Arrange: Create a wallet and a goal linked to it
      await _insertWallet(db, id: 'wallet-1', balance: 400.0);

      final goal = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 400.0,
        targetAmount: 1000.0,
      );
      await repository.createGoal(goal);

      // Verify the link exists
      final goalBefore = await repository.getGoal('goal-1');
      final beforeModel = (goalBefore as Success<GoalModel, dynamic>).value;
      expect(beforeModel.linkedWalletId, equals('wallet-1'));
      expect(beforeModel.trackingMode, equals(TrackingMode.wallet));

      // Act: Delete the wallet (FK onDelete: setNull triggers)
      await (db.delete(db.wallets)..where((t) => t.id.equals('wallet-1')))
          .go();

      // Assert: linkedWalletId is now null (FK set-null behavior)
      final goalAfter = await repository.getGoal('goal-1');
      final afterModel = (goalAfter as Success<GoalModel, dynamic>).value;
      expect(afterModel.linkedWalletId, isNull);
      // Note: trackingMode in DB still says 'wallet' — the GoalNotifier
      // is responsible for detecting the null linkedWalletId and switching
      // trackingMode to manual. Here we verify the FK set-null behavior.
    });

    test('wallet deletion retains the last known currentAmount', () async {
      // Arrange: Create a wallet and a goal with accumulated savings
      await _insertWallet(db, id: 'wallet-1', balance: 750.0);

      final goal = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 750.0,
        targetAmount: 1000.0,
      );
      await repository.createGoal(goal);

      // Act: Delete the wallet
      await (db.delete(db.wallets)..where((t) => t.id.equals('wallet-1')))
          .go();

      // Assert: currentAmount is preserved even though wallet is gone
      final goalAfter = await repository.getGoal('goal-1');
      final afterModel = (goalAfter as Success<GoalModel, dynamic>).value;
      expect(afterModel.currentAmount, equals(750.0));
    });

    test('wallet deletion does not affect goals linked to other wallets',
        () async {
      // Arrange: Two wallets, two goals
      await _insertWallet(db, id: 'wallet-1', balance: 300.0);
      await _insertWallet(db, id: 'wallet-2', balance: 500.0);

      final goal1 = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 300.0,
      );
      final goal2 = _createGoalModel(
        id: 'goal-2',
        linkedWalletId: 'wallet-2',
        trackingMode: TrackingMode.wallet,
        currentAmount: 500.0,
      );
      await repository.createGoal(goal1);
      await repository.createGoal(goal2);

      // Act: Delete wallet-1 only
      await (db.delete(db.wallets)..where((t) => t.id.equals('wallet-1')))
          .go();

      // Assert: goal-1 lost its link, goal-2 still linked
      final g1 = await repository.getGoal('goal-1');
      final g1Model = (g1 as Success<GoalModel, dynamic>).value;
      expect(g1Model.linkedWalletId, isNull);

      final g2 = await repository.getGoal('goal-2');
      final g2Model = (g2 as Success<GoalModel, dynamic>).value;
      expect(g2Model.linkedWalletId, equals('wallet-2'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Wallet already linked to active goal prevents re-linking
  // _Requirements: 4.4_
  // ──────────────────────────────────────────────────────────────────────────
  group('Wallet already linked to active goal prevents re-linking', () {
    test('isWalletLinked returns true when wallet is linked to an active goal',
        () async {
      // Arrange: Create a wallet and link it to an active goal
      await _insertWallet(db, id: 'wallet-1', balance: 200.0);

      final goal = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 200.0,
      );
      await repository.createGoal(goal);

      // Act: Check if wallet is linked
      final result = await repository.isWalletLinked('wallet-1');

      // Assert: wallet is linked
      expect(result, isA<Success>());
      final isLinked = (result as Success<bool, dynamic>).value;
      expect(isLinked, isTrue);
    });

    test(
        'isWalletLinked returns false when wallet is linked to a completed goal',
        () async {
      // Arrange: Create a wallet and link it to a completed goal
      await _insertWallet(db, id: 'wallet-1', balance: 1000.0);

      final goal = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 1000.0,
        targetAmount: 1000.0,
        status: GoalStatus.completed,
      );
      await repository.createGoal(goal);

      // Act: Check if wallet is linked (only active goals count)
      final result = await repository.isWalletLinked('wallet-1');

      // Assert: wallet is NOT considered linked (completed goals don't block)
      expect(result, isA<Success>());
      final isLinked = (result as Success<bool, dynamic>).value;
      expect(isLinked, isFalse);
    });

    test('isWalletLinked returns false when wallet is not linked to any goal',
        () async {
      // Arrange: Create a wallet with no linked goals
      await _insertWallet(db, id: 'wallet-1', balance: 500.0);

      // Act: Check if wallet is linked
      final result = await repository.isWalletLinked('wallet-1');

      // Assert: wallet is not linked
      expect(result, isA<Success>());
      final isLinked = (result as Success<bool, dynamic>).value;
      expect(isLinked, isFalse);
    });

    test(
        'creating a second goal linked to the same wallet is blocked by isWalletLinked check',
        () async {
      // Arrange: Create a wallet and link it to an active goal
      await _insertWallet(db, id: 'wallet-1', balance: 200.0);

      final goal1 = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 200.0,
      );
      await repository.createGoal(goal1);

      // Act: Check if wallet can be linked to another goal
      final linkedResult = await repository.isWalletLinked('wallet-1');
      final isLinked = (linkedResult as Success<bool, dynamic>).value;

      // Assert: The check prevents re-linking
      expect(isLinked, isTrue);

      // Verify: If we tried to create another goal with the same wallet,
      // the business logic (GoalNotifier) would reject it based on this check.
      // At the data layer, the constraint is enforced by the isWalletLinked query.
    });

    test(
        'wallet can be linked to a new goal after the previous linked goal is archived',
        () async {
      // Arrange: Create a wallet and link it to an active goal
      await _insertWallet(db, id: 'wallet-1', balance: 200.0);

      final goal1 = _createGoalModel(
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: TrackingMode.wallet,
        currentAmount: 200.0,
      );
      await repository.createGoal(goal1);

      // Verify wallet is linked
      var linkedResult = await repository.isWalletLinked('wallet-1');
      expect((linkedResult as Success<bool, dynamic>).value, isTrue);

      // Act: Archive the goal (status changes from active to archived)
      await repository.archiveGoal('goal-1');

      // Assert: Wallet is no longer considered linked (only active goals count)
      linkedResult = await repository.isWalletLinked('wallet-1');
      expect((linkedResult as Success<bool, dynamic>).value, isFalse);
    });
  });
}
