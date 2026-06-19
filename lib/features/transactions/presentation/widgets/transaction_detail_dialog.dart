import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/models/category_model.dart';
import '../../../wallets/domain/models/wallet_model.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import 'transaction_type_bottom_sheet.dart';

class TransactionDetailDialog extends ConsumerWidget {
  final TransactionModel transaction;
  final CategoryModel category;
  final List<WalletModel> wallets;

  const TransactionDetailDialog({
    super.key,
    required this.transaction,
    required this.category,
    required this.wallets,
  });

  static Future<void> show(
    BuildContext context, {
    required TransactionModel transaction,
    required CategoryModel category,
    required List<WalletModel> wallets,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => TransactionDetailDialog(
        transaction: transaction,
        category: category,
        wallets: wallets,
      ),
    );
  }



  Color _getCategoryColor(String? colorHex, String type) {
    if (colorHex == null || colorHex.isEmpty || colorHex == 'system') {
      return type == 'expense'
          ? const Color(0xFFF43F5E)
          : const Color(0xFF10B981);
    }
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return type == 'expense'
          ? const Color(0xFFF43F5E)
          : const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpense = transaction.type.toLowerCase() == 'expense';

    // Find matching wallet name
    final matchedWallet = wallets.cast<WalletModel?>().firstWhere(
      (w) => w?.id == transaction.walletId,
      orElse: () => null,
    );
    final walletName = matchedWallet?.name ?? 'Default Wallet';

    final currencyFormat = ref.watch(currencyFormatterProvider);

    final catColor = _getCategoryColor(category.color, transaction.type);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Material(
            color: Colors.transparent,
            child: GlassCard(
              enableBlur: false, // Dialog already blurred via BackdropFilter
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'transaction.detail_title'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: isDark ? Colors.white70 : Colors.black54,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Icon & Name
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          CategoryIconHelper.getIconData(category.icon),
                          color: catColor,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transaction.type.toUpperCase(),
                              style: TextStyle(
                                color: isExpense
                                    ? const Color(0xFFF43F5E)
                                    : const Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Amount
                  Center(
                    child: Text(
                      '${isExpense ? '-' : '+'}${currencyFormat.format(transaction.amount)}',
                      style: TextStyle(
                        color: isExpense
                            ? const Color(0xFFF43F5E)
                            : const Color(0xFF10B981),
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: isDark ? Colors.white10 : Colors.black12),
                  const SizedBox(height: 16),

                  // Info items
                  _buildDetailRow(
                    context,
                    icon: Icons.calendar_month_rounded,
                    label: 'transaction.date'.tr(),
                    value: DateFormat(
                      'EEEE, dd MMMM yyyy - HH:mm',
                      EasyLocalization.of(context)?.locale.languageCode,
                    ).format(transaction.createdAt),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'transaction.wallet'.tr(),
                    value: walletName,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    icon: Icons.notes_rounded,
                    label: 'transaction.notes'.tr(),
                    value: transaction.notes.isNotEmpty
                        ? transaction.notes
                        : 'transaction.no_notes'.tr(),
                    isItalic: transaction.notes.isEmpty,
                  ),

                  // Geofence Location (if present)
                  if (transaction.latitude != null &&
                      transaction.longitude != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      context,
                      icon: Icons.location_on_rounded,
                      label: 'transaction.location'.tr(),
                      value:
                          '${transaction.latitude!.toStringAsFixed(6)}, ${transaction.longitude!.toStringAsFixed(6)}',
                    ),
                  ],
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      // Edit Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop(); // pop dialog
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => TransactionTypeBottomSheet(
                                transaction: transaction,
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          label: Text('transaction.edit'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Delete Button
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF43F5E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                title: Text('transaction.delete_confirm_title'.tr()),
                                content: Text('transaction.delete_confirm_message'.tr()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: Text('transaction.delete_confirm_no'.tr()),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFF43F5E)),
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: Text('transaction.delete_confirm_yes'.tr()),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              if (context.mounted) {
                                Navigator.of(context).pop(); // pop dialog
                                
                                // Soft-delete with undo window
                                final deletedTx = await ref
                                    .read(transactionNotifierProvider.notifier)
                                    .softDeleteTransaction(transaction.id!);
                                
                                if (context.mounted && deletedTx != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('transaction.deleted'.tr()),
                                      duration: const Duration(seconds: 5),
                                      action: SnackBarAction(
                                        label: 'transaction.undo'.tr(),
                                        onPressed: () {
                                          ref
                                              .read(transactionNotifierProvider.notifier)
                                              .undoDelete();
                                        },
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_forever_rounded, size: 18),
                          label: Text('transaction.delete'.tr()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isItalic = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: isDark ? Colors.white30 : Colors.black38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black38,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
