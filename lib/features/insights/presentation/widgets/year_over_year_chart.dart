import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';

class YearOverYearChart extends StatelessWidget {
  final List<MonthlyData> currentYearData;
  final List<MonthlyData> previousYearData;
  final String currencySymbol;

  const YearOverYearChart({
    super.key,
    required this.currentYearData,
    required this.previousYearData,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'insights.yoy_comparison'.tr(),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildLegendItem(
                    context,
                    'insights.current_year'.tr(),
                    isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                  ),
                  const SizedBox(width: 16),
                  _buildLegendItem(
                    context,
                    'insights.previous_year'.tr(),
                    colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(
          height: 300,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, left: 8, bottom: 16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calculateInterval(),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: colorScheme.onSurface.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatCompactCurrency(value),
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < 0 || value.toInt() >= 12) {
                          return const SizedBox.shrink();
                        }
                        final months = [
                          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
                        ];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            months[value.toInt()],
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Current year line
                  LineChartBarData(
                    spots: _buildSpots(currentYearData),
                    isCurved: true,
                    color: isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                          strokeWidth: 2,
                          strokeColor: colorScheme.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF))
                          .withValues(alpha: 0.1),
                    ),
                  ),
                  // Previous year line
                  LineChartBarData(
                    spots: _buildSpots(previousYearData),
                    isCurved: true,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dashArray: [5, 5],
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                          strokeWidth: 1,
                          strokeColor: colorScheme.surface,
                        );
                      },
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isCurrentYear = spot.barIndex == 0;
                        return LineTooltipItem(
                          '$currencySymbol ${_formatCompactCurrency(spot.y)}\n${isCurrentYear ? 'insights.current_year'.tr() : 'insights.previous_year'.tr()}',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildInsights(context),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _buildSpots(List<MonthlyData> data) {
    return data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.amount);
    }).toList();
  }

  double _calculateInterval() {
    final allAmounts = [
      ...currentYearData.map((d) => d.amount),
      ...previousYearData.map((d) => d.amount),
    ];
    if (allAmounts.isEmpty) return 100000;
    final max = allAmounts.reduce((a, b) => a > b ? a : b);
    return (max / 4).ceilToDouble();
  }

  String _formatCompactCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildInsights(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate totals
    final currentTotal = currentYearData.fold<double>(0, (sum, d) => sum + d.amount);
    final previousTotal = previousYearData.fold<double>(0, (sum, d) => sum + d.amount);
    final percentChange = previousTotal > 0
        ? ((currentTotal - previousTotal) / previousTotal * 100)
        : 0.0;

    // Find best/worst months
    final currentBestMonth = currentYearData.isEmpty
        ? null
        : currentYearData.reduce((a, b) => a.amount > b.amount ? a : b);
    final currentWorstMonth = currentYearData.isEmpty
        ? null
        : currentYearData.reduce((a, b) => a.amount < b.amount ? a : b);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'insights.key_insights'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildInsightRow(
            context,
            'insights.total_change'.tr(),
            '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%',
            percentChange >= 0 ? Colors.green : Colors.red,
          ),
          if (currentBestMonth != null)
            _buildInsightRow(
              context,
              'insights.best_month'.tr(),
              '${_getMonthName(currentBestMonth.month)} ($currencySymbol ${_formatCompactCurrency(currentBestMonth.amount)})',
              Colors.blue,
            ),
          if (currentWorstMonth != null)
            _buildInsightRow(
              context,
              'insights.worst_month'.tr(),
              '${_getMonthName(currentWorstMonth.month)} ($currencySymbol ${_formatCompactCurrency(currentWorstMonth.amount)})',
              Colors.orange,
            ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

class MonthlyData {
  final int month;
  final double amount;

  MonthlyData(this.month, this.amount);
}
