import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../data/analysis_helpers.dart';
import 'analysis_common.dart';
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

  // External helper for data check (needed for bar chart navigation)
  final bool Function(int year, int month) hasDataForMonth;

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
    required this.hasDataForMonth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderSection(theme),
        const SizedBox(height: 24),
        _buildBarChartSection(theme),
        const SizedBox(height: 24),
        _buildCalendarSection(theme),
        const SizedBox(height: 24),
        AnalysisPieChart(
          categoryTotals: categoryTotals,
          totalAmount: totalAmount,
          isExpense: isExpense,
        ),
        const SizedBox(height: 16),
        _buildCategoryRankingSection(theme),
      ],
    );
  }

  /// Header Section: 日期选择、收支切换、总金额
  Widget _buildHeaderSection(ThemeData theme) {
    return Column(
      children: [
        // 日期选择 + 收支切换
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 日期选择
            GestureDetector(
              onTap: onMonthPickerTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${selectedYear}年${selectedMonth}月',
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
            // 收支切换 (胶囊形式 SegmentedButton)
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
        // 总金额（大字显示，带动画）
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

  /// 月度小结：近5个月柱状图（金额显示在柱子顶部）
  Widget _buildBarChartSection(ThemeData theme) {
    if (monthlyTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxAmount = monthlyTotals.fold<int>(0, (max, e) => e.amount > max ? e.amount : max);
    // 为金额标签预留空间，增加顶部边距
    final maxY = maxAmount > 0 ? (maxAmount / 100).ceilToDouble() * 1.5 : 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月度小结',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 3,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: monthlyTotals.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final isSelectedMonth = data.year == selectedYear && data.month == selectedMonth;
                final barColor = isSelectedMonth
                    ? const Color(0xFF1976D2)
                    : const Color(0xFF90CAF9);
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data.amount / 100,
                      color: barColor,
                      width: 40,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
                      
                      // 边界月份自动推进逻辑
                      int newYear = tappedMonth.year;
                      int newMonth = tappedMonth.month;
                      
                      if (index == 0) {
                        // 点击最左边的柱子，检查是否有更早的数据
                        int prevMonth = tappedMonth.month - 1;
                        int prevYear = tappedMonth.year;
                        if (prevMonth <= 0) {
                          prevMonth = 12;
                          prevYear -= 1;
                        }
                        // 如果有更早月份的数据，则使用点击的月份（显示范围会自动往前推）
                        if (hasDataForMonth(prevYear, prevMonth)) {
                          // 有更早数据，正常跳转到点击的月份
                          newYear = tappedMonth.year;
                          newMonth = tappedMonth.month;
                        }
                      } else if (index == monthlyTotals.length - 1) {
                        // 点击最右边的柱子，检查是否有更晚的数据
                        int nextMonth = tappedMonth.month + 1;
                        int nextYear = tappedMonth.year;
                        if (nextMonth > 12) {
                          nextMonth = 1;
                          nextYear += 1;
                        }
                        // 如果有更晚月份的数据，则跳转到下一个月（显示范围会往后推）
                        if (hasDataForMonth(nextYear, nextMonth)) {
                          // 有更晚数据，跳转到下一个月
                          newYear = nextYear;
                          newMonth = nextMonth;
                        }
                      }
                      
                      // 跳转到目标月份（带动画）
                      onMonthSwitched(newYear, newMonth);
                    }
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  tooltipMargin: 0,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final data = monthlyTotals[groupIndex];
                    final isSelectedMonth = data.year == selectedYear && data.month == selectedMonth;
                    return BarTooltipItem(
                      formatAmount(data.amount),
                      TextStyle(
                        color: isSelectedMonth
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isSelectedMonth ? FontWeight.w600 : FontWeight.normal,
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

  /// 日历视图
  Widget _buildCalendarSection(ThemeData theme) {
    // 构建每日金额映射
    final dailyMap = <int, int>{};
    for (final dt in dailyTotals) {
      dailyMap[dt.day] = dt.amount;
    }

    // 获取当月第一天是星期几 (0=周日, 1=周一, ..., 6=周六)
    final firstDayOfMonth = DateTime(selectedYear, selectedMonth, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 转换为周日=0
    final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;

    // 今天的日期
    final today = DateTime.now();
    final isCurrentMonth = today.year == selectedYear && today.month == selectedMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 星期标题行
        Row(
          children: ['日', '一', '二', '三', '四', '五', '六']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // 日历网格
        _buildCalendarGrid(
          theme: theme,
          firstWeekday: firstWeekday,
          daysInMonth: daysInMonth,
          dailyMap: dailyMap,
          isCurrentMonth: isCurrentMonth,
          today: today.day,
        ),
      ],
    );
  }

  /// 构建日历网格
  Widget _buildCalendarGrid({
    required ThemeData theme,
    required int firstWeekday,
    required int daysInMonth,
    required Map<int, int> dailyMap,
    required bool isCurrentMonth,
    required int today,
  }) {
    final rows = <Widget>[];
    var currentDay = 1;

    // 计算需要多少行
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    for (var row = 0; row < rowCount; row++) {
      final cells = <Widget>[];
      for (var col = 0; col < 7; col++) {
        final cellIndex = row * 7 + col;
        if (cellIndex < firstWeekday || currentDay > daysInMonth) {
          // 空白格子
          cells.add(const Expanded(child: SizedBox(height: 60)));
        } else {
          final day = currentDay;
          final amount = dailyMap[day] ?? 0;
          final isToday = isCurrentMonth && day == today;
          // Capture current value
          final dayValue = day;
          final amountValue = amount;
          
          cells.add(
            Expanded(
              child: _buildDayCell(
                theme: theme,
                day: dayValue,
                amount: amountValue,
                isToday: isToday,
                onTap: amountValue > 0 ? () => onDayTap(dayValue, amountValue) : null,
              ),
            ),
          );
          currentDay++;
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: cells),
        ),
      );
    }

    return Column(children: rows);
  }

  /// 构建单个日期格子（可点击）
  Widget _buildDayCell({
    required ThemeData theme,
    required int day,
    required int amount,
    required bool isToday,
    required VoidCallback? onTap,
  }) {
    final hasAmount = amount > 0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday
              ? theme.colorScheme.primaryContainer
              : hasAmount
                  ? theme.colorScheme.surfaceContainerHighest
                  : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isToday ? '今天' : '$day',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ),
            if (hasAmount)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  formatAmount(amount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 支出分类排行榜（支付宝风格）
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
