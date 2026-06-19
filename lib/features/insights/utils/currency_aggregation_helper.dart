import 'package:duasaku_app/core/services/exchange_rate_service.dart';
import 'package:duasaku_app/features/transactions/domain/models/transaction_model.dart';
import 'package:duasaku_app/features/wallets/domain/models/wallet_model.dart';

/// Helper for multi-currency aggregation in insights
class CurrencyAggregationHelper {
  final ExchangeRateService _exchangeRateService;

  CurrencyAggregationHelper(this._exchangeRateService);

  /// Convert transaction amount to base currency (IDR)
  double convertTransactionToBase(TransactionModel transaction) {
    return _exchangeRateService.toBaseCurrency(
      amount: transaction.amount,
      from: transaction.currency,
    );
  }

  /// Convert wallet balance to base currency (IDR)
  double convertWalletBalanceToBase(WalletModel wallet) {
    return _exchangeRateService.toBaseCurrency(
      amount: wallet.balance,
      from: wallet.currency,
    );
  }

  /// Sum transaction amounts in base currency
  double sumTransactionsInBase(List<TransactionModel> transactions) {
    return transactions.fold<double>(
      0.0,
      (sum, tx) => sum + convertTransactionToBase(tx),
    );
  }

  /// Sum wallet balances in base currency
  double sumWalletsInBase(List<WalletModel> wallets) {
    return wallets.fold<double>(
      0.0,
      (sum, wallet) => sum + convertWalletBalanceToBase(wallet),
    );
  }

  /// Format amount with currency symbol
  String formatAmount(double amount, String currencyCode) {
    return _exchangeRateService.formatAmount(amount, currencyCode);
  }

  /// Convert amount from base currency to target currency
  double convertFromBase(double amountInBase, String targetCurrency) {
    return _exchangeRateService.convert(
      amount: amountInBase,
      from: 'IDR',
      to: targetCurrency,
    );
  }
}
