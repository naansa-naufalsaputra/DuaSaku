import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/utils/thousands_formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../transactions/providers/category_provider.dart';
import '../../../wallets/domain/models/wallet_model.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../domain/models/frequency.dart';
import '../../domain/models/recurring_status.dart';
import '../../domain/models/recurring_transaction_model.dart';
import '../../domain/models/reminder_timing.dart';
import '../../domain/recurring_scheduler_logic.dart';
import '../../providers/recurring_transaction_provider.dart';

/// Bottom sheet with step-by-step flow for editing a recurring transaction.
///
/// Reuses the same flow as CreateRecurringBottomSheet but pre-fills all fields
/// with existing values. Updates the template without affecting historical
/// transactions.
class EditRecurringBottomSheet extends ConsumerStatefulWidget {
  final RecurringTransactionModel transaction;

  const EditRecurringBottomSheet({
    super.key,
    required this.transaction,
  });

  @override
  ConsumerState<EditRecurringBottomSheet> createState() =>
      _EditRecurringBottomSheetState();

  /// Show the edit bottom sheet.
  static Future<void> show(
    BuildContext context,
    RecurringTransactionModel transaction,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditRecurringBottomSheet(transaction: transaction),
    );
  }
}

enum _EditStep {
  amount,
  type,
  category,
  wallet,
  frequency,
  dates,
  preview,
  confirm,
}

class _EditRecurringBottomSheetState
    extends ConsumerState<EditRecurringBottomSheet>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  _EditStep _currentStep = _EditStep.amount;

  // Form state — pre-filled from existing transaction
  late final TextEditingController _amountController;
  String? _amountError;
  late String _transactionType;
  CategoryModel? _selectedCategory;
  String? _categoryError;
  WalletModel? _selectedWallet;
  String? _walletError;
  late Frequency _selectedFrequency;
  late int _customInterval;
  late DateTime _startDate;
  DateTime? _endDate;
  String? _dateError;
  String? _notes;
  late bool _notifyBefore;
  late ReminderTiming _reminderTiming;

  // Preview dates
  List<DateTime> _previewDates = [];

  // Success animation state
  bool _showSuccess = false;

  late final FixedExtentScrollController _frequencyWheelController;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;

    // Pre-fill form state from existing transaction
    _amountController = TextEditingController(
      text: NumberFormat.decimalPattern('id_ID').format(tx.amount.toInt()),
    );
    _transactionType = tx.type;
    _selectedFrequency = tx.frequency;
    _customInterval = tx.customInterval;
    _startDate = tx.startDate;
    _endDate = tx.endDate;
    _notes = tx.notes;
    _notifyBefore = tx.notifyBefore;
    _reminderTiming = tx.reminderTiming;

    _frequencyWheelController = FixedExtentScrollController(
      initialItem: Frequency.values.indexOf(_selectedFrequency),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-select category and wallet from existing transaction
    _preselectCategoryAndWallet();
  }

  void _preselectCategoryAndWallet() {
    final tx = widget.transaction;

    // Pre-select category
    final categoriesAsync = ref.read(categoryNotifierProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final matchingCategory = categories
        .where((c) => c.id == tx.categoryId)
        .toList();
    if (matchingCategory.isNotEmpty) {
      _selectedCategory = matchingCategory.first;
    }

    // Pre-select wallet
    final walletsAsync = ref.read(walletProvider);
    final wallets = walletsAsync.valueOrNull ?? [];
    final matchingWallet = wallets
        .where((w) => w.id == tx.walletId)
        .toList();
    if (matchingWallet.isNotEmpty) {
      _selectedWallet = matchingWallet.first;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _amountController.dispose();
    _frequencyWheelController.dispose();
    super.dispose();
  }

  void _goToStep(_EditStep step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step.index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextStep() {
    final nextIndex = _currentStep.index + 1;
    if (nextIndex < _EditStep.values.length) {
      _goToStep(_EditStep.values[nextIndex]);
    }
  }

  void _previousStep() {
    final prevIndex = _currentStep.index - 1;
    if (prevIndex >= 0) {
      _goToStep(_EditStep.values[prevIndex]);
    } else {
      Navigator.of(context).pop();
    }
  }

  bool _validateAmount() {
    final amount = ThousandsFormatter.parse(_amountController.text);
    if (amount <= 0) {
      setState(() => _amountError = 'recurring.error.invalid_amount'.tr());
      return false;
    }
    if (!RecurringSchedulerLogic.isValidAmount(amount)) {
      setState(() => _amountError = 'recurring.error.amount_bounds'.tr());
      return false;
    }
    setState(() => _amountError = null);
    return true;
  }

  bool _validateCategory() {
    if (_selectedCategory == null || _selectedCategory!.id == null) {
      setState(() => _categoryError = 'recurring.error.select_category'.tr());
      return false;
    }
    setState(() => _categoryError = null);
    return true;
  }

  bool _validateWallet() {
    if (_selectedWallet == null) {
      setState(() => _walletError = 'recurring.error.select_wallet'.tr());
      return false;
    }
    setState(() => _walletError = null);
    return true;
  }

  bool _validateDates() {
    // For edit, allow past start dates (transaction already exists)
    if (_endDate != null && _endDate!.isBefore(_startDate)) {
      setState(() => _dateError = 'recurring.error.end_before_start'.tr());
      return false;
    }
    setState(() => _dateError = null);
    return true;
  }

  void _computePreview() {
    _previewDates = RecurringSchedulerLogic.computePreviewDates(
      startDate: _startDate,
      frequency: _selectedFrequency,
      customInterval: _customInterval,
      count: 5,
      endDate: _endDate,
    );
  }

  /// Recalculate nextExecutionDate based on current frequency/start date.
  DateTime _computeNextExecutionDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // If start date is in the future, next execution is the start date
    if (_startDate.isAfter(today)) {
      return _startDate;
    }

    // Otherwise, compute the next date from now
    var current = _startDate;
    while (!current.isAfter(today)) {
      final next = RecurringSchedulerLogic.computeNextExecutionDate(
        currentExecutionDate: current,
        frequency: _selectedFrequency,
        customInterval: _customInterval,
        endDate: _endDate,
      );
      if (next == null) {
        // End date reached — return current as last valid
        return current;
      }
      current = next;
    }
    return current;
  }

  Future<void> _submit() async {
    final amount = ThousandsFormatter.parse(_amountController.text);

    // Determine status: if end date is in the past, mark as completed
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    RecurringStatus newStatus = widget.transaction.status;
    if (_endDate != null && _endDate!.isBefore(today)) {
      newStatus = RecurringStatus.completed;
    }

    // Recalculate nextExecutionDate on frequency/start date change
    DateTime newNextExecutionDate = widget.transaction.nextExecutionDate;
    final frequencyChanged =
        _selectedFrequency != widget.transaction.frequency;
    final intervalChanged =
        _customInterval != widget.transaction.customInterval;
    final startDateChanged = _startDate != widget.transaction.startDate;

    if (frequencyChanged || intervalChanged || startDateChanged) {
      newNextExecutionDate = _computeNextExecutionDate();
    }

    // If status is completed, keep nextExecutionDate as-is (or last valid)
    if (newStatus == RecurringStatus.completed) {
      // Keep the existing next execution date — it won't be used
      newNextExecutionDate = widget.transaction.nextExecutionDate;
    }

    final updatedModel = widget.transaction.copyWith(
      walletId: _selectedWallet!.id,
      categoryId: _selectedCategory!.id!,
      amount: amount,
      type: _transactionType,
      frequency: _selectedFrequency,
      customInterval: _customInterval,
      startDate: _startDate,
      endDate: () => _endDate,
      nextExecutionDate: newNextExecutionDate,
      status: newStatus,
      notes: () => _notes,
      notifyBefore: _notifyBefore,
      reminderTiming: _reminderTiming,
    );

    try {
      await ref
          .read(recurringTransactionNotifierProvider.notifier)
          .updateRecurring(updatedModel);
      if (!mounted) return;
      setState(() => _showSuccess = true);
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('recurring.error.update_failed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_showSuccess) {
      return _buildSuccessOverlay(colorScheme);
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              _buildHandle(colorScheme),
              _buildHeader(colorScheme),
              _buildStepIndicator(colorScheme),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildAmountStep(colorScheme, scrollController),
                    _buildTypeStep(colorScheme, scrollController),
                    _buildCategoryStep(colorScheme, scrollController),
                    _buildWalletStep(colorScheme, scrollController),
                    _buildFrequencyStep(colorScheme, scrollController),
                    _buildDatesStep(colorScheme, scrollController),
                    _buildPreviewStep(colorScheme, scrollController),
                    _buildConfirmStep(colorScheme, scrollController),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSuccessOverlay(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: Lottie.asset(
                'assets/animations/success.json',
                repeat: false,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'recurring.success_updated'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildHandle(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          if (_currentStep != _EditStep.amount)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _previousStep,
            ),
          Expanded(
            child: Text(
              'recurring.edit_title'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(_EditStep.values.length, (index) {
          final isActive = index <= _currentStep.index;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Step 1: Amount ─────────────────────────────────────────────────────────

  Widget _buildAmountStep(
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.step.amount_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'recurring.step.amount_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          GlassInputField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            hintText: '0',
            errorText: _amountError,
            onChanged: (_) {
              if (_amountError != null) setState(() => _amountError = null);
            },
          ),
          const SizedBox(height: 16),
          // Notes field
          GlassInputField(
            controller: TextEditingController(text: _notes),
            onChanged: (v) => _notes = v.isEmpty ? null : v,
            labelText: 'recurring.field.notes'.tr(),
          ),
          const SizedBox(height: 32),
          _buildNextButton(
            colorScheme,
            onPressed: () {
              if (_validateAmount()) _nextStep();
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  // ─── Step 2: Type ───────────────────────────────────────────────────────────

  Widget _buildTypeStep(
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.step.type_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 24),
          _buildTypeOption(
            colorScheme,
            label: 'recurring.type.expense'.tr(),
            icon: Icons.arrow_upward_rounded,
            value: 'expense',
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          _buildTypeOption(
            colorScheme,
            label: 'recurring.type.income'.tr(),
            icon: Icons.arrow_downward_rounded,
            value: 'income',
            color: Colors.green,
          ),
          const SizedBox(height: 32),
          _buildNextButton(colorScheme, onPressed: _nextStep),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildTypeOption(
    ColorScheme colorScheme, {
    required String label,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final isSelected = _transactionType == value;
    return GestureDetector(
      onTap: () => setState(() => _transactionType = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color
                : colorScheme.onSurface.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color),
          ],
        ),
      ),
    );
  }

  // ─── Step 3: Category ───────────────────────────────────────────────────────

  Widget _buildCategoryStep(
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final categories = (categoriesAsync.valueOrNull ?? [])
        .where((c) => c.type == _transactionType)
        .toList();

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.step.category_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (_categoryError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _categoryError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
              ),
            ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            Center(
              child: Text(
                'recurring.error.no_categories'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSelected = _selectedCategory?.id == cat.id;
                return ChoiceChip(
                  label: Text(cat.name),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = cat;
                      _categoryError = null;
                    });
                  },
                  selectedColor:
                      colorScheme.primary.withValues(alpha: 0.2),
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 32),
          _buildNextButton(
            colorScheme,
            onPressed: () {
              if (_validateCategory()) _nextStep();
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  // ─── Step 4: Wallet ─────────────────────────────────────────────────────────

  Widget _buildWalletStep(
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    final walletsAsync = ref.watch(walletProvider);
    final wallets = walletsAsync.valueOrNull ?? [];

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.step.wallet_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (_walletError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _walletError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
              ),
            ),
          const SizedBox(height: 16),
          if (wallets.isEmpty)
            Center(
              child: Text(
                'recurring.error.no_wallets'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
            )
          else
            ...wallets.map((wallet) {
              final isSelected = _selectedWallet?.id == wallet.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWallet = wallet;
                      _walletError = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface
                                .withValues(alpha: 0.08),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _walletIcon(wallet.type),
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                wallet.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                              Text(
                                wallet.type,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          const SizedBox(height: 32),
          _buildNextButton(
            colorScheme,
            onPressed: () {
              if (_validateWallet()) _nextStep();
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  IconData _walletIcon(String type) {
    return switch (type.toLowerCase()) {
      'bank' => Icons.account_balance_rounded,
      'e-wallet' => Icons.phone_android_rounded,
      'cash' => Icons.money_rounded,
      _ => Icons.wallet_rounded,
    };
  }

  // ─── Step 5: Frequency ──────────────────────────────────────────────────────

  Widget _buildFrequencyStep(
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.step.frequency_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'recurring.step.frequency_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          // Animated wheel picker for frequency
          SizedBox(
            height: 160,
            child: ListWheelScrollView.useDelegate(
              controller: _frequencyWheelController,
              itemExtent: 50,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedFrequency = Frequency.values[index];
                  if (_customInterval >
                      _selectedFrequency.maxInterval) {
                    _customInterval = 1;
                  }
                });
                HapticFeedback.selectionClick();
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: Frequency.values.length,
                builder: (context, index) {
                  final freq = Frequency.values[index];
                  final isSelected = freq == _selectedFrequency;
                  return Center(
                    child: Text(
                      freq.label.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: isSelected ? 22 : 16,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Custom interval
          Text(
            'recurring.field.interval'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: _customInterval > 1
                    ? () => setState(() => _customInterval--)
                    : null,
                icon:
                    const Icon(Icons.remove_circle_outline_rounded),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.onSurface
                          .withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$_customInterval',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _customInterval <
                        _selectedFrequency.maxInterval
                    ? () => setState(() => _customInterval++)
                    : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'recurring.interval_description'.tr(args: [
                '$_customInterval',
                _selectedFrequency.label.toLowerCase(),
              ]),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ),
          const SizedBox(height: 32),
          _buildNextButton(colorScheme, onPressed: _nextStep),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  // ─── Step 6: Dates ──────────────────────────────────────────────────────────

  Widget _buildDatesStep(
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.step.dates_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _dateError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
              ),
            ),
          const SizedBox(height: 24),
          // Start date — allow past dates for edit
          _buildDateTile(
            colorScheme,
            label: 'recurring.field.start_date'.tr(),
            date: _startDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2000),
                lastDate:
                    DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) {
                setState(() {
                  _startDate = picked;
                  _dateError = null;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          // End date (optional) — allow past dates for edit
          _buildDateTile(
            colorScheme,
            label: 'recurring.field.end_date'.tr(),
            date: _endDate,
            placeholder: 'recurring.field.no_end_date'.tr(),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate ??
                    _startDate.add(const Duration(days: 30)),
                firstDate: DateTime(2000),
                lastDate:
                    DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) {
                setState(() {
                  _endDate = picked;
                  _dateError = null;
                });
              }
            },
            onClear: _endDate != null
                ? () => setState(() => _endDate = null)
                : null,
          ),
          const SizedBox(height: 24),
          // Notification toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'recurring.field.notify_before'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _notifyBefore,
                      onChanged: (v) =>
                          setState(() => _notifyBefore = v),
                    ),
                  ],
                ),
                if (_notifyBefore) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReminderChip(
                          colorScheme,
                          label: 'recurring.reminder.same_day'.tr(),
                          value: ReminderTiming.sameDay,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildReminderChip(
                          colorScheme,
                          label:
                              'recurring.reminder.day_before'.tr(),
                          value: ReminderTiming.dayBefore,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildNextButton(
            colorScheme,
            onPressed: () {
              if (_validateDates()) {
                _computePreview();
                _nextStep();
              }
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildDateTile(
    ColorScheme colorScheme, {
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    String? placeholder,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date != null
                        ? _formatDate(date)
                        : (placeholder ?? '-'),
                    style:
                        Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  color:
                      colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 20,
                ),
                onPressed: onClear,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderChip(
    ColorScheme colorScheme, {
    required String label,
    required ReminderTiming value,
  }) {
    final isSelected = _reminderTiming == value;
    return GestureDetector(
      onTap: () => setState(() => _reminderTiming = value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }

  // ─── Step 7: Preview ────────────────────────────────────────────────────────

  Widget _buildPreviewStep(
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.step.preview_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'recurring.step.preview_subtitle'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          if (_previewDates.isEmpty)
            Center(
              child: Text(
                'recurring.preview.no_dates'.tr(),
                style:
                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
              ),
            )
          else
            ...List.generate(_previewDates.length, (index) {
              final date = _previewDates[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.onSurface
                          .withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDate(date),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(
                        delay: Duration(milliseconds: index * 80))
                    .slideX(begin: 0.05, end: 0),
              );
            }),
          const SizedBox(height: 32),
          _buildNextButton(colorScheme, onPressed: _nextStep),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  // ─── Step 8: Confirm ────────────────────────────────────────────────────────

  Widget _buildConfirmStep(
    ColorScheme colorScheme,
    ScrollController scrollController,
  ) {
    final amount = double.tryParse(
          _amountController.text.replaceAll(',', '.'),
        ) ??
        0;
    final isExpense = _transactionType == 'expense';

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'recurring.step.confirm_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 24),
          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  colorScheme,
                  label: 'recurring.summary.amount'.tr(),
                  value: 'Rp ${amount.toStringAsFixed(0)}',
                  valueColor: isExpense ? Colors.red : Colors.green,
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  colorScheme,
                  label: 'recurring.summary.type'.tr(),
                  value: _transactionType == 'expense'
                      ? 'recurring.type.expense'.tr()
                      : 'recurring.type.income'.tr(),
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  colorScheme,
                  label: 'recurring.summary.category'.tr(),
                  value: _selectedCategory?.name ?? '-',
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  colorScheme,
                  label: 'recurring.summary.wallet'.tr(),
                  value: _selectedWallet?.name ?? '-',
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  colorScheme,
                  label: 'recurring.summary.frequency'.tr(),
                  value: _customInterval == 1
                      ? _selectedFrequency.label
                      : '$_customInterval × ${_selectedFrequency.label}',
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  colorScheme,
                  label: 'recurring.summary.start_date'.tr(),
                  value: _formatDate(_startDate),
                ),
                if (_endDate != null) ...[
                  const Divider(height: 24),
                  _buildSummaryRow(
                    colorScheme,
                    label: 'recurring.summary.end_date'.tr(),
                    value: _formatDate(_endDate!),
                  ),
                ],
                if (_notifyBefore) ...[
                  const Divider(height: 24),
                  _buildSummaryRow(
                    colorScheme,
                    label: 'recurring.summary.reminder'.tr(),
                    value:
                        _reminderTiming == ReminderTiming.dayBefore
                            ? 'recurring.reminder.day_before'.tr()
                            : 'recurring.reminder.same_day'.tr(),
                  ),
                ],
                if (_notes != null && _notes!.isNotEmpty) ...[
                  const Divider(height: 24),
                  _buildSummaryRow(
                    colorScheme,
                    label: 'recurring.summary.notes'.tr(),
                    value: _notes!,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Save button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'recurring.action.save'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildSummaryRow(
    ColorScheme colorScheme, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
        ),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor ?? colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // ─── Shared Widgets ─────────────────────────────────────────────────────────

  Widget _buildNextButton(
    ColorScheme colorScheme, {
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'recurring.action.next'.tr(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
