import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../data/analysis_helpers.dart';
import 'analysis_common.dart';
import 'analysis_pie_chart.dart';

class WeeklyReportView extends StatelessWidget {
  final bool isExpense;
  final int totalAmount;
  final String weekRangeStr;
  final List<WeeklyDailyTotal> weeklyDailyTotals;
  final List<WeeklyDailyTotal> lastWeekDailyTotals;
  final List<CategoryTotal> categoryTotals;
  final VoidCallback onWeekPickerTap;
  final ValueChanged<bool> onTypeChanged;
  final ValueChanged<WeeklyDailyTotal> onDayTap;
  final Function(String category, int amount, int count) onCategoryTap;
  final NumberFormat currencyFormatter;

  const WeeklyReportView({
    super.key,
    required this.isExpense,
    required this.totalAmount,
    required this.weekRangeStr,
    required this.weeklyDailyTotals,
    required this.lastWeekDailyTotals,
    required this.categoryTotals,
    required this.onWeekPickerTap,
    required this.onTypeChanged,
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
        // Header
        _buildHeaderSection(theme),
        const SizedBox(height: 24),
        // 一周小结（双柱对比图）
        _buildBarChartSection(theme),
        const SizedBox(height: 24),
        // 周日历（7天横向）
        _buildCalendarSection(theme),
        const SizedBox(height: 24),
        // 分类饼图
        AnalysisPieChart(
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
          isExpense: isExpense,
        ),
        const SizedBox(height: 16),
        // 分类排行榜
        _buildCategoryRankingSection(theme),
      ],
    );
  }

  /// 周度 Header
  Widget _buildHeaderSection(ThemeData theme) {
    // 判断 weekRangeStr 是否包含 "本周" 逻辑需要在外面处理，或者简单根据文字判断
    // 这里直接显示 weekRangeStr
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onWeekPickerTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    weekRangeStr,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 24,
                    color: theme.colorScheme.onSurface,
                  ),
                ],
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('支出')),
                ButtonSegment(value: false, label: Text('收入')),
              ],
              selected: {isExpense},
              onSelectionChanged: (value) {
                if (value.isNotEmpty) {
                  onTypeChanged(value.first);
                }
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: totalAmount / 100),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Text(
                currencyFormatter.format(value),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 一周小结：双柱对比图（上周 vs 当周）
  Widget _buildBarChartSection(ThemeData theme) {
    if (weeklyDailyTotals.isEmpty) return const SizedBox.shrink();

    final currentWeek = weeklyDailyTotals;
    final lastWeek = lastWeekDailyTotals;

    // 颜色常量 (需要和 AnalysisPage 一致，或者在 common 定义)
    const Color kLightBlue = Color(0xFF90CAF9);
    const Color kDarkBlue = Color(0xFF1976D2);

    final allAmounts = [...currentWeek.map((e) => e.amount), ...lastWeek.map((e) => e.amount)];
    final maxAmount = allAmounts.fold<int>(0, (max, e) => e > max ? e : max);
    final maxY = maxAmount > 0 ? (maxAmount / 100).ceilToDouble() * 1.3 : 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '一周小结',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            // 图例
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: kLightBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text('上周', style: theme.textTheme.bodySmall),
                const SizedBox(width: 12),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: kDarkBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text('当周', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < currentWeek.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            currentWeek[index].dayLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (index) {
                final lastWeekAmount = index < lastWeek.length ? lastWeek[index].amount / 100 : 0.0;
                final currentWeekAmount = index < currentWeek.length ? currentWeek[index].amount / 100 : 0.0;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: lastWeekAmount,
                      color: kLightBlue,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: currentWeekAmount,
                      color: kDarkBlue,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => kDarkBlue,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = rodIndex == 0 ? '上周' : '当周';
                    return BarTooltipItem(
                      '$label: ¥${rod.toY.toStringAsFixed(2)}',
                      const TextStyle(color: Colors.white, fontSize: 12),
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

  /// 周日历：7天横向排列
  Widget _buildCalendarSection(ThemeData theme) {
    const Color kTodayBg = Color(0xFFE3F2FD); // 需要一致
    const Color kDarkBlue = Color(0xFF1976D2);

    return Row(
      children: weeklyDailyTotals.map((day) {
        final hasAmount = day.amount > 0;
        return Expanded(
          child: GestureDetector(
            onTap: hasAmount ? () => onDayTap(day) : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: day.isToday ? kTodayBg : null,
                borderRadius: BorderRadius.circular(8),
                border: day.isToday
                    ? Border.all(color: kDarkBlue, width: 1)
                    : Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.dateLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: day.isToday ? FontWeight.bold : FontWeight.w500,
                      color: day.isToday ? kDarkBlue : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAmount ? (day.amount / 100).toStringAsFixed(0) : '-',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasAmount ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                      fontWeight: hasAmount ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 周度分类排行榜
  Widget _buildCategoryRankingSection(ThemeData theme) {
    if (categoryTotals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            '暂无数据',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...categoryTotals.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final percentage = totalAmount > 0 ? (data.amount / totalAmount * 100) : 0.0;

          return CategoryItem(
            rank: index + 1,
            category: data.category,
            percentage: percentage,
            amount: data.amount,
            count: data.count,
            isExpense: isExpense,
            onTap: () => onCategoryTap(data.category, data.amount, data.count),
          );
        }),
      ],
    );
  }
}
