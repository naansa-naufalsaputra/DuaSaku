/// Badge definitions for the Financial Goals feature.
///
/// These badges are awarded by [GoalGamificationService] and stored
/// in the gamification system via [GamificationNotifier.awardBadge].
library;

/// Badge definition metadata for goal-related badges.
class GoalBadgeDefinition {
  /// The unique badge identifier string used in the gamification system.
  final String id;

  /// Human-readable name for display.
  final String name;

  /// Description of how to earn this badge.
  final String description;

  /// The condition that triggers this badge.
  final String condition;

  const GoalBadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.condition,
  });
}

/// All goal-related badge definitions.
///
/// These are registered in the gamification system and awarded
/// when users reach savings milestones or complete multiple goals.
const goalBadgeDefinitions = <GoalBadgeDefinition>[
  GoalBadgeDefinition(
    id: 'quarter_saver',
    name: 'Quarter Saver',
    description: 'Reached 25% of a savings goal',
    condition: 'Any goal reaches 25% completion',
  ),
  GoalBadgeDefinition(
    id: 'half_way',
    name: 'Half Way',
    description: 'Reached 50% of a savings goal',
    condition: 'Any goal reaches 50% completion',
  ),
  GoalBadgeDefinition(
    id: 'goal_achieved',
    name: 'Goal Achieved',
    description: 'Completed a savings goal',
    condition: 'Any goal reaches 100% completion',
  ),
  GoalBadgeDefinition(
    id: 'triple_saver',
    name: 'Triple Saver',
    description: 'Completed 3 savings goals',
    condition: 'Total completed goals reaches 3',
  ),
  GoalBadgeDefinition(
    id: 'savings_master',
    name: 'Savings Master',
    description: 'Completed 5 savings goals',
    condition: 'Total completed goals reaches 5',
  ),
];

/// Set of all goal badge IDs for quick lookup.
const goalBadgeIds = <String>{
  'quarter_saver',
  'half_way',
  'goal_achieved',
  'triple_saver',
  'savings_master',
};
