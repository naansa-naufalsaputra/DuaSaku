import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../data/budget_repository.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/constants/app_constants.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  double? _suggestedAmount;

  void _showSetBudgetModal() {
    final catCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Reset state
    _suggestedAmount = null;

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
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'budget.set_monthly_budget'.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GlassInputField(
                controller: catCtrl,
                labelText: 'budget.category_hint'.tr(),
                onChanged: (value) async {
                  if (value.trim().isEmpty) return;

                  // Find category ID by name
                  final categories = await ref.read(
                    categoryNotifierProvider.future,
                  );
                  final matchedCategory = categories.firstWhere(
                    (c) => c.name.toLowerCase() == value.trim().toLowerCase(),
                    orElse: () => categories.first,
                  );

                  // Fetch suggestion
                  final budgetRepo = ref.read(budgetRepositoryProvider);
                  final suggestion = await budgetRepo.getSuggestedBudget(
                    AppConstants.defaultUserId,
                    matchedCategory.id ?? '',
                  );

                  setState(() {
                    _suggestedAmount = suggestion;
                  });

                  // Auto-fill if suggestion exists
                  if (suggestion != null && amountCtrl.text.isEmpty) {
                    amountCtrl.text = ThousandsFormatter.format(suggestion);
                  }
                },
              ),
              if (_suggestedAmount != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'budget.suggested_amount'.tr(args: [
                      ref.watch(currencyFormatterProvider).format(_suggestedAmount!),
                    ]),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              GlassInputField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                labelText: 'budget.amount_limit'.tr(),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 14),
                  child: Text(
                    '${ref.watch(currencySymbolProvider)} ',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GlassButton(
                onPressed: () {
                  final amount = ThousandsFormatter.parse(amountCtrl.text);
                  if (catCtrl.text.isNotEmpty && amount > 0) {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(budgetNotifierProvider.notifier)
                        .setBudget(catCtrl.text.trim(), amount);
                    Navigator.pop(context);
                  }
                },
                child: Text('budget.save_budget'.tr()),
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
    final formatter = ref.watch(currencyFormatterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: Text('budget.title'.tr())),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: budgetState.when(
              data: (budgets) {
                if (budgets.isEmpty) {
                  return Center(
                    child: Text(
                      'budget.no_budgets'.tr(),
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
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
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  onPressed: () {
                                    if (bp.budget.id != null) {
                                      HapticFeedback.vibrate();
                                      ref
                                          .read(budgetNotifierProvider.notifier)
                                          .deleteBudget(bp.budget.id!);
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
                                    color: isOver
                                        ? Colors.red
                                        : (isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.9,
                                                )
                                              : Colors.black87),
                                  ),
                                ),
                                Text(
                                  'budget.of'.tr(args: [formatter.format(bp.budget.amountLimit)]),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: bp.percentage,
                              backgroundColor: progressColor.withValues(
                                alpha: 0.1,
                              ),
                              color: progressColor,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            if (isOver) ...[
                              const SizedBox(height: 4),
                              Text(
                                'budget.exceeded'.tr(),
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
        label: Text('budget.set_budget'.tr()),
      ),
    );
  }
}
