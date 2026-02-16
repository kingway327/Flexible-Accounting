import 'package:flutter/material.dart';

import '../../data/analysis_helpers.dart';
import 'analysis_common.dart';

class MonthlyCalendarSection extends StatelessWidget {
  const MonthlyCalendarSection({
    super.key,
    required this.selectedYear,
    required this.selectedMonth,
    required this.dailyTotals,
    required this.onDayTap,
  });

  final int selectedYear;
  final int selectedMonth;
  final List<DailyTotal> dailyTotals;
  final Function(int day, int amount) onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dailyMap = <int, int>{};
    for (final dt in dailyTotals) {
      dailyMap[dt.day] = dt.amount;
    }

    final firstDayOfMonth = DateTime(selectedYear, selectedMonth, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;

    final today = DateTime.now();
    final isCurrentMonth =
        today.year == selectedYear && today.month == selectedMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: ['日', '一', '二', '三', '四', '五', '六']
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
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
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    for (var row = 0; row < rowCount; row++) {
      final cells = <Widget>[];
      for (var col = 0; col < 7; col++) {
        final cellIndex = row * 7 + col;
        if (cellIndex < firstWeekday || currentDay > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 60)));
        } else {
          final day = currentDay;
          final amount = dailyMap[day] ?? 0;
          final isToday = isCurrentMonth && day == today;
          final dayValue = day;
          final amountValue = amount;

          cells.add(
            Expanded(
              child: _buildDayCell(
                theme: theme,
                day: dayValue,
                amount: amountValue,
                isToday: isToday,
                onTap: amountValue > 0
                    ? () => onDayTap(dayValue, amountValue)
                    : null,
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
}
