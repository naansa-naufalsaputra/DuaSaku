class MathPreviewParser {
  /// Cleans the input from currency symbols, spaces, and regional separators.
  static String sanitizeExpression(String input, String currencySymbol) {
    String clean = input.replaceAll(' ', '');
    
    // Remove known currency symbols
    clean = clean.replaceAll(currencySymbol, '');
    clean = clean
        .replaceAll('Rp', '')
        .replaceAll(r'$', '')
        .replaceAll('€', '')
        .replaceAll('¥', '')
        .replaceAll('£', '');

    // Standardize regional decimal/thousand formats
    if (currencySymbol.trim() == 'Rp') {
      // Indonesian format: dot is thousand separator, comma is decimal
      clean = clean.replaceAll('.', '');
      clean = clean.replaceAll(',', '.');
    } else {
      // Standard format: comma is thousand separator, dot is decimal
      clean = clean.replaceAll(',', '');
    }
    return clean;
  }

  /// Checks if the input expression contains any basic mathematical operator.
  static bool hasOperators(String text) {
    final operatorRegex = RegExp(r'[+\-*/]');
    return operatorRegex.hasMatch(text);
  }

  /// Evaluates the basic math expression with order of operations (MDAS).
  static double? evaluate(String expression) {
    try {
      // Keep only numbers, decimals, and basic math operators
      final cleanExpr = expression.replaceAll(RegExp(r'[^0-9.+\-*/]'), '');
      if (cleanExpr.isEmpty) return null;

      // Tokenize: group numbers/decimals or operator chars
      final regex = RegExp(r'(\d+\.?\d*)|([+\-*/])');
      final matches = regex.allMatches(cleanExpr);
      final tokens = <String>[];
      
      for (final match in matches) {
        tokens.add(match.group(0)!);
      }

      if (tokens.isEmpty) return null;

      // If expression ends with a trailing operator, drop it to evaluate what has been typed so far
      if (RegExp(r'[+\-*/]').hasMatch(tokens.last)) {
        tokens.removeLast();
      }

      if (tokens.isEmpty) return null;

      // Pass 1: Multiplication and Division
      int i = 0;
      while (i < tokens.length) {
        if (tokens[i] == '*' || tokens[i] == '/') {
          if (i == 0 || i == tokens.length - 1) return null;
          final left = double.tryParse(tokens[i - 1]);
          final right = double.tryParse(tokens[i + 1]);
          if (left == null || right == null) return null;

          double result = 0.0;
          if (tokens[i] == '*') {
            result = left * right;
          } else {
            if (right == 0) return null; // Prevent division by zero
            result = left / right;
          }

          tokens.replaceRange(i - 1, i + 2, [result.toString()]);
          i--;
        } else {
          i++;
        }
      }

      // Pass 2: Addition and Subtraction
      i = 0;
      while (i < tokens.length) {
        if (tokens[i] == '+' || tokens[i] == '-') {
          if (i == 0 || i == tokens.length - 1) return null;
          final left = double.tryParse(tokens[i - 1]);
          final right = double.tryParse(tokens[i + 1]);
          if (left == null || right == null) return null;

          double result = 0.0;
          if (tokens[i] == '+') {
            result = left + right;
          } else {
            result = left - right;
          }

          tokens.replaceRange(i - 1, i + 2, [result.toString()]);
          i--;
        } else {
          i++;
        }
      }

      if (tokens.length == 1) {
        return double.tryParse(tokens.first);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
