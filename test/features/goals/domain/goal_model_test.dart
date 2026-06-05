import 'package:duasaku_app/features/goals/domain/models/goal_model.dart';
import 'package:duasaku_app/features/goals/domain/models/goal_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper function to build a GoalModel with sensible defaults.
/// Override only the fields relevant to each test.
GoalModel buildGoal({
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

void main() {
  group('GoalModel.progressPercentage', () {
    test('returns 0.0 when targetAmount is 0', () {
      final goal = buildGoal(targetAmount: 0.0, currentAmount: 0.0);
      expect(goal.progressPercentage, equals(0.0));
    });

    test(
      'returns 0.0 when targetAmount is 0 and currentAmount is non-zero',
      () {
        final goal = buildGoal(targetAmount: 0.0, currentAmount: 100.0);
        expect(goal.progressPercentage, equals(0.0));
      },
    );

    test('returns 0.0 when currentAmount is 0', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 0.0);
      expect(goal.progressPercentage, equals(0.0));
    });

    test('returns 0.5 when currentAmount is half of targetAmount', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 500.0);
      expect(goal.progressPercentage, equals(0.5));
    });

    test('returns 1.0 when currentAmount equals targetAmount', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 1000.0);
      expect(goal.progressPercentage, equals(1.0));
    });

    test('clamps to 1.0 when currentAmount exceeds targetAmount', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 1500.0);
      expect(goal.progressPercentage, equals(1.0));
    });

    test('returns correct ratio for small amounts', () {
      final goal = buildGoal(targetAmount: 100.0, currentAmount: 25.0);
      expect(goal.progressPercentage, equals(0.25));
    });

    test('returns correct ratio for large amounts', () {
      final goal = buildGoal(
        targetAmount: 999999999.0,
        currentAmount: 499999999.5,
      );
      expect(goal.progressPercentage, closeTo(0.5, 0.000001));
    });

    test('returns 0.0 when currentAmount is negative (clamped)', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: -100.0);
      expect(goal.progressPercentage, equals(0.0));
    });
  });

  group('GoalModel.remainingDays', () {
    test('returns positive int when deadline is in the future', () {
      final futureDeadline = DateTime.now().add(const Duration(days: 30));
      final goal = buildGoal(deadline: futureDeadline);
      expect(goal.remainingDays, isNotNull);
      expect(goal.remainingDays, greaterThanOrEqualTo(29));
      expect(goal.remainingDays, lessThanOrEqualTo(30));
    });

    test('returns negative int when deadline is in the past', () {
      final pastDeadline = DateTime.now().subtract(const Duration(days: 10));
      final goal = buildGoal(deadline: pastDeadline);
      expect(goal.remainingDays, isNotNull);
      expect(goal.remainingDays, lessThan(0));
    });

    test('returns null when deadline is null', () {
      final goal = buildGoal(deadline: null);
      expect(goal.remainingDays, isNull);
    });

    test('returns 0 or close to 0 when deadline is today', () {
      final todayDeadline = DateTime.now();
      final goal = buildGoal(deadline: todayDeadline);
      expect(goal.remainingDays, isNotNull);
      expect(goal.remainingDays, closeTo(0, 1));
    });

    test('returns large positive value for far future deadline', () {
      final farFuture = DateTime.now().add(const Duration(days: 365));
      final goal = buildGoal(deadline: farFuture);
      expect(goal.remainingDays, isNotNull);
      expect(goal.remainingDays, greaterThanOrEqualTo(364));
    });
  });

  group('GoalModel.currentMilestone', () {
    test('returns 0 when progress is 0%', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 0.0);
      expect(goal.currentMilestone, equals(0));
    });

    test('returns 0 when progress is 24% (just below 25%)', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 240.0);
      expect(goal.currentMilestone, equals(0));
    });

    test('returns 0 when progress is 24.99%', () {
      final goal = buildGoal(targetAmount: 10000.0, currentAmount: 2499.0);
      expect(goal.currentMilestone, equals(0));
    });

    test('returns 25 when progress is exactly 25%', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 250.0);
      expect(goal.currentMilestone, equals(25));
    });

    test('returns 25 when progress is 49% (just below 50%)', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 490.0);
      expect(goal.currentMilestone, equals(25));
    });

    test('returns 25 when progress is 49.99%', () {
      final goal = buildGoal(targetAmount: 10000.0, currentAmount: 4999.0);
      expect(goal.currentMilestone, equals(25));
    });

    test('returns 50 when progress is exactly 50%', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 500.0);
      expect(goal.currentMilestone, equals(50));
    });

    test('returns 50 when progress is 74% (just below 75%)', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 740.0);
      expect(goal.currentMilestone, equals(50));
    });

    test('returns 50 when progress is 74.99%', () {
      final goal = buildGoal(targetAmount: 10000.0, currentAmount: 7499.0);
      expect(goal.currentMilestone, equals(50));
    });

    test('returns 75 when progress is exactly 75%', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 750.0);
      expect(goal.currentMilestone, equals(75));
    });

    test('returns 75 when progress is 99% (just below 100%)', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 990.0);
      expect(goal.currentMilestone, equals(75));
    });

    test('returns 75 when progress is 99.99%', () {
      final goal = buildGoal(targetAmount: 10000.0, currentAmount: 9999.0);
      expect(goal.currentMilestone, equals(75));
    });

    test('returns 100 when progress is exactly 100%', () {
      final goal = buildGoal(targetAmount: 1000.0, currentAmount: 1000.0);
      expect(goal.currentMilestone, equals(100));
    });

    test(
      'returns 100 when currentAmount exceeds targetAmount (clamped progress)',
      () {
        final goal = buildGoal(targetAmount: 1000.0, currentAmount: 1500.0);
        expect(goal.currentMilestone, equals(100));
      },
    );

    test('returns 0 when targetAmount is 0 (progress is 0.0)', () {
      final goal = buildGoal(targetAmount: 0.0, currentAmount: 0.0);
      expect(goal.currentMilestone, equals(0));
    });
  });
}
