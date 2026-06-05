# Implementation Plan

## Overview

This task list implements the bugfix for 8 architecture violations in the DuaSaku Flutter finance app. The workflow follows the exploratory bugfix methodology: write tests to confirm violations exist, write preservation tests to capture baseline behavior, implement the fix, then verify all tests pass.

## Tasks

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Architecture Violations Exist in Unfixed Code
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the violations exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the 8 architecture violations exist
  - **Scoped PBT Approach**: Scope the property to concrete failing cases for each violation type
  - Test assertions (all should FAIL on unfixed code, confirming violations):
    - Assert `walletProvider` is an `AsyncNotifierProvider` (fails: it's a `StateNotifierProvider`)
    - Assert `TransactionNotifier.parseSmartText()` return type is `ParsedTransaction` (fails: returns `Map<String, dynamic>`)
    - Assert `WalletRepository.createWallet()` with invalid data returns `Result.failure` (fails: throws exception)
    - Assert `SecurityWrapper` time-tamper strings use `.tr()` localization keys (fails: hardcoded Indonesian strings)
    - Assert no source file contains literal `'local_user'` string outside constants file (fails: found in `app_database.dart` and `auth_repository.dart`)
    - Assert `WalletRepository` methods have `@override` annotations (fails: annotations missing)
    - Assert `syncPendingTransactions()` has `@Deprecated` annotation or doc comment (fails: undocumented no-op)
    - Assert features `auth`, `insights`, `gamification`, `geofencing`, `profile` have abstract interfaces in `domain/` (fails: directories/files missing)
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the violations exist)
  - Document counterexamples found (e.g., "walletProvider type is StateNotifierProvider", "parseSmartText returns Map<String, dynamic>")
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Runtime Behavior Unchanged for Non-Violating Code Paths
  - **IMPORTANT**: Follow observation-first methodology
  - **Step 1 - Observe**: Run UNFIXED code and record actual behavior for non-buggy paths:
    - Observe: Wallet CRUD operations (create, read, update, delete) produce correct state transitions
    - Observe: `parseSmartText("beli kopi 25000")` returns fields {amount: 25000, category: "food", type: "expense", ...}
    - Observe: `SecurityWrapper` renders loading indicator when `isInitialized == false`, PIN screen when `isLocked == true`, child widget when state is normal
    - Observe: Database queries with userId filter correctly return matching records
    - Observe: `watchWallets()` stream emits wallet list data reactively
    - Observe: `syncPendingTransactions()` completes without crash or side effects
  - **Step 2 - Write property-based tests** capturing observed behavior:
    - For all valid wallet models, `WalletNotifier` state transitions (load → add → update → delete) produce identical results pre/post migration
    - For all parseable transaction text inputs, `parseSmartText()` field values (amount, category, type, walletId, notes) match between map access and structured type access
    - For all non-tampered security states, `SecurityWrapper` renders the same widget tree
    - For all database seed operations, userId value resolves to the same logical value (`'local_user'`)
    - For all successful repository operations, return data is identical regardless of error handling pattern change
  - **Step 3 - Verify**: Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [x] 3. Fix for architecture compliance violations

  - [x] 3.1 Create shared constants and utility classes
    - Create `lib/core/constants/app_constants.dart` with `static const String defaultUserId = 'local_user'` and `static const String defaultUserEmail = 'local_user@duasaku.local'`
    - Create `lib/core/utils/app_error.dart` with sealed class `AppError` and factory constructors for `notFound`, `database`, `validation`, `unknown`
    - _Bug_Condition: isBugCondition(codeUnit) where codeUnit.hasHardcodedLiteralWithoutConstant() OR codeUnit.throwsExceptionForExpectedFailure()_
    - _Expected_Behavior: Shared constants and error types exist for use across the codebase_
    - _Preservation: No runtime behavior changes - these are new files_
    - _Requirements: 2.3, 2.5_

  - [x] 3.2 Migrate WalletNotifier to AsyncNotifierProvider
    - Replace `extends StateNotifier<AsyncValue<List<WalletModel>>>` with `extends AsyncNotifier<List<WalletModel>>`
    - Replace `StateNotifierProvider` declaration with `AsyncNotifierProvider`
    - Remove constructor injection of `_repository` and `_userId`; access via `ref.watch()` in `build()`
    - Add `Future<List<WalletModel>> build() async` method with initialization logic
    - Use `ref.onDispose()` for stream subscription cleanup instead of overriding `dispose()`
    - Update state mutation calls from `state = AsyncValue.data(...)` to `state = AsyncData(...)`
    - _Bug_Condition: isBugCondition(codeUnit) where codeUnit.usesStateNotifierProvider()_
    - _Expected_Behavior: WalletNotifier uses AsyncNotifierProvider with ref as property_
    - _Preservation: Wallet list reactively updates UI identically; all CRUD operations produce same results_
    - _Requirements: 2.1, 3.1_

  - [x] 3.3 Fix parseSmartText return type
    - Change `Future<Map<String, dynamic>> parseSmartText(String text)` to `Future<ParsedTransaction> parseSmartText(String text)`
    - Remove manual map construction; return `ParsedTransaction` from `_parserService.parseTransaction()` directly
    - Update all callers to access `ParsedTransaction` fields (`.amount`, `.category`, `.type`, `.walletId`, `.notes`) instead of map keys
    - _Bug_Condition: isBugCondition(codeUnit) where codeUnit.returnsRawMapFromService()_
    - _Expected_Behavior: parseSmartText() returns structured ParsedTransaction type_
    - _Preservation: Same parsed fields with correct values are accessible to consumers_
    - _Requirements: 2.2, 3.2_

  - [x] 3.4 Implement Result pattern in repositories
    - Update `WalletRepositoryInterface` method signatures to return `Result<T, AppError>`
    - Update `WalletRepository`: replace `rethrow` with `return Failure(AppError.database(e.message))` for expected DB errors
    - Update `TransactionRepositoryInterface`: change `insertTransaction` and `deleteTransaction` return types to `Result<void, AppError>`
    - Update `TransactionRepository`: wrap expected failures in `Failure(...)`, keep `rethrow` only for unrecoverable errors
    - Update provider consumers to use `switch (result) { case Success: ... case Failure: ... }` pattern
    - _Bug_Condition: isBugCondition(codeUnit) where codeUnit.throwsExceptionForExpectedFailure()_
    - _Expected_Behavior: Repositories return Result<T, AppError> for expected failures_
    - _Preservation: Success paths return data identically; only error handling mechanism changes_
    - _Requirements: 2.3, 3.3_

  - [x] 3.5 Localize SecurityWrapper hardcoded strings
    - Add translation keys to `assets/translations/id.json`: `security.time_tamper_title`, `security.time_tamper_message`, `security.recheck_button`
    - Add translation keys to `assets/translations/en.json` with English equivalents
    - Replace `'Deteksi Manipulasi Waktu!'` with `'security.time_tamper_title'.tr()`
    - Replace `'Jam perangkat Anda tidak selaras...'` with `'security.time_tamper_message'.tr()`
    - Replace `'Periksa Kembali'` with `'security.recheck_button'.tr()`
    - _Bug_Condition: isBugCondition(codeUnit) where codeUnit.hasHardcodedUserFacingString()_
    - _Expected_Behavior: All user-facing strings use .tr() localization keys_
    - _Preservation: SecurityWrapper displays same text to Indonesian users; loading/PIN/child states unchanged_
    - _Requirements: 2.4, 3.4_

  - [x] 3.6 Replace magic string 'local_user' with shared constant
    - Replace all 7 occurrences of `'local_user'` in `lib/core/local_db/app_database.dart` with `AppConstants.defaultUserId` (except Drift table `withDefault` which requires string literal)
    - Replace all 4 occurrences in `lib/features/auth/data/auth_repository.dart` with `AppConstants.defaultUserId` and `AppConstants.defaultUserEmail`
    - Add import for `app_constants.dart` in affected files
    - _Bug_Condition: isBugCondition(codeUnit) where codeUnit.hasHardcodedLiteralWithoutConstant()_
    - _Expected_Behavior: All references use AppConstants.defaultUserId shared constant_
    - _Preservation: Database queries filter by same logical value; seed data unchanged_
    - _Requirements: 2.5, 3.5_

  - [x] 3.7 Add @override annotations to WalletRepository
    - Add `@override` annotation before `getWallets()`, `watchWallets()`, `createWallet()`, `updateWallet()`, `deleteWallet()`
    - _Bug_Condition: isBugCondition(codeUnit) where codeUnit.missingOverrideAnnotation()_
    - _Expected_Behavior: All interface implementation methods have @override annotations_
    - _Preservation: No runtime behavior change - annotations are compile-time only_
    - _Requirements: 2.6, 3.6_

  - [x] 3.8 Document syncPendingTransactions no-op
    - Add doc comment to `TransactionRepositoryInterface.syncPendingTransactions()` explaining future cloud sync intent
    - Add `@Deprecated('No-op in offline-first architecture. Reserved for future cloud sync implementation.')` annotation
    - Add doc comment to `TransactionRepository.syncPendingTransactions()` implementation explaining intentional no-op
    - _Bug_Condition: isBugCondition(codeUnit) where codeUnit.hasUndocumentedNoOp()_
    - _Expected_Behavior: No-op method is documented with @Deprecated and doc comment_
    - _Preservation: Method still does nothing; TransactionNotifier.build() call still completes without crash_
    - _Requirements: 2.7, 3.7_

  - [x] 3.9 Create missing domain layer interfaces
    - Create `lib/features/auth/domain/auth_repository_interface.dart` with abstract methods matching `AuthRepository`
    - Create `lib/features/insights/domain/insights_repository_interface.dart` with abstract methods matching `InsightsRepository`
    - Create `lib/features/gamification/domain/gamification_service_interface.dart` with abstract methods matching `GamificationService`
    - Create `lib/features/geofencing/domain/geofence_service_interface.dart` with abstract methods matching `GeofenceService`
    - Create `lib/features/profile/domain/profile_repository_interface.dart` with abstract methods matching `ProfileRepository`
    - Update concrete classes to `implements` the new interfaces
    - Update provider type annotations to reference abstract interfaces
    - _Bug_Condition: isBugCondition(codeUnit) where codeUnit.missingDomainInterface()_
    - _Expected_Behavior: All features with data layers have abstract domain interfaces_
    - _Preservation: Existing features continue to function identically; no runtime behavior change_
    - _Requirements: 2.8, 3.8_

  - [x] 3.10 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Architecture Violations Are Eliminated
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior (all 8 assertions should now pass)
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms all 8 violations are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_

  - [x] 3.11 Verify preservation tests still pass
    - **Property 2: Preservation** - Runtime Behavior Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions in wallet CRUD, transaction parsing, security states, database seeding, stream behavior)
    - Confirm all tests still pass after fix (no regressions)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_

- [x] 4. Checkpoint - Ensure all tests pass
  - Run full test suite to confirm no regressions
  - Verify all 8 architecture violations are resolved
  - Verify all preservation tests pass (wallet CRUD, parsing, security, database, streams)
  - Run `dart analyze` to confirm no new lint warnings introduced
  - Ensure the app compiles and runs without errors
  - Ask the user if questions arise

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "2"] },
    { "id": 1, "tasks": ["3.1"] },
    { "id": 2, "tasks": ["3.2", "3.3", "3.4", "3.5", "3.6", "3.8", "3.9"] },
    { "id": 3, "tasks": ["3.7"] },
    { "id": 4, "tasks": ["3.10"] },
    { "id": 5, "tasks": ["3.11"] },
    { "id": 6, "tasks": ["4"] }
  ]
}
```

## Notes

- Tasks 1 and 2 MUST be completed before any implementation begins (tasks 3.x)
- Task 3.1 creates shared utilities needed by multiple subsequent tasks
- Tasks 3.2–3.9 can be partially parallelized but some have dependencies (noted in graph)
- Tasks 3.10 and 3.11 re-run existing tests from tasks 1 and 2 — do NOT write new tests
- The Drift table `withDefault` in `app_database.dart` requires a string literal and cannot use the constant — this is an acceptable exception documented in the design
