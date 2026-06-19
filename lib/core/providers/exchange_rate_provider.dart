import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duasaku_app/core/services/exchange_rate_service.dart';

/// Provider for exchange rate service (singleton)
final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return ExchangeRateService();
});
