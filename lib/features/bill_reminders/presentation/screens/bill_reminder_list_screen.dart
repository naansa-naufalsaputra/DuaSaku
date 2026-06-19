import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/utils/result.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../providers/bill_reminder_provider.dart';
import '../../domain/models/bill_reminder_model.dart';

class BillReminderListScreen extends ConsumerWidget {
  const BillReminderListScreen({super.key});

  void _showMarkPaidDialog(BuildContext context, WidgetRef ref, BillReminderModel reminder) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MarkPaidBottomSheet(reminder: reminder),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final remindersAsync = ref.watch(billReminderNotifierProvider);
    final formatter = ref.watch(currencyFormatterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text('bill_reminders.title'.tr()),
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: remindersAsync.when(
              data: (reminders) {
                if (reminders.isEmpty) {
                  return _buildEmptyState(isDark, theme);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = reminders[index];
                    return _buildReminderCard(context, ref, reminder, isDark, theme, formatter).liquidStagger(index);
                  },
                );
              },
              loading: () => _buildShimmerLoading(isDark, theme),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'bill_reminders.error_loading'.tr(),
                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/bill-reminders/create');
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    WidgetRef ref,
    BillReminderModel reminder,
    bool isDark,
    ThemeData theme,
    NumberFormat formatter,
  ) {
    final isOverdue = reminder.isOverdue;
    final isPaid = reminder.status == 'paid';
    
    // Status colors
    Color statusColor;
    String statusText;
    if (isPaid) {
      statusColor = Colors.green;
      statusText = 'bill_reminders.status_paid'.tr();
    } else if (isOverdue) {
      statusColor = theme.colorScheme.error;
      statusText = 'bill_reminders.overdue'.tr();
    } else {
      statusColor = Colors.orange;
      statusText = 'bill_reminders.status_pending'.tr();
    }

    final diff = reminder.dueDate.difference(DateTime.now()).inDays;
    String timingText = '';
    if (!isPaid) {
      if (diff < 0) {
        timingText = 'Terlambat ${diff.abs()} hari';
      } else if (diff == 0) {
        timingText = 'Hari Ini';
      } else {
        timingText = '$diff hari lagi';
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row title & status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    reminder.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Amount row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'bill_reminders.amount'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      formatter.format(reminder.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                
                // Actions (Pay button if unpaid)
                if (!isPaid)
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showMarkPaidDialog(context, ref, reminder);
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text('bill_reminders.mark_paid'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(billReminderNotifierProvider.notifier).deleteBillReminder(reminder.id);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Due Date & Reminders timing
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat.yMMMd().format(reminder.dueDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    if (timingText.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '•  $timingText',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                          color: isOverdue ? theme.colorScheme.error : Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'bill_reminders.days_before'.tr(args: [reminder.reminderDaysBefore.toString()]),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),

            if (reminder.notes != null && reminder.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                reminder.notes!,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'bill_reminders.empty'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[300]!,
            highlightColor: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[100]!,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarkPaidBottomSheet extends ConsumerStatefulWidget {
  final BillReminderModel reminder;

  const _MarkPaidBottomSheet({required this.reminder});

  @override
  ConsumerState<_MarkPaidBottomSheet> createState() => _MarkPaidBottomSheetState();
}

class _MarkPaidBottomSheetState extends ConsumerState<_MarkPaidBottomSheet> {
  bool _deductWallet = true;
  String? _selectedWalletId;
  bool _isSubmitting = false;

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
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'bill_reminders.mark_paid'.tr(),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Apakah Anda ingin mencatat pembayaran untuk tagihan "${widget.reminder.title}"?',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Deduct from wallet option switch
          SwitchListTile.adaptive(
            title: Text(
              'bill_reminders.deduct_wallet'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  );
                }
                
                if (_selectedWalletId == null && wallets.isNotEmpty) {
                  _selectedWalletId = wallets.first.id;
                }

                return DropdownButtonFormField<String>(
                  value: _selectedWalletId,
                  decoration: InputDecoration(
                    labelText: 'bill_reminders.select_wallet'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    prefixIcon: const Icon(Icons.wallet_outlined),
                  ),
                  items: wallets.map((w) {
                    return DropdownMenuItem<String>(
                      value: w.id,
                      child: Text('${w.name} (${formatter.format(w.balance)})'),
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
          const SizedBox(height: 24),

          _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : GlassButton(
                  onPressed: () async {
                    if (_deductWallet && _selectedWalletId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${'bottom_sheet.err_required'.tr()}: ${'bottom_sheet.wallet'.tr()}'),
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _isSubmitting = true;
                    });

                    final result = await ref.read(billReminderNotifierProvider.notifier).markAsPaid(
                          reminderId: widget.reminder.id,
                          walletId: _selectedWalletId ?? '',
                          deductWallet: _deductWallet,
                        );

                    setState(() {
                      _isSubmitting = false;
                    });

                    if (mounted) {
                      switch (result) {
                        case Success():
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pembayaran tagihan berhasil dicatat!')),
                          );
                        case Failure(:final error):
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error.message),
                              backgroundColor: theme.colorScheme.error,
                            ),
                          );
                      }
                    }
                  },
                  child: Text(
                    'bill_reminders.mark_paid'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
