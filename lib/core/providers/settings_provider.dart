import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

final currencySymbolProvider = NotifierProvider<CurrencySymbolNotifier, String>(() {
  return CurrencySymbolNotifier();
});

class CurrencySymbolNotifier extends Notifier<String> {
  static const _keyCurrency = 'global_currency_symbol';

  @override
  String build() {
    _loadFromPrefs();
    return 'Rp';
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyCurrency);
      if (saved != null) {
        state = saved;
      }
    } catch (e) {
      debugPrint('[CurrencySymbolNotifier] Error loading: $e');
    }
  }

  Future<void> setSymbol(String symbol) async {
    state = symbol;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrency, symbol);
    } catch (e) {
      debugPrint('[CurrencySymbolNotifier] Error saving: $e');
    }
  }
}

final currencyFormatterProvider = Provider<NumberFormat>((ref) {
  final symbol = ref.watch(currencySymbolProvider);
  return NumberFormat.currency(
    locale: 'id_ID',
    symbol: symbol.endsWith(' ') ? symbol : '$symbol ',
    decimalDigits: 0,
  );
});

final autoGeolocationProvider = NotifierProvider<AutoGeolocationNotifier, bool>(() {
  return AutoGeolocationNotifier();
});

class AutoGeolocationNotifier extends Notifier<bool> {
  static const _keyAutoGeolocate = 'settings_auto_geolocate';

  @override
  bool build() {
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_keyAutoGeolocate) ?? false;
    } catch (e) {
      debugPrint('[AutoGeolocationNotifier] Error loading: $e');
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoGeolocate, enabled);
    } catch (e) {
      debugPrint('[AutoGeolocationNotifier] Error saving: $e');
    }
  }
}
