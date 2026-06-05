# Task Breakdown: Offline Receipt Scanner

This document lists the tasks required to implement the offline receipt scanner in `duasaku_app`.

* **Assignee:** `mobile-developer`
* **Skills:** `clean-code`, `mobile-design`

---

## Dependency Waves (Sequence of Execution)

```mermaid
gpg -- wave-1 [pubspec.yaml Setup]
  wave-1 --> wave-2 [ParsedTransaction & Model Updates]
  wave-2 --> wave-3 [ReceiptScannerService Implementation & Wiring]
  wave-3 --> wave-4 [HomeScreen UI & ImagePicker Integration]
  wave-4 --> wave-5 [TransactionDraftBottomSheet & Fallback UI]
  wave-5 --> wave-6 [Localization & Heuristic Unit Tests]
```

---

## Tasks Checklist

- [ ] **Task 1: Update pubspec.yaml Dependencies**
  * **File:** `pubspec.yaml`
  * **Details:** Add `google_mlkit_text_recognition: ^0.13.0` to the `dependencies` section.
  * **Verification:** Run `flutter pub get` and ensure dependencies compile cleanly without conflicts.

- [ ] **Task 2: Extend ParsedTransaction Model**
  * **File:** `lib/services/models/parsed_transaction.dart`
  * **Details:** Add `bool isReceiptScan` and `bool scanConfidenceLow` fields (defaulting to `false`), update constructor.
  * **Verification:** Compile project to verify no breaking changes on other features.

- [ ] **Task 3: Implement ReceiptScannerService**
  * **File:** `lib/services/receipt_scanner_service.dart` [NEW]
  * **Details:** Create service interface and implementation. Use `google_mlkit_text_recognition`'s `TextRecognizer` to run OCR on-device. Extract total amount using keyword matching heuristics, extract the date using regex, extract the merchant name, and pass it to `TfliteTransactionParserService` to predict the category.
  * **Verification:** Write clean try-catch blocks and ensure the `TextRecognizer` is closed after use to prevent memory leaks.

- [ ] **Task 4: Wire ReceiptScannerService Provider**
  * **File:** `lib/services/service_providers.dart`
  * **Details:** Add `receiptScannerServiceProvider` wiring into `transactionParserServiceProvider`.
  * **Verification:** Compile to verify correct Riverpod dependency injection.

- [ ] **Task 5: Re-integrate Camera Button & Dialog in HomeScreen**
  * **File:** `lib/features/transactions/presentation/screens/home_screen.dart`
  * **Details:**
    * Add a camera button as a suffix icon inside the Smart Input bar, or next to it.
    * Tapping it launches a dialog asking for "Camera" or "Gallery".
    * Trigger `image_picker` to capture/select the image, then call the receipt scanner service.
  * **Verification:** Ensure the UI shows a glassmorphic loading spinner while processing the OCR.

- [ ] **Task 6: Add Fallback Warning Badge to Review Sheet**
  * **File:** `lib/features/transactions/presentation/widgets/transaction_draft_bottom_sheet.dart`
  * **Details:**
    * Detect if the draft represents a receipt scan with low confidence (`isReceiptScan` and `scanConfidenceLow`).
    * Display an amber colored warning box under the Amount field with text: *"Struk pudar? Yuk, bantu koreksi nominalnya."*
  * **Verification:** Inspect the UI when starting a draft with amount `0.0` or marked as low confidence.

- [ ] **Task 7: Add Multi-Language Translations**
  * **Files:** `assets/translations/id.json` and `assets/translations/en.json`
  * **Details:**
    * Add translations for `'bottom_sheet.ocr_low_confidence_warning'` -> `"Struk pudar? Yuk, bantu koreksi nominalnya."` (ID) and `"Receipt blurry? Help us correct the amount."` (EN).
    * Add other camera/gallery selection strings.
  * **Verification:** Run `flutter pub run easy_localization:generate` or test translations in-app.

- [ ] **Task 8: Write Unit Tests for Parser Heuristics**
  * **File:** `test/services/receipt_scanner_service_test.dart` [NEW]
  * **Details:** Mock OCR output strings (including common OCR noise, e.g., '1O.OOO' for prices, total keywords, merchant lines, dates) and verify the parsing service correctly extracts the amount, date, and merchant name.
  * **Verification:** Run `flutter test test/services/receipt_scanner_service_test.dart` and confirm all cases pass.
