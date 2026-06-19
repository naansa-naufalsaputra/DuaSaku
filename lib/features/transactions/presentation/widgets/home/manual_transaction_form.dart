import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../wallets/domain/models/wallet_model.dart';
import '../../../domain/models/category_model.dart';
import '../../../../../core/utils/thousands_formatter.dart';
import '../../../../../core/utils/category_icon_helper.dart';
import '../../../../../core/utils/category_translation.dart';
import '../../../../../core/widgets/glass/glass_button.dart';

class ManualTransactionForm extends StatelessWidget {
  final TextEditingController amountController;
  final TextEditingController notesController;
  final String activeCategory;
  final Function(String) onCategorySelected;
  final String? amountError;
  final String? categoryError;
  final String? selectedWalletId;
  final Function(String) onWalletSelected;
  final String transactionType;
  final List<WalletModel> wallets;
  final List<CategoryModel> categories;
  final bool recordLocation;
  final Function(bool) onRecordLocationChanged;
  final bool isFetchingLocation;
  final VoidCallback onSubmit;
  final String mathExpressionPreview;
  final Function(String) onAmountChanged;
  final VoidCallback onAmountFocusLost;
  final String currencySymbol;
  final Widget walletSelectorWidget;

  const ManualTransactionForm({
    super.key,
    required this.amountController,
    required this.notesController,
    required this.activeCategory,
    required this.onCategorySelected,
    required this.amountError,
    required this.categoryError,
    required this.selectedWalletId,
    required this.onWalletSelected,
    required this.transactionType,
    required this.wallets,
    required this.categories,
    required this.recordLocation,
    required this.onRecordLocationChanged,
    required this.isFetchingLocation,
    required this.onSubmit,
    required this.mathExpressionPreview,
    required this.onAmountChanged,
    required this.onAmountFocusLost,
    required this.currencySymbol,
    required this.walletSelectorWidget,
  });

  Color _getPastelColor(CategoryModel cat, int index) {
    if (cat.type == 'expense') {
      final colors = [
        const Color(0xFFF43F5E),
        const Color(0xFFF59E0B),
        const Color(0xFF007AFF),
      ];
      return colors[index % colors.length];
    } else {
      final colors = [
        const Color(0xFF22C55E),
        const Color(0xFF10B981),
        const Color(0xFF14B8A6),
      ];
      return colors[index % colors.length];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter categories by type
    final filteredCategories = categories
        .where((c) => c.type == transactionType)
        .toList();

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
            if (mathExpressionPreview.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                mathExpressionPreview,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),

        // Wallet Selector
        if (wallets.isEmpty)
          _buildEmptyWalletsCard(isDark)
        else ...[
          walletSelectorWidget,
          const SizedBox(height: 24),
        ],

        // Category Grid
        if (filteredCategories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              'bottom_sheet.category'.tr().toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: filteredCategories.length > 12
                ? 12
                : filteredCategories.length,
            itemBuilder: (context, index) {
              final cat = filteredCategories[index];
              final isSelected =
                  activeCategory.toLowerCase() == cat.name.toLowerCase();
              final catColor = _getPastelColor(cat, index);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onCategorySelected(cat.name);
                },
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: catColor.withValues(alpha: 0.12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF007AFF)
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: Icon(
                        CategoryIconHelper.getIconData(cat.icon),
                        color: catColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cat.name.toLocalizedCategory(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark ? Colors.white54 : Colors.black54),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
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
