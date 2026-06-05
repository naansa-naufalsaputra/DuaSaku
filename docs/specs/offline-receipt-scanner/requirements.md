# Requirements: Offline Receipt Scanner

## 1. Overview
We are implementing a 100% offline, on-device Receipt Scanner in `duasaku_app`. It allows users to take a photo of a shopping receipt (or select one from the gallery), perform optical character recognition (OCR) on-device using Google ML Kit, and extract transaction details (Total Amount, Date, and Merchant Name). The merchant name is then processed by our TFLite classifier to predict the transaction Category.

## 2. User Stories
* **As a user**, I want to tap a camera button, snap a picture of my paper receipt, and have the app automatically fill in the amount, category, date, and merchant notes offline without sending my data to any external server.
* **As a user**, if the receipt is blurry, folded, or faded, I want the app to still load my draft and warn me gently that I should check the amount, rather than crashing or showing a blank error.

## 3. Functional Requirements
* **Input Source:** Integrate an option to scan a receipt via the Home Screen.
  - Tapping the Scan button displays a selection dialog (Camera vs. Gallery) using `image_picker`.
* **OCR Text Extraction (Google ML Kit):**
  - Extract all text lines from the image on-device using `google_mlkit_text_recognition`.
* **Parsing & Heuristics Pipeline:**
  - **Amount Extraction:** Scan text lines for financial totals using targeted Indonesian/English keyword matching (e.g., *total, grand, netto, bayar, cash*). Grab the largest adjacent numeric value. Sanitize common OCR errors like letter 'O'/'o' read as zero.
  - **Date Extraction:** Search for date patterns (e.g., `dd/mm/yyyy`, `dd-mm-yyyy`, `dd MMMM yyyy`) in the text lines. If not found, fallback to the current system date (`DateTime.now()`).
  - **Merchant / Notes Extraction:** Attempt to identify the merchant name (typically found in the first few lines of the receipt). Clean up punctuation.
  - **Category Classification:** Feed the extracted merchant name into the existing Level 3 TFLite/TF-IDF classifier (`TfliteTransactionParserService`) to automatically determine the transaction Category.
* **UI Feedback & Fallbacks:**
  - While OCR processing runs in the background, display a premium glassmorphic loading overlay.
  - If OCR successfully finds an amount, open the `TransactionDraftBottomSheet` pre-populated with all extracted fields.
  - **Fallback Rule:** If OCR confidence is too low or no total amount is detected, open the `TransactionDraftBottomSheet` pre-populated with whatever details were found (notes, date), set the amount field to `0` (or empty), and display an amber warning badge stating: *"Struk pudar? Yuk, bantu koreksi nominalnya."*

## 4. Technical Constraints & Acceptance Criteria
* **Constraint 1:** 100% Offline execution. No cloud APIs, no network calls, no data transmission outside the device.
* **Constraint 2:** Responsive UI. The main thread must not block during OCR model loading or inference.
* **Acceptance Criteria 1:** Uploading a clear receipt image containing "Total: Rp 150.000" and merchant "Alfamart" must open the sheet with:
  - Amount: `150000`
  - Notes: "Alfamart"
  - Category: `Groceries` (or correct category predicted by TFLite)
* **Acceptance Criteria 2:** Uploading a blurry/unreadable image must gracefully open the sheet with Amount `0` (or empty), and show the amber warning badge.
