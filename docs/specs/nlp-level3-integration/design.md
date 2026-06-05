# Design Document: Level 3 Joint NLP Model Integration

## Component Architecture

The integration will introduce a new parser service leveraging an on-device TensorFlow Lite model. The pipeline is as follows:

```
[Raw User Input]
      │
      ▼
[DartTokenizer]
      │  (Lowercase, Strip Punctuation, Map to IDs, Pad/Truncate)
      ▼
[Token IDs (1x10)]
      │
      ▼
[TfliteTransactionParserService]
      │  (Invoke Interpreter)
      ├───► [Intent Tensor (1x1)] ────► Sigmoid (>0.5? Income : Expense)
      ├───► [Category Tensor (1x6)] ──► Argmax ──► Category Name (category_map)
      └───► [NER Tensor (1x10x6)] ────► Argmax per token ──► Extract Amount & Notes
      │
      ▼
[ParsedTransaction]
```

---

## 1. Class Definitions

### 1.1 `TransactionParserServiceInterface`
An abstract interface to decouples the callers from the concrete parser implementation.

```dart
abstract class TransactionParserServiceInterface {
  Future<ParsedTransaction> parseTransaction({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  });
}
```

### 1.2 `DartTokenizer`
Loads vocabulary mapping and handles standardization, word-to-ID mapping, padding, and truncation.

```dart
class DartTokenizer {
  final List<String> vocabulary;
  final Map<String, int> vocabMap;
  final int maxLen;

  DartTokenizer({
    required this.vocabulary,
    required this.maxLen,
  }) : vocabMap = {for (var i = 0; i < vocabulary.length; i++) vocabulary[i]: i};

  factory DartTokenizer.fromJson(Map<String, dynamic> json) {
    final vocab = List<String>.from(json['vocabulary'] as List);
    final maxLen = json['max_len'] as int? ?? 10;
    return DartTokenizer(vocabulary: vocab, maxLen: maxLen);
  }

  List<int> tokenize(String text) {
    // 1. Lowercase
    String normalized = text.toLowerCase();
    
    // 2. Strip punctuation perfectly matching Keras: [!"#$%&'()*+,-./:;<=>?@[\]^_`{|}~]
    // Note that we escape the special chars properly
    final punctuationPattern = RegExp(r'[!"#$%&' + "'" + r'()*+,\-./:;<=>?@\[\\\]^_`{|}~]');
    normalized = normalized.replaceAll(punctuationPattern, '');

    // 3. Split by whitespace
    final tokens = normalized.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    // 4. Map words to ID using vocabMap dynamically
    final unkId = vocabMap['[UNK]'] ?? 1; // Fallback to 1
    final ids = tokens.map((token) => vocabMap[token] ?? unkId).toList();

    // 5. Pad or truncate
    if (ids.length < maxLen) {
      return ids + List<int>.filled(maxLen - ids.length, 0); // 0 is PAD
    } else {
      return ids.sublist(0, maxLen);
    }
  }
}
```

### 1.3 `TfliteTransactionParserService`
Manages the lifecycle of the TFLite Interpreter and executes joint predictions.

```dart
class TfliteTransactionParserService implements TransactionParserServiceInterface {
  Interpreter? _interpreter;
  Map<String, dynamic>? _metadata;
  DartTokenizer? _tokenizer;

  Future<void> initialize() async {
    // Load metadata.json
    final metadataString = await rootBundle.loadString('assets/ml/metadata.json');
    _metadata = json.decode(metadataString) as Map<String, dynamic>;
    _tokenizer = DartTokenizer.fromJson(_metadata!);

    // Load TFLite Model
    _interpreter = await Interpreter.fromAsset('ml/duasaku_level3.tflite');
  }

  @override
  Future<ParsedTransaction> parseTransaction({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) async {
    if (_interpreter == null) await initialize();
    
    // Process input
    final inputIds = _tokenizer!.tokenize(inputText);
    final input = [inputIds]; // Shape: [1, max_len]

    // Pre-allocate outputs dynamically based on tensor shapes
    final outputTensors = _interpreter!.getOutputTensors();
    final outputs = <int, Object>{};
    
    int? intentIdx, categoryIdx, nerIdx;
    
    for (int i = 0; i < outputTensors.length; i++) {
      final shape = outputTensors[i].shape;
      if (shape.length == 2 && shape[1] == 1) {
        outputs[i] = List.generate(1, (_) => List.filled(1, 0.0));
        intentIdx = i;
      } else if (shape.length == 2 && shape[1] > 1) {
        outputs[i] = List.generate(1, (_) => List.filled(shape[1], 0.0));
        categoryIdx = i;
      } else if (shape.length == 3) {
        outputs[i] = List.generate(1, (_) => List.generate(shape[1], (_) => List.filled(shape[2], 0.0)));
        nerIdx = i;
      }
    }

    // Run interpreter
    _interpreter!.runForMultipleInputs([input], outputs);

    // 1. Decode Intent
    final intentProb = (outputs[intentIdx] as List<List<double>>)[0][0];
    final String type = intentProb > 0.5 ? 'income' : 'expense';

    // 2. Decode Category
    final categoryProbs = (outputs[categoryIdx] as List<List<double>>)[0];
    int bestCatIdx = 0;
    double maxCatProb = -1.0;
    for (int i = 0; i < categoryProbs.length; i++) {
      if (categoryProbs[i] > maxCatProb) {
        maxCatProb = categoryProbs[i];
        bestCatIdx = i;
      }
    }
    final categoryMap = _metadata!['category_map'] as Map<String, dynamic>;
    final String parsedCategory = categoryMap[bestCatIdx.toString()] as String? ?? 'Food';

    // 3. Decode NER
    // PENTING: Gunakan rawTokens untuk mempertahankan titik/koma pada angka
    final rawTokens = inputText.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    final nerOutput = (outputs[nerIdx] as List<List<List<double>>>)[0]; // max_len x num_ner_tags
    final nerMap = _metadata!['ner_map'] as Map<String, dynamic>;

    final amountTokens = <String>[];
    final noteTokens = <String>[];

    for (int i = 0; i < rawTokens.length; i++) {
      if (i >= _tokenizer!.maxLen) break;
      
      final tagProbs = nerOutput[i];
      int bestTagIdx = 0;
      double maxTagProb = -1.0;
      for (int j = 0; j < tagProbs.length; j++) {
        if (tagProbs[j] > maxTagProb) {
          maxTagProb = tagProbs[j];
          bestTagIdx = j;
        }
      }

      final String tagName = nerMap[bestTagIdx.toString()] as String? ?? 'O';
      if (tagName == 'B-AMOUNT' || tagName == 'I-AMOUNT') {
        amountTokens.add(rawTokens[i]);
      } else if (tagName == 'B-NOTE' || tagName == 'I-NOTE') {
        noteTokens.add(rawTokens[i]);
      }
    }

    // Extracted Amount parsing
    double amount = 0.0;
    if (amountTokens.isNotEmpty) {
      final amountStr = amountTokens.join(' ');
      // Parse utilizing standard multipliers if present (e.g. k, jt, rb)
      amount = _parseExtractedAmount(amountStr);
    }

    final String parsedNotes = noteTokens.isNotEmpty ? noteTokens.join(' ') : inputText;

    // Optional: Match Wallet if mentioned in the input text
    // (Similar to Level 1, checking tokens against the wallet names/types)
    String? matchedWalletId;
    for (final wallet in wallets) {
      if (inputText.toLowerCase().contains(wallet.name.toLowerCase())) {
        matchedWalletId = wallet.id;
        break;
      }
    }

    return ParsedTransaction(
      amount: amount,
      category: parsedCategory,
      type: type,
      walletId: matchedWalletId,
      notes: parsedNotes,
    );
  }

  double _parseExtractedAmount(String str) {
    // Implement clean amount extraction parser with multipliers
    // Clean spaces and dots
    String cleaned = str.replaceAll(' ', '').replaceAll('.', '').toLowerCase();
    
    // Regex for number and suffix
    final match = RegExp(r'(\d+(?:,\d+)?)(k|rb|ribu|jt|juta)?').firstMatch(cleaned);
    if (match == null) return 0.0;

    final numStr = match.group(1)!.replaceAll(',', '.');
    double value = double.tryParse(numStr) ?? 0.0;

    final suffix = match.group(2);
    if (suffix != null) {
      if (suffix == 'k' || suffix == 'rb' || suffix == 'ribu') {
        value *= 1000;
      } else if (suffix == 'jt' || suffix == 'juta') {
        value *= 1000000;
      }
    }
    return value;
  }
}
```

---

## 2. Integration and Provider Wiring

To align with dependency injection and clean architecture rules:

1. `lib/services/service_providers.dart` will declare `transactionParserServiceProvider` as returning `TransactionParserServiceInterface`.
2. Existing `TransactionParserService` (Level 1) will implement `TransactionParserServiceInterface`.
3. The provider will be wired to return an instance of `TfliteTransactionParserService` initialized with the TFLite assets.
