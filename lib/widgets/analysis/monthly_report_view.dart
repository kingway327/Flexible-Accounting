import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/analysis_helpers.dart';
import 'analysis_common.dart';
import 'monthly_calendar_section.dart';
import 'analysis_pie_chart.dart';

class MonthlyReportView extends StatelessWidget {
  final int selectedYear;
  final int selectedMonth;
  final bool isExpense;
  final int totalAmount;
  final List<DailyTotal> dailyTotals;
  final List<CategoryTotal> categoryTotals;
  final List<MonthlyTotal> monthlyTotals;

  // Callbacks
  final VoidCallback onMonthPickerTap;
  final ValueChanged<bool> onTypeChanged;
  final Function(int year, int month) onMonthSwitched;
  final Function(int day, int amount) onDayTap;
  final Function(String category, int amount, int count) onCategoryTap;
  final NumberFormat currencyFormatter;

  const MonthlyReportView({
    super.key,
    required this.selectedYear,
    required this.selectedMonth,
    required this.isExpense,
    required this.totalAmount,
    required this.dailyTotals,
    required this.categoryTotals,
    required this.monthlyTotals,
    required this.onMonthPickerTap,
    required this.onTypeChanged,
    required this.onMonthSwitched,
    required this.onDayTap,
    required this.onCategoryTap,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AnalysisReportHeader(
          periodLabel: '$selectedYear年$selectedMonth月',
          onPeriodTap: onMonthPickerTap,
          isExpense: isExpense,
          onTypeChanged: onTypeChanged,
          totalAmount: totalAmount,
          currencyFormatter: currencyFormatter,
        ),
        const SizedBox(height: 24),
        _buildBarChartSection(theme),
        const SizedBox(height: 24),
        MonthlyCalendarSection(
          selectedYear: selectedYear,
          selectedMonth: selectedMonth,
          dailyTotals: dailyTotals,
          onDayTap: onDayTap,
        ),
        const SizedBox(height: 24),
        AnalysisPieChart(
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
          isExpense: isExpense,
        ),
        const SizedBox(height: 16),
        CategoryRankingSection(
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
          isExpense: isExpense,
          onCategoryTap: onCategoryTap,
        ),
      ],
    );
  }

  /// 月度小结：近5个月柱状图（金额显示在柱子顶部）
  Widget _buildBarChartSection(ThemeData theme) {
    if (monthlyTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxAmount =
        monthlyTotals.fold<int>(0, (max, e) => e.amount > max ? e.amount : max);
    // 为金额标签预留空间，增加顶部边距
    final maxY = maxAmount > 0 ? (maxAmount / 100).ceilToDouble() * 1.5 : 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月度小结',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < monthlyTotals.length) {
                        final data = monthlyTotals[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data.label,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    interval: maxY / 3,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 3,
                getDrawingHorizontalLine: (value) => FlLine(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: monthlyTotals.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final isSelectedMonth =
                    data.year == selectedYear && data.month == selectedMonth;
                final barColor = isSelectedMonth ? kDarkBlue : kLightBlue;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data.amount / 100,
                      color: barColor,
                      width: 40,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                      // 在柱子顶部显示金额标签
                      rodStackItems: [],
                    ),
                  ],
                  // 显示柱子顶部的金额标签
                  showingTooltipIndicators: data.amount > 0 ? [0] : [],
                );
              }).toList(),
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (event.isInterestedForInteractions &&
                      response?.spot != null) {
                    final index = response!.spot!.touchedBarGroupIndex;
                    if (index >= 0 && index < monthlyTotals.length) {
                      final tappedMonth = monthlyTotals[index];

                      // 始终跳转到被点击的柱子对应月份
                      onMonthSwitched(tappedMonth.year, tappedMonth.month);
                    }
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  tooltipMargin: 0,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final data = monthlyTotals[groupIndex];
                    final isSelectedMonth = data.year == selectedYear &&
                        data.month == selectedMonth;
                    return BarTooltipItem(
                      formatAmount(data.amount),
                      TextStyle(
                        color: isSelectedMonth
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isSelectedMonth
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          ),
        ),
      ],
    );
  }
}
