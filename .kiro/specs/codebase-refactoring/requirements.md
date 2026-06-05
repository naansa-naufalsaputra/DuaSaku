# Requirements Document

## Introduction

This document specifies the requirements for a comprehensive codebase refactoring and steering file overhaul of the DuaSaku Flutter finance app. The refactoring addresses technical debt identified during a full audit, covering two phases: (1) updating the project steering file (`duasaku.md`) with modern standards and new architectural sections, and (2) executing priority refactoring tasks including AI logic extraction, theming compliance, lint hardening, code cleanup, domain layer interfaces, and baseline unit testing.

## Glossary

- **Steering_File**: The `.kiro/steering/duasaku.md` document that defines project-wide coding standards, architecture rules, and patterns for the DuaSaku app.
- **Riverpod_Notifier**: The modern Riverpod 2.x state management class (`Notifier`, `AsyncNotifier`) that replaces deprecated `StateNotifier` and `ChangeNotifier` patterns.
- **Service_Layer**: A dedicated layer (`lib/features/<feature>/services/` or `lib/services/`) responsible for external API integrations and AI logic, separated from data repositories.
- **Gemini_Service**: A dedicated service class that encapsulates all Google Generative AI (Gemini) interactions including text parsing and receipt scanning.
- **Domain_Layer**: The layer containing entities, repository interfaces (abstract classes), and use cases — free from Flutter/external package dependencies.
- **SecurityWrapper**: The widget in `main.dart` that gates app access based on initialization, lock, and time-tamper states.
- **Analysis_Options**: The `analysis_options.yaml` file that configures Dart static analysis rules and linter settings.
- **Result_Pattern**: An error handling pattern using a sealed class (Result/Either) to represent success or failure without throwing exceptions.
- **Deep_Link_Schema**: The URI scheme (`duasaku://`) used for navigating to specific app screens from external sources (widgets, notifications).
- **Background_Sync**: The strategy for scheduling and executing background data synchronization tasks using the `workmanager` package.
- **Transaction_Repository**: The data layer class responsible for CRUD operations on financial transactions in the local Drift database.
- **Local_Parser**: The fallback text parsing logic that extracts transaction details (amount, category, type, wallet) from natural language input without AI.

## Requirements

### Requirement 1: Mandate Riverpod 2.x Notifier Pattern in Steering File

**User Story:** As a developer, I want the steering file to mandate Riverpod 2.x Notifier and AsyncNotifier patterns, so that the team uses modern, supported state management APIs consistently.

#### Acceptance Criteria

1. WHEN the Steering_File is updated, THE Steering_File SHALL replace all `StateNotifierProvider` examples with `NotifierProvider` and `AsyncNotifierProvider` equivalents.
2. WHEN the Steering_File is updated, THE Steering_File SHALL include an explicit ban on `ChangeNotifierProvider` and `StateNotifierProvider` with rationale.
3. THE Steering_File SHALL document the migration path from `StateNotifier` to `Notifier` with before/after code examples.
4. THE Steering_File SHALL retain guidance for `StateProvider`, `FutureProvider`, `StreamProvider`, and `Provider` as valid provider types.

### Requirement 2: Define Service Layer Architecture in Steering File

**User Story:** As a developer, I want the steering file to clearly define the Service Layer's role and boundaries, so that AI integrations and external API calls are properly separated from repository logic.

#### Acceptance Criteria

1. WHEN the Steering_File is updated, THE Steering_File SHALL add a "Service Layer" section defining `lib/services/` for shared services and `lib/features/<feature>/services/` for feature-specific services.
2. THE Steering_File SHALL specify that the Service_Layer handles external API calls (Gemini AI, HTTP endpoints) while repositories handle local database operations exclusively.
3. THE Steering_File SHALL mandate that services return structured data types (not raw JSON maps) to their consumers.

### Requirement 3: Mandate Domain Layer Interfaces in Steering File

**User Story:** As a developer, I want the steering file to mandate abstract repository interfaces in the Domain Layer, so that the codebase follows dependency inversion and is testable.

#### Acceptance Criteria

1. WHEN the Steering_File is updated, THE Steering_File SHALL add a rule mandating abstract class interfaces for all repositories in `lib/features/<feature>/domain/`.
2. THE Steering_File SHALL include a code example showing an abstract repository interface and its concrete implementation.
3. THE Steering_File SHALL specify that providers depend on abstract interfaces, not concrete implementations.

### Requirement 4: Add Error Handling Pattern to Steering File

**User Story:** As a developer, I want the steering file to document a standard error handling pattern, so that error propagation is consistent and type-safe across the codebase.

#### Acceptance Criteria

1. WHEN the Steering_File is updated, THE Steering_File SHALL add an "Error Handling" section documenting the Result_Pattern (sealed class with Success and Failure variants).
2. THE Steering_File SHALL include a code example of the Result sealed class definition.
3. THE Steering_File SHALL specify that service and repository methods return `Result<T, E>` instead of throwing exceptions for expected failure cases.
4. IF a method encounters an unexpected system error, THEN THE Steering_File SHALL permit rethrowing as an unrecoverable exception.

### Requirement 5: Add Database Migration Strategy to Steering File

**User Story:** As a developer, I want the steering file to document a database migration strategy, so that schema changes are handled safely without data loss.

#### Acceptance Criteria

1. WHEN the Steering_File is updated, THE Steering_File SHALL add a "Database Migration" section documenting Drift's `schemaVersion` and `MigrationStrategy` patterns.
2. THE Steering_File SHALL include a code example showing how to increment schema version and write migration steps.
3. THE Steering_File SHALL specify that destructive migrations (dropping tables) require explicit data backup logic.

### Requirement 6: Add Deep Link Schema Documentation to Steering File

**User Story:** As a developer, I want the steering file to document all supported deep link routes, so that new deep links follow a consistent schema.

#### Acceptance Criteria

1. WHEN the Steering_File is updated, THE Steering_File SHALL add a "Deep Link Schema" section listing all registered `duasaku://` URI routes.
2. THE Steering_File SHALL document the existing route `duasaku://new_transaction` with its purpose and parameters.
3. THE Steering_File SHALL specify the naming convention for new deep link routes (lowercase, underscore-separated path segments).

### Requirement 7: Add Background Sync Strategy to Steering File

**User Story:** As a developer, I want the steering file to document the background sync strategy, so that background tasks are implemented consistently using workmanager.

#### Acceptance Criteria

1. WHEN the Steering_File is updated, THE Steering_File SHALL add a "Background Sync" section documenting the workmanager-based task scheduling pattern.
2. THE Steering_File SHALL specify constraints for background task execution (network availability, battery level).
3. THE Steering_File SHALL document the retry and failure handling strategy for background tasks.

### Requirement 8: Extract Gemini AI Logic to Dedicated Service

**User Story:** As a developer, I want Gemini AI logic extracted from TransactionRepository into a dedicated Gemini_Service, so that the repository handles only database operations.

#### Acceptance Criteria

1. WHEN the refactoring is complete, THE Gemini_Service SHALL contain the `parseTransactionWithAI` method extracted from Transaction_Repository.
2. WHEN the refactoring is complete, THE Gemini_Service SHALL contain the `scanReceiptWithAI` method extracted from Transaction_Repository.
3. THE Gemini_Service SHALL reside at `lib/services/gemini_service.dart` as a shared service.
4. WHEN the extraction is complete, THE Transaction_Repository SHALL contain only database CRUD operations and wallet balance adjustments.
5. THE Local_Parser logic (`_parseLocally` method) SHALL be extracted alongside the Gemini_Service or into a dedicated `TransactionParserService`.

### Requirement 9: Fix Hardcoded Colors in SecurityWrapper

**User Story:** As a developer, I want SecurityWrapper to use the theming system instead of hardcoded color values, so that security screens respect the active theme preset.

#### Acceptance Criteria

1. WHEN the refactoring is complete, THE SecurityWrapper SHALL use `Theme.of(context).colorScheme` for all background colors instead of hardcoded `Color(0xFF0D0E12)`.
2. WHEN the refactoring is complete, THE SecurityWrapper SHALL use `Theme.of(context).colorScheme` for all text colors instead of hardcoded `Colors.white` and `Colors.white70`.
3. WHEN the refactoring is complete, THE SecurityWrapper SHALL use `Theme.of(context).colorScheme.error` for warning icon and button colors instead of hardcoded `Color(0xFFEF4444)`.
4. WHEN the refactoring is complete, THE SecurityWrapper SHALL use `Theme.of(context).colorScheme.primary` for the loading indicator color instead of hardcoded `Color(0xFF06B6D4)`.

### Requirement 10: Strengthen Analysis Options with Strict Lint Rules

**User Story:** As a developer, I want strict lint rules enforced in analysis_options.yaml, so that code quality issues are caught at compile time.

#### Acceptance Criteria

1. WHEN the refactoring is complete, THE Analysis_Options SHALL enable `avoid_print` as an error-level rule.
2. WHEN the refactoring is complete, THE Analysis_Options SHALL enable `prefer_const_constructors` and `prefer_const_declarations` rules.
3. WHEN the refactoring is complete, THE Analysis_Options SHALL enable `always_declare_return_types` and `annotate_overrides` rules.
4. WHEN the refactoring is complete, THE Analysis_Options SHALL enable `prefer_final_locals` and `unnecessary_this` rules.
5. WHEN the refactoring is complete, THE Analysis_Options SHALL upgrade the base include to `package:flutter_lints/flutter.yaml` with additional strict rules layered on top.

### Requirement 11: Remove All print() Statements from Production Code

**User Story:** As a developer, I want all `print()` statements removed from production code, so that sensitive data is not leaked to console output and the lint rule passes cleanly.

#### Acceptance Criteria

1. WHEN the refactoring is complete, THE codebase SHALL contain zero `print()` calls in `lib/` directory files.
2. WHERE a `print()` statement served a debugging purpose, THE refactored code SHALL replace the statement with `debugPrint()` or remove it entirely.
3. IF a `print()` statement logged an error condition, THEN THE refactored code SHALL use a structured logging approach or `debugPrint()` with context.

### Requirement 12: Add Abstract Repository Interfaces in Domain Layer

**User Story:** As a developer, I want abstract repository interfaces defined in the domain layer, so that the codebase follows dependency inversion and enables mocking in tests.

#### Acceptance Criteria

1. WHEN the refactoring is complete, THE Domain_Layer SHALL contain an abstract `TransactionRepositoryInterface` in `lib/features/transactions/domain/`.
2. WHEN the refactoring is complete, THE Domain_Layer SHALL contain an abstract `WalletRepositoryInterface` in `lib/features/wallets/domain/`.
3. THE concrete repository implementations SHALL implement their corresponding abstract interfaces.
4. THE Riverpod providers SHALL depend on the abstract interfaces as their declared type.

### Requirement 13: Implement Baseline Unit Tests for Domain and Service Layer

**User Story:** As a developer, I want baseline unit tests for critical domain and service logic, so that future refactoring has a safety net and regressions are caught early.

#### Acceptance Criteria

1. WHEN the testing baseline is complete, THE test suite SHALL include unit tests for the Local_Parser logic covering amount extraction, type detection, wallet matching, and category matching.
2. WHEN the testing baseline is complete, THE test suite SHALL include unit tests for transaction balance calculation logic (income adds, expense subtracts, transfer moves between wallets).
3. THE test files SHALL reside in `test/` following the convention `test/features/<feature>/<layer>/<name>_test.dart`.
4. FOR ALL valid transaction amounts parsed by Local_Parser, parsing a formatted currency string SHALL extract the correct numeric value (round-trip property for amount parsing).
5. FOR ALL transaction insert operations, the sum of wallet balance changes SHALL equal zero (conservation property: money is neither created nor destroyed).
