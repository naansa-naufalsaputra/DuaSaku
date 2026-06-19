import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/utils/result.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../providers/debt_provider.dart';
import '../../domain/models/debt_model.dart';

class DebtDetailScreen extends ConsumerStatefulWidget {
  final String debtId;

  const DebtDetailScreen({super.key, required this.debtId});

  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  bool _isDeleting = false;

  Future<void> _deleteDebt(BuildContext context) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('transaction.delete_confirm_title'.tr()),
        content: Text('transaction.delete_confirm_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('transaction.delete_confirm_no'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text('transaction.delete_confirm_yes'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isDeleting = true;
      });

      final result = await ref
          .read(debtNotifierProvider.notifier)
          .deleteDebt(widget.debtId);

      if (mounted) {
        setState(() {
          _isDeleting = false;
        });

        switch (result) {
          case Success():
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('transaction.deleted_success'.tr())),
            );
            context.pop();
          case Failure(:final error):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error.message),
                backgroundColor: theme.colorScheme.error,
              ),
            );
        }
      }
    }
  }

  void _showPaymentDialog(BuildContext context, DebtModel debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PaymentBottomSheet(debt: debt),
    ).then((success) {
      if (success == true) {
        ref.invalidate(debtPaymentHistoryProvider(widget.debtId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formatter = ref.watch(currencyFormatterProvider);

    final debts = ref.watch(debtNotifierProvider).valueOrNull ?? [];
    final debt = debts.cast<DebtModel?>().firstWhere(
      (d) => d?.id == widget.debtId,
      orElse: () => null,
    );

    if (debt == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(title: Text('debts.title'.tr())),
        body: Stack(
          children: [
            const PremiumBackground(),
            Center(
              child: Text(
                'debts.error_loading'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isOverdue = debt.isOverdue;
    final accentColor = debt.type == 'debt'
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final historyAsync = ref.watch(debtPaymentHistoryProvider(widget.debtId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(
          debt.type == 'debt' ? 'debts.tab_debts'.tr() : 'debts.tab_loans'.tr(),
        ),
        actions: [
          _isDeleting
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _deleteDebt(context),
                ),
        ],
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Detail Header Card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white10
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.8),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  debt.personName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildStatusChip(debt, theme),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Large Remaining Amount
                          Text(
                            'debts.remaining'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          Text(
                            formatter.format(debt.remainingAmount),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: debt.isSettled ? Colors.grey : accentColor,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: debt.amount > 0
                                  ? (debt.paidAmount / debt.amount)
                                  : 0,
                              backgroundColor: isDark
                                  ? Colors.white10
                                  : Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                debt.isSettled ? Colors.green : accentColor,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Metadata Grid
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'debts.amount'.tr(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    formatter.format(debt.amount),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (debt.dueDate != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'debts.due_date'.tr(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      DateFormat.yMMMd().format(debt.dueDate!),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isOverdue
                                            ? theme.colorScheme.error
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),

                          if (debt.notes != null && debt.notes!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              'debts.notes'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              debt.notes!,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // Payment History Title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Text(
                    'debts.payment_history'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // History List
                Expanded(
                  child: historyAsync.when(
                    data: (payments) {
                      if (payments.isEmpty) {
                        return Center(
                          child: Text(
                            'debts.no_payments'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: payments.length,
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.withValues(alpha: 0.1),
                              ),
                            ),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.5),
                            child: ListTile(
                              title: Text(
                                formatter.format(payment.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle:
                                  payment.notes != null &&
                                      payment.notes!.isNotEmpty
                                  ? Text(payment.notes!)
                                  : null,
                              trailing: Text(
                                DateFormat.yMMMd().format(payment.paidAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) =>
                        Center(child: Text('debts.error_loading'.tr())),
                  ),
                ),

                // Action Bar (Bottom Button)
                if (!debt.isSettled)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GlassButton(
                      onPressed: () => _showPaymentDialog(context, debt),
                      child: Text(
                        'debts.add_payment'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(DebtModel debt, ThemeData theme) {
    Color color;
    String text;

    if (debt.isSettled) {
      color = Colors.green;
      text = 'debts.status_paid'.tr();
    } else if (debt.status == 'partial') {
      color = Colors.orange;
      text = 'debts.status_partial'.tr();
    } else {
      color = debt.type == 'debt'
          ? theme.colorScheme.error
          : theme.colorScheme.primary;
      text = 'debts.status_unpaid'.tr();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PaymentBottomSheet extends ConsumerStatefulWidget {
  final DebtModel debt;

  const _PaymentBottomSheet({required this.debt});

  @override
  ConsumerState<_PaymentBottomSheet> createState() =>
      _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends ConsumerState<_PaymentBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _deductWallet = true;
  String? _selectedWalletId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.debt.remainingAmount.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_deductWallet && _selectedWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'bottom_sheet.err_required'.tr() +
                ': ' +
                'bottom_sheet.wallet'.tr(),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final result = await ref
        .read(debtNotifierProvider.notifier)
        .addPayment(
          debtId: widget.debt.id,
          amount: amount,
          walletId: _selectedWalletId ?? '',
          notes: _notesController.text,
          deductWallet: _deductWallet,
        );

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      switch (result) {
        case Success():
          HapticFeedback.lightImpact();
          Navigator.of(context).pop(true);
        case Failure(:final error):
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
    final walletsAsync = ref.watch(walletProvider);
    final formatter = ref.watch(currencyFormatterProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'debts.add_payment'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Input
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'debts.payment_amount'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.monetization_on_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'bottom_sheet.err_required'.tr();
                }
                final val = double.tryParse(value);
                if (val == null || val <= 0) {
                  return 'debts.amount'.tr() + ' > 0';
                }
                if (val > widget.debt.remainingAmount) {
                  return 'Maksimal ' + widget.debt.remainingAmount.toString();
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Wallet Deduct/Add Switch Toggle
            SwitchListTile.adaptive(
              title: Text(
                widget.debt.type == 'debt'
                    ? 'Potong saldo dompet'
                    : 'Tambah ke saldo dompet',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              value: _deductWallet,
              onChanged: (val) {
                setState(() {
                  _deductWallet = val;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),

            if (_deductWallet) ...[
              const SizedBox(height: 8),
              walletsAsync.when(
                data: (wallets) {
                  if (wallets.isEmpty) {
                    return Text(
                      'bottom_sheet.no_wallet_warning'.tr(),
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    );
                  }

                  // Auto-select first wallet if null
                  if (_selectedWalletId == null && wallets.isNotEmpty) {
                    _selectedWalletId = wallets.first.id;
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedWalletId,
                    decoration: InputDecoration(
                      labelText: 'debts.select_wallet'.tr(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      prefixIcon: const Icon(Icons.wallet_outlined),
                    ),
                    items: wallets.map((w) {
                      return DropdownMenuItem<String>(
                        value: w.id,
                        child: Text(
                          '${w.name} (${formatter.format(w.balance)})',
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedWalletId = val;
                      });
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const SizedBox(),
              ),
            ],
            const SizedBox(height: 16),

            // Payment Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'debts.notes'.tr() + ' (Opsional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),

            _isSubmitting
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
    );
  }
}
