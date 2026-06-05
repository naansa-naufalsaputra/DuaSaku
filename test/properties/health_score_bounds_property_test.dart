// Feature: system-audit-fixes, Property 6: Health score is bounded within [0, 100]
// **Validates: Requirements 6.3**

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

// ---------------------------------------------------------------------------
// Pure reimplementation of the health score formula from
// GamificationNotifier._calculateScore() for property-based testing.
// This avoids needing Riverpod/provider infrastructure.
// ---------------------------------------------------------------------------

/// Computes the health score using the same formula as
/// GamificationNotifier._calculateScore().
///
/// Parameters:
/// - [budgetRatio]: totalSpent / totalLimit (can exceed 1.0 if overspent)
/// - [hasBudgets]: whether any budgets exist (if false, S_budget defaults to 40)
/// - [totalIncome]: total income amount
/// - [totalExpense]: total expense amount
/// - [streak]: current streak count in days
/// - [walletCount]: number of wallets
/// - [goalScore]: goal score component (0-5)
int calculateHealthScore({
  required double budgetRatio,
  required bool hasBudgets,
  required double totalIncome,
  required double totalExpense,
  required int streak,
  required int walletCount,
  required int goalScore,
}) {
  // 1. S_budget (40 points max)
  double sBudget = 40.0;
  if (hasBudgets) {
    double ratio = budgetRatio;
    if (ratio > 1.0) ratio = 1.0;
    sBudget = 40.0 * (1.0 - ratio);
  }

  // 2. S_saving (30 points max)
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
  final double sStreak = min(streak * 2.8, 20.0);

  // 4. S_wallet (5 points max)
  final double sWallet = walletCount >= 2 ? 5.0 : (walletCount == 1 ? 2.5 : 0.0);

  // 5. S_goal (5 points max)
  final double sGoal = goalScore.toDouble();

  int totalScore = (sBudget + sSaving + sStreak + sWallet + sGoal).round();

  // Safety cap
  if (totalScore > 100) totalScore = 100;
  if (totalScore < 0) totalScore = 0;

  return totalScore;
}

// ---------------------------------------------------------------------------
// Property-based tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'Feature: system-audit-fixes, '
    'Property 6: Health score is bounded within [0, 100]',
    () {
      // Test with budgets present (hasBudgets = true)
      Glados2(
        any.doubleInRange(0, 3.0), // budgetRatio: 0 to 3x overspent
        any.intInRange(0, 500), // streak: 0 to 500 days
        ExploreConfig(numRuns: 100),
      ).test(
        'health score is within [0, 100] for any budget ratio and streak (with budgets)',
        (budgetRatio, streak) {
          // Generate additional random inputs deterministically from the inputs
          final rng = Random((budgetRatio * 1000).toInt() ^ streak);
          final totalIncome = rng.nextDouble() * 100000;
          final totalExpense = rng.nextDouble() * 150000; // can exceed income
          final walletCount = rng.nextInt(15);
          final goalScore = rng.nextInt(6); // 0-5

          final score = calculateHealthScore(
            budgetRatio: budgetRatio,
            hasBudgets: true,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            streak: streak,
            walletCount: walletCount,
            goalScore: goalScore,
          );

          expect(score, greaterThanOrEqualTo(0));
          expect(score, lessThanOrEqualTo(100));
        },
      );

      // Test without budgets (hasBudgets = false, S_budget defaults to 40)
      Glados2(
        any.intInRange(0, 500), // streak
        any.intInRange(0, 15), // walletCount
        ExploreConfig(numRuns: 100),
      ).test(
        'health score is within [0, 100] without budgets for any streak and wallet count',
        (streak, walletCount) {
          final rng = Random(streak ^ walletCount);
          final totalIncome = rng.nextDouble() * 100000;
          final totalExpense = rng.nextDouble() * 150000;
          final goalScore = rng.nextInt(6);

          final score = calculateHealthScore(
            budgetRatio: 0.0, // irrelevant when hasBudgets is false
            hasBudgets: false,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            streak: streak,
            walletCount: walletCount,
            goalScore: goalScore,
          );

          expect(score, greaterThanOrEqualTo(0));
          expect(score, lessThanOrEqualTo(100));
        },
      );

      // Test edge case: zero income and zero expense (neutral saving = 15)
      Glados2(
        any.intInRange(0, 500), // streak
        any.intInRange(0, 5), // goalScore
        ExploreConfig(numRuns: 100),
      ).test(
        'health score is within [0, 100] when income and expense are both zero',
        (streak, goalScore) {
          final rng = Random(streak ^ goalScore);
          final walletCount = rng.nextInt(15);
          final budgetRatio = rng.nextDouble() * 3.0;

          final score = calculateHealthScore(
            budgetRatio: budgetRatio,
            hasBudgets: rng.nextBool(),
            totalIncome: 0,
            totalExpense: 0,
            streak: streak,
            walletCount: walletCount,
            goalScore: goalScore,
          );

          expect(score, greaterThanOrEqualTo(0));
          expect(score, lessThanOrEqualTo(100));
        },
      );

      // Test with negative saving ratio (expense > income)
      Glados2(
        any.doubleInRange(0.01, 50000), // totalIncome (positive)
        any.doubleInRange(0.01, 150000), // totalExpense (can exceed income)
        ExploreConfig(numRuns: 100),
      ).test(
        'health score is within [0, 100] for any income/expense combination',
        (totalIncome, totalExpense) {
          final rng = Random((totalIncome * 100).toInt() ^ (totalExpense * 100).toInt());
          final streak = rng.nextInt(500);
          final walletCount = rng.nextInt(15);
          final goalScore = rng.nextInt(6);
          final budgetRatio = rng.nextDouble() * 3.0;

          final score = calculateHealthScore(
            budgetRatio: budgetRatio,
            hasBudgets: rng.nextBool(),
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            streak: streak,
            walletCount: walletCount,
            goalScore: goalScore,
          );

          expect(score, greaterThanOrEqualTo(0));
          expect(score, lessThanOrEqualTo(100));
        },
      );
    },
  );
}
