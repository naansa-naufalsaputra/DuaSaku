/// ISO 4217 currency code with metadata
class Currency {
  final String code; // e.g., 'IDR', 'USD', 'EUR'
  final String symbol; // e.g., 'Rp', '$', '€'
  final String name; // e.g., 'Indonesian Rupiah'
  final int decimalDigits; // e.g., 0 for IDR, 2 for USD

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimalDigits,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// Supported currencies
class SupportedCurrencies {
  static const idr = Currency(
    code: 'IDR',
    symbol: 'Rp',
    name: 'Indonesian Rupiah',
    decimalDigits: 0,
  );

  static const usd = Currency(
    code: 'USD',
    symbol: '\$',
    name: 'US Dollar',
    decimalDigits: 2,
  );

  static const eur = Currency(
    code: 'EUR',
    symbol: '€',
    name: 'Euro',
    decimalDigits: 2,
  );

  static const gbp = Currency(
    code: 'GBP',
    symbol: '£',
    name: 'British Pound',
    decimalDigits: 2,
  );

  static const jpy = Currency(
    code: 'JPY',
    symbol: '¥',
    name: 'Japanese Yen',
    decimalDigits: 0,
  );

  static const sgd = Currency(
    code: 'SGD',
    symbol: 'S\$',
    name: 'Singapore Dollar',
    decimalDigits: 2,
  );

  static const myr = Currency(
    code: 'MYR',
    symbol: 'RM',
    name: 'Malaysian Ringgit',
    decimalDigits: 2,
  );

  static const thb = Currency(
    code: 'THB',
    symbol: '฿',
    name: 'Thai Baht',
    decimalDigits: 2,
  );

  static const cny = Currency(
    code: 'CNY',
    symbol: '¥',
    name: 'Chinese Yuan',
    decimalDigits: 2,
  );

  static const aud = Currency(
    code: 'AUD',
    symbol: 'A\$',
    name: 'Australian Dollar',
    decimalDigits: 2,
  );

  static const List<Currency> all = [
    idr,
    usd,
    eur,
    gbp,
    jpy,
    sgd,
    myr,
    thb,
    cny,
    aud,
  ];

  static Currency? fromCode(String code) {
    try {
      return all.firstWhere((c) => c.code == code);
    } catch (_) {
      return null;
    }
  }
}
