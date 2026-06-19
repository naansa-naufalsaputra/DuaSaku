import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'math_parser.dart';

/// A custom [TextInputFormatter] that formats numeric input with thousands separators
/// automatically as the user types, using the Indonesian locale format (e.g. 1.000.000).
class ThousandsFormatter extends TextInputFormatter {
  static final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  /// Formats a number with thousands separators using the Indonesian locale format.
  static String format(num value) {
    return _formatter.format(value);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // If the input contains math operators or parentheses, bypass thousands formatting
    // to allow freeform typing of the expression.
    final hasOperators = RegExp(r'[+\-*/()]').hasMatch(newValue.text);
    if (hasOperators) {
      return newValue;
    }

    // Only allow numeric characters
    final cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    try {
      final int numValue = int.parse(cleanText);
      final String formatted = _formatter.format(numValue);

      return newValue.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } catch (e) {
      return oldValue;
    }
  }

  /// Helper to convert a formatted text string back to a double value
  static double parse(String text) {
    if (text.isEmpty) return 0.0;
    // Check if the text is a math expression that needs evaluation
    final double? evalResult = MathParser.eval(text);
    if (evalResult != null) return evalResult;

    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0.0;
  }
}
