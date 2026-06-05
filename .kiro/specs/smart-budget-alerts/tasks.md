# Implementation Plan: Smart Budget Alerts

## Overview

Implementasi fitur Smart Budget Alerts untuk DuaSaku menggunakan event-driven approach. Fitur ini terdiri dari 3 tabel Drift baru (schema v7), domain models, repository interfaces + implementations, service layer (Alert Engine, Prediction Engine, Notification Service), providers (Riverpod), dan presentation layer (Alert Center, Alert Preferences). Property-based tests menggunakan glados library.

## Tasks

- [x] 1. Set up data model dan database schema
  - [x] 1.1 Create domain models (BudgetAlertModel, AlertPreferenceModel, AlertThresholdStatusModel, AlertType enum)
    - Create `lib/features/smart_budget_alerts/domain/models/alert_type.dart` with `AlertType` enum (threshold, prediction, overBudget)
    - Create `lib/features/smart_budget_alerts/domain/models/budget_alert_model.dart` with all fields, `toJson()`, `fromJson()`, `copyWith()`
    - Create `lib/features/smart_budget_alerts/domain/models/alert_preference_model.dart` with all fields, `defaults()` factory, `toJson()`, `fromJson()`, `copyWith()`
    - Create `lib/features/smart_budget_alerts/domain/models/alert_threshold_status_model.dart` with all fields, `toJson()`, `fromJson()`
    - _Requirements: 7.1, 7.2, 7.3, 7.6, 7.7_

  - [x] 1.2 Write property tests for model serialization round-trip
    - **Property 13: BudgetAlertModel serialization round-trip**
    - **Property 14: AlertPreferenceModel serialization round-trip**
    - Use glados with custom Arbitrary instances for each model
    - Minimum 100 iterations per property
    - **Validates: Requirements 7.6, 7.7**

  - [x] 1.3 Create Drift table definitions and migration to schema v7
    - Add `BudgetAlerts` table with index on (userId, createdAt) in `lib/core/local_db/app_database.dart`
    - Add `BudgetAlertPreferences` table with index on (userId)
    - Add `BudgetAlertThresholdStatus` table with index on (userId, categoryId, budgetMonth)
    - Increment `schemaVersion` to 7
    - Add migration step with `if (from < 7)` guard: create tables + indexes
    - Run `dart run build_runner build` to generate code
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 2. Implement repository layer
  - [x] 2.1 Create abstract repository interfaces in domain layer
    - Create `lib/features/smart_budget_alerts/domain/alert_repository_interface.dart` with methods: getAlerts, watchAlerts, getUnreadCount, watchUnreadCount, insertAlert, markAsRead, markAllVisibleAsRead, deleteAlert, deleteAllRead
    - Create `lib/features/smart_budget_alerts/domain/alert_preferences_repository_interface.dart` with methods: getGlobalPreferences, getCategoryPreferences, getAllPreferences, savePreferences, initializeDefaults, watchGlobalPreferences
    - Create `lib/features/smart_budget_alerts/domain/alert_threshold_status_repository_interface.dart` with methods: getTriggeredThresholds, markThresholdTriggered, resetThreshold, resetAllForNewPeriod
    - _Requirements: 7.1, 7.2, 7.3_

  - [x] 2.2 Implement AlertRepository (concrete, Drift-based)
    - Create `lib/features/smart_budget_alerts/data/alert_repository.dart` implementing `AlertRepositoryInterface`
    - Implement all CRUD operations using Drift queries on `BudgetAlerts` table
    - Ensure `watchAlerts` returns stream ordered by createdAt descending
    - Implement `getUnreadCount` and `watchUnreadCount` with isRead filter
    - _Requirements: 4.1, 4.3, 4.4, 4.8, 7.1_

  - [x] 2.3 Implement AlertPreferencesRepository (concrete, Drift-based)
    - Create `lib/features/smart_budget_alerts/data/alert_preferences_repository.dart` implementing `AlertPreferencesRepositoryInterface`
    - Implement `initializeDefaults` with thresholds [50, 75, 90, 100], predictions enabled, no quiet hours
    - Handle JSON encoding/decoding for thresholds list and TimeOfDay for quiet hours
    - _Requirements: 3.5, 3.6, 7.2_

  - [x] 2.4 Implement AlertThresholdStatusRepository (concrete, Drift-based)
    - Create `lib/features/smart_budget_alerts/data/alert_threshold_status_repository.dart` implementing `AlertThresholdStatusRepositoryInterface`
    - Implement threshold tracking per (userId, categoryId, budgetMonth, thresholdValue)
    - Implement reset methods for spending decrease and new period scenarios
    - _Requirements: 1.5, 1.7, 6.3, 7.3_

- [x] 3. Checkpoint - Ensure data layer compiles and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement service layer — Alert Engine
  - [x] 4.1 Implement AlertEngineService
    - Create `lib/features/smart_budget_alerts/services/alert_engine_service.dart`
    - Implement `evaluateThresholds()`: fetch budget + total spending, calculate percentage, check against configured thresholds, skip already-triggered thresholds, generate alert, save to DB, send notification
    - Implement `evaluateOverallThresholds()`: aggregate spending across all categories against overall monthly budget
    - Implement `reevaluateAfterSpendingDecrease()`: recalculate spending, reset threshold statuses where spending dropped below threshold
    - Respect master toggle and per-category enable/disable from preferences
    - Use Result pattern for error handling; skip silently if no budget configured (Req 6.4)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 6.1, 6.2, 6.4, 6.5, 6.6_

  - [x] 4.2 Write property tests for Alert Engine
    - **Property 1: Alert correctness — threshold and over-budget alerts contain accurate financial data**
    - **Validates: Requirements 1.1, 1.3**

  - [x] 4.3 Write property test for no duplicate alerts
    - **Property 2: No duplicate alerts per threshold per category per period**
    - **Validates: Requirements 1.5**

  - [x] 4.4 Write property test for threshold reset on spending decrease
    - **Property 3: Threshold reset on spending decrease**
    - **Validates: Requirements 1.7, 6.6**

  - [x] 4.5 Write property test for master toggle
    - **Property 9: Master toggle disables all alerts and notifications**
    - **Validates: Requirements 3.7, 5.5**

- [x] 5. Implement service layer — Prediction Engine
  - [x] 5.1 Implement PredictionEngineService
    - Create `lib/features/smart_budget_alerts/services/prediction_engine_service.dart`
    - Implement `calculateSpendingRate()`: totalSpent / elapsedDays
    - Implement `projectTotalSpending()`: currentSpent + (dailyRate * remainingDays) + upcomingRecurring
    - Implement `calculateOverspendDate()`: find date when cumulative spending exceeds budget limit
    - Implement `evaluatePrediction()`: orchestrate calculation, enforce 3-day minimum, check if overspend date is within current period, generate alert
    - Fetch upcoming recurring transactions from RecurringTransactionDao for projection accuracy
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 5.2 Write property tests for Prediction Engine calculations
    - **Property 4: Projection calculation correctness**
    - **Validates: Requirements 2.1, 2.2**

  - [x] 5.3 Write property test for prediction alert overspend date
    - **Property 5: Prediction alert generation with correct overspend date**
    - **Validates: Requirements 2.3**

  - [x] 5.4 Write property test for prediction within current period only
    - **Property 6: Prediction alerts only generated within current budget period**
    - **Validates: Requirements 2.5**

- [x] 6. Implement service layer — Budget Notification Service
  - [x] 6.1 Implement BudgetNotificationService
    - Create `lib/features/smart_budget_alerts/services/budget_notification_service.dart`
    - Configure notification channel "Budget Alerts" with high priority
    - Implement `sendAlertNotification()`: check quiet hours, send or queue
    - Implement `isQuietHoursActive()`: handle same-day and midnight-spanning ranges
    - Implement `queueNotification()`: persist queued notifications for later delivery
    - Implement `processQueuedNotifications()`: if queue > 3 send summary, else send individual with 10s interval
    - Respect master toggle — no notifications when disabled
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 3.4_

  - [x] 6.2 Write property tests for quiet hours detection
    - **Property 8: Quiet hours detection**
    - **Validates: Requirements 3.4**

  - [x] 6.3 Write property test for notification queue batch logic
    - **Property 12: Notification queue batch logic**
    - **Validates: Requirements 5.2**

- [x] 7. Checkpoint - Ensure all service layer tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Implement providers and alert preferences logic
  - [x] 8.1 Create Riverpod providers for repositories and services
    - Create `lib/features/smart_budget_alerts/providers/alert_center_provider.dart` with alertCenterProvider (StreamProvider) and unreadBadgeCountProvider (StreamProvider)
    - Create `lib/features/smart_budget_alerts/providers/alert_preferences_provider.dart` with AlertPreferencesNotifier (AsyncNotifier) for CRUD operations on preferences
    - Create `lib/features/smart_budget_alerts/providers/unread_badge_provider.dart` with unreadBadgeCountProvider
    - Register alertEngineProvider, predictionEngineProvider, budgetNotificationServiceProvider as Provider<T>
    - Register repository providers with abstract interface types
    - _Requirements: 3.5, 3.6, 4.4_

  - [x] 8.2 Implement threshold value validation in AlertPreferencesNotifier
    - Validate custom thresholds: must be multiples of 5, between 10 and 100 inclusive
    - Implement master toggle logic that disables all alerts
    - Implement per-category enable/disable
    - Implement quiet hours configuration with TimeOfDay start/end
    - _Requirements: 3.1, 3.2, 3.3, 3.7_

  - [x] 8.3 Write property test for threshold value validation
    - **Property 7: Threshold value validation**
    - **Validates: Requirements 3.2**

- [x] 9. Implement integration with existing transaction system
  - [x] 9.1 Wire alert evaluation into transaction add/update/delete flows
    - After expense transaction insert (manual or recurring): call `alertEngine.evaluateThresholds()` and `predictionEngine.evaluatePrediction()`
    - After expense transaction delete or amount/category update: call `alertEngine.reevaluateAfterSpendingDecrease()`
    - After recurring transaction execution: trigger same evaluation as manual transaction
    - Skip evaluation if category has no active budget for current month
    - Implement period reset logic: reset all threshold statuses at start of new budget month
    - _Requirements: 1.4, 2.4, 6.1, 6.3, 6.4, 6.5, 6.6_

  - [x] 9.2 Write property tests for alert list ordering and unread count
    - **Property 10: Alerts sorted descending by creation timestamp**
    - **Property 11: Unread count accuracy**
    - **Validates: Requirements 4.1, 4.4**

- [x] 10. Implement presentation layer — Alert Center
  - [x] 10.1 Create Alert Center screen and widgets
    - Create `lib/features/smart_budget_alerts/presentation/screens/alert_center_screen.dart`
    - Display alert list ordered by createdAt descending with staggered fade-in animation (flutter_animate)
    - Each AlertCard shows: alert type icon, category name, message, timestamp, read/unread indicator
    - Mark visible alerts as read when screen opens
    - Implement swipe-to-delete gesture for individual alerts
    - Implement "clear all" button to delete all read alerts
    - Show empty state with Lottie animation when no alerts
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 4.8_

  - [x] 10.2 Create Alert Badge widget
    - Create `lib/features/smart_budget_alerts/presentation/widgets/alert_badge_widget.dart`
    - Display unread count badge on navigation icon
    - Watch unreadBadgeCountProvider for real-time updates
    - _Requirements: 4.4_

  - [x] 10.3 Implement alert tap navigation
    - On tap threshold/over-budget alert: navigate to budget detail screen for that category
    - On tap prediction alert: navigate to budget detail with projection info displayed
    - _Requirements: 4.6, 4.7_

- [x] 11. Implement presentation layer — Alert Preferences
  - [x] 11.1 Create Alert Preferences screen
    - Create `lib/features/smart_budget_alerts/presentation/screens/alert_preferences_screen.dart`
    - Master toggle to enable/disable all budget alerts
    - Per-category toggle list to enable/disable alerts individually
    - Custom threshold selector (multiples of 5, 10-100) per category
    - Prediction alerts toggle (separate from threshold alerts)
    - Quiet hours configuration with time pickers for start/end
    - Save changes immediately to DB without restart requirement
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

- [x] 12. Implement background task for quiet hours queue processing
  - [x] 12.1 Register background task for notification queue processing
    - Add budget alert queue processing to workmanager periodic task in `lib/core/background/`
    - Process queued notifications when quiet hours end: summary if > 3, individual if ≤ 3
    - Handle notification tap deep link to open Alert Center (`duasaku://alert_center`)
    - Follow existing retry pattern (return false for exponential backoff)
    - _Requirements: 5.2, 5.3_

- [x] 13. Implement push notification tap handling
  - [x] 13.1 Configure notification tap action to open Alert Center
    - Register deep link route `duasaku://alert_center` in app routing
    - Handle notification tap payload to navigate to Alert Center and highlight relevant alert
    - Configure notification channel "Budget Alerts" with high priority
    - _Requirements: 5.3, 5.4_

- [x] 14. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document (14 properties total)
- Unit tests validate specific examples and edge cases
- All repositories use abstract interfaces in domain layer per project architecture rules
- Database migration uses `if (from < 7)` guard pattern
- Providers depend on abstract interface types, not concrete implementations
- glados library used for property-based testing (minimum 100 iterations)
- flutter_animate for staggered list animations, Lottie for empty states
- All user-facing strings must use `.tr()` for localization

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["2.1"] },
    { "id": 3, "tasks": ["2.2", "2.3", "2.4"] },
    { "id": 4, "tasks": ["4.1", "5.1", "6.1"] },
    { "id": 5, "tasks": ["4.2", "4.3", "4.4", "4.5", "5.2", "5.3", "5.4", "6.2", "6.3"] },
    { "id": 6, "tasks": ["8.1", "8.2"] },
    { "id": 7, "tasks": ["8.3", "9.1"] },
    { "id": 8, "tasks": ["9.2", "10.1", "10.2", "11.1"] },
    { "id": 9, "tasks": ["10.3", "12.1", "13.1"] }
  ]
}
```
