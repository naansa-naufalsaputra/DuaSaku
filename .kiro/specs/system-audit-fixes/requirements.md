# Requirements Document

## Introduction

This spec addresses the most urgent findings from a comprehensive system audit of the DuaSaku Flutter finance app. It covers four priority issues: a critical data integrity bug where background recurring transaction execution does not update wallet balances, banned Riverpod provider patterns still in production code, missing battery constraints on background tasks, and incorrect error surfacing in TransactionNotifier. Each fix restores compliance with the project steering file and ensures data correctness.

## Glossary

- **RecurringExecutor**: The background isolate class (`lib/core/background/recurring_executor.dart`) responsible for executing due recurring transactions without Riverpod access.
- **TransactionRepository**: The foreground data layer class (`lib/features/transactions/data/transaction_repository.dart`) that inserts transactions and adjusts wallet balances within a single database transaction.
- **Wallet_Balance**: The `balance` column on the `Wallets` table representing the current monetary balance of a wallet.
- **Balance_Recalculation_Migration**: A one-time Drift schema migration step that recomputes all wallet balances from transaction history to correct accumulated drift.
- **NotifierProvider**: The modern Riverpod 2.x provider type that replaces the deprecated `StateNotifierProvider`. Uses `Notifier` or `AsyncNotifier` base classes with built-in `ref` access.
- **StateNotifierProvider**: A deprecated Riverpod provider type explicitly banned by the project steering file.
- **ChangeNotifierProvider**: A mutable-state provider type from `package:provider` explicitly banned by the project steering file.
- **BackgroundTaskHelper**: The class (`lib/core/background/background_task_helper.dart`) that registers periodic and one-off WorkManager tasks.
- **TransactionNotifier**: The `AsyncNotifier` class (`lib/features/transactions/providers/transaction_provider.dart`) managing transaction list state and mutations.
- **AsyncError_State**: The `AsyncValue.error(error, stackTrace)` state used by Riverpod `AsyncNotifier` to surface failures without throwing exceptions.
- **GoRouter_RefreshListenable**: The `refreshListenable` parameter on GoRouter that triggers route re-evaluation when the listenable notifies.
- **Result_Pattern**: The sealed `Result<T, E>` class used for type-safe success/failure returns without exceptions.

## Requirements

### Requirement 1: Background Recurring Transaction Wallet Balance Update

**User Story:** As a user with recurring transactions, I want my wallet balances to be updated correctly when recurring transactions execute in the background, so that the displayed balance always reflects my actual financial state.

#### Acceptance Criteria

1. WHEN RecurringExecutor creates a transaction of type 'expense', THE RecurringExecutor SHALL decrease the associated Wallet_Balance by the transaction amount within the same database transaction block.
2. WHEN RecurringExecutor creates a transaction of type 'income', THE RecurringExecutor SHALL increase the associated Wallet_Balance by the transaction amount within the same database transaction block.
3. WHEN RecurringExecutor creates a transaction of type 'transfer', THE RecurringExecutor SHALL decrease the source wallet (fromWalletId) balance and increase the destination wallet (toWalletId) balance by the transaction amount within the same database transaction block.
4. THE RecurringExecutor SHALL wrap the transaction insert and all associated Wallet_Balance adjustments in a single Drift `transaction()` block to ensure atomicity, so that if any step fails the entire operation is rolled back.
5. IF the wallet referenced by the recurring transaction does not exist in the database, THEN THE RecurringExecutor SHALL roll back the database transaction block, treat the execution as a non-retryable failure, and pause the recurring transaction.
6. WHEN RecurringExecutor executes multiple catch-up transactions for a single recurring transaction, THE RecurringExecutor SHALL apply a separate Wallet_Balance adjustment for each individual catch-up execution rather than a single bulk adjustment.
7. THE RecurringExecutor SHALL produce the same Wallet_Balance change as TransactionRepository.insertTransaction produces for a foreground transaction with identical type, amount, and wallet references.

### Requirement 2: One-Time Balance Recalculation Migration

**User Story:** As a user whose wallet balances have drifted due to the background executor bug, I want my balances to be automatically corrected on app update, so that I see accurate financial data without manual intervention.

#### Acceptance Criteria

1. WHEN the database upgrades to schema version 8, THE Balance_Recalculation_Migration SHALL recompute each Wallet_Balance as: the sum of all transaction amounts where `type = 'income'` and `walletId` matches the wallet, minus the sum of all transaction amounts where `type = 'expense'` and `walletId` matches the wallet, plus the sum of all transaction amounts where `type = 'transfer'` and `toWalletId` matches the wallet, minus the sum of all transaction amounts where `type = 'transfer'` and `fromWalletId` matches the wallet.
2. THE Balance_Recalculation_Migration SHALL execute within a single database transaction block to ensure atomicity.
3. IF a wallet has zero associated transactions, THEN THE Balance_Recalculation_Migration SHALL set the Wallet_Balance to zero.
4. THE Balance_Recalculation_Migration SHALL not delete or modify any row in the Wallets or Transactions tables beyond the `balance` column of the Wallets table.
5. IF the migration transaction fails for any reason, THEN THE Balance_Recalculation_Migration SHALL roll back all balance changes, leaving every Wallet_Balance at its pre-migration value, and SHALL propagate the error to the Drift migration framework so the schema version remains at 7.

### Requirement 3: Migrate SecurityNotifier to NotifierProvider

**User Story:** As a developer, I want the security provider to use the modern `NotifierProvider` pattern, so that the codebase complies with the project steering file's banned-provider rules.

#### Acceptance Criteria

1. THE Security_Provider SHALL use `NotifierProvider<SecurityNotifier, SecurityState>` instead of `StateNotifierProvider<SecurityNotifier, SecurityState>`.
2. THE SecurityNotifier SHALL extend `Notifier<SecurityState>` and initialize state in the `build()` method by reading the biometric preference from SharedPreferences, setting `isLocked` to match the stored biometric-enabled flag, running NTP time verification, and returning the resulting `SecurityState` with `isInitialized: true` upon completion.
3. THE SecurityNotifier SHALL retain all existing public methods with identical signatures and observable behavior: `authenticate()`, `setBiometricEnabled(bool)`, `verifyNtpTime()`, `unlock()`, `lockAppManually()`, and the `didChangeAppLifecycleState` lifecycle callback.
4. WHEN the app resumes from background after 30 seconds or more, THE SecurityNotifier SHALL set `isLocked: true` on the state and invoke `authenticate()`.
5. THE SecurityNotifier SHALL mix in `WidgetsBindingObserver` and register itself via `WidgetsBinding.instance.addObserver(this)` during `build()`, and deregister via `WidgetsBinding.instance.removeObserver(this)` in a `ref.onDispose` callback to prevent lifecycle listener leaks.
6. THE SecurityNotifier SHALL access dependencies via the inherited `ref` property instead of constructor-injected `Ref`, and no constructor parameters SHALL be required.

### Requirement 4: Migrate ThemeNotifier to NotifierProvider

**User Story:** As a developer, I want the theme provider to use the modern `NotifierProvider` pattern, so that the codebase complies with the project steering file's banned-provider rules.

#### Acceptance Criteria

1. THE Theme_Provider SHALL use `NotifierProvider<ThemeNotifier, ThemeState>` instead of `StateNotifierProvider<ThemeNotifier, ThemeState>`.
2. THE ThemeNotifier SHALL extend `Notifier<ThemeState>` and initialize state in the `build()` method.
3. THE ThemeNotifier SHALL retain all existing functionality: loading saved preset and mode from SharedPreferences, updating preset, and updating theme mode.

### Requirement 5: Migrate InsightsNotifier to NotifierProvider

**User Story:** As a developer, I want the insights provider to use the modern `NotifierProvider` pattern, so that the codebase complies with the project steering file's banned-provider rules.

#### Acceptance Criteria

1. THE Insights_Provider SHALL use `NotifierProvider<InsightsNotifier, InsightsState>` instead of `StateNotifierProvider<InsightsNotifier, InsightsState>`.
2. THE InsightsNotifier SHALL extend `Notifier<InsightsState>` and initialize state in the `build()` method.
3. THE InsightsNotifier SHALL retain the `generateAiAnalysis()` method with identical behavior: loading state, AI call, and error handling.

### Requirement 6: Migrate GamificationNotifier to NotifierProvider

**User Story:** As a developer, I want the gamification provider to use the modern `NotifierProvider` pattern, so that the codebase complies with the project steering file's banned-provider rules.

#### Acceptance Criteria

1. THE Gamification_Provider SHALL use `NotifierProvider<GamificationNotifier, GamificationState>` instead of `StateNotifierProvider<GamificationNotifier, GamificationState>`.
2. THE GamificationNotifier SHALL extend `Notifier<GamificationState>` and initialize state in the `build()` method.
3. THE GamificationNotifier SHALL retain all existing functionality: streak tracking, health score calculation, badge awarding, goal score updates, and dependency listening.
4. THE GamificationNotifier SHALL continue to implement `GamificationServiceInterface`.

### Requirement 7: Migrate AuthRepository Provider Away from ChangeNotifierProvider

**User Story:** As a developer, I want the auth provider to stop using `ChangeNotifierProvider` while still supporting GoRouter's `refreshListenable`, so that the codebase complies with the project steering file's banned-provider rules.

#### Acceptance Criteria

1. THE Auth_Provider SHALL NOT use `ChangeNotifierProvider<AuthRepository>`.
2. THE Auth_Provider SHALL expose the AuthRepository via a standard `Provider<AuthRepository>` that creates and holds a single AuthRepository instance for the app's lifetime.
3. THE AuthRepository SHALL continue to extend `ChangeNotifier` (the class itself is not banned — only `ChangeNotifierProvider` is banned) so that it remains a valid `Listenable` for GoRouter's `refreshListenable` parameter.
4. THE GoRouter configuration SHALL obtain the AuthRepository instance via `ref.read(authRepositoryProvider)` and pass it directly to `refreshListenable`, ensuring route guards re-evaluate when authentication state changes.
5. THE Auth_Provider SHALL retain all existing functionality: PIN verification, biometric authentication, sign-out, and local authentication.
6. WHEN authentication state changes (via `notifyListeners()`), GoRouter SHALL re-evaluate its redirect logic within the same event loop tick.
7. THE `userProvider` and `authStateProvider` convenience providers SHALL continue to derive their values by watching `authRepositoryProvider` and SHALL rebuild when the AuthRepository notifies listeners.

### Requirement 8: Migrate PinAuthNotifier to NotifierProvider.family

**User Story:** As a developer, I want the PIN auth notifier to use the modern `NotifierProvider.family` pattern, so that the codebase complies with the project steering file's banned-provider rules.

#### Acceptance Criteria

1. THE PinAuth_Provider SHALL use `NotifierProvider.family.autoDispose<PinAuthNotifier, PinAuthState, bool>` instead of `StateNotifierProvider.family.autoDispose`.
2. THE PinAuthNotifier SHALL extend `FamilyAsyncNotifier` or `AutoDisposeFamilyNotifier` as appropriate and initialize state in the `build()` method.
3. THE PinAuthNotifier SHALL retain all existing PIN entry, verification, and change-PIN functionality.

### Requirement 9: Add Battery Constraint to Periodic Background Tasks

**User Story:** As a user, I want background tasks to respect my device's battery level, so that periodic sync does not drain my battery when it is low.

#### Acceptance Criteria

1. WHEN BackgroundTaskHelper registers the recurring transaction periodic task, THE BackgroundTaskHelper SHALL include the constraint `requiresBatteryNotLow: true`.
2. WHEN BackgroundTaskHelper registers the budget alert queue periodic task, THE BackgroundTaskHelper SHALL include the constraint `requiresBatteryNotLow: true`.
3. THE BackgroundTaskHelper SHALL use a `Constraints` object with `requiresBatteryNotLow: true` for all periodic task registrations.

### Requirement 10: TransactionNotifier Error Handling via AsyncError State

**User Story:** As a developer consuming TransactionNotifier, I want failures to be surfaced via `AsyncError` state instead of thrown exceptions, so that the Result pattern is respected and callers do not need try/catch blocks.

#### Acceptance Criteria

1. WHEN `addTransaction()` receives a `Failure` result from the repository, THE TransactionNotifier SHALL set `state = AsyncValue.error(appError, stackTrace)` where `appError` is the `AppError` instance from the `Failure` and `stackTrace` is the error's associated stack trace (or `StackTrace.current` if none is available), instead of throwing an exception.
2. WHEN `deleteTransaction()` receives a `Failure` result from the repository, THE TransactionNotifier SHALL set `state = AsyncValue.error(appError, stackTrace)` where `appError` is the `AppError` instance from the `Failure` and `stackTrace` is the error's associated stack trace (or `StackTrace.current` if none is available), instead of throwing an exception.
3. THE TransactionNotifier SHALL NOT throw exceptions when `addTransaction()` or `deleteTransaction()` receives a `Failure` result from the repository (i.e., all `Result_Pattern` failure cases are handled via state, not exceptions).
4. WHEN `deleteTransaction()` receives a `Failure` result after an optimistic UI removal, THE TransactionNotifier SHALL first restore `state` to `AsyncData` containing the transaction list as it was before the optimistic removal, and then set `state` to `AsyncValue.error(appError, stackTrace)`, so that the previous data is available via `state.hasValue` for UI recovery.
5. WHEN `addTransaction()` receives a `Failure` result from the repository, THE TransactionNotifier SHALL preserve the existing transaction list in state such that `state.hasValue` remains true and `state.value` returns the list as it was before the `addTransaction()` call.
