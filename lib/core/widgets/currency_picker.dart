import 'package:flutter/material.dart';
import 'package:duasaku_app/core/domain/currency.dart';

/// Currency picker bottom sheet
///
/// Shows list of supported currencies with flag emoji, symbol, and name.
/// Returns selected Currency object.
class CurrencyPicker extends StatelessWidget {
  final String? selectedCurrencyCode;

  const CurrencyPicker({super.key, this.selectedCurrencyCode});

  static Future<Currency?> show(
    BuildContext context, {
    String? selectedCurrencyCode,
  }) {
    return showModalBottomSheet<Currency>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          CurrencyPicker(selectedCurrencyCode: selectedCurrencyCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Select Currency',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Currency list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: SupportedCurrencies.all.length,
              itemBuilder: (context, index) {
                final currency = SupportedCurrencies.all[index];
                final isSelected = currency.code == selectedCurrencyCode;

                return ListTile(
                  leading: Text(
                    _getFlagEmoji(currency.code),
                    style: const TextStyle(fontSize: 32),
                  ),
                  title: Text(
                    '${currency.symbol} ${currency.code}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: Text(currency.name),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, currency),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getFlagEmoji(String currencyCode) {
    // Map currency codes to country flag emojis
    const flags = {
      'IDR': '🇮🇩',
      'USD': '🇺🇸',
      'EUR': '🇪🇺',
      'GBP': '🇬🇧',
      'JPY': '🇯🇵',
      'SGD': '🇸🇬',
      'MYR': '🇲🇾',
      'THB': '🇹🇭',
      'CNY': '🇨🇳',
      'AUD': '🇦🇺',
    };
    return flags[currencyCode] ?? '💱';
  }
}
