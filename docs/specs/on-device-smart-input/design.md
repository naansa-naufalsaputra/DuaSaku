# Design Document: Local Smart Input Engine

## Architecture Overview
The solution moves the parsing logic from a remote AI endpoint to a local deterministic engine. It follows a pipeline pattern:
`Raw Text` $\rightarrow$ `Amount Extractor (Regex)` $\rightarrow$ `Sanitizer (Stop-word & Amount removal)` $\rightarrow$ `Intent Classifier` $\rightarrow$ `Category Matcher (Synonym Dictionary + Fuzzy Levenshtein)` $\rightarrow$ `TransactionModel`

## Components

### 1. `AmountExtractor` (Regex Utilities)
Uses Dart's `RegExp` to parse amounts.

**Key Patterns:**
* `(?:(?:Rp|rp|IDR|idr)\.?\s*)?(\d+(?:\.\d+)*)\s*(k|rb|ribu|jt|juta)?`
* **Logic:**
  1. Find all matches in the text.
  2. Parse the first/primary match's numeric group. Strip dot separators if they represent thousands separators (e.g. `25.000` $\rightarrow$ `25000`).
  3. Apply multipliers based on the suffix:
     - `k` / `rb` / `ribu` $\rightarrow$ `* 1000`
     - `jt` / `juta` $\rightarrow$ `* 1000000`
  4. Return the parsed `double` and the start/end indexes of the match to allow stripping it from the notes.

### 2. `FuzzyMatcher` (Levenshtein Distance)
A pure Dart implementation of the Levenshtein distance algorithm to compare two strings and return a similarity score (0.0 to 1.0).

```dart
int computeLevenshtein(String a, String b) {
  final s1 = a.toLowerCase().trim();
  final s2 = b.toLowerCase().trim();
  
  if (s1 == s2) return 0;
  if (s1.isEmpty) return s2.length;
  if (s2.isEmpty) return s1.length;
  
  final List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
  final List<int> v1 = List<int>.filled(s2.length + 1, 0);
  
  for (int i = 0; i < s1.length; i++) {
    v1[0] = i + 1;
    for (int j = 0; j < s2.length; j++) {
      final cost = s1.codeUnitAt(i) == s2.codeUnitAt(j) ? 0 : 1;
      v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
    }
    v0.setAll(0, v1);
  }
  return v0[s2.length];
}

int _min3(int a, int b, int c) {
  int min = a;
  if (b < min) min = b;
  if (c < min) min = c;
  return min;
}

double similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  final distance = computeLevenshtein(a, b);
  final maxLength = a.length > b.length ? a.length : b.length;
  return 1.0 - (distance / maxLength);
}
```

### 3. DictionaryEngine
Stores static maps of trigger words, stop words, and category synonyms:

* **Income Triggers:** `['gaji', 'bonus', 'dikasih', 'transferan', 'refund', 'pemasukan', 'sampingan', 'cuan']`
* **Expense Triggers:** `['beli', 'bayar', 'jajan', 'tagihan', 'langganan', 'pengeluaran', 'ongkos', 'sewa']`
* **Stop Words:** `['di', 'ke', 'dari', 'buat', 'untuk', 'hari', 'ini', 'pada', 'dengan', 'saya', 'aku']`
* **CategorySynonymDictionary:**
  Maps common colloquial keywords to standard database category names:
  ```dart
  static const Map<String, String> categorySynonyms = {
    // Transportasi
    'bensin': 'Transportasi',
    'pertalite': 'Transportasi',
    'pertamax': 'Transportasi',
    'gojek': 'Transportasi',
    'grab': 'Transportasi',
    'ojek': 'Transportasi',
    'parkir': 'Transportasi',
    'sepatu': 'Transportasi',
    // Makanan & Minuman
    'nasi': 'Makanan',
    'makan': 'Makanan',
    'kopi': 'Makanan',
    'bakso': 'Makanan',
    'indomie': 'Makanan',
    'jajan': 'Makanan',
    'resto': 'Makanan',
    'minum': 'Makanan',
    // Tagihan & Utilitas
    'listrik': 'Tagihan',
    'pln': 'Tagihan',
    'wifi': 'Tagihan',
    'pulsa': 'Tagihan',
    'kuota': 'Tagihan',
    'kos': 'Tagihan',
  };
  ```

### 4. LocalTransactionParserService
Implements `TransactionParserServiceInterface`.

**Pipeline Logic:**
1. **Extract Amount:** Call `AmountExtractor.extractAmount(text)`.
2. **Extract Notes (Catatan):** Take the original text, strip the matched amount substring (and excess whitespace), and sanitize it.
3. **Classify Intent:** Scan the sanitized text for Income/Expense triggers to determine the type. Default to `expense`.
4. **Match Category:**
   - Scan sanitized words against `CategorySynonymDictionary`.
   - If a synonym matches (e.g. "bensin" $\rightarrow$ "Transportasi"), search database categories for "Transportasi".
   - If no synonym matches directly, run `FuzzyMatcher.similarity()` of the sanitized text/words against all database category names.
   - If the similarity is above the threshold (60%), select the closest category.
   - Otherwise, default to "Umum" or the first available category.
5. **Return Model:** Create and return a `TransactionModel` with:
   - `amount`: parsed value (default to 0 if not found)
   - `notes`: extracted notes
   - `type`: parsed intent (`income` or `expense`)
   - `category`: matched category
   - `date`: `DateTime.now()`

## Provider Integration
The `transactionParserServiceProvider` will be updated to return `LocalTransactionParserService` instead of the Gemini implementation. This makes the UI completely unaware of the underlying logic change.
