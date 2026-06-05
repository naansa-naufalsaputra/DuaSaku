import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplayNameNotifier extends Notifier<String> {
  static const String _prefKey = 'display_name';

  @override
  String build() {
    _loadPreference();
    return '';
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString(_prefKey);
      if (savedName != null && savedName.isNotEmpty) {
        state = savedName;
      }
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> setDisplayName(String name) async {
    state = name;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, name);
    } catch (e) {
      // Failed to save preference
    }
  }
}

final displayNameProvider = NotifierProvider<DisplayNameNotifier, String>(() {
  return DisplayNameNotifier();
});
