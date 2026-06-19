import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../wallets/domain/models/wallet_model.dart';
import '../../../../../core/utils/thousands_formatter.dart';
import '../../../../../core/widgets/glass/glass_button.dart';

class TransferTransactionForm extends StatelessWidget {
  final TextEditingController amountController;
  final TextEditingController notesController;
  final String? amountError;
  final List<WalletModel> wallets;
  final bool recordLocation;
  final Function(bool) onRecordLocationChanged;
  final bool isFetchingLocation;
  final VoidCallback onSubmit;
  final Function(String) onAmountChanged;
  final VoidCallback onAmountFocusLost;
  final String currencySymbol;
  final Widget fromWalletSelectorWidget;
  final Widget toWalletSelectorWidget;

  const TransferTransactionForm({
    super.key,
    required this.amountController,
    required this.notesController,
    required this.amountError,
    required this.wallets,
    required this.recordLocation,
    required this.onRecordLocationChanged,
    required this.isFetchingLocation,
    required this.onSubmit,
    required this.onAmountChanged,
    required this.onAmountFocusLost,
    required this.currencySymbol,
    required this.fromWalletSelectorWidget,
    required this.toWalletSelectorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Amount Input Zone
        Column(
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$currencySymbol ',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.black.withValues(alpha: 0.9),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 60,
                    maxWidth: 280,
                  ),
                  child: IntrinsicWidth(
                    child: Focus(
                      onFocusChange: (hasFocus) {
                        if (!hasFocus) {
                          onAmountFocusLost();
                        }
                      },
                      child: TextField(
                        controller: amountController,
                        keyboardType: TextInputType.text,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: const TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          errorText: amountError,
                          errorStyle: const TextStyle(height: 0),
                        ),
                        inputFormatters: [ThousandsFormatter()],
                        onChanged: onAmountChanged,
                        onEditingComplete: onAmountFocusLost,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),

        // Wallet Selectors (From -> To)
        if (wallets.isEmpty)
          _buildEmptyWalletsCard(isDark)
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              fromWalletSelectorWidget,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              toWalletSelectorWidget,
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Description/Notes Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notes_rounded,
                color: isDark ? Colors.white30 : Colors.black38,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: notesController,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'bottom_sheet.description_hint'.tr(),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black38,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Location Switcher
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: isDark ? Colors.white30 : Colors.black38,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'bottom_sheet.record_location'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              isFetchingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: recordLocation,
                      onChanged: onRecordLocationChanged,
                      activeThumbColor: const Color(0xFF007AFF),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Submit Button
        GlassButton(
          onPressed: onSubmit,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'bottom_sheet.save'.tr(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWalletsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        'bottom_sheet.no_wallet_warning'.tr(),
        style: const TextStyle(color: Colors.redAccent),
        textAlign: TextAlign.center,
      ),
    );
  }
}
