import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gamification/providers/gamification_provider.dart';
import '../domain/models/goal_model.dart';
import '../domain/models/goal_status.dart';

/// Provider for the [GoalGamificationService].
final goalGamificationProvider = Provider<GoalGamificationService>((ref) {
  return GoalGamificationService(ref);
});

/// Handles gamification logic related to financial goals.
///
/// Calculates the S_goal health score component and awards badges
/// when users reach savings milestones or complete multiple goals.
class GoalGamificationService {
  final Ref _ref;

  GoalGamificationService(this._ref);

  /// Calculate S_goal: average completion % across active goals × 5.
  ///
  /// Returns 0 if there are no active goals.
  /// Result is clamped between 0 and 5.
  double calculateSGoal(List<GoalModel> goals) {
    final activeGoals =
        goals.where((g) => g.status == GoalStatus.active).toList();

    if (activeGoals.isEmpty) return 0.0;

    final totalProgress = activeGoals.fold<double>(
      0.0,
      (sum, goal) => sum + goal.progressPercentage,
    );

    final averageProgress = totalProgress / activeGoals.length;

    return (averageProgress * 5.0).clamp(0.0, 5.0);
  }

  /// Check and award milestone badges based on goal progress.
  ///
  /// Awards:
  /// - `quarter_saver` when any goal reaches 25%
  /// - `half_way` when any goal reaches 50%
  /// - `goal_achieved` when any goal reaches 100%
  ///
  /// Returns the list of newly awarded badge names.
  Future<List<String>> checkMilestoneBadges(GoalModel goal) async {
    final gamification = _ref.read(gamificationProvider.notifier);
    final awarded = <String>[];

    final progress = goal.progressPercentage;

    if (progress >= 0.25) {
      final isNew = await gamification.awardBadge('quarter_saver');
      if (isNew) awarded.add('quarter_saver');
    }

    if (progress >= 0.50) {
      final isNew = await gamification.awardBadge('half_way');
      if (isNew) awarded.add('half_way');
    }

    if (progress >= 1.0) {
      final isNew = await gamification.awardBadge('goal_achieved');
      if (isNew) awarded.add('goal_achieved');
    }

    return awarded;
  }

  /// Check and award completion count badges.
  ///
  /// Awards:
  /// - `triple_saver` when 3 goals have been completed
  /// - `savings_master` when 5 goals have been completed
  ///
  /// Returns the list of newly awarded badge names.
  Future<List<String>> checkCompletionBadges(int completedCount) async {
    final gamification = _ref.read(gamificationProvider.notifier);
    final awarded = <String>[];

    if (completedCount >= 3) {
      final isNew = await gamification.awardBadge('triple_saver');
      if (isNew) awarded.add('triple_saver');
    }

    if (completedCount >= 5) {
      final isNew = await gamification.awardBadge('savings_master');
      if (isNew) awarded.add('savings_master');
    }

    return awarded;
  }
}
