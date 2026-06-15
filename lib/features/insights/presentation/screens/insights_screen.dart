import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../gamification/providers/gamification_provider.dart';
import '../../../transactions/providers/transaction_provider.dart';
import '../../../transactions/providers/category_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../../core/theme/premium_background.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  final ScrollController _scrollController = ScrollController();
  int _touchedPieIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  IconData _getIconData(String? name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'receipt':
        return Icons.receipt_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'electrical_services':
        return Icons.electrical_services_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'build':
        return Icons.build_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'payments':
        return Icons.payments_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getMonochromaticBlue(int index, int total, bool isDark) {
    final baseColor = isDark
        ? const Color(0xFF0A84FF)
        : const Color(0xFF007AFF);
    if (total <= 1) return baseColor;

    // Generate distinct shades of blue by adjusting opacity
    double opacity = 1.0 - (index / total) * 0.7; // From 1.0 down to 0.3
    if (opacity < 0.25) opacity = 0.25;
    return baseColor.withValues(alpha: opacity);
  }

  String _getScoreMessage(int score) {
    if (score >= 80) return "insights.score_excellent".tr();
    if (score >= 50) return "insights.score_good".tr();
    return "insights.score_caution".tr();
  }

  @override
  Widget build(BuildContext context) {
    final gamificationState = ref.watch(gamificationProvider);
    final transactionsAsync = ref.watch(transactionNotifierProvider);
    final transactions = transactionsAsync.value ?? [];
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color accentColor = isDark
        ? const Color(0xFF0A84FF)
        : const Color(0xFF007AFF);

    // Calculate totals
    double totalExpense = 0;
    final Map<String, double> categoryExpenses = {};
    final Map<String, int> categoryCounts = {};

    for (var t in transactions) {
      if (t.type.toLowerCase() == 'expense') {
        totalExpense += t.amount;
        categoryExpenses[t.category] =
            (categoryExpenses[t.category] ?? 0) + t.amount;
        categoryCounts[t.category] = (categoryCounts[t.category] ?? 0) + 1;
      }
    }

    // Calculate cumulative spending day-by-day for the last 7 days
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final startDate = todayStart.subtract(const Duration(days: 6));
    final List<DateTime> targetDays = List.generate(
      7,
      (index) => startDate.add(Duration(days: index)),
    );

    final Map<int, double> dailySpending = {};
    for (int d = 1; d <= 7; d++) {
      dailySpending[d] = 0.0;
    }

    for (var t in transactions) {
      if (t.type.toLowerCase() == 'expense') {
        final tDate = DateTime(
          t.createdAt.year,
          t.createdAt.month,
          t.createdAt.day,
        );
        for (int i = 0; i < 7; i++) {
          if (tDate.isAtSameMomentAs(targetDays[i])) {
            dailySpending[i + 1] = (dailySpending[i + 1] ?? 0.0) + t.amount;
            break;
          }
        }
      }
    }

    final List<FlSpot> lineSpots = [];
    double cumulativeSum = 0;
    for (int d = 1; d <= 7; d++) {
      cumulativeSum += dailySpending[d] ?? 0.0;
      lineSpots.add(FlSpot(d.toDouble(), cumulativeSum));
    }
    if (lineSpots.isEmpty) {
      lineSpots.add(const FlSpot(1, 0));
    }

    double maxCumulative = 0;
    for (var spot in lineSpots) {
      if (spot.y > maxCumulative) maxCumulative = spot.y;
    }
    final double maxYVal = maxCumulative == 0 ? 10000.0 : maxCumulative * 1.15;

    // Build sorted category expense breakdown list
    final List<_CategoryExpenseItem> sortedExpenseBreakdown = [];
    categoryExpenses.forEach((category, amount) {
      if (amount > 0) {
        final matchedCategory = categories.firstWhere(
          (c) => c.name.toLowerCase() == category.toLowerCase(),
          orElse: () => CategoryModel(
            id: '',
            userId: '',
            name: category,
            type: 'expense',
            icon: 'restaurant',
            color: '#007AFF',
            createdAt: DateTime.now(),
          ),
        );
        sortedExpenseBreakdown.add(
          _CategoryExpenseItem(
            category: category,
            amount: amount,
            icon: matchedCategory.icon,
            count: categoryCounts[category] ?? 0,
          ),
        );
      }
    });
    // Sort from highest expenditure to lowest
    sortedExpenseBreakdown.sort((a, b) => b.amount.compareTo(a.amount));

    // Prepare monochromatic pie chart sections
    final List<PieChartSectionData> pieSections = [];
    for (int i = 0; i < sortedExpenseBreakdown.length; i++) {
      final item = sortedExpenseBreakdown[i];
      final isTouched = i == _touchedPieIndex;
      final radius = isTouched ? 16.0 : 12.0;

      pieSections.add(
        PieChartSectionData(
          color: _getMonochromaticBlue(
            i,
            sortedExpenseBreakdown.length,
            isDark,
          ),
          value: item.amount,
          title: '',
          radius: radius,
        ),
      );
    }

    if (pieSections.isEmpty) {
      pieSections.add(
        PieChartSectionData(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          value: 1,
          title: '',
          radius: 12,
        ),
      );
    }

    // Dynamic Donut center details
    String largestCategoryName = 'NONE';
    double largestPercentage = 0;
    if (totalExpense > 0 && sortedExpenseBreakdown.isNotEmpty) {
      largestCategoryName = sortedExpenseBreakdown.first.category;
      largestPercentage =
          (sortedExpenseBreakdown.first.amount / totalExpense) * 100;
    }

    String displayedCategoryName = largestCategoryName;
    double displayedPercentage = largestPercentage;

    if (_touchedPieIndex >= 0 &&
        _touchedPieIndex < sortedExpenseBreakdown.length) {
      final touchedItem = sortedExpenseBreakdown[_touchedPieIndex];
      displayedCategoryName = touchedItem.category;
      displayedPercentage = (touchedItem.amount / totalExpense) * 100;
    }

    final formattedTotalExpense = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(totalExpense);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Center(
            child: CircleAvatar(
              radius: 18,
              backgroundColor: accentColor.withValues(alpha: 0.1),
              child: Text(
                'U',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'insights.title'.tr(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            color: accentColor,
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Overall Health Ring Gauge
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'insights.overall_health'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: gamificationState.healthScore.toDouble(),
                          ),
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedValue, child) {
                            final displayScore = animatedValue.toInt();
                            final progress = animatedValue / 100.0;
                            final status = _getScoreMessage(displayScore);

                            return SizedBox(
                              width: 170,
                              height: 170,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 4,
                                    backgroundColor: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : Colors.black.withValues(alpha: 0.04),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accentColor,
                                    ),
                                  ),
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$displayScore',
                                          style: TextStyle(
                                            fontSize: 56,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                            height: 1.1,
                                          ),
                                        ),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 2. Spending Trend Section
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.2 : 0.03,
                          ),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'insights.spending_trend'.tr(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'insights.last_7_days'.tr(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formattedTotalExpense,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'insights.total_expense'.tr(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: accentColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          height: 120,
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                show: true,
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    interval: 1.0,
                                    getTitlesWidget: (value, meta) {
                                      final style = TextStyle(
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      );
                                      final dayIndex = value.toInt();
                                      if (dayIndex >= 1 && dayIndex <= 7) {
                                        final date = targetDays[dayIndex - 1];
                                        final label = DateFormat.E(
                                          Localizations.localeOf(
                                            context,
                                          ).toString(),
                                        ).format(date);
                                        return SideTitleWidget(
                                          axisSide: meta.axisSide,
                                          space: 4,
                                          child: Text(label, style: style),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                              ),
                              minX: 1,
                              maxX: 7.0,
                              minY: 0,
                              maxY: maxYVal,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: lineSpots,
                                  isCurved: true,
                                  curveSmoothness: 0.35,
                                  barWidth: 3,
                                  color: accentColor,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        accentColor.withValues(alpha: 0.15),
                                        accentColor.withValues(alpha: 0.00),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 3. Top Categories Section
                  Text(
                    'insights.top_categories'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (totalExpense == 0)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Text(
                          'insights.no_expense_data'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    // Donut Chart
                    Center(
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: Stack(
                          children: [
                            PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 54,
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                        setState(() {
                                          if (!event
                                                  .isInterestedForInteractions ||
                                              pieTouchResponse == null ||
                                              pieTouchResponse.touchedSection ==
                                                  null) {
                                            _touchedPieIndex = -1;
                                            return;
                                          }
                                          _touchedPieIndex = pieTouchResponse
                                              .touchedSection!
                                              .touchedSectionIndex;
                                        });
                                      },
                                ),
                                sections: pieSections,
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${displayedPercentage.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayedCategoryName.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Borderless list items with dividers
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedExpenseBreakdown.length,
                      separatorBuilder: (context, index) => Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        height: 24,
                      ),
                      itemBuilder: (context, index) {
                        final item = sortedExpenseBreakdown[index];
                        final formattedAmount = NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(item.amount);

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconData(item.icon),
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.category,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'insights.transactions_count'.tr(
                                        args: [item.count.toString()],
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formattedAmount,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryExpenseItem {
  final String category;
  final double amount;
  final String? icon;
  final int count;

  const _CategoryExpenseItem({
    required this.category,
    required this.amount,
    required this.icon,
    required this.count,
  });
}
