# Requirements: Level 4 Hybrid Parser Pipeline

## 1. Overview
We are implementing a Level 4 Hybrid Parser Pipeline in `duasaku_app` that utilizes Google ML Kit's on-device translation and entity extraction. This builds upon our existing financial transaction parser (TF Lite + Local Regex/Fuzzy) by adding dynamic, natural date and time extraction from Indonesian text inputs.

## 2. User Stories
* **As a user**, I want to type natural text inputs like *"beli bensin kemarin sore 50rb"* or *"gajian tadi pagi 5jt"* in the Smart Input bar, and have the app automatically detect the correct date/time (e.g., yesterday afternoon or this morning) in the transaction draft.
* **As a user**, I want the app to start quickly and not block me with loading screens for downloading ML models. These models should download silently in the background.

## 3. Functional Requirements
* **Input Integration:** The dynamic date/time extraction must be integrated directly into the main transaction Smart Input text bar on the Home Screen.
* **Sequential Parser Execution Flow:**
  1. **Financial Parsing (TFLite/Regex):** Extract amount, intent type, wallet, and category. Remove financial slang tokens (e.g., "50rb", "goceng", "Rp 100.000") to avoid confusing the translation model.
  2. **Translation Bridge:** Pass the remaining clean text to `google_mlkit_translation` to translate it from Indonesian to English.
  3. **Entity Extraction:** Pass the translated English text to `google_mlkit_entity_extraction` to extract temporal entities (date and time) using the current date as the reference time.
  4. **Fallback:** If no temporal entity is found, if the models fail to initialize, or if translation fails, fallback to `DateTime.now()` gracefully.
* **Model Downloading:** Initialize downloads silently in the background on app startup. No UI-blocking loaders or splash screens.
* **Date UI Propagation:** Update `ParsedTransaction` to support a `date` field. Propagate this date to the review bottom sheet (`TransactionDraftBottomSheet`) and save it in the database when the transaction is confirmed.

## 4. Technical Constraints & Acceptance Criteria
* **Acceptance Criteria 1:** Input *"makan sate kemarin malam 75k"* must extract:
  - Amount: `75000.0`
  - Date: Yesterday evening (e.g., 20:00 or general evening hour)
  - Category: `Food` (based on synonym/TFLite)
  - Notes: *"makan sate"*
* **Acceptance Criteria 2:** If the user is offline or the models are not yet downloaded, the pipeline must still function using the regex parser and default to `DateTime.now()` without crash or delay.
* **Acceptance Criteria 3:** App size and download management should handle model preparation gracefully without locking the main thread.
