import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'analysis_modals.dart';

class AnalysisPickerInvoker {
  const AnalysisPickerInvoker({
    required this.allRecords,
    required this.selectedYear,
    required this.selectedMonth,
    required this.isExpense,
    required this.weekOffset,
    required this.selectedColor,
  });

  final List<TransactionRecord> allRecords;
  final int selectedYear;
  final int selectedMonth;
  final bool isExpense;
  final int weekOffset;
  final Color selectedColor;

  void showWeekPicker(BuildContext context, ValueChanged<int> onSelect) {
    showAnalysisWeekPicker(
      context: context,
      currentWeekOffset: weekOffset,
      selectedColor: selectedColor,
      onSelect: onSelect,
    );
  }

  void showYearPicker(BuildContext context, ValueChanged<int> onSelect) {
    showAnalysisYearPicker(
      context: context,
      selectedYear: selectedYear,
      allRecords: allRecords,
      isExpense: isExpense,
      selectedColor: selectedColor,
      onSelect: onSelect,
    );
  }

  void showMonthYearPicker(
    BuildContext context,
    void Function(int year, int month) onConfirm,
  ) {
    showAnalysisMonthYearPicker(
      context: context,
      initialYear: selectedYear,
      initialMonth: selectedMonth,
      allRecords: allRecords,
      isExpense: isExpense,
      onConfirm: onConfirm,
    );
  }
}
