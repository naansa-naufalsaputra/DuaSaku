import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/budget_provider.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/utils/thousands_formatter.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  void _showSetBudgetModal() {
    final catCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set Monthly Budget',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GlassInputField(
                controller: catCtrl,
                labelText: 'Category (e.g. Food)',
              ),
              const SizedBox(height: 16),
              GlassInputField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                labelText: 'Amount Limit',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12, top: 14),
                  child: Text('Rp ', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
              GlassButton(
                onPressed: () {
                  final amount = ThousandsFormatter.parse(amountCtrl.text);
                  if (catCtrl.text.isNotEmpty && amount > 0) {
                    HapticFeedback.mediumImpact();
                    ref.read(budgetNotifierProvider.notifier).setBudget(catCtrl.text.trim(), amount);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save Budget'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final budgetState = ref.watch(budgetNotifierProvider);
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const GlassAppBar(
        title: Text('Monthly Budgets'),
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: budgetState.when(
              data: (budgets) {
                if (budgets.isEmpty) {
                  return Center(
                    child: Text(
                      'No budgets set for this month.',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: budgets.length,
                  itemBuilder: (context, index) {
                    final bp = budgets[index];
                    final isOver = bp.percentage >= 1.0;
                    final progressColor = isOver ? Colors.red : Colors.green;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassCard(
                        enableBlur: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  bp.budget.category,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 16,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  padding: const EdgeInsets.all(12),
                                  onPressed: () {
                                    if (bp.budget.id != null) {
                                      HapticFeedback.vibrate();
                                      ref.read(budgetNotifierProvider.notifier).deleteBudget(bp.budget.id!);
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatter.format(bp.spent),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOver ? Colors.red : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                                  ),
                                ),
                                Text(
                                  'of ${formatter.format(bp.budget.amountLimit)}',
                                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: bp.percentage,
                              backgroundColor: progressColor.withValues(alpha: 0.1),
                              color: progressColor,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            if (isOver) ...[
                              const SizedBox(height: 4),
                              const Text('Budget exceeded!', style: TextStyle(color: Colors.red, fontSize: 12)),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showSetBudgetModal();
        },
        icon: const Icon(Icons.add),
        label: const Text('Set Budget'),
      ),
    );
  }
}
