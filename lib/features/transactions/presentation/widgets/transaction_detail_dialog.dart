import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/models/category_model.dart';
import '../../../wallets/domain/models/wallet_model.dart';
import '../../../../core/widgets/glass/glass_card.dart';

class TransactionDetailDialog extends StatelessWidget {
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

  IconData _getIconData(String? name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'receipt':
        return Icons.receipt_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'electrical_services':
        return Icons.electrical_services_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'build':
        return Icons.build_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'payments':
        return Icons.payments_rounded;
      default:
        return Icons.category_rounded;
    }
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isExpense = transaction.type.toLowerCase() == 'expense';

    // Find matching wallet name
    final matchedWallet = wallets.cast<WalletModel?>().firstWhere(
      (w) => w?.id == transaction.walletId,
      orElse: () => null,
    );
    final walletName = matchedWallet?.name ?? 'Default Wallet';

    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

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
                          _getIconData(category.icon),
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

                  // Close button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white12 : Colors.black87,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('transaction.close'.tr()),
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
