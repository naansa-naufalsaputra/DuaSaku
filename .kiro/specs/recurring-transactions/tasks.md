# Implementation Plan: Recurring Transactions

## Overview

Implement a recurring transactions feature for DuaSaku that allows users to schedule automatic repeating transactions (salary, bills, subscriptions). The implementation uses the existing workmanager infrastructure for background execution, Drift for persistence, Riverpod (AsyncNotifierProvider pattern) for state management, and flutter_animate + Lottie for premium UI animations. The feature follows the project's feature-based clean architecture with abstract repository interfaces in the domain layer.

## Tasks

- [x] 1. Domain layer — models, interfaces, and pure logic
  - [x] 1.1 Create domain models (Frequency, RecurringStatus, RecurringTransactionModel, ExecutionLogModel)
    - Create `lib/features/recurring_transactions/domain/models/frequency.dart` with `Frequency` enum (daily, weekly, monthly, yearly) including `maxInterval` getter
    - Create `lib/features/recurring_transactions/domain/models/recurring_status.dart` with `RecurringStatus` enum (active, paused, completed)
    - Create `lib/features/recurring_transactions/domain/models/recurring_transaction_model.dart` with all fields, `copyWith`, `fromDriftRow`, and `toDriftCompanion` methods
    - Create `lib/features/recurring_transactions/domain/models/execution_log_model.dart` with all fields and conversion methods
    - _Requirements: 7.1, 7.2_

  - [x] 1.2 Create RecurringTransactionRepositoryInterface
    - Create `lib/features/recurring_transactions/domain/recurring_transaction_repository_interface.dart`
    - Define CRUD methods returning `Result<T, AppError>`
    - Define query methods: `watchAll`, `getActive`, `getDueForExecution`, `getUpcoming`
    - Define execution methods: `updateNextExecutionDate`, `updateStatus`, `incrementRetryCount`, `resetRetryCount`
    - Define execution log methods and locking methods
    - _Requirements: 7.1, 7.2, 8.5_

  - [x] 1.3 Implement RecurringSchedulerLogic (pure Dart functions)
    - Create `lib/features/recurring_transactions/domain/recurring_scheduler_logic.dart`
    - Implement `computeNextExecutionDate` — calculates next date based on frequency and customInterval
    - Implement `computePreviewDates` — generates N upcoming dates for preview
    - Implement `computeProgressRing` — returns 0.0–1.0 value for ring widget
    - Implement `isValidCustomInterval` — validates interval against frequency bounds
    - Implement `computeMissedExecutions` — calculates all missed dates for catch-up (max 90)
    - All functions must be pure Dart with no external dependencies
    - _Requirements: 1.2, 1.5, 2.2, 2.4, 3.9, 8.4, 8.6_

  - [x] 1.4 Write property tests for RecurringSchedulerLogic (Property 1: Frequency/Interval Round-Trip)
    - **Property 1: Frequency/Interval Round-Trip**
    - **Validates: Requirements 8.6**
    - Use glados package to generate arbitrary (Frequency, customInterval, DateTime) tuples
    - Verify that computing next execution date produces a date offset matching frequency × customInterval

  - [x]* 1.5 Write property tests for RecurringSchedulerLogic (Property 2: Custom Interval Validation Boundaries)
    - **Property 2: Custom Interval Validation Boundaries**
    - **Validates: Requirements 1.2**
    - Use glados to generate arbitrary (Frequency, int) pairs
    - Verify `isValidCustomInterval` accepts iff 1 ≤ interval ≤ frequency.maxInterval

  - [x]* 1.6 Write property tests for RecurringSchedulerLogic (Property 3: Amount Validation Boundaries)
    - **Property 3: Amount Validation Boundaries**
    - **Validates: Requirements 1.6**
    - Use glados to generate arbitrary double values
    - Verify validation accepts iff 0.01 ≤ amount ≤ 999,999,999.99

  - [x]* 1.7 Write property tests for RecurringSchedulerLogic (Property 4: Preview Dates Computation)
    - **Property 4: Preview Dates Computation**
    - **Validates: Requirements 1.5**
    - Use glados to generate arbitrary (startDate, Frequency, customInterval) tuples
    - Verify `computePreviewDates(count: 5)` returns exactly 5 strictly increasing dates with correct intervals

  - [x]* 1.8 Write property tests for RecurringSchedulerLogic (Property 8: End Date Enforcement)
    - **Property 8: End Date Enforcement**
    - **Validates: Requirements 1.3, 1.4, 2.5**
    - Use glados to generate recurring transactions with and without end dates
    - Verify no computed next date exceeds end date; verify null end date always produces a valid next date

  - [x]* 1.9 Write property tests for RecurringSchedulerLogic (Property 10: Next Execution Date Invariant)
    - **Property 10: Next Execution Date Invariant**
    - **Validates: Requirements 8.4, 2.4**
    - Use glados to generate arbitrary execution dates
    - Verify `computeNextExecutionDate` always returns a date strictly greater than the input date

  - [x]* 1.10 Write property tests for RecurringSchedulerLogic (Property 13: Progress Ring Computation)
    - **Property 13: Progress Ring Computation**
    - **Validates: Requirements 3.9**
    - Use glados to generate (lastExecution, nextExecution, now) triples where last ≤ now ≤ next
    - Verify result is in [0.0, 1.0], 1.0 when now == last, 0.0 when now == next

- [x] 2. Checkpoint — Ensure all domain tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Data layer — Drift tables, DAO, repository, and migration
  - [x] 3.1 Define Drift tables (RecurringTransactions, RecurringExecutionLogs) and add badge column to Transactions
    - Add `RecurringTransactions` table class with all columns, primary key, indexes, and foreign keys to `app_database.dart`
    - Add `RecurringExecutionLogs` table class with all columns, auto-increment id, indexes, and foreign keys
    - Add `TextColumn get badge => text().nullable()()` to existing `Transactions` table
    - Register new tables in `@DriftDatabase` annotation
    - Increment `schemaVersion` from 4 to 5
    - Add migration step `if (from < 5)` to create new tables, indexes, and add badge column
    - Run `dart run build_runner build` to regenerate `.g.dart`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 5.1_

  - [x] 3.2 Implement RecurringTransactionDao
    - Create `lib/features/recurring_transactions/data/recurring_transaction_dao.dart`
    - Implement `watchByUser(userId)` — Stream query ordered by nextExecutionDate
    - Implement `getDueForExecution(now)` — select where status='active' AND nextExecutionDate <= now
    - Implement `getUpcoming(userId, days, limit)` — select active within N days, limited, ascending order
    - Implement CRUD: `insertRecurring`, `updateRecurring`, `deleteRecurring`, `getById`
    - Implement execution log methods: `insertLog`, `getLogsByRecurringId`
    - Register DAO in AppDatabase
    - _Requirements: 7.1, 7.2, 7.4, 5.2_

  - [x] 3.3 Implement RecurringTransactionRepository
    - Create `lib/features/recurring_transactions/data/recurring_transaction_repository.dart`
    - Implement `RecurringTransactionRepositoryInterface` using the DAO
    - Validate wallet and category existence on `create` and `update`
    - Use Result pattern for all fallible operations
    - Implement locking mechanism using a simple in-memory set (for single-isolate) or DB flag for background isolate
    - _Requirements: 1.7, 1.8, 8.5_

  - [x]* 3.4 Write property test for repository/executor (Property 12: Dashboard Upcoming Query)
    - **Property 12: Dashboard Upcoming Query**
    - **Validates: Requirements 5.2**
    - Use in-memory Drift database with glados-generated recurring transactions
    - Verify `getUpcoming(days=7, limit=5)` returns ≤5 results, all within 7 days, sorted ascending

- [x] 4. Background execution — RecurringExecutor and workmanager integration
  - [x] 4.1 Implement RecurringExecutor
    - Create `lib/core/background/recurring_executor.dart`
    - Implement `execute()` — main entry point: get due transactions, lock, execute, unlock
    - Implement `_executeRecurring` — create transaction, log execution, update next date
    - Implement `_handleCatchUp` — compute missed executions, execute chronologically (max 90)
    - Implement `_createTransaction` — insert into Transactions table with badge='recurring'
    - Implement `_logExecution` — insert into RecurringExecutionLogs
    - Implement `_updateNextDate` — compute and set next execution date, handle end date → completed
    - Implement `_handleFailure` — retry logic (max 3 for DB errors), immediate pause for other errors
    - Initialize database directly (no Riverpod in background isolate)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 5.1, 8.1, 8.5_

  - [x] 4.2 Integrate RecurringExecutor into existing callbackDispatcher
    - Modify `lib/core/background/background_task_helper.dart`
    - Import and instantiate `RecurringExecutor` in `callbackDispatcher`
    - Call `executor.execute()` within the existing periodic task
    - Maintain existing error handling (return false on failure for WorkManager retry)
    - _Requirements: 2.6_

  - [x]* 4.3 Write property test for RecurringExecutor (Property 5: Execution Creates Transaction and Log)
    - **Property 5: Execution Creates Transaction and Log**
    - **Validates: Requirements 2.1, 5.1**
    - Use in-memory DB, generate active due recurring transactions
    - Verify exactly one Transaction (badge='recurring') and one ExecutionLog (status='success') created per execution

  - [x]* 4.4 Write property test for RecurringExecutor (Property 6: Catch-Up Executes Missed Transactions Chronologically)
    - **Property 6: Catch-Up Executes Missed Transactions Chronologically**
    - **Validates: Requirements 2.2**
    - Generate recurring transactions with nextExecutionDate far in the past
    - Verify min(N, 90) executions in strictly chronological order

  - [x]* 4.5 Write property test for RecurringExecutor (Property 7: Paused Transactions Are Never Executed)
    - **Property 7: Paused Transactions Are Never Executed**
    - **Validates: Requirements 2.3, 8.2**
    - Generate paused recurring transactions with due dates
    - Verify zero executions and zero log entries

  - [x]* 4.6 Write property test for RecurringExecutor (Property 9: No Duplicate Executions)
    - **Property 9: No Duplicate Executions**
    - **Validates: Requirements 8.1, 8.5**
    - Run executor twice on the same due transaction
    - Verify only one transaction and one log entry exist

  - [x]* 4.7 Write property test for RecurringExecutor (Property 14: Retry Logic)
    - **Property 14: Retry Logic**
    - **Validates: Requirements 2.7**
    - Simulate database failures, verify retryCount increments, verify pause at 3

- [x] 5. Checkpoint — Ensure all data and background tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Providers layer
  - [x] 6.1 Implement Riverpod providers for recurring transactions
    - Create `lib/features/recurring_transactions/providers/recurring_transaction_provider.dart`
    - Implement `recurringTransactionRepositoryProvider` — Provider<RecurringTransactionRepositoryInterface>
    - Implement `recurringTransactionNotifierProvider` — AsyncNotifierProvider with CRUD mutations (create, update, delete, pause, resume)
    - Implement `upcomingRecurringProvider` — FutureProvider.autoDispose for dashboard widget (7 days, limit 5)
    - Implement `recurringTransactionByIdProvider` — FutureProvider.autoDispose.family for detail view
    - Use `ref.watch` in build, `ref.read` in mutation methods
    - _Requirements: 3.1, 3.8, 5.2, 9.1_

- [x] 7. Notification service
  - [x] 7.1 Implement RecurringNotificationService
    - Create `lib/features/recurring_transactions/services/recurring_notification_service.dart`
    - Implement `scheduleReminder` — schedule notification 1 day before (09:00) or same day (08:00)
    - Implement `showExecutionSuccess` — immediate notification with name, amount, wallet
    - Implement `showExecutionFailure` — immediate notification with name and error category
    - Implement `cancelNotifications` — cancel all notifications for a recurring transaction
    - Use flutter_local_notifications with deep link payload `duasaku://recurring_transactions?id={id}`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 7.2 Wire notification service into RecurringExecutor
    - Import and call `showExecutionSuccess` after successful execution in background
    - Import and call `showExecutionFailure` after failed execution in background
    - Schedule reminders when creating/updating recurring transactions (in provider/repository)
    - _Requirements: 4.2, 4.3_

- [x] 8. Presentation layer — screens and widgets
  - [x] 8.1 Create RecurringTransactionsScreen (list view)
    - Create `lib/features/recurring_transactions/presentation/screens/recurring_transactions_screen.dart`
    - Display list of all recurring transactions using `recurringTransactionNotifierProvider`
    - Implement staggered fade-in + slideY animation (50ms delay per item) using flutter_animate
    - Implement shimmer loading placeholder while data loads
    - Implement empty state with Lottie animation and CTA button
    - _Requirements: 3.1, 3.2, 3.8, 3.11, 6.1, 6.2, 6.8_

  - [x] 8.2 Create RecurringTransactionCard widget
    - Create `lib/features/recurring_transactions/presentation/widgets/recurring_transaction_card.dart`
    - Display: next execution date, frequency badge, amount (green/red color coding), status badge (active/paused/completed)
    - Implement progress ring showing days remaining proportion
    - Implement scale bounce micro-interaction on tap
    - Implement swipe-right for pause/resume with 200-300ms easeOutCubic animation + haptic feedback
    - Implement swipe-left for delete with confirmation dialog
    - Use card borders (no elevation), border radius 16px, theme colors via colorScheme
    - _Requirements: 3.3, 3.4, 3.5, 3.6, 3.7, 3.9, 3.10, 6.5, 6.6, 6.7_

  - [x] 8.3 Create ProgressRingWidget
    - Create `lib/features/recurring_transactions/presentation/widgets/progress_ring_widget.dart`
    - Animated circular progress indicator using `computeProgressRing` value
    - Display days remaining label in center
    - _Requirements: 3.9_

  - [x] 8.4 Create CreateRecurringBottomSheet (step-by-step flow)
    - Create `lib/features/recurring_transactions/presentation/widgets/create_recurring_bottom_sheet.dart`
    - Step-by-step flow: amount → type → category → wallet → frequency → dates → preview → confirm
    - Implement animated frequency selector (wheel/carousel picker)
    - Implement preview showing 5 upcoming execution dates
    - Validate: amount bounds, valid wallet, valid category, start date not in past
    - Show Lottie success animation on creation
    - All strings use `.tr()` for localization
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 6.2, 6.4_

  - [x] 8.5 Create RecurringTransactionDetailScreen
    - Create `lib/features/recurring_transactions/presentation/screens/recurring_transaction_detail_screen.dart`
    - Hero transition from card to detail view
    - Display execution timeline (max 5 past + 5 upcoming executions)
    - Display full recurring transaction details with edit button
    - _Requirements: 3.12, 6.3_

  - [x] 8.6 Create ExecutionTimelineWidget
    - Create `lib/features/recurring_transactions/presentation/widgets/execution_timeline_widget.dart`
    - Visual timeline showing past executions (with status) and upcoming dates
    - Max 5 previous + 5 upcoming
    - _Requirements: 3.12_

  - [x] 8.7 Implement edit recurring transaction flow
    - Create edit form (reuse bottom sheet with pre-filled values)
    - Update template without affecting historical transactions
    - Recalculate nextExecutionDate on frequency/start date change
    - Handle end date set to past → status becomes completed
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

  - [x]* 8.8 Write property test for immutability (Property 11: Historical Transactions Immutability)
    - **Property 11: Historical Transactions Immutability**
    - **Validates: Requirements 5.7, 8.3, 9.2**
    - Create recurring transaction, execute it, then delete/edit the template
    - Verify historical transactions remain unchanged

- [x] 9. Checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 10. Integration — routing, deep links, dashboard widget, and budget tracking
  - [x] 10.1 Register routes and deep link handler
    - Add `/recurring-transactions` route to go_router configuration
    - Add `/recurring-transactions/:id` route for detail view
    - Register `duasaku://recurring_transactions` deep link in handler (with optional `?id=` param)
    - Handle notification tap → navigate to detail or list (fallback if deleted)
    - _Requirements: 4.5, 4.6, 5.6_

  - [x] 10.2 Create UpcomingRecurringDashboardWidget
    - Create `lib/features/recurring_transactions/presentation/widgets/upcoming_recurring_dashboard_widget.dart`
    - Display max 5 upcoming recurring transactions within 7 days on home screen
    - Show name, amount, and execution date per item
    - Hide section if no upcoming transactions in 7 days
    - _Requirements: 5.2, 5.3_

  - [x] 10.3 Integrate with budget tracking
    - When expense recurring transaction executes, add amount to budget actual for matching category + month
    - If no budget configured for category/month, skip budget update (transaction still created)
    - _Requirements: 5.4, 5.5_

  - [x] 10.4 Wire dashboard widget into home screen
    - Import and place `UpcomingRecurringDashboardWidget` in the home screen layout
    - Ensure it uses `upcomingRecurringProvider` for data
    - _Requirements: 5.2, 5.3_

- [x] 11. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document using the glados package
- Unit tests validate specific examples and edge cases
- Domain layer (task 1) is pure Dart — no Flutter dependencies, easily testable
- Background isolate (task 4) initializes its own database instance — no Riverpod access
- All UI strings must use `.tr()` for easy_localization
- Cards use borders (not elevation), border radius 16px, theme colors via `Theme.of(context).colorScheme`
- Run `dart run build_runner build` after modifying Drift tables/DAOs

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3"] },
    { "id": 2, "tasks": ["1.4", "1.5", "1.6", "1.7", "1.8", "1.9", "1.10", "3.1"] },
    { "id": 3, "tasks": ["3.2"] },
    { "id": 4, "tasks": ["3.3", "3.4"] },
    { "id": 5, "tasks": ["4.1", "6.1"] },
    { "id": 6, "tasks": ["4.2", "4.3", "4.4", "4.5", "4.6", "4.7", "7.1"] },
    { "id": 7, "tasks": ["7.2", "8.1", "8.3"] },
    { "id": 8, "tasks": ["8.2", "8.4", "8.5", "8.6"] },
    { "id": 9, "tasks": ["8.7", "8.8"] },
    { "id": 10, "tasks": ["10.1", "10.2", "10.3"] },
    { "id": 11, "tasks": ["10.4"] }
  ]
}
```
