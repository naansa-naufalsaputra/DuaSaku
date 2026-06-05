import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/features/goals/data/goal_dao.dart';

/// Creates a fresh in-memory database with foreign keys enabled.
AppDatabase _createTestDb() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON;');
      },
    ),
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
  await db
      .into(db.wallets)
      .insert(
        WalletsCompanion.insert(
          id: id,
          userId: userId,
          name: name,
          type: 'Cash',
          balance: Value(balance),
          icon: 'wallet',
          color: '#000000',
          createdAt: DateTime(2024, 1, 1),
        ),
      );
}

/// Helper to insert a goal.
Future<void> _insertGoal(
  GoalDao dao, {
  required String id,
  String userId = 'test-user',
  String name = 'Test Goal',
  double targetAmount = 1000.0,
  double currentAmount = 0.0,
  String? linkedWalletId,
  String trackingMode = 'manual',
  String status = 'active',
  DateTime? createdAt,
}) async {
  await dao.insertGoal(
    GoalsCompanion.insert(
      id: id,
      userId: userId,
      name: name,
      targetAmount: targetAmount,
      currentAmount: Value(currentAmount),
      icon: 'savings',
      color: '#4CAF50',
      linkedWalletId: Value(linkedWalletId),
      trackingMode: trackingMode,
      status: Value(status),
      createdAt: createdAt ?? DateTime(2024, 1, 1),
    ),
  );
}

/// Helper to insert a deposit.
Future<void> _insertDeposit(
  GoalDao dao, {
  required String id,
  required String goalId,
  double amount = 100.0,
  String? note,
  DateTime? createdAt,
}) async {
  await dao.insertDeposit(
    GoalDepositsCompanion.insert(
      id: id,
      goalId: goalId,
      amount: amount,
      note: Value(note),
      createdAt: createdAt ?? DateTime(2024, 1, 15),
    ),
  );
}

void main() {
  late AppDatabase db;
  late GoalDao dao;

  setUp(() {
    db = _createTestDb();
    dao = db.goalDao;
  });

  tearDown(() async {
    await db.close();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // CRUD Operations
  // _Requirements: 9.3, 9.4, 9.5, 9.6_
  // ──────────────────────────────────────────────────────────────────────────
  group('CRUD Operations', () {
    test('insertGoal and getGoalById returns the inserted goal', () async {
      await _insertGoal(dao, id: 'goal-1', name: 'Vacation Fund');

      final goal = await dao.getGoalById('goal-1');

      expect(goal, isNotNull);
      expect(goal!.id, equals('goal-1'));
      expect(goal.name, equals('Vacation Fund'));
      expect(goal.targetAmount, equals(1000.0));
      expect(goal.currentAmount, equals(0.0));
      expect(goal.trackingMode, equals('manual'));
      expect(goal.status, equals('active'));
    });

    test('getGoalById returns null for non-existent goal', () async {
      final goal = await dao.getGoalById('non-existent');
      expect(goal, isNull);
    });

    test('updateGoal modifies the goal fields', () async {
      await _insertGoal(dao, id: 'goal-1', name: 'Old Name');

      await dao.updateGoal(
        const GoalsCompanion(
          id: Value('goal-1'),
          name: Value('New Name'),
          currentAmount: Value(500.0),
        ),
      );

      final goal = await dao.getGoalById('goal-1');
      expect(goal!.name, equals('New Name'));
      expect(goal.currentAmount, equals(500.0));
    });

    test('deleteGoal removes the goal', () async {
      await _insertGoal(dao, id: 'goal-1');

      await dao.deleteGoal('goal-1');

      final goal = await dao.getGoalById('goal-1');
      expect(goal, isNull);
    });

    test('getGoalsByUser returns goals for the specified user', () async {
      await _insertGoal(dao, id: 'goal-1', userId: 'user-a');
      await _insertGoal(dao, id: 'goal-2', userId: 'user-a');
      await _insertGoal(dao, id: 'goal-3', userId: 'user-b');

      final goalsA = await dao.getGoalsByUser('user-a');
      final goalsB = await dao.getGoalsByUser('user-b');

      expect(goalsA.length, equals(2));
      expect(goalsB.length, equals(1));
    });

    test(
      'getGoalsByUser returns goals ordered by createdAt descending',
      () async {
        await _insertGoal(dao, id: 'goal-old', createdAt: DateTime(2024, 1, 1));
        await _insertGoal(dao, id: 'goal-new', createdAt: DateTime(2024, 6, 1));

        final goals = await dao.getGoalsByUser('test-user');

        expect(goals.first.id, equals('goal-new'));
        expect(goals.last.id, equals('goal-old'));
      },
    );

    test('insertDeposit and getDepositsByGoal returns deposits', () async {
      await _insertGoal(dao, id: 'goal-1');
      await _insertDeposit(dao, id: 'dep-1', goalId: 'goal-1', amount: 200.0);
      await _insertDeposit(dao, id: 'dep-2', goalId: 'goal-1', amount: 300.0);

      final deposits = await dao.getDepositsByGoal('goal-1');

      expect(deposits.length, equals(2));
      expect(deposits.map((d) => d.amount).toList(), contains(200.0));
      expect(deposits.map((d) => d.amount).toList(), contains(300.0));
    });

    test('markCompleted sets status and completedAt', () async {
      await _insertGoal(dao, id: 'goal-1');
      final completedAt = DateTime(2024, 6, 15);

      await dao.markCompleted('goal-1', completedAt);

      final goal = await dao.getGoalById('goal-1');
      expect(goal!.status, equals('completed'));
      expect(goal.completedAt, equals(completedAt));
    });

    test('archiveGoal sets status to archived', () async {
      await _insertGoal(dao, id: 'goal-1');

      await dao.archiveGoal('goal-1');

      final goal = await dao.getGoalById('goal-1');
      expect(goal!.status, equals('archived'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Cascade Delete (Goal deletion removes deposits)
  // _Requirements: 9.3_
  // ──────────────────────────────────────────────────────────────────────────
  group('Cascade Delete', () {
    test('deleting a goal removes all associated deposits', () async {
      await _insertGoal(dao, id: 'goal-1');
      await _insertDeposit(dao, id: 'dep-1', goalId: 'goal-1', amount: 100.0);
      await _insertDeposit(dao, id: 'dep-2', goalId: 'goal-1', amount: 200.0);
      await _insertDeposit(dao, id: 'dep-3', goalId: 'goal-1', amount: 300.0);

      // Verify deposits exist before deletion
      final depositsBefore = await dao.getDepositsByGoal('goal-1');
      expect(depositsBefore.length, equals(3));

      // Delete the goal
      await dao.deleteGoal('goal-1');

      // Verify deposits are gone
      final depositsAfter = await dao.getDepositsByGoal('goal-1');
      expect(depositsAfter, isEmpty);
    });

    test('deleting a goal does not affect deposits of other goals', () async {
      await _insertGoal(dao, id: 'goal-1');
      await _insertGoal(dao, id: 'goal-2');
      await _insertDeposit(dao, id: 'dep-1', goalId: 'goal-1');
      await _insertDeposit(dao, id: 'dep-2', goalId: 'goal-2');

      await dao.deleteGoal('goal-1');

      final depositsGoal2 = await dao.getDepositsByGoal('goal-2');
      expect(depositsGoal2.length, equals(1));
      expect(depositsGoal2.first.id, equals('dep-2'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // FK Set-Null (Wallet deletion nullifies linkedWalletId)
  // _Requirements: 9.4_
  // ──────────────────────────────────────────────────────────────────────────
  group('FK Set-Null on Wallet Deletion', () {
    test(
      'deleting a wallet sets linkedWalletId to null on linked goals',
      () async {
        // Insert a wallet first
        await _insertWallet(db, id: 'wallet-1');

        // Create a goal linked to that wallet
        await _insertGoal(
          dao,
          id: 'goal-1',
          linkedWalletId: 'wallet-1',
          trackingMode: 'wallet',
        );

        // Verify the link exists
        final goalBefore = await dao.getGoalById('goal-1');
        expect(goalBefore!.linkedWalletId, equals('wallet-1'));

        // Delete the wallet
        await (db.delete(
          db.wallets,
        )..where((t) => t.id.equals('wallet-1'))).go();

        // Verify linkedWalletId is now null
        final goalAfter = await dao.getGoalById('goal-1');
        expect(goalAfter!.linkedWalletId, isNull);
      },
    );

    test(
      'deleting a wallet does not affect goals linked to other wallets',
      () async {
        await _insertWallet(db, id: 'wallet-1');
        await _insertWallet(db, id: 'wallet-2');

        await _insertGoal(
          dao,
          id: 'goal-1',
          linkedWalletId: 'wallet-1',
          trackingMode: 'wallet',
        );
        await _insertGoal(
          dao,
          id: 'goal-2',
          linkedWalletId: 'wallet-2',
          trackingMode: 'wallet',
        );

        // Delete wallet-1
        await (db.delete(
          db.wallets,
        )..where((t) => t.id.equals('wallet-1'))).go();

        // goal-1 should have null linkedWalletId
        final goal1 = await dao.getGoalById('goal-1');
        expect(goal1!.linkedWalletId, isNull);

        // goal-2 should still be linked to wallet-2
        final goal2 = await dao.getGoalById('goal-2');
        expect(goal2!.linkedWalletId, equals('wallet-2'));
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Stream Reactivity
  // _Requirements: 9.5_
  // ──────────────────────────────────────────────────────────────────────────
  group('Stream Reactivity', () {
    test(
      'watchGoalsByUser emits updated list when a goal is inserted',
      () async {
        // Start listening to the stream
        final stream = dao.watchGoalsByUser('test-user');

        // Expect the stream to emit: first empty, then with the new goal
        final expectation = expectLater(
          stream,
          emitsInOrder([
            isEmpty, // Initial empty state
            hasLength(1), // After insert
          ]),
        );

        // Give the stream time to emit the initial value
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Insert a goal
        await _insertGoal(dao, id: 'goal-1');

        await expectation;
      },
    );

    test(
      'watchDepositsByGoal emits updated list when a deposit is added',
      () async {
        await _insertGoal(dao, id: 'goal-1');

        final stream = dao.watchDepositsByGoal('goal-1');

        final expectation = expectLater(
          stream,
          emitsInOrder([
            isEmpty, // Initial empty state
            hasLength(1), // After deposit insert
          ]),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        await _insertDeposit(dao, id: 'dep-1', goalId: 'goal-1');

        await expectation;
      },
    );

    test('watchGoalsByUser emits update when a goal is deleted', () async {
      await _insertGoal(dao, id: 'goal-1');

      final stream = dao.watchGoalsByUser('test-user');

      final expectation = expectLater(
        stream,
        emitsInOrder([
          hasLength(1), // Initial state with one goal
          isEmpty, // After deletion
        ]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      await dao.deleteGoal('goal-1');

      await expectation;
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Status Filtering in watchGoalsByUser
  // _Requirements: 9.6_
  // ──────────────────────────────────────────────────────────────────────────
  group('Status Filtering', () {
    test(
      'watchGoalsByUser with status filter returns only matching goals',
      () async {
        await _insertGoal(dao, id: 'goal-active-1', status: 'active');
        await _insertGoal(dao, id: 'goal-active-2', status: 'active');
        await _insertGoal(dao, id: 'goal-completed', status: 'completed');
        await _insertGoal(dao, id: 'goal-archived', status: 'archived');

        final stream = dao.watchGoalsByUser('test-user', status: 'active');

        await expectLater(
          stream,
          emits(
            allOf(
              hasLength(2),
              everyElement(
                isA<Goal>().having((g) => g.status, 'status', equals('active')),
              ),
            ),
          ),
        );
      },
    );

    test('watchGoalsByUser without status filter returns all goals', () async {
      await _insertGoal(dao, id: 'goal-active', status: 'active');
      await _insertGoal(dao, id: 'goal-completed', status: 'completed');
      await _insertGoal(dao, id: 'goal-archived', status: 'archived');

      final stream = dao.watchGoalsByUser('test-user');

      await expectLater(stream, emits(hasLength(3)));
    });

    test(
      'getGoalsByUser with status filter returns only matching goals',
      () async {
        await _insertGoal(dao, id: 'goal-active', status: 'active');
        await _insertGoal(dao, id: 'goal-completed', status: 'completed');
        await _insertGoal(dao, id: 'goal-archived', status: 'archived');

        final activeGoals = await dao.getGoalsByUser(
          'test-user',
          status: 'active',
        );
        final completedGoals = await dao.getGoalsByUser(
          'test-user',
          status: 'completed',
        );
        final archivedGoals = await dao.getGoalsByUser(
          'test-user',
          status: 'archived',
        );

        expect(activeGoals.length, equals(1));
        expect(activeGoals.first.status, equals('active'));
        expect(completedGoals.length, equals(1));
        expect(completedGoals.first.status, equals('completed'));
        expect(archivedGoals.length, equals(1));
        expect(archivedGoals.first.status, equals('archived'));
      },
    );

    test(
      'getGoalsByUser with status filter for empty result returns empty',
      () async {
        await _insertGoal(dao, id: 'goal-active', status: 'active');

        final completedGoals = await dao.getGoalsByUser(
          'test-user',
          status: 'completed',
        );

        expect(completedGoals, isEmpty);
      },
    );
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Wallet Linking Queries
  // ──────────────────────────────────────────────────────────────────────────
  group('Wallet Linking Queries', () {
    test(
      'getGoalByLinkedWallet returns active goal linked to wallet',
      () async {
        await _insertWallet(db, id: 'wallet-1');
        await _insertGoal(
          dao,
          id: 'goal-1',
          linkedWalletId: 'wallet-1',
          trackingMode: 'wallet',
          status: 'active',
        );

        final goal = await dao.getGoalByLinkedWallet('wallet-1');
        expect(goal, isNotNull);
        expect(goal!.id, equals('goal-1'));
      },
    );

    test('getGoalByLinkedWallet returns null for completed goal', () async {
      await _insertWallet(db, id: 'wallet-1');
      await _insertGoal(
        dao,
        id: 'goal-1',
        linkedWalletId: 'wallet-1',
        trackingMode: 'wallet',
        status: 'completed',
      );

      final goal = await dao.getGoalByLinkedWallet('wallet-1');
      expect(goal, isNull);
    });

    test(
      'isWalletLinked returns true when wallet is linked to active goal',
      () async {
        await _insertWallet(db, id: 'wallet-1');
        await _insertGoal(
          dao,
          id: 'goal-1',
          linkedWalletId: 'wallet-1',
          trackingMode: 'wallet',
          status: 'active',
        );

        final isLinked = await dao.isWalletLinked('wallet-1');
        expect(isLinked, isTrue);
      },
    );

    test('isWalletLinked returns false when wallet is not linked', () async {
      await _insertWallet(db, id: 'wallet-1');

      final isLinked = await dao.isWalletLinked('wallet-1');
      expect(isLinked, isFalse);
    });
  });
}
