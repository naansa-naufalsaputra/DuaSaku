# Implementation Plan: System Audit Fixes

## Overview

This plan addresses four priority audit findings: (1) RecurringExecutor wallet balance updates, (2) one-time balance recalculation migration, (3) six provider migrations from banned patterns to modern Riverpod 2.x, (4) battery constraints on background tasks, and (5) TransactionNotifier error handling via AsyncError state. Tasks are ordered so foundational data-layer fixes come first, followed by provider migrations, then operational safety improvements.

## Tasks

- [x] 1. Fix RecurringExecutor wallet balance updates
  - [x] 1.1 Implement `_adjustWalletBalance` and `_adjustTransferBalances` methods in RecurringExecutor
    - Add `_adjustWalletBalance({required String walletId, required double amount, required String type})` that queries the wallet, throws `StateError` if not found, and updates the balance (income adds, expense subtracts)
    - Add `_adjustTransferBalances(RecurringTransaction recurring)` that decreases source wallet and increases destination wallet
    - _Requirements: 1.1, 1.2, 1.3, 1.5_

  - [x] 1.2 Wrap transaction insert and balance adjustment in a single `_db.transaction()` block
    - Replace the existing `_createTransaction` logic with `_createTransactionWithBalanceUpdate` that wraps insert + balance adjustment in a Drift `transaction()` block
    - Ensure each catch-up execution calls this method individually (not batched)
    - Handle `StateError` (wallet not found) as non-retryable failure that pauses the recurring transaction
    - _Requirements: 1.4, 1.5, 1.6, 1.7_

  - [x] 1.3 Write property test for balance adjustment correctness (Property 1)
    - **Property 1: Balance adjustment correctness by transaction type**
    - **Validates: Requirements 1.1, 1.2, 1.3**

  - [x] 1.4 Write property test for catch-up execution balance adjustments (Property 2)
    - **Property 2: Catch-up executions produce individual balance adjustments**
    - **Validates: Requirements 1.6**

  - [x] 1.5 Write property test for RecurringExecutor and TransactionRepository equivalence (Property 3)
    - **Property 3: RecurringExecutor and TransactionRepository produce equivalent balance changes**
    - **Validates: Requirements 1.7**

- [x] 2. Implement balance recalculation migration (schema v7 → v8)
  - [x] 2.1 Add schema version 8 migration in `app_database.dart`
    - Bump `schemaVersion` to 8
    - Add `if (from < 8)` block in `onUpgrade` with `customStatement` SQL that recalculates all wallet balances using aggregate subqueries (SUM income - SUM expense + SUM transfer-in - SUM transfer-out)
    - Ensure wallets with zero transactions get balance set to zero via COALESCE
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 2.2 Write property test for balance recalculation formula correctness (Property 4)
    - **Property 4: Balance recalculation formula correctness**
    - **Validates: Requirements 2.1, 2.3**

  - [x] 2.3 Write property test for migration data preservation (Property 5)
    - **Property 5: Migration preserves all non-balance data**
    - **Validates: Requirements 2.4**

- [x] 3. Checkpoint - Verify data integrity fixes
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Migrate SecurityNotifier to NotifierProvider
  - [x] 4.1 Refactor SecurityNotifier to extend `Notifier<SecurityState>` with WidgetsBindingObserver
    - Change `securityProvider` from `StateNotifierProvider` to `NotifierProvider<SecurityNotifier, SecurityState>`
    - Change class to extend `Notifier<SecurityState>` and mix in `WidgetsBindingObserver`
    - Move initialization logic into `build()` method: register observer, set up `ref.onDispose` for deregistration, read biometric preference, run NTP verification, return initial `SecurityState`
    - Replace constructor-injected `Ref` with inherited `ref` property
    - Retain all public methods with identical signatures: `authenticate()`, `setBiometricEnabled(bool)`, `verifyNtpTime()`, `unlock()`, `lockAppManually()`, `didChangeAppLifecycleState`
    - Ensure app-resume-after-30-seconds logic sets `isLocked: true` and calls `authenticate()`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

  - [x] 4.2 Update all consumers of `securityProvider` to use new API
    - Replace `.notifier` access patterns if needed (Notifier uses same `.notifier` pattern)
    - Verify all `ref.watch(securityProvider)` and `ref.read(securityProvider.notifier)` call sites still compile
    - _Requirements: 3.1_

- [x] 5. Migrate ThemeNotifier to NotifierProvider
  - [x] 5.1 Refactor ThemeNotifier to extend `Notifier<ThemeState>`
    - Change `themeNotifierProvider` from `StateNotifierProvider` to `NotifierProvider<ThemeNotifier, ThemeState>`
    - Change class to extend `Notifier<ThemeState>`
    - Move initialization into `build()`: load saved preset and mode from SharedPreferences, return default `ThemeState`
    - Replace constructor-injected `Ref` with inherited `ref`
    - Retain `updatePreset()` and `updateThemeMode()` methods
    - _Requirements: 4.1, 4.2, 4.3_

  - [x] 5.2 Update all consumers of `themeNotifierProvider` to use new API
    - Verify all watch/read call sites compile correctly
    - _Requirements: 4.1_

- [x] 6. Migrate InsightsNotifier to NotifierProvider
  - [x] 6.1 Refactor InsightsNotifier to extend `Notifier<InsightsState>`
    - Change `insightsProvider` from `StateNotifierProvider` to `NotifierProvider<InsightsNotifier, InsightsState>`
    - Change class to extend `Notifier<InsightsState>`
    - Move initialization into `build()`: return initial `InsightsState`
    - Retain `generateAiAnalysis()` with identical behavior using `ref` directly
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 6.2 Update all consumers of `insightsProvider` to use new API
    - Verify all watch/read call sites compile correctly
    - _Requirements: 5.1_

- [x] 7. Migrate GamificationNotifier to NotifierProvider
  - [x] 7.1 Refactor GamificationNotifier to extend `Notifier<GamificationState>` implementing GamificationServiceInterface
    - Change `gamificationProvider` from `StateNotifierProvider` to `NotifierProvider<GamificationNotifier, GamificationState>`
    - Change class to extend `Notifier<GamificationState>` and implement `GamificationServiceInterface`
    - Move initialization into `build()`: init streak/score, set up `ref.listen` for dependencies (budgetNotifierProvider, transactionNotifierProvider, walletProvider)
    - Retain all existing functionality: streak tracking, health score calculation, badge awarding, goal score updates
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 7.2 Update all consumers of `gamificationProvider` to use new API
    - Verify all watch/read call sites compile correctly
    - _Requirements: 6.1_

  - [x] 7.3 Write property test for health score bounds (Property 6)
    - **Property 6: Health score is bounded within [0, 100]**
    - **Validates: Requirements 6.3**

- [x] 8. Migrate AuthRepository provider away from ChangeNotifierProvider
  - [x] 8.1 Replace `ChangeNotifierProvider<AuthRepository>` with `Provider<AuthRepository>`
    - Change `authRepositoryProvider` to `Provider<AuthRepository>` that creates and holds a single instance
    - Add `ref.onDispose(() => repo.dispose())` for cleanup
    - AuthRepository class continues to extend `ChangeNotifier` (class is not banned, only the provider wrapper)
    - Expose `authStateStream` from AuthRepository via a `StreamController<AuthState>` that emits on `notifyListeners()`
    - Update `authStateProvider` to be a `StreamProvider<AuthState>` watching the stream
    - Update `userProvider` to derive from `authStateProvider`
    - _Requirements: 7.1, 7.2, 7.3, 7.5, 7.6, 7.7_

  - [x] 8.2 Update GoRouter configuration to use `ref.read(authRepositoryProvider)` as `refreshListenable`
    - Pass `AuthRepository` instance directly to GoRouter's `refreshListenable` parameter
    - Verify route guards re-evaluate when authentication state changes
    - _Requirements: 7.4, 7.6_

  - [x] 8.3 Update all consumers of auth providers to use new API
    - Update all `ref.watch(authRepositoryProvider)` and derived provider usages
    - Verify `userProvider` and `authStateProvider` rebuild correctly on auth state changes
    - _Requirements: 7.5, 7.7_

- [x] 9. Migrate PinAuthNotifier to NotifierProvider.family
  - [x] 9.1 Refactor PinAuthNotifier to extend `AutoDisposeFamilyNotifier<PinAuthState, bool>`
    - Change `pinAuthNotifierProvider` to `NotifierProvider.family.autoDispose<PinAuthNotifier, PinAuthState, bool>`
    - Change class to extend `AutoDisposeFamilyNotifier<PinAuthState, bool>`
    - Move initialization into `build(bool isChangePinMode)`: read authRepository via `ref`, return initial `PinAuthState` based on mode
    - Retain all PIN entry, verification, and change-PIN functionality
    - _Requirements: 8.1, 8.2, 8.3_

  - [x] 9.2 Update all consumers of `pinAuthNotifierProvider` to use new API
    - Verify all call sites pass the `bool` family argument correctly
    - _Requirements: 8.1_

- [x] 10. Checkpoint - Verify provider migrations
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Add battery constraint to periodic background tasks
  - [x] 11.1 Add `requiresBatteryNotLow: true` constraint to all periodic task registrations in BackgroundTaskHelper
    - Add `constraints: Constraints(requiresBatteryNotLow: true)` to the recurring transaction periodic task registration
    - Add `constraints: Constraints(requiresBatteryNotLow: true)` to the budget alert queue periodic task registration
    - _Requirements: 9.1, 9.2, 9.3_

- [x] 12. Fix TransactionNotifier error handling via AsyncError state
  - [x] 12.1 Refactor `addTransaction()` to use `AsyncValue.error` with `copyWithPrevious` on Failure
    - Replace exception throwing with `state = AsyncValue<List<TransactionModel>>.error(error, StackTrace.current).copyWithPrevious(AsyncData(previousData))`
    - Preserve existing transaction list so `state.hasValue` remains true after failure
    - _Requirements: 10.1, 10.3, 10.5_

  - [x] 12.2 Refactor `deleteTransaction()` to restore state and use `AsyncValue.error` with `copyWithPrevious` on Failure
    - After optimistic removal, on Failure: set state to `AsyncValue.error(error, StackTrace.current).copyWithPrevious(AsyncData(previousState))` to restore original list and surface error
    - Ensure `state.hasValue` is true and `state.value` returns the pre-removal list
    - _Requirements: 10.2, 10.3, 10.4_

  - [x] 12.3 Write property test for repository failures producing AsyncError state (Property 7)
    - **Property 7: Repository failures produce AsyncError state without throwing**
    - **Validates: Requirements 10.1, 10.2, 10.3**

  - [x] 12.4 Write property test for failure preserving previous transaction data (Property 8)
    - **Property 8: Failure preserves previous transaction data**
    - **Validates: Requirements 10.4, 10.5**

- [x] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation after data-layer fixes and provider migrations
- Property tests validate universal correctness properties defined in the design document
- The design uses Dart/Flutter — all implementations use Drift for database, Riverpod 2.x for state management, and WorkManager for background tasks
- RecurringExecutor changes must be tested with in-memory SQLite databases since the executor runs in a background isolate without Riverpod access
- Provider migrations are structural refactors — observable behavior must remain identical

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "11.1"] },
    { "id": 1, "tasks": ["1.2", "2.2", "2.3"] },
    { "id": 2, "tasks": ["1.3", "1.4", "1.5"] },
    { "id": 3, "tasks": ["4.1", "5.1", "6.1", "7.1", "8.1", "9.1"] },
    { "id": 4, "tasks": ["4.2", "5.2", "6.2", "7.2", "8.2", "9.2", "7.3"] },
    { "id": 5, "tasks": ["8.3"] },
    { "id": 6, "tasks": ["12.1", "12.2"] },
    { "id": 7, "tasks": ["12.3", "12.4"] }
  ]
}
```
