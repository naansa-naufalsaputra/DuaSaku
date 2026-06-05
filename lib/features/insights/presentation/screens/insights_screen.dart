import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../gamification/providers/gamification_provider.dart';
import '../../../transactions/providers/transaction_provider.dart';
import '../../../transactions/providers/category_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';
import '../widgets/spending_heatmap.dart';

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
      case 'restaurant': return Icons.restaurant_rounded;
      case 'local_cafe': return Icons.local_cafe_rounded;
      case 'attach_money': return Icons.attach_money_rounded;
      case 'receipt': return Icons.receipt_rounded;
      case 'shopping_bag': return Icons.shopping_bag_rounded;
      case 'directions_car': return Icons.directions_car_rounded;
      case 'local_gas_station': return Icons.local_gas_station_rounded;
      case 'home': return Icons.home_rounded;
      case 'electrical_services': return Icons.electrical_services_rounded;
      case 'water_drop': return Icons.water_drop_rounded;
      case 'wifi': return Icons.wifi_rounded;
      case 'medical_services': return Icons.medical_services_rounded;
      case 'sports_esports': return Icons.sports_esports_rounded;
      case 'movie': return Icons.movie_rounded;
      case 'flight': return Icons.flight_rounded;
      case 'school': return Icons.school_rounded;
      case 'fitness_center': return Icons.fitness_center_rounded;
      case 'pets': return Icons.pets_rounded;
      case 'card_giftcard': return Icons.card_giftcard_rounded;
      case 'work': return Icons.work_rounded;
      case 'trending_up': return Icons.trending_up_rounded;
      case 'savings': return Icons.savings_rounded;
      case 'account_balance': return Icons.account_balance_rounded;
      case 'build': return Icons.build_rounded;
      case 'spa': return Icons.spa_rounded;
      case 'payments': return Icons.payments_rounded;
      default: return Icons.category_rounded;
    }
  }

  Color _getCategoryColor(String? colorHex, String type) {
    if (colorHex == null || colorHex.isEmpty || colorHex == 'system') {
      return type == 'expense' ? const Color(0xFFF43F5E) : const Color(0xFF10B981);
    }
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return type == 'expense' ? const Color(0xFFF43F5E) : const Color(0xFF10B981);
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 50) return Colors.orange;
    return const Color(0xFFF43F5E);
  }

  String _getScoreMessage(int score) {
    if (score >= 80) return "Excellent financial health! Keep it up.";
    if (score >= 50) return "You're doing okay, but there's room for improvement.";
    return "Caution! You need to manage your budget and savings better.";
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

    // Calculate totals
    double totalIncome = 0;
    double totalExpense = 0;
    final Map<String, double> categoryExpenses = {};

    for (var t in transactions) {
      if (t.type.toLowerCase() == 'income') {
        totalIncome += t.amount;
      } else if (t.type.toLowerCase() == 'expense') {
        totalExpense += t.amount;
        categoryExpenses[t.category] = (categoryExpenses[t.category] ?? 0) + t.amount;
      }
    }

    // Calculate cumulative spending day-by-day for the current month
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final Map<int, double> dailySpending = {};
    for (int d = 1; d <= daysInMonth; d++) {
      dailySpending[d] = 0.0;
    }
    
    for (var t in transactions) {
      if (t.type.toLowerCase() == 'expense' &&
          t.createdAt.month == now.month &&
          t.createdAt.year == now.year) {
        final day = t.createdAt.day;
        dailySpending[day] = (dailySpending[day] ?? 0.0) + t.amount;
      }
    }

    final List<FlSpot> lineSpots = [];
    double cumulativeSum = 0;
    for (int d = 1; d <= now.day; d++) {
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
            color: '#F43F5E',
            createdAt: DateTime.now(),
          ),
        );
        sortedExpenseBreakdown.add(_CategoryExpenseItem(
          category: category,
          amount: amount,
          color: _getCategoryColor(matchedCategory.color, 'expense'),
          icon: matchedCategory.icon,
        ));
      }
    });
    // Sort from highest expenditure to lowest
    sortedExpenseBreakdown.sort((a, b) => b.amount.compareTo(a.amount));

    // Prepare pie chart sections
    final List<PieChartSectionData> pieSections = [];
    for (int i = 0; i < sortedExpenseBreakdown.length; i++) {
      final item = sortedExpenseBreakdown[i];
      final isTouched = i == _touchedPieIndex;
      final radius = isTouched ? 60.0 : 50.0;
      
      pieSections.add(PieChartSectionData(
        color: item.color,
        value: item.amount,
        title: totalExpense > 0 ? '${(item.amount / totalExpense * 100).toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: isTouched ? 13 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
        ),
      ));
    }

    if (pieSections.isEmpty) {
      pieSections.add(PieChartSectionData(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        value: 1,
        title: '',
        radius: 50,
      ));
    }

    // Dynamic Legend items
    final List<Widget> legendItems = [];
    for (var item in sortedExpenseBreakdown) {
      legendItems.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              item.category,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: const Text('Financial Insights'),
        scrollController: _scrollController,
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Health Score Gauge
                  GlassCard(
                    enableBlur: false,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: gamificationState.healthScore.toDouble()),
                            duration: const Duration(milliseconds: 1500),
                            curve: Curves.easeOutCubic,
                            builder: (context, animatedValue, child) {
                              final displayScore = animatedValue.toInt();
                              final progress = animatedValue / 100.0;
                              final activeColor = _getScoreColor(displayScore);

                              return SizedBox(
                                width: 80,
                                height: 80,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 8,
                                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                                    ),
                                    Center(
                                      child: Text(
                                        '$displayScore',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Health Score',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getScoreMessage(gamificationState.healthScore),
                                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade700, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Spending Trend Line Chart (This Month)
                  GlassCard(
                    enableBlur: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spending Trend (This Month)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cumulative spending day-by-day',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                lineTouchData: LineTouchData(
                                  enabled: true,
                                  touchTooltipData: LineTouchTooltipData(
                                    getTooltipColor: (spot) => theme.colorScheme.surface.withValues(alpha: 0.9),
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                        final formatted = NumberFormat.currency(
                                          locale: 'id_ID',
                                          symbol: 'Rp ',
                                          decimalDigits: 0,
                                        ).format(spot.y);
                                        return LineTooltipItem(
                                          'Hari ${spot.x.toInt()}\n$formatted',
                                          TextStyle(
                                            color: isDark ? Colors.white : Colors.black87,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      interval: 1.0,
                                      getTitlesWidget: (value, meta) {
                                        final style = TextStyle(
                                          color: isDark ? Colors.white60 : Colors.black54,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        );
                                        final day = value.toInt();
                                        if (day == 1 || day == 7 || day == 14 || day == 21 || day == 28 || day == now.day) {
                                          return SideTitleWidget(
                                            axisSide: meta.axisSide,
                                            space: 8,
                                            child: Text('$day', style: style),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                ),
                                minX: 1,
                                maxX: now.day.toDouble(),
                                minY: 0,
                                maxY: maxYVal,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: lineSpots,
                                    isCurved: true,
                                    curveSmoothness: 0.35,
                                    barWidth: 4,
                                    color: theme.colorScheme.primary,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          theme.colorScheme.primary.withValues(alpha: 0.30),
                                          theme.colorScheme.primary.withValues(alpha: 0.00),
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
                  ),
                  const SizedBox(height: 16),

                  // 2. Income vs Expense Bar Chart
                  GlassCard(
                    enableBlur: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Income vs Expense',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (totalIncome > totalExpense ? totalIncome : totalExpense) * 1.2,
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (double value, TitleMeta meta) {
                                      final style = TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: isDark ? Colors.white60 : Colors.black54,
                                      );
                                      final String text = value.toInt() == 0 ? 'Income' : (value.toInt() == 1 ? 'Expense' : '');
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        space: 4,
                                        child: Text(text, style: style),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: totalIncome,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      width: 32,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    )
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: totalExpense,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                      width: 32,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Expenses by Category Pie Chart & Breakdown List
                  GlassCard(
                    enableBlur: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expenses by Category',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (totalExpense == 0)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No expense data for this period.',
                                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
                              ),
                            ),
                          )
                        else ...[
                          SizedBox(
                            height: 180,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                pieTouchData: PieTouchData(
                                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection == null) {
                                        _touchedPieIndex = -1;
                                        return;
                                      }
                                      _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                sections: pieSections,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Dynamic Legend
                          Center(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: legendItems,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Divider(color: isDark ? Colors.white10 : Colors.black12),
                          const SizedBox(height: 16),
                          Text(
                            'Spending Breakdown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sortedExpenseBreakdown.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final item = sortedExpenseBreakdown[index];
                              final percentage = (item.amount / totalExpense) * 100;
                              final formattedAmount = NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp ',
                                decimalDigits: 0,
                              ).format(item.amount);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: item.color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getIconData(item.icon),
                                          color: item.color,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        item.category,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '$formattedAmount (${percentage.toStringAsFixed(1)}%)',
                                        style: TextStyle(
                                          color: isDark ? Colors.white70 : Colors.black54,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: item.amount / totalExpense,
                                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                      valueColor: AlwaysStoppedAnimation<Color>(item.color),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Spending Intensity Heatmap
                  const SpendingHeatmap(),
                  const SizedBox(height: 16),
                  // 5. Gamification Streak Indicator
                  GlassCard(
                    enableBlur: false,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${gamificationState.currentStreak} Days Streak!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Keep recording your transactions daily.',
                                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ).liquidFadeIn(),
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
  final Color color;
  final String? icon;

  const _CategoryExpenseItem({
    required this.category,
    required this.amount,
    required this.color,
    required this.icon,
  });
}
