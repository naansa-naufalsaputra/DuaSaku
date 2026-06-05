# Tasks Breakdown: Smart Parser Orchestrator & Dynamic Contextual Geofencing

This document provides a step-by-step checklist of tasks required to implement both enhancements. Work is divided into four distinct waves to maintain clear boundaries.

---

## 🌊 Wave 1: Database Migration & Basic Location Model
In this wave, we modify the local database schema to support coordinate data and regenerate Dart source files.

- [x] **Task 1.1: Modify Drift Table Definition**
  - Path: [app_database.dart](file:///c:/Codingg/duasaku_app/lib/core/local_db/app_database.dart)
  - Add nullable `latitude` and `longitude` fields to the `Transactions` table.
  - Increment `schemaVersion` to `9`.
  - Add upgrade migration step inside `onUpgrade` for `from < 9`.
  - Verification: Drift database test schema validation passes.

- [x] **Task 1.2: Regenerate Drift DB Code**
  - Command: `dart run build_runner build --delete-conflicting-outputs`
  - Verification: `app_database.g.dart` compiles successfully with no missing symbol errors.

- [x] **Task 1.3: Update Transaction Domain Models**
  - Path: [transaction_model.dart](file:///c:/Codingg/duasaku_app/lib/features/transactions/domain/models/transaction_model.dart)
  - Update `TransactionModel` constructors and `copyWith` / serialization methods to support `latitude` and `longitude`.
  - Verification: Clean compilation of all files importing `TransactionModel`.

---

## 🌊 Wave 2: Fallback Orchestrator (Smart Parser)
In this wave, we build the engine switcher and implement the graceful fallback mechanism.

- [x] **Task 2.1: Define ParserMode Preference**
  - Path: `lib/features/transactions/domain/parser_mode.dart` [NEW]
  - Define `ParserMode` enum (`auto`, `tfliteOnly`, `regexOnly`).
  - Create a StateNotifier / Provider for `ParserMode` backed by `SharedPreferences`.
  - Verification: Ability to save and read mode across app restarts.

- [x] **Task 2.2: Implement SmartParserOrchestrator**
  - Path: `lib/features/transactions/services/smart_parser_orchestrator.dart` [NEW]
  - Create wrapper class delegating to TFLite and Regex services.
  - Implement timeout (3s) and try-catch fallback.
  - Verification: Failures in TFLite are caught and successfully fallback to Regex.

- [x] **Task 2.3: Wire Provider to Orchestrator**
  - Path: [service_providers.dart](file:///c:/Codingg/duasaku_app/lib/services/service_providers.dart)
  - Refactor `transactionParserServiceProvider` to construct orchestrator based on the chosen mode.
  - Verification: Clean provider compilation.

- [x] **Task 2.4: Write Orchestrator Unit Tests**
  - Path: `test/features/transactions/smart_parser_orchestrator_test.dart` [NEW]
  - Verification: Mocking initialization failures correctly returns values processed by `LocalTransactionParserService`.

---

## 🌊 Wave 3: Clustering Logic & Hotspots Detection
In this wave, we build the location processing engine that aggregates transaction coordinates.

- [x] **Task 3.1: Implement Haversine Distance Calculator**
  - Path: `lib/core/utils/location_helper.dart` [NEW]
  - Verification: Write unit tests to check distance calculation accuracy.

- [x] **Task 3.2: Implement LocationClusteringService**
  - Path: `lib/features/geofencing/services/location_clustering_service.dart` [NEW]
  - Implement the centroid grouping logic.
  - Implement filters: count >= 3 or sum >= Rp 500,000.
  - Verification: Grouping logic assigns points to correct clusters.

- [x] **Task 3.3: Write Clustering Unit Tests**
  - Path: `test/features/geofencing/location_clustering_service_test.dart` [NEW]
  - Mock database rows with various locations to verify correct hotspot selection.

---

## 🌊 Wave 4: Dynamic Geofencing & UI Integration
In this wave, we tie the services together and present settings to the user.

- [x] **Task 4.1: Extend GeofenceService**
  - Path: [geofence_service.dart](file:///c:/Codingg/duasaku_app/lib/features/geofencing/services/geofence_service.dart)
  - Implement `updateGeofences` method to register/unregister hotspots dynamically.
  - Verification: Correct integration with local notification plugin triggers.

- [x] **Task 4.2: Add Location Input to Transaction UI**
  - Path: `lib/features/transactions/presentation/widgets/transaction_type_bottom_sheet.dart`
  - Add a toggle button to capture GPS location via `geolocator` when adding a transaction.
  - Verification: Newly created transactions store coordinates in local database.

- [x] **Task 4.3: Add Settings UI in Profile Screen**
  - Path: [profile_screen.dart](file:///c:/Codingg/duasaku_app/lib/features/profile/presentation/screens/profile_screen.dart)
  - Add configuration cards to swap Parser Engine mode.
  - Add toggle for geofencing alerts.
  - Verification: Swaps are saved to `SharedPreferences` instantly.

- [x] **Task 4.4: Schedule Background Sync**
  - Trigger clustering updates periodically (WorkManager) and on every new transaction insertion.
  - Verification: New locations trigger updates to registered geofence hotspots.

---

## 🌊 Wave 5: Final Auditing & Verification
- [x] **Task 5.1: Run Checklist Auditing**
  - Run: `python .agent/scripts/checklist.py .`
- [x] **Task 5.2: Run Full Tests Suite**
  - Run: `flutter test`
- [x] **Task 5.3: Verify APK Build**
  - Run: `flutter build apk --debug`
