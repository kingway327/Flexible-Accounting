import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/analysis_helpers.dart';
import 'analysis_common.dart';
import 'analysis_pie_chart.dart';

class YearlyReportView extends StatelessWidget {
  final int selectedYear;
  final bool isExpense;
  final int totalAmount;
  final int selectedYearlyMonth;
  final int averageAmount;
  final List<YearlyMonthTotal> yearlyMonthlyTotals;
  final List<CategoryTotal> categoryTotals;

  // Callbacks
  final VoidCallback onYearPickerTap;
  final ValueChanged<bool> onTypeChanged;
  final ValueChanged<int> onMonthChanged; // When bar is touched
  final Function(int month, int amount) onMonthTap; // When tooltip is clicked
  final Function(String category, int amount, int count) onCategoryTap;
  final NumberFormat currencyFormatter;

  const YearlyReportView({
    super.key,
    required this.selectedYear,
    required this.isExpense,
    required this.totalAmount,
    required this.selectedYearlyMonth,
    required this.averageAmount,
    required this.yearlyMonthlyTotals,
    required this.categoryTotals,
    required this.onYearPickerTap,
    required this.onTypeChanged,
    required this.onMonthChanged,
    required this.onMonthTap,
    required this.onCategoryTap,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        AnalysisReportHeader(
          periodLabel: '$selectedYear年',
          onPeriodTap: onYearPickerTap,
          isExpense: isExpense,
          onTypeChanged: onTypeChanged,
          totalAmount: totalAmount,
          currencyFormatter: currencyFormatter,
        ),
        const SizedBox(height: 24),
        // 月度对比图
        _buildBarChartSection(theme),
        const SizedBox(height: 24),
        // 分类饼图
        AnalysisPieChart(
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
          isExpense: isExpense,
        ),
        const SizedBox(height: 16),
        // 分类排行榜
        CategoryRankingSection(
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
          isExpense: isExpense,
          onCategoryTap: onCategoryTap,
        ),
      ],
    );
  }

  /// 年度月度对比图
  Widget _buildBarChartSection(ThemeData theme) {
    if (yearlyMonthlyTotals.isEmpty) return const SizedBox.shrink();

    final maxAmount = yearlyMonthlyTotals.fold<int>(
        0, (max, e) => e.amount > max ? e.amount : max);
    final avgY = averageAmount / 100;
    final maxY =
        (maxAmount > averageAmount ? maxAmount : averageAmount) / 100 * 1.3;
    final selectedMonth = selectedYearlyMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '月度对比',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            // 图例
            Row(
              children: [
                Container(width: 16, height: 2, color: Colors.orange),
                const SizedBox(width: 4),
                Text('月支出均值', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 计算每个柱子的位置，用于放置可点击的 tooltip
              final chartWidth = constraints.maxWidth;
              final barWidth = chartWidth / 12;

              return Stack(
                children: [
                  // 柱状图
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY > 0 ? maxY : 100,
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < 12) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${index + 1}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: avgY,
                            color: Colors.orange,
                            strokeWidth: 1,
                            dashArray: [5, 5],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              labelResolver: (line) => avgY.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      barGroups:
                          yearlyMonthlyTotals.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        final isSelected = data.month == selectedMonth;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data.amount / 100,
                              color: isSelected ? kDarkBlue : kLightBlue,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ],
                          // 不显示内置 tooltip，使用自定义的
                          showingTooltipIndicators: [],
                        );
                      }).toList(),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          if (event.isInterestedForInteractions &&
                              response?.spot != null) {
                            final index = response!.spot!.touchedBarGroupIndex;
                            if (index >= 0 && index < 12) {
                              onMonthChanged(index + 1);
                            }
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero,
                          tooltipMargin: 0,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                              null,
                        ),
                      ),
                    ),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  ),
                  // 选中月份的可点击 tooltip
                  if (yearlyMonthlyTotals.isNotEmpty)
                    ...yearlyMonthlyTotals.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      final isSelected = data.month == selectedMonth;
                      if (!isSelected || data.amount <= 0) {
                        return const SizedBox.shrink();
                      }

                      // 计算 tooltip 位置
                      final barCenterX = barWidth * index + barWidth / 2;
                      final barHeight =
                          maxY > 0 ? (data.amount / 100) / maxY : 0;
                      // 图表高度减去底部标题空间(30)，tooltip 在柱子上方
                      const chartHeight = 220.0;
                      final tooltipY = chartHeight * (1 - barHeight) -
                          45; // 45 是 tooltip 高度 + margin

                      // tooltip 宽度约 90，计算水平位置并确保不超出边界
                      const tooltipWidth = 90.0;
                      var tooltipX = barCenterX - tooltipWidth / 2;
                      // 左边界限制
                      if (tooltipX < 0) {
                        tooltipX = 0;
                      }
                      // 右边界限制
                      if (tooltipX + tooltipWidth > chartWidth) {
                        tooltipX = chartWidth - tooltipWidth;
                      }

                      return Positioned(
                        left: tooltipX,
                        top: tooltipY > 0 ? tooltipY : 0,
                        child: GestureDetector(
                          onTap: () => onMonthTap(data.month, data.amount),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: kDarkBlue,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '$selectedYear年${data.month}月\n${formatAmount(data.amount)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
