import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../../core/utils/math_parser.dart';

import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../services/models/parsed_transaction.dart';
import '../../providers/transaction_provider.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../providers/category_provider.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/providers/settings_provider.dart';

class TransactionDraftBottomSheet extends ConsumerStatefulWidget {
  final ParsedTransaction draftData;

  const TransactionDraftBottomSheet({super.key, required this.draftData});

  @override
  ConsumerState<TransactionDraftBottomSheet> createState() =>
      _TransactionDraftBottomSheetState();
}

class _TransactionDraftBottomSheetState
    extends ConsumerState<TransactionDraftBottomSheet> {
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  late String _type; // 'expense' or 'income'
  String? _selectedWalletId;
  String? _selectedCategoryName;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    // Initialize parsed states
    final double amount = widget.draftData.amount;
    _amountController = TextEditingController(
      text: amount > 0
          ? NumberFormat.decimalPattern('id_ID').format(amount.toInt())
          : '',
    );
    _notesController = TextEditingController(text: widget.draftData.notes);
    _type = widget.draftData.type;

    _selectedWalletId = widget.draftData.walletId;
    _selectedCategoryName = widget.draftData.categoryId;
    _selectedDate = widget.draftData.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _evaluateAmountField() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return;
    final result = MathParser.eval(text);
    if (result != null && result > 0) {
      final formatted = NumberFormat.decimalPattern(
        'id_ID',
      ).format(result.toInt());
      setState(() {
        _amountController.text = formatted;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty || _notesController.text.isEmpty) {
      HapticFeedback.vibrate();
      return;
    }

    final double amount = ThousandsFormatter.parse(_amountController.text);
    if (amount <= 0) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('amount_positive_warning'.tr())));
      return;
    }

    if (_selectedWalletId == null) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('bottom_sheet.no_wallet_warning'.tr())),
      );
      return;
    }

    try {
      HapticFeedback.mediumImpact();
      await ref
          .read(transactionNotifierProvider.notifier)
          .createTransaction(
            amount: amount,
            category: _selectedCategoryName ?? 'Food',
            type: _type,
            notes: _notesController.text.trim(),
            walletId: _selectedWalletId,
            createdAt: _selectedDate,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('transaction_saved_success'.tr())),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final walletsAsync = ref.watch(walletProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Colors.deepPurpleAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'bottom_sheet.review_ai_transaction'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Transaction Type Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _type = 'expense');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _type == 'expense'
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'bottom_sheet.expense'.tr().toUpperCase(),
                            style: TextStyle(
                              color: _type == 'expense'
                                  ? Colors.redAccent
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _type = 'income');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _type == 'income'
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'bottom_sheet.income'.tr().toUpperCase(),
                            style: TextStyle(
                              color: _type == 'income'
                                  ? Colors.green
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Amount Text Field
              Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    _evaluateAmountField();
                  }
                },
                child: GlassInputField(
                  controller: _amountController,
                  labelText: 'bottom_sheet.amount'.tr(),
                  keyboardType: TextInputType.text,
                  inputFormatters: [ThousandsFormatter()],
                  onEditingComplete: _evaluateAmountField,
                ),
              ),
              if (widget.draftData.isReceiptScan &&
                  widget.draftData.scanConfidenceLow) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'bottom_sheet.ocr_low_confidence_warning'.tr(),
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Notes Text Field
              GlassInputField(
                controller: _notesController,
                labelText: 'bottom_sheet.notes'.tr(),
                prefixIcon: const Icon(Icons.edit, size: 20),
              ),
              const SizedBox(height: 16),

              // Wallet Selection Dropdown
              walletsAsync.when(
                data: (wallets) {
                  if (wallets.isEmpty) {
                    return _buildNoWalletAlert(isDark);
                  }

                  // Preselect logic
                  final walletIds = wallets.map((w) => w.id).toList();
                  if (_selectedWalletId == null ||
                      !walletIds.contains(_selectedWalletId)) {
                    _selectedWalletId = walletIds.first;
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedWalletId,
                    dropdownColor: Theme.of(context).colorScheme.surface,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'bottom_sheet.wallet'.tr(),
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: isDark
                            ? BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              )
                            : const BorderSide(color: Colors.grey),
                      ),
                    ),
                    items: wallets.map((w) {
                      return DropdownMenuItem<String>(
                        value: w.id,
                        child: Text(
                          '${w.name} (${ref.watch(currencyFormatterProvider).format(w.balance)})',
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedWalletId = val);
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, stack) => Text('Failed to load wallets: $err'),
              ),
              const SizedBox(height: 16),

              // Date & Time Picker
              _buildDatePicker(context, isDark),
              const SizedBox(height: 16),

              // Category Selection Grid
              categoriesAsync.when(
                data: (categories) {
                  final filteredCategories = categories
                      .where((c) => c.type == _type)
                      .toList();
                  if (filteredCategories.isEmpty) {
                    return const Text(
                      'No categories available for this type. Please create one in settings.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    );
                  }

                  // Matching logic
                  final matchedCat = filteredCategories.firstWhere(
                    (c) =>
                        c.name.toLowerCase() ==
                        _selectedCategoryName?.toLowerCase(),
                    orElse: () {
                      // Fallback to closest match
                      final closest = filteredCategories.firstWhere(
                        (c) =>
                            c.name.toLowerCase().contains(
                              _selectedCategoryName?.toLowerCase() ?? 'food',
                            ) ||
                            (_selectedCategoryName?.toLowerCase() ?? 'food')
                                .contains(c.name.toLowerCase()),
                        orElse: () => filteredCategories.firstWhere(
                          (c) =>
                              c.name.toLowerCase() ==
                              (_type == 'income' ? 'salary' : 'food'),
                          orElse: () => filteredCategories.first,
                        ),
                      );
                      return closest;
                    },
                  );
                  _selectedCategoryName = matchedCat.name;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'bottom_sheet.category'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 2.3,
                              ),
                          itemCount: filteredCategories.length,
                          itemBuilder: (context, index) {
                            final cat = filteredCategories[index];
                            final isSelected =
                                _selectedCategoryName?.toLowerCase() ==
                                cat.name.toLowerCase();
                            final catColor = _getCategoryColor(
                              cat.color,
                              cat.type,
                            );

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(
                                  () => _selectedCategoryName = cat.name,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? catColor.withValues(alpha: 0.12)
                                      : (isDark
                                            ? Colors.white.withValues(
                                                alpha: 0.03,
                                              )
                                            : Colors.black.withValues(
                                                alpha: 0.02,
                                              )),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? catColor
                                        : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.08,
                                                )
                                              : Colors.black.withValues(
                                                  alpha: 0.05,
                                                )),
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: catColor.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: catColor.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        CategoryIconHelper.getIconData(
                                          cat.icon,
                                        ),
                                        color: catColor,
                                        size: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        cat.name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? (isDark
                                                    ? Colors.white
                                                    : Colors.black87)
                                              : (isDark
                                                    ? Colors.white54
                                                    : Colors.black54),
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, stack) => Text('Failed to load categories: $err'),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      variant: GlassButtonVariant.secondary,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.pop();
                      },
                      child: Text(
                        'cancel'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      onPressed: _saveTransaction,
                      child: Text(
                        'bottom_sheet.save_transaction'.tr(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoWalletAlert(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'bottom_sheet.no_wallet_warning'.tr(),
            style: TextStyle(
              color: isDark ? Colors.amber[200] : Colors.amber[800],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          GlassButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.pop();
              context.push('/manage-wallets');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_card, size: 16),
                const SizedBox(width: 8),
                Text('bottom_sheet.btn_create_wallet'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Widget _buildDatePicker(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(_selectedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'bottom_sheet.transaction_date'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDateTime,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_calendar_rounded,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ],
            ),
          ),
        ),
      ],
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
}
