# Architecture Compliance Fix — Bugfix Design

## Overview

This design addresses 8 architecture violations in the DuaSaku Flutter finance app that break rules defined in the project's steering file. The violations span banned provider patterns, missing type safety, incorrect error handling, hardcoded strings, missing constants, missing annotations, undocumented no-ops, and incomplete domain layer interfaces. The fix strategy is minimal and targeted: each violation is corrected to comply with the steering rules while preserving all existing runtime behavior (wallet CRUD, transaction parsing, security flows, database seeding, and feature functionality).

## Glossary

- **Bug_Condition (C)**: Code that violates an architecture rule defined in `.kiro/steering/duasaku.md` — the code compiles and runs but is structurally non-compliant
- **Property (P)**: The corrected code structure that satisfies the steering rule while producing identical runtime behavior
- **Preservation**: All existing runtime behaviors (UI updates, data flow, error handling paths) that must remain unchanged after the fix
- **StateNotifierProvider**: Deprecated Riverpod 1.x pattern explicitly banned by the steering file
- **AsyncNotifierProvider**: Modern Riverpod 2.x replacement where `ref` is accessed as a property
- **Result<T, E>**: Sealed class in `core/utils/result.dart` for type-safe error handling without exceptions
- **ParsedTransaction**: Structured model in `lib/services/models/parsed_transaction.dart` for AI/local parsing output
- **AppConstants**: A new shared constants class to be created in `lib/core/` for project-wide literal values

## Bug Details

### Bug Condition

The bug manifests when the codebase is audited against the steering file rules. Eight distinct violations exist across provider patterns, type safety, error handling, localization, constants, annotations, documentation, and domain layer completeness.

**Formal Specification:**
```
FUNCTION isBugCondition(codeUnit)
  INPUT: codeUnit of type DartSourceFile
  OUTPUT: boolean
  
  RETURN codeUnit.usesStateNotifierProvider()
         OR codeUnit.returnsRawMapFromService()
         OR codeUnit.throwsExceptionForExpectedFailure()
         OR codeUnit.hasHardcodedUserFacingString()
         OR codeUnit.hasHardcodedLiteralWithoutConstant()
         OR codeUnit.missingOverrideAnnotation()
         OR codeUnit.hasUndocumentedNoOp()
         OR codeUnit.missingDomainInterface()
END FUNCTION
```

### Examples

- **Violation 1**: `wallet_provider.dart` declares `StateNotifierProvider<WalletNotifier, AsyncValue<List<WalletModel>>>` and `WalletNotifier extends StateNotifier` — should use `AsyncNotifierProvider` + `AsyncNotifier`
- **Violation 2**: `TransactionNotifier.parseSmartText()` returns `Map<String, dynamic>` by manually destructuring a `ParsedTransaction` into a map — should return `ParsedTransaction` directly
- **Violation 3**: `WalletRepository.createWallet()`, `updateWallet()`, `deleteWallet()` use `rethrow` for DB constraint errors — should return `Result<void, AppError>`
- **Violation 4**: `SecurityWrapper` renders `'Deteksi Manipulasi Waktu!'`, `'Jam perangkat Anda tidak selaras...'`, `'Periksa Kembali'` as hardcoded strings — should use `.tr()` keys
- **Violation 5**: `app_database.dart` uses `'local_user'` literal 7 times and `auth_repository.dart` uses it 4 times — should reference `AppConstants.defaultUserId`
- **Violation 6**: `WalletRepository` implements `WalletRepositoryInterface` but omits `@override` on all 5 methods
- **Violation 7**: `TransactionRepository.syncPendingTransactions()` has an empty body with only a comment — no `@Deprecated` annotation or doc comment explaining the intentional no-op
- **Violation 8**: Features `auth`, `insights`, `gamification`, `geofencing`, `profile` have data repositories/services but no abstract interfaces in `domain/`

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Wallet list reactively updates the UI when wallets are loaded, created, updated, or deleted
- `parseSmartText()` returns the same parsed fields (amount, category, type, walletId, notes) with correct values
- Repository success paths return data identically to current behavior
- `SecurityWrapper` displays loading indicator, PIN screen, or child widget for non-tampered states
- Database queries filtering by userId correctly match the default user's data
- `WalletRepository` methods perform the same Drift database operations
- `TransactionNotifier.build()` calling `syncPendingTransactions()` does not crash or produce side effects
- Existing features (`transactions`, `wallets`) continue to function identically with their existing interface contracts

**Scope:**
All runtime behavior that does NOT involve the structural violations should be completely unaffected by this fix. This includes:
- All UI rendering and navigation flows
- All database read/write operations (success paths)
- All provider rebuild/watch chains
- All security state transitions
- All background sync scheduling

## Hypothesized Root Cause

Based on the codebase audit, the root causes are:

1. **Legacy Migration Debt (Violation 1)**: `WalletNotifier` was written during Riverpod 1.x era and never migrated to the 2.x `AsyncNotifier` pattern after the steering file was updated to ban `StateNotifierProvider`.

2. **Unnecessary Indirection (Violation 2)**: `parseSmartText()` in `TransactionNotifier` manually destructures the `ParsedTransaction` returned by `TransactionParserService.parseTransaction()` into a raw `Map<String, dynamic>`, likely because the UI consumer was written to expect a map before the `ParsedTransaction` model existed.

3. **Missing Error Pattern Adoption (Violation 3)**: Repositories were written with traditional try/catch/rethrow before the `Result<T, E>` sealed class was introduced in `core/utils/result.dart`. The `AppError` class also does not yet exist.

4. **Localization Oversight (Violation 4)**: The `SecurityWrapper` time-tamper UI was added as a quick security feature with hardcoded Indonesian strings, bypassing the `.tr()` localization system.

5. **Magic String Proliferation (Violation 5)**: The `'local_user'` string was introduced in the database seed and spread to `auth_repository.dart` without extracting a shared constant.

6. **Annotation Omission (Violation 6)**: `WalletRepository` was written without `@override` annotations — Dart does not enforce them as errors by default (only lint warnings).

7. **Incomplete Documentation (Violation 7)**: `syncPendingTransactions()` was added to the interface for future cloud sync but implemented as a no-op without documenting the intentional behavior.

8. **Incomplete Architecture Rollout (Violation 8)**: The domain interface pattern was established for `wallets` and `transactions` but never propagated to `auth`, `insights`, `gamification`, `geofencing`, and `profile` features.

## Correctness Properties

Property 1: Bug Condition - Architecture Violations Are Eliminated

_For any_ source file where a steering rule violation exists (isBugCondition returns true), the fixed codebase SHALL use the correct pattern as defined by the steering file: `AsyncNotifierProvider` instead of `StateNotifierProvider`, structured return types instead of raw maps, `Result<T, E>` instead of thrown exceptions for expected failures, `.tr()` localization instead of hardcoded strings, shared constants instead of magic strings, `@override` annotations on interface implementations, documented no-ops with `@Deprecated`, and abstract domain interfaces for all features with data layers.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8**

Property 2: Preservation - Runtime Behavior Unchanged

_For any_ operation that does NOT involve the structural violations (wallet CRUD, transaction parsing success paths, security state transitions, database seeding, provider rebuild chains), the fixed code SHALL produce exactly the same observable behavior as the original code, preserving all UI updates, data flow, and error handling for end users.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8**

## Fix Implementation

### Changes Required

#### Violation 1: WalletNotifier Migration

**File**: `lib/features/wallets/providers/wallet_provider.dart`

**Specific Changes**:
1. **Replace class hierarchy**: Change `extends StateNotifier<AsyncValue<List<WalletModel>>>` to `extends AsyncNotifier<List<WalletModel>>`
2. **Replace provider declaration**: Change `StateNotifierProvider<WalletNotifier, AsyncValue<List<WalletModel>>>` to `AsyncNotifierProvider<WalletNotifier, List<WalletModel>>`
3. **Remove constructor injection**: Remove `_repository` and `_userId` constructor parameters; access via `ref.watch()` in `build()`
4. **Add `build()` method**: Move initialization logic from constructor into `Future<List<WalletModel>> build() async`
5. **Update stream subscription**: Use `ref.onDispose()` for cleanup instead of overriding `dispose()`
6. **Update all consumers**: Any widget using `ref.watch(walletProvider)` already gets `AsyncValue<List<WalletModel>>` — no consumer changes needed

#### Violation 2: parseSmartText Return Type

**File**: `lib/features/transactions/providers/transaction_provider.dart`

**Specific Changes**:
1. **Change return type**: `Future<Map<String, dynamic>> parseSmartText(String text)` → `Future<ParsedTransaction> parseSmartText(String text)`
2. **Return structured type directly**: Remove the manual map construction; return the `ParsedTransaction` from `_parserService.parseTransaction()` directly
3. **Update callers**: Find all call sites of `parseSmartText()` and update them to access `ParsedTransaction` fields instead of map keys

#### Violation 3: Result Pattern in Repositories

**Files**: `lib/features/wallets/data/wallet_repository.dart`, `lib/features/transactions/data/transaction_repository.dart`

**Specific Changes**:
1. **Create `AppError` class**: Add `lib/core/utils/app_error.dart` with factory constructors for `notFound`, `database`, `validation`, `unknown`
2. **Update `WalletRepositoryInterface`**: Change return types to `Result<T, AppError>` for methods that can fail (e.g., `Future<Result<void, AppError>> createWallet(...)`)
3. **Update `WalletRepository`**: Replace `rethrow` with `return Failure(AppError.database(e.message))` for expected DB errors
4. **Update `TransactionRepositoryInterface`**: Change `insertTransaction` and `deleteTransaction` return types to `Result<void, AppError>`
5. **Update `TransactionRepository`**: Wrap expected failures in `Failure(...)`, keep `rethrow` only for truly unrecoverable errors
6. **Update provider consumers**: Use `switch (result) { case Success: ... case Failure: ... }` pattern

#### Violation 4: SecurityWrapper Localization

**File**: `lib/main.dart`

**Specific Changes**:
1. **Add import**: `import 'package:easy_localization/easy_localization.dart';`
2. **Replace hardcoded strings**:
   - `'Deteksi Manipulasi Waktu!'` → `'security.time_tamper_title'.tr()`
   - `'Jam perangkat Anda tidak selaras...'` → `'security.time_tamper_message'.tr()`
   - `'Periksa Kembali'` → `'security.recheck_button'.tr()`
3. **Add translation keys**: Add entries to `assets/translations/id.json` and `assets/translations/en.json`

#### Violation 5: Shared Constant for 'local_user'

**Files**: `lib/core/constants/app_constants.dart` (new), `lib/core/local_db/app_database.dart`, `lib/features/auth/data/auth_repository.dart`

**Specific Changes**:
1. **Create constants file**: `lib/core/constants/app_constants.dart` with `static const String defaultUserId = 'local_user';` and `static const String defaultUserEmail = 'local_user@duasaku.local';`
2. **Replace in `app_database.dart`**: Replace all 6 occurrences of `'local_user'` with `AppConstants.defaultUserId` (note: the `Budgets` table `withDefault` uses a Drift `Constant` — this must remain a string literal in the table definition but the seed data can use the constant)
3. **Replace in `auth_repository.dart`**: Replace all 4 occurrences of `User(id: 'local_user', email: 'local_user@duasaku.local')` with `User(id: AppConstants.defaultUserId, email: AppConstants.defaultUserEmail)`

#### Violation 6: @override Annotations

**File**: `lib/features/wallets/data/wallet_repository.dart`

**Specific Changes**:
1. **Add `@override`** before `getWallets()`, `watchWallets()`, `createWallet()`, `updateWallet()`, `deleteWallet()`

#### Violation 7: Document syncPendingTransactions No-Op

**Files**: `lib/features/transactions/domain/transaction_repository_interface.dart`, `lib/features/transactions/data/transaction_repository.dart`

**Specific Changes**:
1. **Add doc comment to interface**: Explain that this method is reserved for future cloud sync and is intentionally a no-op in offline-first mode
2. **Add `@Deprecated` annotation**: `@Deprecated('No-op in offline-first architecture. Reserved for future cloud sync implementation.')`
3. **Add doc comment to implementation**: Explain the intentional no-op behavior

#### Violation 8: Missing Domain Interfaces

**New Files**:
- `lib/features/auth/domain/auth_repository_interface.dart`
- `lib/features/insights/domain/insights_repository_interface.dart`
- `lib/features/gamification/domain/gamification_service_interface.dart`
- `lib/features/geofencing/domain/geofence_service_interface.dart`
- `lib/features/profile/domain/profile_repository_interface.dart`

**Specific Changes**:
1. **Create abstract interfaces** with method signatures matching current concrete implementations (pure Dart, no external package imports)
2. **Update concrete classes** to `implements` the new interface
3. **Update provider types** to reference abstract interfaces instead of concrete classes
4. **Create `domain/` directories** where they don't exist (`auth/domain/`, `insights/domain/`, `gamification/domain/`, `geofencing/domain/`, `profile/domain/`)

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the violations on unfixed code (static analysis and runtime tests), then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the architecture violations BEFORE implementing the fix. Confirm or refute the root cause analysis.

**Test Plan**: Write static analysis tests and runtime tests that detect each violation pattern. Run these tests on the UNFIXED code to observe failures.

**Test Cases**:
1. **StateNotifier Detection Test**: Assert that `walletProvider` is an `AsyncNotifierProvider` (will fail on unfixed code — it's a `StateNotifierProvider`)
2. **Return Type Test**: Assert that `parseSmartText()` returns `ParsedTransaction` (will fail on unfixed code — returns `Map<String, dynamic>`)
3. **Result Pattern Test**: Call `WalletRepository.createWallet()` with invalid data and assert it returns `Failure` (will fail on unfixed code — throws exception)
4. **Localization Test**: Assert `SecurityWrapper` time-tamper text uses `.tr()` keys (will fail on unfixed code — hardcoded strings)
5. **Constant Usage Test**: Grep for literal `'local_user'` in source files (will find matches on unfixed code)
6. **Override Annotation Test**: Static analysis lint check for missing `@override` (will flag on unfixed code)
7. **No-Op Documentation Test**: Assert `syncPendingTransactions()` has `@Deprecated` annotation (will fail on unfixed code)
8. **Domain Interface Test**: Assert each feature's `domain/` directory contains an abstract interface file (will fail for 5 features on unfixed code)

**Expected Counterexamples**:
- `walletProvider` type is `StateNotifierProvider` instead of `AsyncNotifierProvider`
- `parseSmartText()` return type is `Map<String, dynamic>` instead of `ParsedTransaction`
- `WalletRepository.createWallet()` throws on constraint violation instead of returning `Failure`
- Possible causes: legacy code, incomplete migration, missing adoption of new patterns

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed code produces the expected behavior.

**Pseudocode:**
```
FOR ALL codeUnit WHERE isBugCondition(codeUnit) DO
  result := applyFix(codeUnit)
  ASSERT isCompliant(result, steeringRules)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed code produces the same result as the original code.

**Pseudocode:**
```
FOR ALL operation WHERE NOT isBugCondition(operation) DO
  ASSERT originalBehavior(operation) = fixedBehavior(operation)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across the input domain (random wallet data, transaction amounts, user IDs)
- It catches edge cases that manual unit tests might miss (boundary amounts, empty lists, null walletIds)
- It provides strong guarantees that behavior is unchanged for all non-buggy inputs

**Test Plan**: Observe behavior on UNFIXED code first for wallet CRUD, transaction parsing, and security state transitions, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Wallet CRUD Preservation**: Verify that creating, reading, updating, and deleting wallets produces identical results after the `AsyncNotifier` migration
2. **Parse Result Preservation**: Verify that `parseSmartText()` returns the same field values (amount, category, type, walletId, notes) regardless of return type change
3. **Security State Preservation**: Verify that `SecurityWrapper` renders the same UI states (loading, locked, tampered, normal) after localization change
4. **Database Seed Preservation**: Verify that default categories are seeded with the same userId value after constant extraction
5. **Stream Behavior Preservation**: Verify that `watchWallets()` stream emits the same data sequence after `@override` addition

### Unit Tests

- Test `WalletNotifier` (as `AsyncNotifier`) correctly loads wallets, adds, updates, and deletes
- Test `parseSmartText()` returns `ParsedTransaction` with correct field values for various inputs
- Test `WalletRepository` returns `Result<void, AppError>` with `Failure` for constraint violations
- Test `SecurityWrapper` renders localized strings from translation keys
- Test `AppConstants.defaultUserId` equals `'local_user'`
- Test `syncPendingTransactions()` has `@Deprecated` annotation (reflection/analyzer test)
- Test each new abstract interface is implemented by its concrete class

### Property-Based Tests

- Generate random wallet models and verify `WalletNotifier` state transitions are identical pre/post migration
- Generate random transaction text inputs and verify `parseSmartText()` field values match between map and structured type
- Generate random DB operations (success/failure scenarios) and verify `Result` pattern returns equivalent data to try/catch pattern
- Generate random userId strings and verify constant substitution produces identical query results

### Integration Tests

- Test full wallet lifecycle (create → read → update → delete) with new `AsyncNotifier` pattern
- Test transaction entry flow end-to-end with `ParsedTransaction` return type
- Test security flow: app launch → time tamper detected → localized warning displayed → recheck button works
- Test that all 5 new domain interfaces are properly wired through providers to presentation layer
