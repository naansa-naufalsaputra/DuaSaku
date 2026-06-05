# Implementation Plan: Financial Goals

## Overview

Implement the Financial Goals (Savings Target) feature for DuaSaku, enabling users to create savings goals, track progress via manual deposits or linked wallet balance, visualize progress with milestone markers, earn gamification badges, and receive local notifications. The implementation follows the existing feature-based clean architecture with Riverpod AsyncNotifier, Drift persistence (schema migration v5→v6), and integrates with the existing gamification and notification systems.

## Tasks

- [x] 1. Set up feature structure, domain models, and database schema
  - [x] 1.1 Create domain models and enums
    - Create `lib/features/goals/domain/models/goal_status.dart` with `GoalStatus` enum (active, completed, archived) and `TrackingMode` enum (manual, wallet)
    - Create `lib/features/goals/domain/models/goal_model.dart` with all fields, computed properties (`progressPercentage`, `remainingDays`, `currentMilestone`), and `copyWith` method
    - Create `lib/features/goals/domain/models/goal_deposit_model.dart` with id, goalId, amount, note, createdAt fields
    - _Requirements: 1.1, 1.5, 1.6, 1.7, 9.1, 9.2_

  - [x] 1.2 Create repository interface
    - Create `lib/features/goals/domain/goal_repository_interface.dart` with abstract class defining all CRUD, query, deposit, wallet-linking, and completion methods using `Result<T, AppError>` return types and `Stream` for watch queries
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

  - [x] 1.3 Add Drift tables and migrate database to schema v6
    - Add `Goals` table class with all columns, indexes (`idx_goals_user_id`, `idx_goals_status`, `idx_goals_linked_wallet`), and FK to Wallets (nullable, onDelete: setNull) in `app_database.dart`
    - Add `GoalDeposits` table class with columns, index (`idx_goal_deposits_goal_id`), and FK to Goals (onDelete: cascade)
    - Register both tables in `@DriftDatabase` annotation and add `GoalDao` to daos list
    - Bump `schemaVersion` to 6 and add migration block: `if (from < 6) { ... }` creating tables and indexes
    - Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_database.g.dart`
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x] 1.4 Write unit tests for GoalModel computed properties
    - Test `progressPercentage` for various currentAmount/targetAmount ratios including edge cases (0/0, max values)
    - Test `remainingDays` with future deadline, past deadline, null deadline
    - Test `currentMilestone` at boundary values (0%, 24%, 25%, 49%, 50%, 74%, 75%, 99%, 100%)
    - _Requirements: 5.1, 2.3, 11.2_

- [x] 2. Implement data layer (DAO and Repository)
  - [x] 2.1 Create GoalDao with Drift queries
    - Create `lib/features/goals/data/goal_dao.dart` as a `@DriftAccessor` with tables: Goals, GoalDeposits
    - Implement: insertGoal, getGoalById, updateGoal, deleteGoal, watchGoalsByUser (with optional status filter), getGoalsByUser, insertDeposit, watchDepositsByGoal, getDepositsByGoal, getGoalByLinkedWallet, isWalletLinked, markCompleted, archiveGoal
    - Use `watch()` for stream-based queries
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

  - [x] 2.2 Create GoalRepository implementing GoalRepositoryInterface
    - Create `lib/features/goals/data/goal_repository.dart` implementing `GoalRepositoryInterface`
    - Map between Drift companion/data classes and domain models (GoalModel, GoalDepositModel)
    - Wrap all DAO calls in try-catch returning `Result<T, AppError>` (Success/Failure)
    - Handle `SqliteException` for constraint violations
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

  - [x] 2.3 Write unit tests for GoalDao
    - Test CRUD operations with in-memory Drift database (`AppDatabase.forTesting(NativeDatabase.memory())`)
    - Test cascade delete (goal deletion removes deposits)
    - Test FK set-null behavior (wallet deletion nullifies linkedWalletId)
    - Test stream reactivity (insert triggers stream update)
    - Test status filtering in watchGoalsByUser
    - _Requirements: 9.3, 9.4, 9.5, 9.6_

- [x] 3. Checkpoint - Ensure data layer tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement business logic (Providers and Services)
  - [x] 4.1 Create GoalNotifier (AsyncNotifier)
    - Create `lib/features/goals/providers/goal_provider.dart` with `GoalNotifier extends AsyncNotifier<List<GoalModel>>`
    - Implement `build()` method subscribing to `watchGoals` stream (same pattern as existing TransactionNotifier)
    - Implement `createGoal` with validation (name length 1-100, positive target, future deadline), tracking mode assignment based on linkedWalletId presence, and initial currentAmount from wallet balance if wallet-linked
    - Implement `addDeposit` with validation, cap enforcement, deposit persistence, goal update, and milestone/completion check
    - Implement `updateGoal` with validation and cap enforcement if target reduced
    - Implement `deleteGoal` (cascade handled by DB)
    - Implement `syncWalletBalance` respecting cap and completion permanence
    - Implement `archiveGoal` status transition
    - Add `ref.listen(walletProvider, ...)` for automatic wallet sync in `build()`
    - Create Riverpod provider declarations (`goalNotifierProvider`, `goalRepositoryProvider`)
    - _Requirements: 1.1–1.8, 3.1–3.5, 4.1–4.4, 6.1–6.5, 10.1–10.6_

  - [x] 4.2 Create GoalGamificationService
    - Create `lib/features/goals/providers/goal_gamification_provider.dart`
    - Implement `calculateSGoal(List<GoalModel> goals)`: average progress × 5, clamped 0–5, returns 0 if no active goals
    - Implement `checkMilestoneBadges(GoalModel goal)`: award quarter_saver (25%), half_way (50%), goal_achieved (100%) via existing GamificationNotifier
    - Implement `checkCompletionBadges(int completedCount)`: award triple_saver (3), savings_master (5)
    - Wire into existing gamification system's health score calculation
    - _Requirements: 7.1–7.7_

  - [x] 4.3 Create GoalNotificationService
    - Create `lib/features/goals/services/goal_notification_service.dart`
    - Implement `notifyMilestone(goal, milestonePercent)`: send immediate local notification, update `notifiedMilestones` set to prevent duplicates
    - Implement `scheduleDeadlineReminders(goal)`: schedule 7-day and 1-day reminders via `flutter_local_notifications` zonedSchedule (only if goal has deadline)
    - Implement `cancelGoalNotifications(goalId)`: cancel all scheduled notifications for a goal
    - Implement `notifyCompletion(goal)`: send celebration notification
    - Use existing notification channel/setup from the app
    - _Requirements: 8.1–8.5_

  - [x] 4.4 Write property tests for goal domain logic
    - **Property 1: Goal creation round-trip** — Create goal via repository, read back, assert all fields preserved
    - **Validates: Requirements 1.1, 1.8, 11.5**
    - _File: `test/features/goals/properties/goal_properties_test.dart`_

  - [x] 4.5 Write property test for deposit sum invariant
    - **Property 2: Deposit sum invariant** — For any sequence of deposits, currentAmount == min(sum(deposits), targetAmount)
    - **Validates: Requirements 3.1, 3.4, 11.1**

  - [x] 4.6 Write property test for progress percentage formula
    - **Property 3: Progress percentage formula** — For any goal with targetAmount > 0, progressPercentage == (currentAmount / targetAmount).clamp(0.0, 1.0)
    - **Validates: Requirements 5.1, 11.2**

  - [x] 4.7 Write property test for current amount cap invariant
    - **Property 4: Current amount cap invariant** — For any sequence of deposits/syncs, currentAmount <= targetAmount always holds
    - **Validates: Requirements 3.4, 6.2, 11.3**

  - [x] 4.8 Write property test for wallet-linked goal synchronization
    - **Property 5: Wallet-linked goal synchronization** — After wallet balance change, goal currentAmount == min(wallet.balance, goal.targetAmount)
    - **Validates: Requirements 4.1, 4.2, 11.4**

  - [x] 4.9 Write property test for milestone check idempotence
    - **Property 6: Milestone check idempotence** — Applying milestone check N times produces same result as applying once
    - **Validates: Requirements 8.5, 11.6**

  - [x] 4.10 Write property test for completed goal invariant
    - **Property 7: Completed goal invariant** — Any completed goal has currentAmount == targetAmount
    - **Validates: Requirements 10.1, 11.7**

  - [x] 4.11 Write property test for input validation
    - **Property 8: Input validation rejects invalid data** — Invalid name/amount/deadline/deposit always returns validation error without state change
    - **Validates: Requirements 1.2, 1.3, 1.4, 3.2**

  - [x] 4.12 Write property test for tracking mode assignment
    - **Property 9: Tracking mode assignment** — linkedWalletId null → manual, non-null → wallet
    - **Validates: Requirements 1.6, 1.7**

  - [x] 4.13 Write property test for completion permanence
    - **Property 10: Completion permanence** — Completed goal status never reverts to active regardless of wallet balance changes
    - **Validates: Requirements 10.5, 10.6**

  - [x] 4.14 Write property test for S_goal health score
    - **Property 11: S_goal health score calculation** — S_goal == (avg_progress × 5).clamp(0, 5), 0 if no active goals
    - **Validates: Requirements 7.6, 7.7**

  - [x] 4.15 Write property test for milestone badge awarding
    - **Property 12: Milestone badge awarding** — Crossing milestone threshold adds badge without duplicates
    - **Validates: Requirements 7.1, 7.2, 7.3**

- [x] 5. Checkpoint - Ensure business logic and property tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Implement presentation layer
  - [x] 6.1 Create GoalListScreen with tabs
    - Create `lib/features/goals/presentation/screens/goal_list_screen.dart`
    - Implement TabBar with "Active" and "Completed" tabs
    - Display goals using `goalNotifierProvider` with loading/error/data states
    - Sort active goals by creation date (newest first)
    - Add FAB for creating new goal (navigates to GoalFormScreen)
    - Include empty state illustration when no goals exist
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 10.3_

  - [x] 6.2 Create GoalCard widget with progress bar
    - Create `lib/features/goals/presentation/widgets/goal_card.dart` showing name, current/target amount, progress percentage, remaining days
    - Create `lib/features/goals/presentation/widgets/goal_progress_bar.dart` with animated progress bar (flutter_animate) and milestone markers at 25/50/75/100%
    - Create `lib/features/goals/presentation/widgets/milestone_marker.dart` for individual milestone indicators with celebration animation on unlock
    - _Requirements: 2.2, 5.1, 5.2, 5.3_

  - [x] 6.3 Create GoalDetailScreen
    - Create `lib/features/goals/presentation/screens/goal_detail_screen.dart`
    - Display full progress visualization with milestone markers
    - Show deposit history list using `watchDeposits` stream
    - Create `lib/features/goals/presentation/widgets/deposit_history_tile.dart` for deposit list items
    - Add action buttons: Add Deposit, Edit, Archive, Delete
    - Show Lottie celebration animation when goal is 100% complete
    - _Requirements: 2.5, 5.1, 5.2, 5.4_

  - [x] 6.4 Create GoalFormScreen (Create/Edit)
    - Create `lib/features/goals/presentation/screens/goal_form_screen.dart`
    - Form fields: name (TextFormField, 1-100 chars), target amount (numeric input, > 0), deadline (optional DatePicker, must be future), icon picker, color picker, wallet selector (dropdown, optional, filtered to unlinked wallets)
    - Inline validation with error messages
    - Handle both create and edit modes (pre-fill fields in edit mode)
    - Show warning when reducing target below current amount in edit mode
    - _Requirements: 1.1–1.8, 6.1, 6.2_

  - [x] 6.5 Create GoalDepositScreen (Bottom Sheet)
    - Create `lib/features/goals/presentation/screens/goal_deposit_screen.dart` as a modal bottom sheet
    - Amount input field with validation (positive number)
    - Optional note text field
    - Submit button calling `goalNotifierProvider.addDeposit()`
    - Show remaining amount needed to reach target
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [x] 6.6 Add localization strings (ID + EN)
    - Add all goal-related strings to localization JSON files for both Indonesian and English
    - Include: screen titles, form labels, validation messages, notification texts, empty states, confirmation dialogs
    - _Requirements: All UI requirements_

  - [x] 6.7 Write widget tests for GoalProgressBar
    - Test progress bar renders correct fill percentage
    - Test milestone markers appear at correct positions
    - Test celebration animation triggers at 100%
    - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 7. Wire navigation and integrate with existing systems
  - [x] 7.1 Register routes and navigation
    - Add goal routes to `lib/core/routing/app_router.dart` (goal list, detail, form screens)
    - Add Goals entry point to the main dashboard/home screen navigation
    - Wire FAB and card taps to correct navigation targets
    - _Requirements: 2.5_

  - [x] 7.2 Integrate GoalGamificationService with existing health score
    - Connect `calculateSGoal` output to the existing gamification health score system
    - Ensure S_goal is included in the overall health score calculation alongside existing components
    - Register badge definitions (quarter_saver, half_way, goal_achieved, triple_saver, savings_master) in the gamification system
    - _Requirements: 7.1–7.7_

  - [x] 7.3 Wire notification service and schedule reminders
    - Initialize `GoalNotificationService` in the app startup/provider setup
    - Ensure milestone notifications fire after deposit/sync operations in GoalNotifier
    - Schedule deadline reminders on goal creation/edit (with deadline)
    - Cancel notifications on goal deletion or completion
    - _Requirements: 8.1–8.5_

  - [x] 7.4 Write integration tests for wallet-goal sync
    - Test wallet balance change propagates to linked goal's currentAmount
    - Test wallet deletion switches goal to manual mode
    - Test wallet already linked to active goal prevents re-linking
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

  - [x] 7.5 Write integration tests for gamification integration
    - Test S_goal calculation updates when goals progress
    - Test badge awarding on milestone crossing
    - Test completion count badges (triple_saver, savings_master)
    - _Requirements: 7.1–7.7_

- [x] 8. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document (12 properties total)
- Unit tests validate specific examples and edge cases
- The Drift schema migration (v5→v6) is non-destructive — only adds new tables and indexes
- All property tests use `dart_check` library with minimum 100 iterations
- Wallet sync logic respects completion permanence (completed goals never revert)
- Localization covers both Indonesian and English via easy_localization

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3"] },
    { "id": 2, "tasks": ["1.4", "2.1"] },
    { "id": 3, "tasks": ["2.2"] },
    { "id": 4, "tasks": ["2.3"] },
    { "id": 5, "tasks": ["4.1"] },
    { "id": 6, "tasks": ["4.2", "4.3"] },
    { "id": 7, "tasks": ["4.4", "4.5", "4.6", "4.7", "4.8", "4.9", "4.10", "4.11", "4.12", "4.13", "4.14", "4.15"] },
    { "id": 8, "tasks": ["6.1", "6.2", "6.6"] },
    { "id": 9, "tasks": ["6.3", "6.4", "6.5"] },
    { "id": 10, "tasks": ["6.7", "7.1"] },
    { "id": 11, "tasks": ["7.2", "7.3"] },
    { "id": 12, "tasks": ["7.4", "7.5"] }
  ]
}
```
