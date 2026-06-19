import 'package:duasaku_app/core/domain/currency.dart';

/// Exchange rate service with offline fallback to hardcoded rates
///
/// In a real-world scenario, this would fetch from an API like:
/// - https://exchangerate-api.com (free tier 1500 requests/month)
/// - https://currencyapi.com
/// - https://openexchangerates.org
///
/// For this offline-first app, we use hardcoded approximate rates
/// relative to IDR as base currency.
class ExchangeRateService {
  /// Hardcoded exchange rates (1 unit of currency = X IDR)
  /// Updated: 2026-06-18 (approximate market rates)
  static const Map<String, double> _ratesFromIDR = {
    'IDR': 1.0,
    'USD': 15800.0,
    'EUR': 17200.0,
    'GBP': 20100.0,
    'JPY': 106.0,
    'SGD': 11700.0,
    'MYR': 3350.0,
    'THB': 445.0,
    'CNY': 2180.0,
    'AUD': 10500.0,
  };

  /// Convert amount from one currency to another
  ///
  /// Example:
  /// ```dart
  /// convert(100, from: 'USD', to: 'IDR') // returns 1580000.0
  /// convert(1000000, from: 'IDR', to: 'USD') // returns ~63.29
  /// ```
  double convert({
    required double amount,
    required String from,
    required String to,
  }) {
    if (from == to) return amount;

    final fromRate = _ratesFromIDR[from];
    final toRate = _ratesFromIDR[to];

    if (fromRate == null || toRate == null) {
      throw ArgumentError('Unsupported currency: $from or $to');
    }

    // Convert from -> IDR -> to
    final amountInIDR = amount * fromRate;
    return amountInIDR / toRate;
  }

  /// Get exchange rate between two currencies
  ///
  /// Returns: 1 [from] = X [to]
  double getRate({required String from, required String to}) {
    return convert(amount: 1.0, from: from, to: to);
  }

  /// Convert to base currency (IDR) for aggregation
  double toBaseCurrency({required double amount, required String from}) {
    return convert(amount: amount, from: from, to: 'IDR');
  }

  /// Check if currency is supported
  bool isSupported(String currencyCode) {
    return _ratesFromIDR.containsKey(currencyCode);
  }

  /// Get all supported currency codes
  List<String> get supportedCurrencies => _ratesFromIDR.keys.toList();

  /// Format amount with currency
  ///
  /// Example:
  /// ```dart
  /// formatAmount(1000000, 'IDR') // "Rp 1,000,000"
  /// formatAmount(100.50, 'USD') // "$100.50"
  /// ```
  String formatAmount(double amount, String currencyCode) {
    final currency = SupportedCurrencies.fromCode(currencyCode);
    if (currency == null) {
      return '$amount $currencyCode';
    }

    final formatted = _formatNumber(amount, currency.decimalDigits);

    // Symbol-first currencies (most Western currencies)
    if (currencyCode == 'USD' ||
        currencyCode == 'EUR' ||
        currencyCode == 'GBP' ||
        currencyCode == 'AUD' ||
        currencyCode == 'SGD') {
      return '${currency.symbol}$formatted';
    }

    // Symbol-last currencies (IDR, THB, MYR, etc.)
    return '${currency.symbol} $formatted';
  }

  String _formatNumber(double amount, int decimalDigits) {
    final parts = amount.toStringAsFixed(decimalDigits).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';

    // Add thousand separators
    final buffer = StringBuffer();
    var count = 0;
    for (var i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
      count++;
    }

    final formatted = buffer.toString().split('').reversed.join();

    if (decimalDigits > 0 && decPart.isNotEmpty) {
      return '$formatted.$decPart';
    }

    return formatted;
  }
}
