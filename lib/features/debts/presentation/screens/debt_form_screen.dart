import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/utils/result.dart';
import '../../providers/debt_provider.dart';

class DebtFormScreen extends ConsumerStatefulWidget {
  final String? initialType;

  const DebtFormScreen({super.key, this.initialType});

  @override
  ConsumerState<DebtFormScreen> createState() => _DebtFormScreenState();
}

class _DebtFormScreenState extends ConsumerState<DebtFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType == 'loan' ? 'loan' : 'debt';
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final result = await ref.read(debtNotifierProvider.notifier).createDebt(
          type: _type,
          personName: _personController.text,
          amount: amount,
          notes: _notesController.text,
          dueDate: _dueDate,
        );

    setState(() {
      _isLoading = false;
    });

    switch (result) {
      case Success():
        HapticFeedback.lightImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('bottom_sheet.success_save'.tr())),
          );
          context.pop();
        }
      case Failure(:final error):
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleKey = _type == 'debt' ? 'debts.add_debt' : 'debts.add_loan';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(titleKey.tr()),
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Type Selection (Segmented Control)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _type = 'debt';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _type == 'debt'
                                      ? theme.colorScheme.error
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'debts.tab_debts'.tr(),
                                  style: TextStyle(
                                    color: _type == 'debt'
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _type = 'loan';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _type == 'loan'
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'debts.tab_loans'.tr(),
                                  style: TextStyle(
                                    color: _type == 'loan'
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Person Name Field
                    TextFormField(
                      controller: _personController,
                      decoration: InputDecoration(
                        labelText: 'debts.person_name'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'bottom_sheet.err_required'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'debts.amount'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.monetization_on_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'bottom_sheet.err_required'.tr();
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'debts.amount'.tr() + ' > 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Due Date Field
                    InkWell(
                      onTap: () => _selectDueDate(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded),
                                const SizedBox(width: 12),
                                Text(
                                  _dueDate != null
                                      ? DateFormat.yMMMd().format(_dueDate!)
                                      : 'debts.due_date'.tr() + ' (Opsional)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _dueDate != null
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                            if (_dueDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() {
                                    _dueDate = null;
                                  });
                                },
                              )
                            else
                              const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Notes Field
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'debts.notes'.tr() + ' (Opsional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Save Button
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : GlassButton(
                            onPressed: _submit,
                            child: Text(
                              'debts.save'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
