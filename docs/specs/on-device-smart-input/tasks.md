# Implementation Plan: Local Smart Input Engine

## Tasks

* [ ] **1. Core Utilities (Regex & Fuzzy Logic)**
  * [ ] 1.1 Create `lib/core/utils/amount_extractor.dart`
    * Implement class `AmountExtractor` and the static method `extractAmount(String input)` which returns an object/record containing `double amount` and `String textWithoutAmount`.
    * Ensure regex matches Indonesian patterns: raw digits, dots as thousands separators, currency prefixes (`Rp`, `Rp.`, `IDR`), and suffixes (`k`, `rb`, `ribu`, `jt`, `juta`).
    * *Requirements: 2.1, 2.2, 5.3*
  * [ ] 1.2 Create `lib/core/utils/fuzzy_matcher.dart`
    * Implement class `FuzzyMatcher` with static method `computeLevenshtein(String a, String b)` and `similarity(String a, String b)`.
    * *Requirements: 3.1*
  * [ ] 1.3 Create `lib/core/utils/text_sanitizer.dart`
    * Implement class `TextSanitizer` to handle stop-word removal, trim whitespace, and map words against `CategorySynonymDictionary` (e.g., "bensin" $\rightarrow$ "Transportasi").
    * Implement static helper to determine intent type (`income` or `expense`) using trigger dictionary.
    * *Requirements: 3.2, 3.4, 4.1, 4.2*

* [ ] **2. Service Layer Implementation**
  * [ ] 2.1 Create `lib/features/transactions/services/local_transaction_parser_service.dart`
    * Implement `TransactionParserServiceInterface` (or existing parser contract).
    * Inject `CategoryRepository` (via provider/constructor) to query available categories.
    * Build the pipeline: Extract Amount $\rightarrow$ Strip Amount for Notes $\rightarrow$ Classify Intent $\rightarrow$ Match Category (first via Synonym Dictionary, fallback to Levenshtein Fuzzy Similarity) $\rightarrow$ Return TransactionModel.
    * Default date to `DateTime.now()`.
    * *Requirements: 1.1, 1.2, 3.3, 5.1, 5.2, 5.4*

* [ ] **3. Riverpod Integration**
  * [ ] 3.1 Update `lib/features/transactions/providers/parser_provider.dart`
    * Modify the parser provider to supply `LocalTransactionParserService` instead of the previous Gemini implementation.
    * Inject `categoryRepositoryProvider` (or whatever repository is used to load category definitions).

* [ ] **4. Unit Testing**
  * [ ] 4.1 Create `test/core/utils/amount_extractor_test.dart`
    * Test various inputs: "25000", "25.000", "Rp25000", "Rp. 25.000", "IDR 25k", "makan 15rb", "gaji 5.5jt", "beli kopi 25000", and verifying amount extraction and correct text stripping.
  * [ ] 4.2 Create `test/core/utils/fuzzy_matcher_test.dart`
    * Test Levenshtein distance computations and similarity calculations (e.g., exact matches, partial matches, completely different strings).
  * [ ] 4.3 Create `test/features/transactions/services/local_transaction_parser_service_test.dart`
    * Test the full local parser service pipeline with mock categories. Verify category matching (via synonyms and fuzzy fallback), intent detection, notes sanitization, and date default.
  * [ ] 4.4 Run `flutter test` and verify that all tests pass.

## Task Dependency Graph
```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["3.1"] },
    { "id": 3, "tasks": ["4.1", "4.2", "4.3", "4.4"] }
  ]
}
```
