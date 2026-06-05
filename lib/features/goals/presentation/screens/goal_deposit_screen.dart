import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../domain/models/goal_model.dart';
import '../../providers/goal_provider.dart';

/// Modal bottom sheet for adding a deposit to a financial goal.
///
/// Displays the remaining amount needed to reach the target, an amount input
/// field with validation, an optional note field, and a submit button.
class GoalDepositScreen extends ConsumerStatefulWidget {
  final GoalModel goal;

  const GoalDepositScreen({super.key, required this.goal});

  /// Shows this screen as a modal bottom sheet.
  static Future<void> show(BuildContext context, GoalModel goal) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => GoalDepositScreen(goal: goal),
    );
  }

  @override
  ConsumerState<GoalDepositScreen> createState() => _GoalDepositScreenState();
}

class _GoalDepositScreenState extends ConsumerState<GoalDepositScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _amountError;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  double get _remainingAmount =>
      widget.goal.targetAmount - widget.goal.currentAmount;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Manual validation
    setState(() {
      if (_amountController.text.trim().isEmpty) {
        _amountError = 'goals.validation_deposit_invalid'.tr();
      } else {
        final parsed = ThousandsFormatter.parse(_amountController.text);
        if (parsed <= 0) {
          _amountError = 'goals.validation_deposit_invalid'.tr();
        } else {
          _amountError = null;
        }
      }
    });

    if (_amountError != null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final amount = ThousandsFormatter.parse(_amountController.text);
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    final result = await ref
        .read(goalNotifierProvider.notifier)
        .addDeposit(widget.goal.id, amount, note: note);

    if (!mounted) return;

    switch (result) {
      case Success():
        await HapticFeedback.mediumImpact();
        if (mounted) {
          Navigator.of(context).pop();
        }
      case Failure(:final error):
        setState(() {
          _isSubmitting = false;
          _errorMessage = error.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'goals.deposit_title'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Remaining amount info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'goals.deposit_remaining'.tr(
                    args: [_currencyFormat.format(_remainingAmount)],
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Form
              Column(
                children: [
                  // Amount field
                  GlassInputField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsFormatter()],
                    labelText: 'goals.deposit_amount'.tr(),
                    errorText: _amountError,
                    onChanged: (_) {
                      if (_amountError != null) {
                        setState(() => _amountError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Note field
                  GlassInputField(
                    controller: _noteController,
                    labelText: 'goals.deposit_note'.tr(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Error message
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
                  ),
                ),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  onPressed: _isSubmitting ? null : _submit,
                  isLoading: _isSubmitting,
                  child: Text('goals.deposit_submit'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
