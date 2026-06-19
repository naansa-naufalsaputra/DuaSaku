import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duasaku_app/core/providers/exchange_rate_provider.dart';
import '../utils/currency_aggregation_helper.dart';

/// Provider for currency aggregation helper
final currencyAggregationHelperProvider = Provider<CurrencyAggregationHelper>((
  ref,
) {
  final exchangeRateService = ref.watch(exchangeRateServiceProvider);
  return CurrencyAggregationHelper(exchangeRateService);
});
