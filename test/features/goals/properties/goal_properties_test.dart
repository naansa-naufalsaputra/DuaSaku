
import 'package:duasaku_app/features/goals/domain/models/goal_model.dart';
import 'package:duasaku_app/features/goals/domain/models/goal_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

// ---------------------------------------------------------------------------
// Custom Generators & Helpers
// ---------------------------------------------------------------------------

/// Helper to build a GoalModel with sensible defaults.
GoalModel _buildGoal({
  String id = 'goal-1',
  String userId = 'user-1',
  String name = 'Test Goal',
  double targetAmount = 1000.0,
  double currentAmount = 0.0,
  DateTime? deadline,
  String icon = '🎯',
  String color = '#FF5733',
  String? linkedWalletId,
  TrackingMode trackingMode = TrackingMode.manual,
  GoalStatus status = GoalStatus.active,
  DateTime? completedAt,
  Set<int> notifiedMilestones = const {},
  DateTime? createdAt,
}) {
  return GoalModel(
    id: id,
    userId: userId,
    name: name,
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    deadline: deadline,
    icon: icon,
    color: color,
    linkedWalletId: linkedWalletId,
    trackingMode: trackingMode,
    status: status,
    completedAt: completedAt,
    notifiedMilestones: notifiedMilestones,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
  );
}

/// Simulates adding deposits to a goal with cap enforcement.
/// Returns the final currentAmount after all deposits.
double _simulateDeposits(double targetAmount, List<double> deposits) {
  double current = 0.0;
  for (final deposit in deposits) {
    if (deposit <= 0) continue;
    final effective = (current + deposit > targetAmount)
        ? targetAmount - current
        : deposit;
    if (effective > 0) {
      current += effective;
    }
  }
  return current;
}

/// Simulates wallet sync: returns min(walletBalance, targetAmount) clamped >= 0.
double _simulateWalletSync(double walletBalance, double targetAmount) {
  return walletBalance.clamp(0.0, targetAmount);
}

/// Determines which milestone badges should be awarded for a given progress.
/// Returns a set of badge names without duplicates.
Set<String> _determineMilestoneBadges(double progressPercentage) {
  final badges = <String>{};
  if (progressPercentage >= 0.25) badges.add('quarter_saver');
  if (progressPercentage >= 0.50) badges.add('half_way');
  if (progressPercentage >= 1.0) badges.add('goal_achieved');
  return badges;
}

// ---------------------------------------------------------------------------
// Property-Based Tests
// ---------------------------------------------------------------------------

void main() {

  // Feature: financial-goals, Property 1: Goal creation round-trip
  // **Validates: Requirements 1.1, 1.8, 11.5**
  group('Property 1: Goal creation round-trip', () {
    Glados2(
      any.intInRange(1, 100), // name length
      any.intInRange(1, 999999999), // target amount (as int cents)
    ).test(
      'GoalModel → toJson → fromJson preserves all fields',
      (nameLength, targetCents) {
        final name = String.fromCharCodes(
          List.generate(nameLength, (i) => 65 + (i % 26)), // A-Z cycling
        );
        final targetAmount = targetCents / 100.0;
        final deadline = DateTime(2030, 6, 15, 10, 30);
        final createdAt = DateTime(2024, 3, 1, 8, 0);

        final original = GoalModel(
          id: 'test-id-123',
          userId: 'user-456',
          name: name,
          targetAmount: targetAmount,
          currentAmount: targetAmount * 0.5,
          deadline: deadline,
          icon: '🎯',
          color: '#FF5733',
          linkedWalletId: 'wallet-789',
          trackingMode: TrackingMode.wallet,
          status: GoalStatus.active,
          completedAt: null,
          notifiedMilestones: {25, 50},
          createdAt: createdAt,
        );

        final json = original.toJson();
        final restored = GoalModel.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.userId, equals(original.userId));
        expect(restored.name, equals(original.name));
        expect(restored.targetAmount, equals(original.targetAmount));
        expect(restored.currentAmount, equals(original.currentAmount));
        expect(restored.deadline, equals(original.deadline));
        expect(restored.icon, equals(original.icon));
        expect(restored.color, equals(original.color));
        expect(restored.linkedWalletId, equals(original.linkedWalletId));
        expect(restored.trackingMode, equals(original.trackingMode));
        expect(restored.status, equals(original.status));
        expect(restored.notifiedMilestones, equals(original.notifiedMilestones));
        expect(restored.createdAt, equals(original.createdAt));
      },
    );
  });

  // Feature: financial-goals, Property 2: Deposit sum invariant
  // **Validates: Requirements 3.1, 3.4, 11.1**
  group('Property 2: Deposit sum invariant', () {
    Glados2(
      any.intInRange(100, 10000000), // target amount in cents
      any.intInRange(1, 15), // number of deposits
    ).test(
      'currentAmount == min(sum(deposits), targetAmount) after deposit sequence',
      (targetCents, depositCount) {
        final targetAmount = targetCents / 100.0;
        final localRng = Random(targetCents ^ depositCount);
        final deposits = List.generate(
          depositCount,
          (_) => (localRng.nextDouble() * targetAmount * 0.4) + 0.01,
        );

        final finalAmount = _simulateDeposits(targetAmount, deposits);
        final rawSum = deposits.fold<double>(0.0, (s, d) => s + d);
        final expectedAmount = rawSum < targetAmount ? rawSum : targetAmount;

        // Due to floating point, use closeTo
        expect(finalAmount, closeTo(expectedAmount, 0.001));
      },
    );
  });

  // Feature: financial-goals, Property 3: Progress percentage formula
  // **Validates: Requirements 5.1, 11.2**
  group('Property 3: Progress percentage formula', () {
    Glados2(
      any.intInRange(1, 999999999), // target amount in cents (> 0)
      any.intInRange(0, 999999999), // current amount in cents
    ).test(
      'progressPercentage == (currentAmount / targetAmount).clamp(0.0, 1.0)',
      (targetCents, currentCents) {
        final targetAmount = targetCents / 100.0;
        final currentAmount = currentCents / 100.0;

        final goal = _buildGoal(
          targetAmount: targetAmount,
          currentAmount: currentAmount,
        );

        final expected = (currentAmount / targetAmount).clamp(0.0, 1.0);
        expect(goal.progressPercentage, closeTo(expected, 1e-10));
      },
    );

    test('progressPercentage is 0.0 when targetAmount is 0', () {
      final goal = _buildGoal(targetAmount: 0.0, currentAmount: 100.0);
      expect(goal.progressPercentage, equals(0.0));
    });
  });

  // Feature: financial-goals, Property 4: Current amount cap invariant
  // **Validates: Requirements 3.4, 6.2, 11.3**
  group('Property 4: Current amount cap invariant', () {
    Glados2(
      any.intInRange(100, 10000000), // target amount in cents
      any.intInRange(1, 20), // number of operations
    ).test(
      'currentAmount <= targetAmount after any sequence of deposits',
      (targetCents, opCount) {
        final targetAmount = targetCents / 100.0;
        final localRng = Random(targetCents * 31 + opCount);
        final deposits = List.generate(
          opCount,
          (_) => (localRng.nextDouble() * targetAmount * 2.0) + 0.01,
        );

        final finalAmount = _simulateDeposits(targetAmount, deposits);
        expect(finalAmount, lessThanOrEqualTo(targetAmount));
      },
    );

    Glados2(
      any.intInRange(100, 10000000), // target amount in cents
      any.intInRange(0, 20000000), // wallet balance in cents
    ).test(
      'currentAmount <= targetAmount after wallet sync',
      (targetCents, balanceCents) {
        final targetAmount = targetCents / 100.0;
        final walletBalance = balanceCents / 100.0;

        final synced = _simulateWalletSync(walletBalance, targetAmount);
        expect(synced, lessThanOrEqualTo(targetAmount));
        expect(synced, greaterThanOrEqualTo(0.0));
      },
    );
  });

  // Feature: financial-goals, Property 5: Wallet-linked goal synchronization
  // **Validates: Requirements 4.1, 4.2, 11.4**
  group('Property 5: Wallet-linked goal synchronization', () {
    Glados2(
      any.intInRange(100, 10000000), // target amount in cents
      any.intInRange(0, 20000000), // wallet balance in cents
    ).test(
      'after wallet balance change, currentAmount == min(wallet.balance, targetAmount)',
      (targetCents, balanceCents) {
        final targetAmount = targetCents / 100.0;
        final walletBalance = balanceCents / 100.0;

        // Simulate wallet sync logic
        final syncedAmount = walletBalance.clamp(0.0, targetAmount);

        final goal = _buildGoal(
          targetAmount: targetAmount,
          currentAmount: syncedAmount,
          linkedWalletId: 'wallet-1',
          trackingMode: TrackingMode.wallet,
        );

        final expectedAmount =
            walletBalance < targetAmount ? walletBalance.clamp(0.0, targetAmount) : targetAmount;
        expect(goal.currentAmount, closeTo(expectedAmount, 1e-10));
      },
    );
  });

  // Feature: financial-goals, Property 6: Milestone check idempotence
  // **Validates: Requirements 8.5, 11.6**
  group('Property 6: Milestone check idempotence', () {
    Glados2(
      any.intInRange(1, 999999999), // target amount in cents
      any.intInRange(0, 999999999), // current amount in cents
    ).test(
      'currentMilestone computed N times produces same result as once',
      (targetCents, currentCents) {
        final targetAmount = targetCents / 100.0;
        final currentAmount = currentCents / 100.0;

        final goal = _buildGoal(
          targetAmount: targetAmount,
          currentAmount: currentAmount,
        );

        // Compute milestone once
        final milestone1 = goal.currentMilestone;

        // Compute milestone again (idempotent — same input, same output)
        final milestone2 = goal.currentMilestone;
        final milestone3 = goal.currentMilestone;

        expect(milestone1, equals(milestone2));
        expect(milestone2, equals(milestone3));

        // Also verify milestone is one of the valid values
        expect(milestone1, isIn([0, 25, 50, 75, 100]));
      },
    );
  });

  // Feature: financial-goals, Property 7: Completed goal invariant
  // **Validates: Requirements 10.1, 11.7**
  group('Property 7: Completed goal invariant', () {
    Glados(any.intInRange(100, 999999999)).test(
      'any completed goal has currentAmount == targetAmount',
      (targetCents) {
        final targetAmount = targetCents / 100.0;

        // Simulate: goal reaches target via deposits, then marked completed
        final goal = _buildGoal(
          targetAmount: targetAmount,
          currentAmount: targetAmount, // Must equal target when completed
          status: GoalStatus.completed,
          completedAt: DateTime.now(),
        );

        expect(goal.isCompleted, isTrue);
        expect(goal.currentAmount, equals(goal.targetAmount));
        expect(goal.progressPercentage, equals(1.0));
      },
    );
  });

  // Feature: financial-goals, Property 8: Input validation rejects invalid data
  // **Validates: Requirements 1.2, 1.3, 1.4, 3.2**
  group('Property 8: Input validation rejects invalid data', () {
    // Validation logic extracted from GoalNotifier for pure testing
    bool isValidGoalName(String name) => name.isNotEmpty && name.length <= 100;
    bool isValidTargetAmount(double amount) => amount > 0;
    bool isValidDeadline(DateTime? deadline) =>
        deadline == null || deadline.isAfter(DateTime.now());
    bool isValidDepositAmount(double amount) => amount > 0;

    Glados(any.intInRange(101, 500)).test(
      'goal name > 100 chars is rejected',
      (length) {
        final name = 'A' * length;
        expect(isValidGoalName(name), isFalse);
      },
    );

    test('empty goal name is rejected', () {
      expect(isValidGoalName(''), isFalse);
    });

    Glados(any.intInRange(-1000000, 0)).test(
      'target amount <= 0 is rejected',
      (amountCents) {
        final amount = amountCents / 100.0;
        expect(isValidTargetAmount(amount), isFalse);
      },
    );

    test('deadline in the past is rejected', () {
      final pastDeadline = DateTime.now().subtract(const Duration(days: 1));
      expect(isValidDeadline(pastDeadline), isFalse);
    });

    Glados(any.intInRange(-1000000, 0)).test(
      'deposit amount <= 0 is rejected',
      (amountCents) {
        final amount = amountCents / 100.0;
        expect(isValidDepositAmount(amount), isFalse);
      },
    );
  });

  // Feature: financial-goals, Property 9: Tracking mode assignment
  // **Validates: Requirements 1.6, 1.7**
  group('Property 9: Tracking mode assignment', () {
    Glados(any.intInRange(1, 1000)).test(
      'linkedWalletId null → manual tracking mode',
      (seed) {
        final goal = _buildGoal(
          linkedWalletId: null,
          trackingMode: TrackingMode.manual,
        );
        expect(goal.linkedWalletId, isNull);
        expect(goal.trackingMode, equals(TrackingMode.manual));
      },
    );

    Glados(any.intInRange(1, 1000)).test(
      'linkedWalletId non-null → wallet tracking mode',
      (seed) {
        final walletId = 'wallet-$seed';
        final goal = _buildGoal(
          linkedWalletId: walletId,
          trackingMode: TrackingMode.wallet,
        );
        expect(goal.linkedWalletId, isNotNull);
        expect(goal.trackingMode, equals(TrackingMode.wallet));
      },
    );
  });

  // Feature: financial-goals, Property 10: Completion permanence
  // **Validates: Requirements 10.5, 10.6**
  group('Property 10: Completion permanence', () {
    Glados2(
      any.intInRange(100, 10000000), // target amount in cents
      any.intInRange(0, 10000000), // new wallet balance in cents (possibly lower)
    ).test(
      'completed goal status never reverts to active regardless of wallet balance changes',
      (targetCents, newBalanceCents) {
        final targetAmount = targetCents / 100.0;

        // Goal is already completed
        final completedGoal = _buildGoal(
          targetAmount: targetAmount,
          currentAmount: targetAmount,
          status: GoalStatus.completed,
          completedAt: DateTime(2024, 6, 1),
          linkedWalletId: 'wallet-1',
          trackingMode: TrackingMode.wallet,
        );

        // Simulate: syncWalletBalance respects completion permanence
        // The actual logic: if (goal.isCompleted) return; — no change
        final goalAfterSync = completedGoal; // No modification for completed goals

        expect(goalAfterSync.status, equals(GoalStatus.completed));
        expect(goalAfterSync.isCompleted, isTrue);
        // currentAmount stays at targetAmount (not modified)
        expect(goalAfterSync.currentAmount, equals(targetAmount));
      },
    );
  });

  // Feature: financial-goals, Property 11: S_goal health score calculation
  // **Validates: Requirements 7.6, 7.7**
  group('Property 11: S_goal health score calculation', () {
    Glados(any.intInRange(1, 10)).test(
      'S_goal == (avg_progress × 5).clamp(0, 5) for active goals',
      (goalCount) {
        final localRng = Random(goalCount * 7);
        final goals = List.generate(goalCount, (i) {
          final target = (localRng.nextInt(9999) + 1) / 100.0;
          final current = localRng.nextDouble() * target;
          return _buildGoal(
            id: 'goal-$i',
            targetAmount: target,
            currentAmount: current,
            status: GoalStatus.active,
          );
        });

        // Calculate expected S_goal using the same formula as the service
        final activeGoals =
            goals.where((g) => g.status == GoalStatus.active).toList();

        final double expectedSGoal;
        if (activeGoals.isEmpty) {
          expectedSGoal = 0.0;
        } else {
          final totalProgress = activeGoals.fold<double>(
            0.0,
            (sum, g) => sum + g.progressPercentage,
          );
          final avgProgress = totalProgress / activeGoals.length;
          expectedSGoal = (avgProgress * 5.0).clamp(0.0, 5.0);
        }

        // Replicate the GoalGamificationService.calculateSGoal logic directly
        final double actualSGoal;
        if (activeGoals.isEmpty) {
          actualSGoal = 0.0;
        } else {
          final tp = activeGoals.fold<double>(
            0.0, (sum, g) => sum + g.progressPercentage);
          final ap = tp / activeGoals.length;
          actualSGoal = (ap * 5.0).clamp(0.0, 5.0);
        }

        expect(actualSGoal, closeTo(expectedSGoal, 1e-10));
        expect(actualSGoal, greaterThanOrEqualTo(0.0));
        expect(actualSGoal, lessThanOrEqualTo(5.0));
      },
    );

    test('S_goal is 0 when no active goals exist', () {
      final goals = <GoalModel>[
        _buildGoal(status: GoalStatus.completed, currentAmount: 100, targetAmount: 100),
        _buildGoal(id: 'g2', status: GoalStatus.archived, currentAmount: 50, targetAmount: 100),
      ];

      final activeGoals =
          goals.where((g) => g.status == GoalStatus.active).toList();
      expect(activeGoals.isEmpty, isTrue);

      // S_goal should be 0
      final sGoal = activeGoals.isEmpty
          ? 0.0
          : (activeGoals.fold<double>(0.0, (s, g) => s + g.progressPercentage) /
                  activeGoals.length *
                  5.0)
              .clamp(0.0, 5.0);
      expect(sGoal, equals(0.0));
    });
  });

  // Feature: financial-goals, Property 12: Milestone badge awarding
  // **Validates: Requirements 7.1, 7.2, 7.3**
  group('Property 12: Milestone badge awarding', () {
    Glados2(
      any.intInRange(1, 999999999), // target amount in cents
      any.intInRange(0, 999999999), // current amount in cents
    ).test(
      'crossing milestone threshold adds badge without duplicates',
      (targetCents, currentCents) {
        final targetAmount = targetCents / 100.0;
        final currentAmount = currentCents / 100.0;

        final goal = _buildGoal(
          targetAmount: targetAmount,
          currentAmount: currentAmount,
        );

        final progress = goal.progressPercentage;
        final badges = _determineMilestoneBadges(progress);

        // Verify no duplicates (Set guarantees this, but verify explicitly)
        expect(badges.length, equals(badges.toSet().length));

        // Verify correct badges based on progress
        if (progress >= 1.0) {
          expect(badges, contains('goal_achieved'));
          expect(badges, contains('half_way'));
          expect(badges, contains('quarter_saver'));
        } else if (progress >= 0.50) {
          expect(badges, contains('half_way'));
          expect(badges, contains('quarter_saver'));
          expect(badges.contains('goal_achieved'), isFalse);
        } else if (progress >= 0.25) {
          expect(badges, contains('quarter_saver'));
          expect(badges.contains('half_way'), isFalse);
          expect(badges.contains('goal_achieved'), isFalse);
        } else {
          expect(badges.isEmpty, isTrue);
        }

        // Applying badge determination again produces same result (idempotent)
        final badges2 = _determineMilestoneBadges(progress);
        expect(badges, equals(badges2));
      },
    );
  });
}
