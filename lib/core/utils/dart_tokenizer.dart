/// A robust, client-side tokenizer implemented in pure Dart.
///
/// Standardizes input text, filters punctuation matching Keras's default,
/// maps words to integer IDs using a loaded vocabulary, and handles
/// padding and truncation to `max_len`.
class DartTokenizer {
  /// The full list of vocabulary tokens.
  final List<String> vocabulary;

  /// Fast lookup map of word to vocabulary index.
  final Map<String, int> vocabMap;

  /// Fixed sequence length required by the model.
  final int maxLen;

  /// Dynamic ID for unknown Out-Of-Vocabulary (OOV) tokens.
  final int unkId;

  DartTokenizer({required this.vocabulary, required this.maxLen})
    : vocabMap = {for (var i = 0; i < vocabulary.length; i++) vocabulary[i]: i},
      unkId =
          {
            for (var i = 0; i < vocabulary.length; i++) vocabulary[i]: i,
          }['[UNK]'] ??
          1;

  /// Factory constructor to instantiate a tokenizer from parsed metadata JSON.
  factory DartTokenizer.fromJson(Map<String, dynamic> json) {
    final vocabList = List<String>.from(json['vocabulary'] as List);
    final maxLen = json['max_len'] as int? ?? 10;
    return DartTokenizer(vocabulary: vocabList, maxLen: maxLen);
  }

  /// Standardizes, tokenizes, and converts a raw text string into a list of token IDs.
  ///
  /// Matching Keras's standardization pipeline:
  /// 1. Converts input to lowercase.
  /// 2. Replaces Keras default punctuation filter characters with empty strings.
  /// 3. Splits by whitespace.
  /// 4. Maps tokens to their respective IDs (or [unkId] if unknown).
  /// 5. Pads with `0` (PAD) or truncates to exactly [maxLen].
  List<int> tokenize(String text) {
    // 1. Convert to lowercase
    String normalized = text.toLowerCase();

    // 2. Strip Keras default punctuation: !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
    final punctuationPattern = RegExp(
      r'[!"#$%&'
      "'"
      r'()*+,\-./:;<=>?@\[\\\]^_`{|}~]',
    );
    normalized = normalized.replaceAll(punctuationPattern, '');

    // 3. Split by whitespace and remove empty strings
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    // 4. Map words to ID using vocabMap dynamically
    final ids = tokens.map((token) => vocabMap[token] ?? unkId).toList();

    // 5. Pad or truncate to exactly maxLen
    if (ids.length < maxLen) {
      return ids + List<int>.filled(maxLen - ids.length, 0); // 0 is PAD
    } else {
      return ids.sublist(0, maxLen);
    }
  }
}
