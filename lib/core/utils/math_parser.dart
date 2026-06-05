import 'dart:core';

/// A lightweight, robust utility to safely parse and evaluate simple mathematical
/// expressions (supporting +, -, *, / and parentheses) fully offline.
class MathParser {
  /// Evaluates a simple mathematical expression. Returns null if invalid or fails.
  static double? eval(String expression) {
    // Sanitize input
    String sanitized = expression
        .replaceAll(RegExp(r'\s+'), '') // Remove whitespace
        .replaceAll('.', ''); // Remove thousand dots (IDR format)

    // Replace comma with dot if decimals are entered
    sanitized = sanitized.replaceAll(',', '.');

    // Only allow digits, decimals, and basic operators
    final validPattern = RegExp(r'^[0-9+\-*/().]+$');
    if (!validPattern.hasMatch(sanitized)) return null;

    try {
      return _evaluate(sanitized);
    } catch (_) {
      return null;
    }
  }

  static double _evaluate(String expression) {
    final tokens = _tokenize(expression);
    if (tokens.isEmpty) throw ArgumentError('Empty expression');

    final state = _ParserState(tokens);
    final result = state.parseAddSub();
    if (state.index < tokens.length) {
      throw ArgumentError('Unexpected tokens at end of expression');
    }
    return result;
  }

  static List<String> _tokenize(String expression) {
    final List<String> tokens = [];
    final length = expression.length;
    int i = 0;

    while (i < length) {
      final char = expression[i];
      if ('+-*/()'.contains(char)) {
        tokens.add(char);
        i++;
      } else if (RegExp(r'[0-9.]').hasMatch(char)) {
        final buffer = StringBuffer();
        while (i < length && RegExp(r'[0-9.]').hasMatch(expression[i])) {
          buffer.write(expression[i]);
          i++;
        }
        tokens.add(buffer.toString());
      } else {
        throw ArgumentError('Invalid character: $char');
      }
    }
    return tokens;
  }
}

class _ParserState {
  final List<String> tokens;
  int index = 0;

  _ParserState(this.tokens);

  double parsePrimary() {
    if (index >= tokens.length) {
      throw ArgumentError('Unexpected end of expression');
    }
    final token = tokens[index];
    if (token == '(') {
      index++; // consume '('
      final result = parseAddSub();
      if (index >= tokens.length || tokens[index] != ')') {
        throw ArgumentError('Missing closing parenthesis');
      }
      index++; // consume ')'
      return result;
    } else if (token == '-' &&
        index + 1 < tokens.length &&
        RegExp(r'[0-9.]').hasMatch(tokens[index + 1])) {
      // Negative primary number
      index++;
      final val = double.parse(tokens[index]);
      index++;
      return -val;
    } else {
      final val = double.parse(token);
      index++;
      return val;
    }
  }

  double parseMulDiv() {
    double left = parsePrimary();
    while (index < tokens.length) {
      final op = tokens[index];
      if (op == '*' || op == '/') {
        index++;
        final right = parsePrimary();
        if (op == '*') {
          left *= right;
        } else {
          if (right == 0) throw ArgumentError('Division by zero');
          left /= right;
        }
      } else {
        break;
      }
    }
    return left;
  }

  double parseAddSub() {
    double left = parseMulDiv();
    while (index < tokens.length) {
      final op = tokens[index];
      if (op == '+' || op == '-') {
        index++;
        final right = parseMulDiv();
        if (op == '+') {
          left += right;
        } else {
          left -= right;
        }
      } else {
        break;
      }
    }
    return left;
  }
}
