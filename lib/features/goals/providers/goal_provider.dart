import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/local_db/app_database_provider.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/result.dart';
import '../../auth/providers/auth_provider.dart';
import '../../gamification/providers/gamification_provider.dart';
import '../../wallets/domain/models/wallet_model.dart';
import '../../wallets/providers/wallet_provider.dart';
import '../data/goal_repository.dart';
import '../domain/goal_repository_interface.dart';
import '../domain/models/goal_deposit_model.dart';
import '../domain/models/goal_model.dart';
import '../domain/models/goal_status.dart';
import '../services/goal_notification_service.dart';
import 'goal_gamification_provider.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Provider declarations
// ---------------------------------------------------------------------------

final goalRepositoryProvider = Provider<GoalRepositoryInterface>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GoalRepository(db.goalDao);
});

/// Provides the GoalNotificationService for milestone, completion, and
/// deadline reminder notifications.
final goalNotificationServiceProvider = Provider<GoalNotificationService>((
  ref,
) {
  final plugin = FlutterLocalNotificationsPlugin();
  return GoalNotificationService(plugin);
});

final goalNotifierProvider =
    AsyncNotifierProvider<GoalNotifier, List<GoalModel>>(GoalNotifier.new);

// ---------------------------------------------------------------------------
// GoalNotifier
// ---------------------------------------------------------------------------

/// Manages the list of financial goals for the current user.
///
/// Subscribes to a Drift stream for real-time updates and listens to
/// [walletProvider] changes to automatically sync wallet-linked goals.
class GoalNotifier extends AsyncNotifier<List<GoalModel>> {
  late GoalRepositoryInterface _repository;
  late GoalNotificationService _notificationService;
  StreamSubscription<List<GoalModel>>? _subscription;

  @override
  Future<List<GoalModel>> build() async {
    _repository = ref.watch(goalRepositoryProvider);
    _notificationService = ref.watch(goalNotificationServiceProvider);
    final user = ref.watch(userProvider);

    // Cancel previous subscription on rebuild
    _subscription?.cancel();

    // Clean up subscription when provider is disposed
    ref.onDispose(() {
      _subscription?.cancel();
    });

    if (user?.id == null) {
      return [];
    }

    // Listen to wallet changes for automatic sync of wallet-linked goals
    ref.listen(walletProvider, (previous, next) {
      final wallets = next.valueOrNull ?? [];
      _syncLinkedGoals(wallets);
    });

    // Set up reactive stream listening using completer pattern
    final completer = Completer<List<GoalModel>>();
    bool isFirst = true;

    _subscription = _repository
        .watchGoals(user!.id)
        .listen(
          (goals) {
            if (isFirst) {
              completer.complete(goals);
              isFirst = false;
            } else {
              state = AsyncData(goals);
            }
            // Update S_goal score whenever goals list changes
            _updateGoalScore();
          },
          onError: (e, stack) {
            if (isFirst) {
              completer.completeError(e, stack);
              isFirst = false;
            } else {
              state = AsyncError(e, stack);
            }
          },
        );

    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Public methods
  // ---------------------------------------------------------------------------

  /// Creates a new financial goal with validation.
  ///
  /// If [linkedWalletId] is provided, the goal uses wallet tracking mode and
  /// its initial [currentAmount] is set to the wallet's current balance.
  Future<Result<GoalModel, AppError>> createGoal({
    required String name,
    required double targetAmount,
    DateTime? deadline,
    required String icon,
    required String color,
    String? linkedWalletId,
  }) async {
    // Validation
    if (name.isEmpty || name.length > 100) {
      return Failure(AppError.validation('Goal name must be 1-100 characters'));
    }
    if (targetAmount <= 0) {
      return Failure(
        AppError.validation('Target amount must be greater than zero'),
      );
    }
    if (deadline != null && deadline.isBefore(DateTime.now())) {
      return Failure(AppError.validation('Deadline cannot be in the past'));
    }

    final user = ref.read(userProvider);
    if (user?.id == null) {
      return Failure(AppError.validation('User not authenticated'));
    }

    // Determine tracking mode and initial amount
    TrackingMode trackingMode;
    double initialAmount = 0.0;

    if (linkedWalletId != null) {
      // Check if wallet is already linked to another active goal
      final linkedResult = await _repository.isWalletLinked(linkedWalletId);
      switch (linkedResult) {
        case Success(:final value):
          if (value) {
            return Failure(
              AppError.validation(
                'This wallet is already linked to another active goal',
              ),
            );
          }
        case Failure(:final error):
          return Failure(error);
      }

      trackingMode = TrackingMode.wallet;

      // Set initial currentAmount from wallet balance
      final wallets = ref.read(walletProvider).valueOrNull ?? [];
      final wallet = _findWallet(wallets, linkedWalletId);
      if (wallet != null) {
        initialAmount = wallet.balance.clamp(0.0, targetAmount);
      }
    } else {
      trackingMode = TrackingMode.manual;
    }

    final goal = GoalModel(
      id: _uuid.v4(),
      userId: user!.id,
      name: name,
      targetAmount: targetAmount,
      currentAmount: initialAmount,
      deadline: deadline,
      icon: icon,
      color: color,
      linkedWalletId: linkedWalletId,
      trackingMode: trackingMode,
      status: GoalStatus.active,
      createdAt: DateTime.now(),
    );

    final result = await _repository.createGoal(goal);
    switch (result) {
      case Success(:final value):
        // Check if already completed on creation (wallet balance >= target)
        if (value.currentAmount >= value.targetAmount) {
          await _markCompleted(value.id);
          await _notificationService.notifyCompletion(value);
        }
        // Schedule deadline reminders if deadline is set
        if (value.deadline != null) {
          await _notificationService.scheduleDeadlineReminders(value);
        }
        return Success(value);
      case Failure(:final error):
        return Failure(error);
    }
  }

  /// Adds a manual deposit to a goal.
  ///
  /// Validates amount > 0, caps at target amount, persists the deposit,
  /// updates the goal, and checks for milestone/completion.
  Future<Result<void, AppError>> addDeposit(
    String goalId,
    double amount, {
    String? note,
  }) async {
    // Validate
    if (amount <= 0) {
      return Failure(
        AppError.validation('Deposit amount must be greater than zero'),
      );
    }

    // Get current goal
    final goalResult = await _repository.getGoal(goalId);
    late GoalModel goal;
    switch (goalResult) {
      case Success(:final value):
        goal = value;
      case Failure(:final error):
        return Failure(error);
    }

    // Calculate effective amount (cap at targetAmount)
    final effectiveAmount = (goal.currentAmount + amount > goal.targetAmount)
        ? goal.targetAmount - goal.currentAmount
        : amount;

    if (effectiveAmount <= 0) {
      return Failure(AppError.validation('Goal is already fully funded'));
    }

    // Persist deposit
    final deposit = GoalDepositModel(
      id: _uuid.v4(),
      goalId: goalId,
      amount: effectiveAmount,
      note: note,
      createdAt: DateTime.now(),
    );
    final depositResult = await _repository.addDeposit(deposit);
    switch (depositResult) {
      case Success():
        break;
      case Failure(:final error):
        return Failure(error);
    }

    // Update goal currentAmount
    final updatedGoal = goal.copyWith(
      currentAmount: goal.currentAmount + effectiveAmount,
    );
    final updateResult = await _repository.updateGoal(updatedGoal);
    switch (updateResult) {
      case Success():
        break;
      case Failure(:final error):
        return Failure(error);
    }

    // Check completion & milestones
    await _checkCompletionAndMilestones(updatedGoal);

    return const Success(null);
  }

  /// Updates an existing goal with validation and cap enforcement.
  Future<Result<void, AppError>> updateGoal(GoalModel goal) async {
    // Validate
    if (goal.name.isEmpty || goal.name.length > 100) {
      return Failure(AppError.validation('Goal name must be 1-100 characters'));
    }
    if (goal.targetAmount <= 0) {
      return Failure(
        AppError.validation('Target amount must be greater than zero'),
      );
    }
    if (goal.deadline != null && goal.deadline!.isBefore(DateTime.now())) {
      return Failure(AppError.validation('Deadline cannot be in the past'));
    }

    // Cap enforcement: if target reduced below current amount
    GoalModel goalToSave = goal;
    if (goal.currentAmount > goal.targetAmount) {
      goalToSave = goal.copyWith(currentAmount: goal.targetAmount);
    }

    final result = await _repository.updateGoal(goalToSave);
    switch (result) {
      case Success():
        // Re-schedule deadline reminders if deadline is set
        if (goalToSave.deadline != null) {
          // Cancel existing deadline notifications first, then re-schedule
          await _notificationService.cancelGoalNotifications(goalToSave.id);
          await _notificationService.scheduleDeadlineReminders(goalToSave);
        } else {
          // Deadline removed — cancel any existing deadline notifications
          await _notificationService.cancelGoalNotifications(goalToSave.id);
        }
        return const Success(null);
      case Failure(:final error):
        return Failure(error);
    }
  }

  /// Deletes a goal. Cascade delete of deposits is handled by the DB.
  Future<Result<void, AppError>> deleteGoal(String goalId) async {
    // Cancel all scheduled notifications for this goal
    await _notificationService.cancelGoalNotifications(goalId);
    return _repository.deleteGoal(goalId);
  }

  /// Synchronizes a wallet-linked goal's currentAmount with the wallet balance.
  ///
  /// Respects completion permanence: completed goals are not modified.
  /// Caps currentAmount at targetAmount.
  Future<void> syncWalletBalance(String goalId, double newBalance) async {
    final goalResult = await _repository.getGoal(goalId);
    late GoalModel goal;
    switch (goalResult) {
      case Success(:final value):
        goal = value;
      case Failure():
        return; // Goal not found, nothing to sync
    }

    // Completion permanence: do not modify completed goals
    if (goal.isCompleted) return;

    // Cap at target amount
    final cappedAmount = newBalance.clamp(0.0, goal.targetAmount);

    if (cappedAmount == goal.currentAmount) return; // No change

    final updatedGoal = goal.copyWith(currentAmount: cappedAmount);
    final updateResult = await _repository.updateGoal(updatedGoal);
    switch (updateResult) {
      case Success():
        // Check milestone badges after wallet sync changes progress
        final gamificationService = ref.read(goalGamificationProvider);
        await gamificationService.checkMilestoneBadges(updatedGoal);

        // Update S_goal score
        _updateGoalScore();

        // Fire milestone notifications for newly crossed milestones
        final milestones = [25, 50, 75];
        for (final milestone in milestones) {
          final threshold = goal.targetAmount * milestone / 100;
          if (cappedAmount >= threshold &&
              !goal.notifiedMilestones.contains(milestone)) {
            await _notificationService.notifyMilestone(updatedGoal, milestone);
          }
        }

        // Check if goal reached 100%
        if (cappedAmount >= goal.targetAmount) {
          await _markCompleted(goal.id);

          // Send completion notification and cancel deadline reminders
          await _notificationService.notifyCompletion(updatedGoal);
          await _notificationService.cancelGoalNotifications(goal.id);

          // Award completion badges
          final allGoals = state.valueOrNull ?? [];
          final completedCount =
              allGoals.where((g) => g.status == GoalStatus.completed).length +
              1;
          await gamificationService.checkCompletionBadges(completedCount);
        }
      case Failure():
        break; // Silently fail for sync operations
    }
  }

  /// Archives an active goal (status transition: active → archived).
  Future<Result<void, AppError>> archiveGoal(String goalId) async {
    return _repository.archiveGoal(goalId);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Syncs all wallet-linked goals when wallet balances change.
  Future<void> _syncLinkedGoals(List<WalletModel> wallets) async {
    final goals = state.valueOrNull ?? [];
    for (final goal in goals) {
      if (goal.trackingMode == TrackingMode.wallet &&
          goal.linkedWalletId != null) {
        final wallet = _findWallet(wallets, goal.linkedWalletId!);
        if (wallet != null && wallet.balance != goal.currentAmount) {
          await syncWalletBalance(goal.id, wallet.balance);
        }
      }
    }
  }

  /// Finds a wallet by ID in the given list.
  WalletModel? _findWallet(List<WalletModel> wallets, String walletId) {
    for (final wallet in wallets) {
      if (wallet.id == walletId) return wallet;
    }
    return null;
  }

  /// Marks a goal as completed.
  Future<void> _markCompleted(String goalId) async {
    await _repository.markCompleted(goalId, DateTime.now());
  }

  /// Updates the S_goal score in the gamification health score system.
  ///
  /// Calculates the score based on all current goals and pushes it to
  /// the [GamificationNotifier] via [updateGoalScore].
  void _updateGoalScore() {
    final goals = state.valueOrNull ?? [];
    final gamificationService = ref.read(goalGamificationProvider);
    final sGoal = gamificationService.calculateSGoal(goals);
    ref.read(gamificationProvider.notifier).updateGoalScore(sGoal.round());
  }

  /// Checks if a goal has reached completion or crossed a milestone.
  Future<void> _checkCompletionAndMilestones(GoalModel goal) async {
    final gamificationService = ref.read(goalGamificationProvider);

    // Check completion (100%)
    if (goal.currentAmount >= goal.targetAmount) {
      await _markCompleted(goal.id);

      // Send completion notification and cancel deadline reminders
      await _notificationService.notifyCompletion(goal);
      await _notificationService.cancelGoalNotifications(goal.id);

      // Award completion badges based on total completed count
      final allGoals = state.valueOrNull ?? [];
      final completedCount =
          allGoals.where((g) => g.status == GoalStatus.completed).length + 1;
      await gamificationService.checkCompletionBadges(completedCount);
    }

    // Check milestone badges based on progress
    await gamificationService.checkMilestoneBadges(goal);

    // Update S_goal score in the health score system
    _updateGoalScore();

    // Check milestones (25%, 50%, 75%, 100%)
    final milestones = [25, 50, 75, 100];
    final newMilestones = <int>{};

    for (final milestone in milestones) {
      final threshold = goal.targetAmount * milestone / 100;
      if (goal.currentAmount >= threshold &&
          !goal.notifiedMilestones.contains(milestone)) {
        newMilestones.add(milestone);
      }
    }

    if (newMilestones.isNotEmpty) {
      final updatedMilestones = {...goal.notifiedMilestones, ...newMilestones};
      final updatedGoal = goal.copyWith(notifiedMilestones: updatedMilestones);
      await _repository.updateGoal(updatedGoal);

      // Fire milestone notifications for newly crossed milestones
      // (exclude 100% since completion notification is already sent above)
      for (final milestone in newMilestones) {
        if (milestone < 100) {
          await _notificationService.notifyMilestone(goal, milestone);
        }
      }
    }
  }
}
