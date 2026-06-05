# Requirements Document: Local Smart Input Engine (Level 1)

## Introduction
This spec outlines the implementation of a 100% offline, on-device text parsing engine for DuaSaku. It replaces the existing Gemini API dependency for parsing casual transaction input (e.g., "beli nasi padang 25k") by utilizing a hybrid approach of Regular Expressions (Regex) for amount extraction and Levenshtein distance (Fuzzy Logic) for category classification.

## Requirements

### Requirement 1: 100% Offline Execution
1. THE `LocalTransactionParserService` SHALL process all inputs locally on the device without any HTTP/network requests.
2. THE service SHALL execute synchronously or predictably fast (under 50ms) to ensure zero UI lag.

### Requirement 2: Robust Amount Extraction (Regex)
1. THE engine SHALL extract nominal amounts using Regex that supports Indonesian colloquial formats:
   - Pure numbers: "25000", "25.000"
   - Currency prefixes: "Rp25000", "Rp. 25.000", "IDR 25k"
   - 'k' suffix: "25k", "25 k" $\rightarrow$ 25000
   - 'rb'/'ribu' suffix: "25rb", "25 ribu" $\rightarrow$ 25000
   - 'jt'/'juta' suffix: "1.5jt", "2 juta" $\rightarrow$ 1500000, 2000000
2. IF multiple numbers exist in the string, THE engine SHALL prioritize the number accompanied by currency keywords or the largest logical nominal.

### Requirement 3: Fuzzy Logic Category Matching
1. THE engine SHALL implement the Levenshtein distance algorithm in pure Dart to match the transaction note against existing database categories.
2. THE engine SHALL strip stop-words (e.g., "beli", "bayar", "dapat", "buat") before performing category matching to increase accuracy.
3. IF the highest fuzzy match score is below a certain confidence threshold (e.g., < 60%), THE engine SHALL assign the transaction to a default "Umum" or "Lainnya" category.
4. THE engine SHALL utilize a predefined `CategorySynonymDictionary` mapping colloquial keywords (e.g., "bensin", "gojek", "pertalite" $\rightarrow$ "Transportasi"; "nasi", "kopi", "bakso" $\rightarrow$ "Makanan") BEFORE performing the fuzzy match against category names.

### Requirement 4: Intent Classification (Income vs Expense)
1. THE engine SHALL determine the transaction type (`income` or `expense`) based on a predefined dictionary of trigger words (e.g., "gaji", "dikasih", "refund" for income; "beli", "bayar", "jajan" for expense).
2. IF no trigger words are found, THE engine SHALL default to `expense`.

### Requirement 5: Interface Compliance
1. THE `LocalTransactionParserService` SHALL implement the existing `TransactionParserServiceInterface`.
2. THE output SHALL be a valid `TransactionModel` identical in structure to what the previous AI service produced.
3. THE engine SHALL populate the notes field of the `TransactionModel` using the sanitized original input string (e.g., stripping the extracted amount but keeping the contextual words).
4. THE engine SHALL NOT attempt to parse relative dates in Level 1; the date field of the `TransactionModel` SHALL default to the current timestamp (`DateTime.now()`).
