import 'package:duasaku_app/features/gamification/providers/gamification_provider.dart';
import 'package:duasaku_app/features/goals/domain/models/goal_model.dart';
import 'package:duasaku_app/features/goals/domain/models/goal_status.dart';
import 'package:duasaku_app/features/goals/providers/goal_gamification_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper function to build a GoalModel with sensible defaults.
GoalModel _buildGoal({
  String id = 'goal-1',
  String userId = 'user-1',
  String name = 'Test Goal',
  double targetAmount = 1000.0,
  double currentAmount = 0.0,
  GoalStatus status = GoalStatus.active,
  TrackingMode trackingMode = TrackingMode.manual,
}) {
  return GoalModel(
    id: id,
    userId: userId,
    name: name,
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    icon: '🎯',
    color: '#FF5733',
    trackingMode: trackingMode,
    status: status,
    createdAt: DateTime(2024, 1, 1),
  );
}

/// A fake GamificationNotifier that tracks badge awards without
/// requiring SharedPreferences or other providers.
class FakeGamificationNotifier extends GamificationNotifier {
  final List<String> awardedBadges = [];

  @override
  GamificationState build() {
    return GamificationState();
  }

  @override
  Future<bool> awardBadge(String badgeName) async {
    if (state.unlockedBadges.contains(badgeName)) return false;
    awardedBadges.add(badgeName);
    final newBadges = [...state.unlockedBadges, badgeName];
    state = state.copyWith(unlockedBadges: newBadges);
    return true;
  }

  @override
  GamificationState get currentState => state;

  @override
  Future<void> logDailyActivity() async {}

  @override
  void updateGoalScore(int score) {
    state = state.copyWith(scoreGoal: score);
  }
}

void main() {
  group('GoalGamificationService - S_goal calculation', () {
    late ProviderContainer container;
    late FakeGamificationNotifier fakeGamification;

    setUp(() {
      fakeGamification = FakeGamificationNotifier();
      container = ProviderContainer(
        overrides: [
          gamificationProvider.overrideWith(() => fakeGamification),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('returns 0.0 when there are no goals', () {
      final service = container.read(goalGamificationProvider);
      final result = service.calculateSGoal([]);
      expect(result, equals(0.0));
    });

    test('returns 0.0 when there are no active goals', () {
      final goals = [
        _buildGoal(
          id: 'g1',
          status: GoalStatus.completed,
          targetAmount: 1000.0,
          currentAmount: 1000.0,
        ),
        _buildGoal(
          id: 'g2',
          status: GoalStatus.archived,
          targetAmount: 500.0,
          currentAmount: 200.0,
        ),
      ];
      final service = container.read(goalGamificationProvider);
      final result = service.calculateSGoal(goals);
      expect(result, equals(0.0));
    });

    test('returns 5.0 when single active goal is 100% complete', () {
      final goals = [
        _buildGoal(
          targetAmount: 1000.0,
          currentAmount: 1000.0,
          status: GoalStatus.active,
        ),
      ];
      final service = container.read(goalGamificationProvider);
      final result = service.calculateSGoal(goals);
      expect(result, equals(5.0));
    });

    test('returns 2.5 when single active goal is 50% complete', () {
      final goals = [
        _buildGoal(
          targetAmount: 1000.0,
          currentAmount: 500.0,
          status: GoalStatus.active,
        ),
      ];
      final service = container.read(goalGamificationProvider);
      final result = service.calculateSGoal(goals);
      expect(result, equals(2.5));
    });

    test('returns correct average across multiple active goals', () {
      final goals = [
        _buildGoal(
          id: 'g1',
          targetAmount: 1000.0,
          currentAmount: 500.0, // 50%
          status: GoalStatus.active,
        ),
        _buildGoal(
          id: 'g2',
          targetAmount: 2000.0,
          currentAmount: 2000.0, // 100%
          status: GoalStatus.active,
        ),
      ];
      // Average = (0.5 + 1.0) / 2 = 0.75
      // S_goal = 0.75 * 5 = 3.75
      final service = container.read(goalGamificationProvider);
      final result = service.calculateSGoal(goals);
      expect(result, equals(3.75));
    });

    test('ignores completed and archived goals in calculation', () {
      final goals = [
        _buildGoal(
          id: 'g1',
          targetAmount: 1000.0,
          currentAmount: 250.0, // 25% - active
          status: GoalStatus.active,
        ),
        _buildGoal(
          id: 'g2',
          targetAmount: 1000.0,
          currentAmount: 1000.0, // completed - should be ignored
          status: GoalStatus.completed,
        ),
        _buildGoal(
          id: 'g3',
          targetAmount: 500.0,
          currentAmount: 100.0, // archived - should be ignored
          status: GoalStatus.archived,
        ),
      ];
      // Only g1 is active: 0.25 * 5 = 1.25
      final service = container.read(goalGamificationProvider);
      final result = service.calculateSGoal(goals);
      expect(result, equals(1.25));
    });

    test('clamps result to maximum of 5.0', () {
      final goals = [
        _buildGoal(
          targetAmount: 1000.0,
          currentAmount: 1000.0, // 100% (clamped to 1.0)
          status: GoalStatus.active,
        ),
      ];
      final service = container.read(goalGamificationProvider);
      final result = service.calculateSGoal(goals);
      expect(result, lessThanOrEqualTo(5.0));
    });

    test('returns 0.0 when active goals have zero progress', () {
      final goals = [
        _buildGoal(
          id: 'g1',
          targetAmount: 1000.0,
          currentAmount: 0.0,
          status: GoalStatus.active,
        ),
        _buildGoal(
          id: 'g2',
          targetAmount: 2000.0,
          currentAmount: 0.0,
          status: GoalStatus.active,
        ),
      ];
      final service = container.read(goalGamificationProvider);
      final result = service.calculateSGoal(goals);
      expect(result, equals(0.0));
    });
  });

  group('GoalGamificationService - milestone badge awarding', () {
    late ProviderContainer container;
    late FakeGamificationNotifier fakeGamification;

    setUp(() {
      fakeGamification = FakeGamificationNotifier();
      container = ProviderContainer(
        overrides: [
          gamificationProvider.overrideWith(() => fakeGamification),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('awards quarter_saver badge when goal reaches 25%', () async {
      final goal = _buildGoal(
        targetAmount: 1000.0,
        currentAmount: 250.0, // exactly 25%
      );

      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkMilestoneBadges(goal);

      expect(awarded, contains('quarter_saver'));
      expect(fakeGamification.awardedBadges, contains('quarter_saver'));
    });

    test('awards half_way badge when goal reaches 50%', () async {
      final goal = _buildGoal(
        targetAmount: 1000.0,
        currentAmount: 500.0, // exactly 50%
      );

      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkMilestoneBadges(goal);

      expect(awarded, contains('half_way'));
    });

    test('awards goal_achieved badge when goal reaches 100%', () async {
      final goal = _buildGoal(
        targetAmount: 1000.0,
        currentAmount: 1000.0, // 100%
      );

      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkMilestoneBadges(goal);

      expect(awarded, contains('goal_achieved'));
    });

    test('awards all milestone badges at once when goal is at 100%', () async {
      final goal = _buildGoal(
        targetAmount: 1000.0,
        currentAmount: 1000.0, // 100% — crosses all thresholds
      );

      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkMilestoneBadges(goal);

      expect(awarded, contains('quarter_saver'));
      expect(awarded, contains('half_way'));
      expect(awarded, contains('goal_achieved'));
    });

    test('does not award any badge when goal is below 25%', () async {
      final goal = _buildGoal(
        targetAmount: 1000.0,
        currentAmount: 200.0, // 20%
      );

      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkMilestoneBadges(goal);

      expect(awarded, isEmpty);
    });

    test('does not duplicate badges already awarded', () async {
      final goal = _buildGoal(
        targetAmount: 1000.0,
        currentAmount: 500.0, // 50%
      );

      final service = container.read(goalGamificationProvider);

      // First call awards badges
      final firstAward = await service.checkMilestoneBadges(goal);
      expect(firstAward, contains('quarter_saver'));
      expect(firstAward, contains('half_way'));

      // Second call should not re-award
      final secondAward = await service.checkMilestoneBadges(goal);
      expect(secondAward, isEmpty);
    });

    test('awards quarter_saver and half_way but not goal_achieved at 50%', () async {
      final goal = _buildGoal(
        targetAmount: 1000.0,
        currentAmount: 500.0, // 50%
      );

      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkMilestoneBadges(goal);

      expect(awarded, contains('quarter_saver'));
      expect(awarded, contains('half_way'));
      expect(awarded, isNot(contains('goal_achieved')));
    });
  });

  group('GoalGamificationService - completion count badges', () {
    late ProviderContainer container;
    late FakeGamificationNotifier fakeGamification;

    setUp(() {
      fakeGamification = FakeGamificationNotifier();
      container = ProviderContainer(
        overrides: [
          gamificationProvider.overrideWith(() => fakeGamification),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('awards triple_saver badge when 3 goals completed', () async {
      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkCompletionBadges(3);

      expect(awarded, contains('triple_saver'));
      expect(fakeGamification.awardedBadges, contains('triple_saver'));
    });

    test('awards both triple_saver and savings_master when 5 goals completed', () async {
      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkCompletionBadges(5);

      expect(awarded, contains('triple_saver'));
      expect(awarded, contains('savings_master'));
    });

    test('does not award triple_saver when fewer than 3 goals completed', () async {
      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkCompletionBadges(2);

      expect(awarded, isEmpty);
    });

    test('does not award savings_master when fewer than 5 goals completed', () async {
      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkCompletionBadges(4);

      expect(awarded, contains('triple_saver'));
      expect(awarded, isNot(contains('savings_master')));
    });

    test('does not duplicate badges on repeated calls', () async {
      final service = container.read(goalGamificationProvider);

      // First call awards badges
      final firstAward = await service.checkCompletionBadges(5);
      expect(firstAward, contains('triple_saver'));
      expect(firstAward, contains('savings_master'));

      // Second call should not re-award
      final secondAward = await service.checkCompletionBadges(5);
      expect(secondAward, isEmpty);
    });

    test('awards triple_saver for counts above 3 (e.g., 4)', () async {
      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkCompletionBadges(4);

      expect(awarded, contains('triple_saver'));
      expect(awarded, isNot(contains('savings_master')));
    });

    test('awards savings_master for counts above 5 (e.g., 10)', () async {
      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkCompletionBadges(10);

      expect(awarded, contains('triple_saver'));
      expect(awarded, contains('savings_master'));
    });

    test('does not award any badge when 0 goals completed', () async {
      final service = container.read(goalGamificationProvider);
      final awarded = await service.checkCompletionBadges(0);

      expect(awarded, isEmpty);
    });
  });
}
