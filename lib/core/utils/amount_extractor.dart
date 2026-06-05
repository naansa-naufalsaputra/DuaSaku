class AmountExtractor {
  /// Regular expression to match Indonesian financial amounts.
  /// Group 1: Optional currency prefix (e.g., Rp, Rp., IDR).
  /// Group 2: The numeric value (digits, optionally separated by dots or commas).
  /// Group 3: Optional currency suffix (e.g., k, rb, ribu, jt, juta).
  static final RegExp _amountRegExp = RegExp(
    r'(?:([Rr][Pp]\.?|[Ii][Dd][Rr])\s*)?(\d+(?:[.,]\d+)*)(?:\s*([Kk]|[Rr][Bb]|[Rr][Ii][Bb][Uu]|[Jj][Tt]|[Jj][Uu][Tt][Aa])\b)?',
  );

  /// Extracts the transaction amount and returns the remaining text.
  ///
  /// Returns a record:
  /// - `amount`: the parsed numeric value (defaulting to 0.0 if not found).
  /// - `textWithoutAmount`: the input string with the matched amount substring removed
  ///   and whitespace normalized.
  static ({double amount, String textWithoutAmount}) extractAmount(
    String input,
  ) {
    if (input.trim().isEmpty) {
      return (amount: 0.0, textWithoutAmount: '');
    }

    final matches = _amountRegExp.allMatches(input).toList();
    if (matches.isEmpty) {
      return (amount: 0.0, textWithoutAmount: _normalizeWhitespace(input));
    }

    final List<_AmountMatch> candidateMatches = [];

    for (final match in matches) {
      final prefix = match.group(1);
      final numStr = match.group(2);
      final suffix = match.group(3);

      if (numStr == null) continue;

      final parsedValue = _parseNumber(numStr, suffix);
      if (parsedValue == 0.0) continue;

      candidateMatches.add(
        _AmountMatch(
          fullMatchText: match.group(0) ?? '',
          start: match.start,
          end: match.end,
          amount: parsedValue,
          hasPrefix: prefix != null && prefix.trim().isNotEmpty,
          hasSuffix: suffix != null && suffix.trim().isNotEmpty,
        ),
      );
    }

    if (candidateMatches.isEmpty) {
      return (amount: 0.0, textWithoutAmount: _normalizeWhitespace(input));
    }

    // Sort candidates:
    // 1. By score descending (prefix/suffix priority)
    // 2. By amount descending (largest logical nominal)
    candidateMatches.sort((a, b) {
      final scoreComparison = b.score.compareTo(a.score);
      if (scoreComparison != 0) return scoreComparison;
      return b.amount.compareTo(a.amount);
    });

    final bestMatch = candidateMatches.first;

    // Strip the best match from the original input
    final beforeMatch = input.substring(0, bestMatch.start);
    final afterMatch = input.substring(bestMatch.end);
    final cleanedText = _normalizeWhitespace('$beforeMatch $afterMatch');

    return (amount: bestMatch.amount, textWithoutAmount: cleanedText);
  }

  /// Parses the raw number string and applies suffix multipliers.
  static double _parseNumber(String numStr, String? suffix) {
    // Replace Indonesian decimal comma with dot
    String cleaned = numStr.replaceAll(',', '.');

    // Count dots in the string
    final dotCount = '.'.allMatches(cleaned).length;
    if (dotCount > 1) {
      // Multiple dots indicate thousands separators (e.g., 5.500.000)
      cleaned = cleaned.replaceAll('.', '');
    } else if (dotCount == 1) {
      // Single dot: check if it's a thousands separator (e.g., 25.000) or decimal (e.g., 1.5)
      final parts = cleaned.split('.');
      if (parts.length == 2 && parts[1].length == 3) {
        // Exactly 3 digits after the dot indicates thousands separator
        cleaned = cleaned.replaceAll('.', '');
      }
    }

    double value = double.tryParse(cleaned) ?? 0.0;

    // Apply multiplier based on suffix
    if (suffix != null) {
      final s = suffix.toLowerCase().trim();
      if (s == 'k' || s == 'rb' || s == 'ribu') {
        value *= 1000.0;
      } else if (s == 'jt' || s == 'juta') {
        value *= 1000000.0;
      }
    }

    return value;
  }

  /// Normalizes whitespace by replacing multiple spaces with a single space and trimming.
  static String _normalizeWhitespace(String str) {
    return str.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

/// Helper class to score and compare regex amount matches.
class _AmountMatch {
  final String fullMatchText;
  final int start;
  final int end;
  final double amount;
  final bool hasPrefix;
  final bool hasSuffix;

  const _AmountMatch({
    required this.fullMatchText,
    required this.start,
    required this.end,
    required this.amount,
    required this.hasPrefix,
    required this.hasSuffix,
  });

  /// Computes priority score for a match.
  double get score {
    double s = 0.0;
    if (hasPrefix) s += 100.0;
    if (hasSuffix) s += 50.0;
    if (amount >= 1000.0) s += 10.0;
    return s;
  }
}
