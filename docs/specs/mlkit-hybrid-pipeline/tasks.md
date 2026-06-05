# Task Breakdown: Level 4 Hybrid Parser Pipeline

This document details the tasks required to implement the Level 4 Hybrid Parser Pipeline.

* **Assignee:** `mobile-developer`
* **Skills:** `clean-code`, `mobile-design`

---

## Dependency Waves (Sequence of Execution)

```mermaid
gpg -- wave-1 [pubspec.yaml / pub get]
  wave-1 --> wave-2 [ParsedTransaction & TransactionNotifier updates]
  wave-2 --> wave-3 [SmartInputMlService implementation]
  wave-3 --> wave-4 [Riverpod Injection & Startup Initialization]
  wave-4 --> wave-5 [UI Integration in Bottom Sheet]
  wave-5 --> wave-6 [Verification & Testing]
```

---

## Tasks Checklist

- [ ] **Task 1: Add Dependencies**
  * **File:** `pubspec.yaml`
  * **Details:** Add `google_mlkit_translation: ^0.13.1` and `google_mlkit_entity_extraction: ^0.15.3` to `dependencies`.
  * **Verification:** Run `flutter pub get` and ensure it completes without version conflicts.

- [ ] **Task 2: Update Models**
  * **File:** `lib/services/models/parsed_transaction.dart`
  * **Details:** Add `DateTime? date` field, update constructor, and default to `null` if not provided.
  * **Verification:** Compile project to check for any breaking model references.

- [ ] **Task 3: Implement SmartInputMlService**
  * **File:** `lib/services/smart_input_ml_service.dart` [NEW]
  * **Details:** Implement the offline translator bridge and entity extractor. Ensure translation from ID to EN, then EN Entity Extraction. Return `DateTime`.
  * **Verification:** Implement standard try-catch blocks and verify clean exception propagation.

- [ ] **Task 4: Wire Providers & Orchestration**
  * **File:** `lib/services/service_providers.dart` and `lib/features/transactions/services/smart_parser_orchestrator.dart`
  * **Details:**
    * Register `smartInputMlServiceProvider`.
    * Update `SmartParserOrchestrator` to inject and invoke the ML service for date extraction after amount/category extraction.
  * **Verification:** Ensure parser mode provider compiles correctly.

- [ ] **Task 5: Silent Background Model Download on Startup**
  * **File:** `lib/main.dart`
  * **Details:** Trigger `smartInputMlServiceProvider.initializeSilently()` asynchronously without `await` to initiate downloads in the background on startup.
  * **Verification:** Ensure app starts instantly without hanging on a blank screen.

- [ ] **Task 6: Update Transaction Controller/Notifier**
  * **File:** `lib/features/transactions/providers/transaction_provider.dart`
  * **Details:** Update `createTransaction` method to accept an optional `createdAt` parameter and pass it into the `TransactionModel` creation.
  * **Verification:** Verify that unit tests for `TransactionNotifier` still compile and pass.

- [ ] **Task 7: UI Date Selection & Integration**
  * **File:** `lib/features/transactions/presentation/widgets/transaction_draft_bottom_sheet.dart`
  * **Details:**
    * Add a state variable `_selectedDate` initialized with `widget.draftData.date ?? DateTime.now()`.
    * Add a styled, interactive Date & Time picker button/row to the sheet.
    * Pass `_selectedDate` to the `createTransaction` invocation.
  * **Verification:** Verify visually that the parsed date matches what the user typed.

- [ ] **Task 8: End-to-End Verification**
  * **Details:** Run manual verification flow with texts:
    * *"gopay bayar kopi 25k tadi pagi"* -> should output current date at morning (e.g., 08:00).
    * *"beli baju kemarin siang 150rb"* -> should output yesterday's date at midday.
  * **Verification:** Check console logs to confirm no exceptions during ML Kit model loading and translation.
