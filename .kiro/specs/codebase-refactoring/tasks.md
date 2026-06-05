# Implementation Plan: Codebase Refactoring

## Overview

This plan implements a two-phase refactoring of the DuaSaku Flutter finance app. Phase 1 updates the steering file with modern standards and architectural sections. Phase 2 executes priority code refactoring tasks including AI logic extraction, theming compliance, lint hardening, code cleanup, domain layer interfaces, and baseline unit testing.

## Tasks

- [x] 1. Update Steering File — Riverpod 2.x and Service Layer
  - [x] 1.1 Replace StateNotifier examples with Notifier/AsyncNotifier patterns in steering file
    - Open `.kiro/steering/duasaku.md`
    - Replace all `StateNotifierProvider` examples with `NotifierProvider` and `AsyncNotifierProvider` equivalents
    - Add explicit ban on `ChangeNotifierProvider` and `StateNotifierProvider` with rationale
    - Document migration path from `StateNotifier` to `Notifier` with before/after code examples
    - Retain guidance for `StateProvider`, `FutureProvider`, `StreamProvider`, and `Provider`
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [x] 1.2 Add Service Layer architecture section to steering file
    - Add "Service Layer" section defining `lib/services/` for shared services and `lib/features/<feature>/services/` for feature-specific services
    - Specify that Service Layer handles external API calls (Gemini AI, HTTP endpoints) while repositories handle local database operations exclusively
    - Mandate that services return structured data types (not raw JSON maps)
    - _Requirements: 2.1, 2.2, 2.3_

.  - [ ] 1.3 Add Domain Layer interfaces mandate to steering file
    - Add rule mandating abstract class interfaces for all repositories in `lib/features/<feature>/domain/`
    - Include code example showing abstract repository interface and concrete implementation
    - Specify that providers depend on abstract interfaces, not concrete implementations
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 2. Update Steering File — Error Handling, Database, Deep Links, Background Sync
  - [x] 2.1 Add Error Handling section with Result pattern to steering file
    - Add "Error Handling" section documenting the Result pattern (sealed class with Success and Failure variants)
    - Include code example of the `Result` sealed class definition
    - Specify that service and repository methods return `Result<T, E>` instead of throwing exceptions for expected failures
    - Permit rethrowing as unrecoverable exception for unexpected system errors
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

  - [x] 2.2 Add Database Migration Strategy section to steering file
    - Add "Database Migration" section documenting Drift's `schemaVersion` and `MigrationStrategy` patterns
    - Include code example showing how to increment schema version and write migration steps
    - Specify that destructive migrations require explicit data backup logic
    - _Requirements: 5.1, 5.2, 5.3_

  - [x] 2.3 Add Deep Link Schema section to steering file
    - Add "Deep Link Schema" section listing all registered `duasaku://` URI routes
    - Document existing route `duasaku://new_transaction` with purpose and parameters
    - Specify naming convention for new deep link routes (lowercase, underscore-separated path segments)
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 2.4 Add Background Sync Strategy section to steering file
    - Add "Background Sync" section documenting workmanager-based task scheduling pattern
    - Specify constraints for background task execution (network availability, battery level)
    - Document retry and failure handling strategy for background tasks
    - _Requirements: 7.1, 7.2, 7.3_

- [x] 3. Checkpoint — Steering File Complete
  - Ensure all steering file sections are complete and consistent, ask the user if questions arise.

- [x] 4. Create Core Utilities and Data Models
  - [x] 4.1 Create Result pattern sealed class
    - Create `lib/core/utils/result.dart` with `Result<T, E>` sealed class
    - Implement `Success<T, E>` and `Failure<T, E>` final classes
    - Export from a barrel file if one exists in `lib/core/`
    - _Requirements: 4.2_

  - [x] 4.2 Create ParsedTransaction and lightweight DTO models
    - Create `ParsedTransaction` class in `lib/services/models/parsed_transaction.dart`
    - Create `WalletInfo` and `CategoryInfo` DTOs in `lib/services/models/`
    - Ensure models are immutable with `const` constructors
    - _Requirements: 8.1, 8.2_

- [x] 5. Extract Gemini AI Logic to Dedicated Service
  - [x] 5.1 Create GeminiService class
    - Create `lib/services/gemini_service.dart`
    - Extract `parseTransactionWithAI` method from `TransactionRepository` into `GeminiService.parseTransactionText`
    - Extract `scanReceiptWithAI` method from `TransactionRepository` into `GeminiService.scanReceipt`
    - Replace `print()` statements with `debugPrint()` using `[GeminiService]` prefix
    - Return `ParsedTransaction?` (null on failure) instead of throwing
    - _Requirements: 8.1, 8.2, 8.3, 11.1_

  - [x] 5.2 Create TransactionParserService with local fallback
    - Create `lib/services/transaction_parser_service.dart`
    - Extract `_parseLocally` method from `TransactionRepository` into `TransactionParserService.parseLocally`
    - Implement `parseTransaction` method with AI-first, local-fallback strategy
    - Ensure `parseLocally` is a pure function with no side effects
    - _Requirements: 8.5_

  - [x] 5.3 Refactor TransactionRepository to remove AI logic
    - Remove all Gemini AI methods from `TransactionRepository`
    - Remove local parsing logic from `TransactionRepository`
    - Ensure `TransactionRepository` contains only database CRUD operations and wallet balance adjustments
    - Update any callers to use `TransactionParserService` and `GeminiService` instead
    - Wire new services into Riverpod providers
    - _Requirements: 8.4_

  - [x] 5.4 Write property tests for local parser — Amount Parsing Round-Trip
    - **Property 1: Amount Parsing Round-Trip**
    - Test that for any valid numeric amount and supported multiplier format, formatting and parsing round-trips correctly
    - Use `glados` package for property-based testing
    - Create test at `test/features/transactions/services/transaction_parser_service_test.dart`
    - **Validates: Requirements 13.4**

  - [x] 5.5 Write property tests for local parser — Transaction Type Detection
    - **Property 2: Transaction Type Detection from Keywords**
    - Test that input containing income keywords classifies as "income", otherwise "expense"
    - Use `glados` package for property-based testing
    - Add to `test/features/transactions/services/transaction_parser_service_test.dart`
    - **Validates: Requirements 13.1**

- [x] 6. Fix SecurityWrapper Theming Compliance
  - [x] 6.1 Replace hardcoded colors in SecurityWrapper with theme-aware references
    - Open `lib/main.dart` (or wherever SecurityWrapper resides)
    - Replace `Color(0xFF0D0E12)` with `Theme.of(context).colorScheme.surface`
    - Replace `Color(0xFF06B6D4)` with `Theme.of(context).colorScheme.primary`
    - Replace `Color(0xFFEF4444)` with `Theme.of(context).colorScheme.error`
    - Replace `Colors.white` with `Theme.of(context).colorScheme.onSurface`
    - Replace `Colors.white70` with `Theme.of(context).colorScheme.onSurface.withOpacity(0.7)`
    - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 7. Strengthen Lint Rules and Remove print() Statements
  - [x] 7.1 Update analysis_options.yaml with strict lint rules
    - Upgrade base include to `package:flutter_lints/flutter.yaml`
    - Enable `avoid_print` as error-level rule
    - Enable `prefer_const_constructors` and `prefer_const_declarations`
    - Enable `always_declare_return_types` and `annotate_overrides`
    - Enable `prefer_final_locals` and `unnecessary_this`
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 7.2 Remove all print() statements from lib/ directory
    - Search for all `print()` calls in `lib/`
    - Remove debug-only print statements entirely
    - Replace error-logging print statements with `debugPrint()` including context prefix
    - Ensure zero `print()` calls remain in `lib/`
    - _Requirements: 11.1, 11.2, 11.3_

- [x] 8. Checkpoint — Core Refactoring Complete
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Add Abstract Repository Interfaces in Domain Layer
  - [x] 9.1 Create TransactionRepositoryInterface
    - Create `lib/features/transactions/domain/transaction_repository_interface.dart`
    - Define abstract class with `fetchTransactions`, `insertTransaction`, `deleteTransaction`, `syncPendingTransactions` methods
    - Ensure concrete `TransactionRepository` implements this interface
    - _Requirements: 12.1, 12.3_

  - [x] 9.2 Create WalletRepositoryInterface
    - Create `lib/features/wallets/domain/wallet_repository_interface.dart`
    - Define abstract class with `getWallets`, `watchWallets`, `createWallet`, `updateWallet`, `deleteWallet` methods
    - Ensure concrete `WalletRepository` implements this interface
    - _Requirements: 12.2, 12.3_

  - [x] 9.3 Update Riverpod providers to depend on abstract interfaces
    - Update transaction-related providers to declare type as `TransactionRepositoryInterface`
    - Update wallet-related providers to declare type as `WalletRepositoryInterface`
    - Ensure dependency inversion is enforced at the provider level
    - _Requirements: 12.4_

- [x] 10. Implement Baseline Unit Tests
  - [x] 10.1 Add test dependencies to pubspec.yaml
    - Add `mockito: ^5.4.0` to dev_dependencies
    - Add `build_runner: ^2.15.0` to dev_dependencies
    - Add `glados: ^1.1.1` to dev_dependencies for property-based testing
    - Run `flutter pub get` to install
    - _Requirements: 13.1, 13.2_

  - [x] 10.2 Write unit tests for local parser logic
    - Create `test/features/transactions/services/transaction_parser_service_test.dart`
    - Test amount extraction with various formats (plain numbers, "k"/"rb"/"ribu", "jt"/"juta")
    - Test type detection with income and expense keywords
    - Test wallet matching logic
    - Test category matching logic
    - _Requirements: 13.1_

  - [x] 10.3 Write unit tests for transaction balance calculation
    - Create `test/features/wallets/data/wallet_balance_test.dart`
    - Test that income transactions increase wallet balance by exact amount
    - Test that expense transactions decrease wallet balance by exact amount
    - Test that transfer transactions move exact amount between wallets (net zero)
    - _Requirements: 13.2_

  - [x] 10.4 Write property test for wallet balance conservation
    - **Property 3: Wallet Balance Conservation on Transfer**
    - Test that for any transfer transaction, sum of all wallet balance changes equals zero
    - Use `glados` package for property-based testing
    - Create test at `test/features/wallets/data/wallet_balance_test.dart`
    - **Validates: Requirements 13.2, 13.5**

  - [x] 10.5 Write property test for income/expense balance symmetry
    - **Property 4: Income/Expense Balance Symmetry**
    - Test that income of amount A increases balance by A, expense decreases by A
    - Use `glados` package for property-based testing
    - Add to `test/features/wallets/data/wallet_balance_test.dart`
    - **Validates: Requirements 13.2, 13.5**

- [x] 11. Final Checkpoint — All Tests Pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Phase 1 (steering file, tasks 1–3) can be completed independently of Phase 2 (code changes, tasks 4–11)
- The `glados` package is used for Dart property-based testing as specified in the design

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "2.1", "2.2", "2.3", "2.4"] },
    { "id": 1, "tasks": ["4.1", "4.2"] },
    { "id": 2, "tasks": ["5.1", "5.2", "6.1", "7.1"] },
    { "id": 3, "tasks": ["5.3", "7.2"] },
    { "id": 4, "tasks": ["5.4", "5.5", "9.1", "9.2"] },
    { "id": 5, "tasks": ["9.3", "10.1"] },
    { "id": 6, "tasks": ["10.2", "10.3"] },
    { "id": 7, "tasks": ["10.4", "10.5"] }
  ]
}
```
