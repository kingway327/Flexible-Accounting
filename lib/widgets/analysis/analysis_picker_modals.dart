import 'package:flutter/material.dart';

import '../../data/analysis_helpers.dart';
import '../../models/models.dart';
import '../month_picker.dart';

void showAnalysisWeekPicker({
  required BuildContext context,
  required int currentWeekOffset,
  required Color selectedColor,
  required ValueChanged<int> onSelect,
}) {
  final theme = Theme.of(context);
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '选择周',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              title: const Text('本周'),
              trailing: currentWeekOffset == 0
                  ? Icon(Icons.check, color: selectedColor)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onSelect(0);
              },
            ),
            ListTile(
              title: const Text('上周'),
              trailing: currentWeekOffset == -1
                  ? Icon(Icons.check, color: selectedColor)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onSelect(-1);
              },
            ),
            ListTile(
              title: const Text('上上周'),
              trailing: currentWeekOffset == -2
                  ? Icon(Icons.check, color: selectedColor)
                  : null,
              onTap: () {
                Navigator.pop(context);
                onSelect(-2);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

void showAnalysisYearPicker({
  required BuildContext context,
  required int selectedYear,
  required List<TransactionRecord> allRecords,
  required bool isExpense,
  required Color selectedColor,
  required ValueChanged<int> onSelect,
}) {
  final theme = Theme.of(context);
  final years = List.generate(31, (i) => 2030 - i);
  final initialIndex = years.indexOf(selectedYear);
  final scrollController = ScrollController(
    initialScrollOffset: initialIndex > 0 ? (initialIndex * 56.0) : 0,
  );

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '选择年份',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              height: 300,
              child: ListView.builder(
                controller: scrollController,
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final hasData = hasDataForYear(
                    records: allRecords,
                    year: year,
                    isExpense: isExpense,
                  );
                  return ListTile(
                    title: Text(
                      '$year年',
                      style: TextStyle(
                        color: hasData ? Colors.black : Colors.grey.shade400,
                        fontWeight:
                            hasData ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    trailing: selectedYear == year
                        ? Icon(Icons.check, color: selectedColor)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(year);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

void showAnalysisMonthYearPicker({
  required BuildContext context,
  required int initialYear,
  required int initialMonth,
  required List<TransactionRecord> allRecords,
  required bool isExpense,
  required void Function(int year, int month) onConfirm,
}) {
  showMonthYearPicker(
    context,
    initialYear: initialYear,
    initialMonth: initialMonth,
    onConfirm: onConfirm,
    hasDataForYearMonth: (year, month) => hasDataForMonth(
      records: allRecords,
      year: year,
      month: month,
      isExpense: isExpense,
    ),
    noDataWarning: '该月份暂无数据',
  );
}
