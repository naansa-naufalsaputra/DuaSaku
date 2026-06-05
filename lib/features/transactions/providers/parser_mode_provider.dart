import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/parser_mode.dart';

class ParserModeNotifier extends Notifier<ParserMode> {
  static const String _prefKey = 'smart_input_parser_mode';

  @override
  ParserMode build() {
    _loadPreference();
    return ParserMode.auto;
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_prefKey);
      if (modeIndex != null && modeIndex >= 0 && modeIndex < ParserMode.values.length) {
        state = ParserMode.values[modeIndex];
      }
    } catch (e) {
      // Fail silently, fallback remains ParserMode.auto
    }
  }

  Future<void> setMode(ParserMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, mode.index);
    } catch (e) {
      // Failed to save preference
    }
  }
}

final parserModeProvider = NotifierProvider<ParserModeNotifier, ParserMode>(() {
  return ParserModeNotifier();
});
