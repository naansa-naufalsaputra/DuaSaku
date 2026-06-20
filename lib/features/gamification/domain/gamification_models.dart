class GamificationState {
  final int healthScore;
  final int currentStreak;
  final List<String> unlockedBadges;
  final int scoreBudget;
  final int scoreSaving;
  final int scoreStreak;
  final int scoreWallet;
  final int scoreGoal;

  GamificationState({
    this.healthScore = 0,
    this.currentStreak = 0,
    this.unlockedBadges = const [],
    this.scoreBudget = 0,
    this.scoreSaving = 0,
    this.scoreStreak = 0,
    this.scoreWallet = 0,
    this.scoreGoal = 0,
  });

  GamificationState copyWith({
    int? healthScore,
    int? currentStreak,
    List<String>? unlockedBadges,
    int? scoreBudget,
    int? scoreSaving,
    int? scoreStreak,
    int? scoreWallet,
    int? scoreGoal,
  }) {
    return GamificationState(
      healthScore: healthScore ?? this.healthScore,
      currentStreak: currentStreak ?? this.currentStreak,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      scoreBudget: scoreBudget ?? this.scoreBudget,
      scoreSaving: scoreSaving ?? this.scoreSaving,
      scoreStreak: scoreStreak ?? this.scoreStreak,
      scoreWallet: scoreWallet ?? this.scoreWallet,
      scoreGoal: scoreGoal ?? this.scoreGoal,
    );
  }
}
