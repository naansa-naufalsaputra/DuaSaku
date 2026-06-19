import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/utils/result.dart';
import '../../providers/bill_reminder_provider.dart';

class BillReminderFormScreen extends ConsumerStatefulWidget {
  const BillReminderFormScreen({super.key});

  @override
  ConsumerState<BillReminderFormScreen> createState() =>
      _BillReminderFormScreenState();
}

class _BillReminderFormScreenState
    extends ConsumerState<BillReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dueDate;
  int _reminderDaysBefore = 7; // Default 7 days as approved
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        return child!;
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

    if (_dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${'bottom_sheet.err_required'.tr()}: ${'bill_reminders.due_date'.tr()}',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final result = await ref
        .read(billReminderNotifierProvider.notifier)
        .createBillReminder(
          title: _titleController.text,
          amount: amount,
          dueDate: _dueDate!,
          reminderDaysBefore: _reminderDaysBefore,
          notes: _notesController.text,
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: Text('bill_reminders.add'.tr())),
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
                    // Title field
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'bill_reminders.bill_title'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.title_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'bottom_sheet.err_required'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Amount field
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'bill_reminders.amount'.tr(),
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
                          return '${'bill_reminders.amount'.tr()} > 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Due Date Selector
                    InkWell(
                      onTap: () => _selectDueDate(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
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
                                      : 'bill_reminders.due_date'.tr(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _dueDate != null
                                        ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                        : (isDark
                                              ? Colors.white60
                                              : Colors.black54),
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Reminder days before dropdown
                    DropdownButtonFormField<int>(
                      initialValue: _reminderDaysBefore,
                      decoration: InputDecoration(
                        labelText: 'bill_reminders.reminder_days'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        prefixIcon: const Icon(Icons.alarm_on_rounded),
                      ),
                      items: [1, 2, 3, 5, 7].map((days) {
                        return DropdownMenuItem<int>(
                          value: days,
                          child: Text(
                            'bill_reminders.days_before'.tr(
                              args: [days.toString()],
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _reminderDaysBefore = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Notes Field
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: '${'debts.notes'.tr()} (Opsional)',
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
