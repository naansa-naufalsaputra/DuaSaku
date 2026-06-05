# Bugfix Requirements Document

## Introduction

This document addresses 8 architecture violations and code quality bugs discovered during a codebase audit of the DuaSaku Flutter finance app. These violations break rules explicitly defined in the project's steering file (`.kiro/steering/duasaku.md`), including banned provider patterns, missing type safety, unused Result pattern, hardcoded strings, missing constants, missing annotations, no-op methods, and incomplete domain layer interfaces. Fixing these ensures the codebase is consistent, maintainable, and compliant with the established architecture.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN `WalletNotifier` is defined in `lib/features/wallets/providers/wallet_provider.dart` THEN the system uses `StateNotifierProvider` and `extends StateNotifier<AsyncValue<List<WalletModel>>>`, which is explicitly banned by the steering file

1.2 WHEN `parseSmartText()` is called in `TransactionNotifier` THEN the system returns a raw `Map<String, dynamic>` instead of a structured type, violating the rule that services must return structured data types

1.3 WHEN `TransactionRepository` or `WalletRepository` encounters expected failures (not found, constraint violations) THEN the system throws/rethrows exceptions instead of using the `Result<T, E>` sealed class defined in `core/utils/result.dart`

1.4 WHEN `SecurityWrapper` displays the time-tampering warning in `lib/main.dart` THEN the system renders hardcoded Indonesian strings (`'Deteksi Manipulasi Waktu!'`, `'Jam perangkat Anda tidak selaras...'`, `'Periksa Kembali'`) instead of using `.tr()` localization keys

1.5 WHEN the database seeds default categories or defines the `Budgets` table default userId THEN the system uses the hardcoded literal string `'local_user'` in multiple locations without a shared constant

1.6 WHEN `WalletRepository` implements `WalletRepositoryInterface` THEN the system omits `@override` annotations on the implementing methods (`getWallets`, `watchWallets`, `createWallet`, `updateWallet`, `deleteWallet`)

1.7 WHEN `syncPendingTransactions()` is called on `TransactionRepository` THEN the system executes an empty no-op method body with only a comment, providing no documentation or explicit contract about its intentional no-op status in the interface

1.8 WHEN features `auth`, `insights`, `gamification`, `geofencing`, and `profile` are used THEN the system lacks abstract repository interfaces in their `domain/` directories, violating the mandatory domain layer interface rule

### Expected Behavior (Correct)

2.1 WHEN `WalletNotifier` is defined THEN the system SHALL use `AsyncNotifierProvider` and `extends AsyncNotifier<List<WalletModel>>` with `ref` accessed directly as a property (no constructor injection)

2.2 WHEN `parseSmartText()` is called THEN the system SHALL return a structured `ParsedTransaction` type (or equivalent domain model) instead of a raw map

2.3 WHEN `TransactionRepository` or `WalletRepository` encounters expected failures THEN the system SHALL return `Result<T, AppError>` (using `Failure(AppError.xxx(...))`) for expected errors and only rethrow for truly unrecoverable system errors

2.4 WHEN `SecurityWrapper` displays the time-tampering warning THEN the system SHALL use `.tr()` localization keys for all user-facing strings (e.g., `'security.time_tamper_title'.tr()`, `'security.time_tamper_message'.tr()`, `'security.recheck_button'.tr()`)

2.5 WHEN the database seeds default categories or defines default userId values THEN the system SHALL reference a shared constant (e.g., `AppConstants.defaultUserId`) defined in a single location in `lib/core/`

2.6 WHEN `WalletRepository` implements `WalletRepositoryInterface` THEN the system SHALL include `@override` annotations on all methods that implement the interface contract

2.7 WHEN `syncPendingTransactions()` exists in the interface and implementation THEN the system SHALL either document it with a `@Deprecated` annotation and doc comment explaining the intentional no-op for offline-first architecture, OR remove it from the interface if it serves no future purpose

2.8 WHEN features `auth`, `insights`, `gamification`, `geofencing`, and `profile` have data repositories or services THEN the system SHALL define abstract repository interfaces in `lib/features/<feature>/domain/` following the dependency inversion principle

### Unchanged Behavior (Regression Prevention)

3.1 WHEN wallets are loaded, created, updated, or deleted via the provider THEN the system SHALL CONTINUE TO reactively update the UI with the correct wallet list data

3.2 WHEN `parseSmartText()` successfully parses transaction text THEN the system SHALL CONTINUE TO return the same parsed fields (amount, category, type, walletId, notes) with correct values

3.3 WHEN repository operations succeed (no errors) THEN the system SHALL CONTINUE TO return data identically to the current behavior (success path unchanged)

3.4 WHEN `SecurityWrapper` checks security state for `isInitialized`, `isLocked`, or normal (non-tampered) states THEN the system SHALL CONTINUE TO display the loading indicator, PIN screen, or child widget respectively

3.5 WHEN the database performs queries filtering by userId THEN the system SHALL CONTINUE TO correctly match the default user's data using the same logical value

3.6 WHEN `WalletRepository` methods are called THEN the system SHALL CONTINUE TO perform the same Drift database operations with identical behavior

3.7 WHEN `TransactionNotifier.build()` calls `syncPendingTransactions()` THEN the system SHALL CONTINUE TO not crash or produce side effects (graceful no-op behavior preserved)

3.8 WHEN existing features (`transactions`, `wallets`) use their domain interfaces THEN the system SHALL CONTINUE TO function identically with no changes to their existing interface contracts
