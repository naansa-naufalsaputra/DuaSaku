import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../transactions/providers/budget_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../domain/gamification_service_interface.dart';
import '../../wallets/providers/wallet_provider.dart';

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

final gamificationProvider =
    NotifierProvider<GamificationNotifier, GamificationState>(() {
      return GamificationNotifier();
    });

class GamificationNotifier extends Notifier<GamificationState>
    implements GamificationServiceInterface {
  static const String _streakKey = 'user_streak_days';
  static const String _lastActiveKey = 'user_last_active_date';
  static const String _badgesKey = 'user_unlocked_badges';

  @override
  GamificationState build() {
    _initStreakAndScore();
    _listenToDependencies();
    return GamificationState();
  }

  @override
  GamificationState get currentState => state;

  void _listenToDependencies() {
    ref.listen(budgetNotifierProvider, (previous, next) {
      _calculateScore();
    });
    ref.listen(transactionNotifierProvider, (previous, next) {
      _calculateScore();
    });
    ref.listen(walletProvider, (previous, next) {
      _calculateScore();
    });
  }

  Future<void> _initStreakAndScore() async {
    final prefs = await SharedPreferences.getInstance();
    int streak = prefs.getInt(_streakKey) ?? 0;
    final String? lastActiveStr = prefs.getString(_lastActiveKey);
    final List<String> badges = prefs.getStringList(_badgesKey) ?? [];

    final today = DateTime.now();

    if (lastActiveStr != null) {
      final lastActive = DateTime.parse(lastActiveStr);
      final difference = DateTime(today.year, today.month, today.day)
          .difference(
            DateTime(lastActive.year, lastActive.month, lastActive.day),
          )
          .inDays;

      if (difference == 1) {
        // Logged in next day, streak continues (but wait for action to increment)
      } else if (difference > 1) {
        // Streak broken
        streak = 0;
        await prefs.setInt(_streakKey, streak);
      }
    }

    state = state.copyWith(currentStreak: streak, unlockedBadges: badges);
    _calculateScore();
  }

  @override
  Future<void> logDailyActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final String? lastActiveStr = prefs.getString(_lastActiveKey);

    if (lastActiveStr != null) {
      final lastActive = DateTime.parse(lastActiveStr);
      final difference = DateTime(today.year, today.month, today.day)
          .difference(
            DateTime(lastActive.year, lastActive.month, lastActive.day),
          )
          .inDays;

      if (difference == 1) {
        // Increment streak
        final int newStreak = state.currentStreak + 1;
        await prefs.setInt(_streakKey, newStreak);
        await prefs.setString(_lastActiveKey, today.toIso8601String());
        state = state.copyWith(currentStreak: newStreak);
      } else if (difference > 1) {
        // Restart streak
        await prefs.setInt(_streakKey, 1);
        await prefs.setString(_lastActiveKey, today.toIso8601String());
        state = state.copyWith(currentStreak: 1);
      }
    } else {
      // First time
      await prefs.setInt(_streakKey, 1);
      await prefs.setString(_lastActiveKey, today.toIso8601String());
      state = state.copyWith(currentStreak: 1);
    }
    _calculateScore();
  }

  void _calculateScore() {
    // 1. S_budget (40 points max)
    final budgetsAsync = ref.read(budgetNotifierProvider);
    final budgets = budgetsAsync.value ?? [];
    double sBudget = 40.0;
    if (budgets.isNotEmpty) {
      final double totalLimit = budgets.fold(
        0.0,
        (sum, b) => sum + b.budget.amountLimit,
      );
      final double totalSpent = budgets.fold(0.0, (sum, b) => sum + b.spent);
      if (totalLimit > 0) {
        double ratio = totalSpent / totalLimit;
        if (ratio > 1.0) ratio = 1.0;
        sBudget = 40.0 * (1.0 - ratio);
      }
    }

    // 2. S_saving (30 points max)
    final transactionsAsync = ref.read(transactionNotifierProvider);
    final transactions = transactionsAsync.value ?? [];
    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in transactions) {
      if (t.type == 'income') totalIncome += t.amount;
      if (t.type == 'expense') totalExpense += t.amount;
    }
    double sSaving = 0;
    if (totalIncome > 0) {
      double savingRatio = (totalIncome - totalExpense) / totalIncome;
      if (savingRatio < 0) savingRatio = 0;
      if (savingRatio > 1) savingRatio = 1;
      sSaving = 30.0 * savingRatio;
    } else if (totalExpense == 0) {
      sSaving = 15; // Neutral
    }

    // 3. S_streak (20 points max)
    final double sStreak = min(state.currentStreak * 2.8, 20.0);

    // 4. S_wallet (5 points max)
    final walletsAsync = ref.read(walletProvider);
    final wallets = walletsAsync.value ?? [];
    final double sWallet = wallets.length >= 2
        ? 5.0
        : (wallets.length == 1 ? 2.5 : 0.0);

    // 5. S_goal (5 points max) — provided by GoalGamificationService
    final double sGoal = state.scoreGoal.toDouble();

    int totalScore = (sBudget + sSaving + sStreak + sWallet + sGoal).round();

    // Safety cap
    if (totalScore > 100) totalScore = 100;
    if (totalScore < 0) totalScore = 0;

    state = state.copyWith(
      healthScore: totalScore,
      scoreBudget: sBudget.round(),
      scoreSaving: sSaving.round(),
      scoreStreak: sStreak.round(),
      scoreWallet: sWallet.round(),
      scoreGoal: sGoal.round(),
    );

    _checkBadges();
  }

  /// Awards a badge if not already unlocked. Returns true if newly awarded.
  Future<bool> awardBadge(String badgeName) async {
    if (state.unlockedBadges.contains(badgeName)) return false;

    final newBadges = [...state.unlockedBadges, badgeName];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_badgesKey, newBadges);
    state = state.copyWith(unlockedBadges: newBadges);
    return true;
  }

  /// Updates the S_goal score component and recalculates the total health score.
  void updateGoalScore(int score) {
    state = state.copyWith(scoreGoal: score);
    _calculateScore();
  }

  Future<void> _checkBadges() async {
    final List<String> newBadges = List.from(state.unlockedBadges);
    bool changed = false;

    if (state.currentStreak >= 7 && !newBadges.contains('streak_7')) {
      newBadges.add('streak_7');
      changed = true;
    }
    if (state.healthScore >= 80 && !newBadges.contains('healthy_80')) {
      newBadges.add('healthy_80');
      changed = true;
    }

    // Saver Master
    final transactionsAsync = ref.read(transactionNotifierProvider);
    final transactions = transactionsAsync.value ?? [];
    final int expenseCount = transactions
        .where((t) => t.type == 'expense')
        .length;
    if (expenseCount >= 50 && !newBadges.contains('saver_master')) {
      newBadges.add('saver_master');
      changed = true;
    }

    if (changed) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_badgesKey, newBadges);
      state = state.copyWith(unlockedBadges: newBadges);
    }
  }
}
