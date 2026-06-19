import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../transactions/providers/transaction_provider.dart';
import '../../../transactions/providers/budget_provider.dart';

import '../../../../core/providers/settings_provider.dart';

class SpendingHeatmap extends ConsumerWidget {
  const SpendingHeatmap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionNotifierProvider);
    final budgetsAsync = ref.watch(budgetNotifierProvider);
    final themeState = ref.watch(themeNotifierProvider);
    final currencyFormat = ref.watch(currencyFormatterProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeDetails = ThemePresets.getDetails(themeState.preset, isDark);

    return transactionsAsync.when(
      data: (transactions) {
        final budgets = budgetsAsync.value ?? [];

        // 1. Calculate average daily budget
        double dailyBudget = 150000; // Default fallback
        if (budgets.isNotEmpty) {
          double totalBudgetLimit = 0;
          for (var b in budgets) {
            totalBudgetLimit += b.budget.amountLimit;
          }
          if (totalBudgetLimit > 0) {
            dailyBudget = totalBudgetLimit / 30;
          }
        }

        // 2. Map expenses by date (yyyy-MM-dd)
        final Map<String, double> dailyExpenses = {};
        for (var t in transactions) {
          if (t.type == 'expense') {
            final dateKey = DateFormat('yyyy-MM-dd').format(t.createdAt);
            dailyExpenses[dateKey] = (dailyExpenses[dateKey] ?? 0) + t.amount;
          }
        }

        // 3. Generate date grid: 13 weeks (columns) x 7 days (rows)
        // Aligning to start on a Sunday to look like a clean calendar block
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysToSubtract = 90 + (today.weekday % 7); // Adjust to Sunday
        final startDate = today.subtract(Duration(days: daysToSubtract));

        final List<List<DateTime>> weeks = [];
        for (int w = 0; w < 13; w++) {
          final List<DateTime> weekDays = [];
          for (int d = 0; d < 7; d++) {
            weekDays.add(startDate.add(Duration(days: w * 7 + d)));
          }
          weeks.add(weekDays);
        }

        return GlassCard(
          enableBlur: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spending Intensity (90 Days)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildLegend(themeDetails.heatmapColors),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Weekdays labels (Sun, Tue, Thu, Sat)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildDayLabel('S'),
                          const SizedBox(height: 4),
                          _buildDayLabel(''),
                          const SizedBox(height: 4),
                          _buildDayLabel('T'),
                          const SizedBox(height: 4),
                          _buildDayLabel(''),
                          const SizedBox(height: 4),
                          _buildDayLabel('T'),
                          const SizedBox(height: 4),
                          _buildDayLabel(''),
                          const SizedBox(height: 4),
                          _buildDayLabel('S'),
                        ],
                      ),
                    ),
                    // 13 columns (weeks), animated dynamically to maintain high frame rate
                    Row(
                      children:
                          List.generate(weeks.length, (wIndex) {
                                final week = weeks[wIndex];
                                return Column(
                                  children: List.generate(week.length, (
                                    dIndex,
                                  ) {
                                    final date = week[dIndex];
                                    final dateKey = DateFormat(
                                      'yyyy-MM-dd',
                                    ).format(date);
                                    final expense =
                                        dailyExpenses[dateKey] ?? 0.0;

                                    // Choose color shade based on expense density
                                    Color cellColor;
                                    if (expense == 0) {
                                      cellColor = themeDetails.heatmapColors[0];
                                    } else if (expense <= dailyBudget * 0.25) {
                                      cellColor = themeDetails.heatmapColors[1];
                                    } else if (expense <= dailyBudget * 0.60) {
                                      cellColor = themeDetails.heatmapColors[2];
                                    } else if (expense <= dailyBudget) {
                                      cellColor = themeDetails.heatmapColors[3];
                                    } else {
                                      cellColor = themeDetails.heatmapColors[4];
                                    }

                                    final isCurrentDay =
                                        date.year == today.year &&
                                        date.month == today.month &&
                                        date.day == today.day;

                                    return Tooltip(
                                      message:
                                          '${DateFormat('EEEE, d MMMM y').format(date)}\nSpent: ${currencyFormat.format(expense)}',
                                      triggerMode: TooltipTriggerMode.tap,
                                      preferBelow: false,
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        margin: const EdgeInsets.all(2.0),
                                        decoration: BoxDecoration(
                                          color: cellColor,
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                          border: isCurrentDay
                                              ? Border.all(
                                                  color: themeDetails
                                                      .themeData
                                                      .colorScheme
                                                      .primary,
                                                  width: 1.5,
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              })
                              .animate(interval: 40.ms)
                              .fade(duration: 250.ms)
                              .slideX(
                                begin: 0.15,
                                end: 0,
                                curve: Curves.easeOutCubic,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const GlassCard(
        enableBlur: false,
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => GlassCard(
        enableBlur: false,
        child: SizedBox(
          height: 180,
          child: Center(child: Text('Error loading heatmap data: $err')),
        ),
      ),
    );
  }

  Widget _buildDayLabel(String label) {
    return SizedBox(
      height: 16,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(List<Color> colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Less ',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        ...colors.map(
          (c) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 1.0),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
        const Text(
          ' More',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
