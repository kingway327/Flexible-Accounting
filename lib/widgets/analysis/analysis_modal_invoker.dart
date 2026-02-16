import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/analysis_helpers.dart';
import '../../data/analysis_transaction_queries.dart';
import '../../models/models.dart';
import 'analysis_modals.dart';

class AnalysisModalInvoker {
  const AnalysisModalInvoker({
    required this.records,
    required this.selectedYear,
    required this.selectedMonth,
    required this.isExpense,
    required this.weekOffset,
    required this.currencyFormatter,
    required this.onRefresh,
  });

  final List<TransactionRecord> records;
  final int selectedYear;
  final int selectedMonth;
  final bool isExpense;
  final int weekOffset;
  final NumberFormat currencyFormatter;
  final VoidCallback onRefresh;

  void showWeekDayTransactionsModal(
      BuildContext context, WeeklyDailyTotal day) {
    showAnalysisWeekDayTransactionsModal(
      context: context,
      day: day,
      allRecords: records,
      isExpense: isExpense,
      onRefresh: onRefresh,
    );
  }

  void showWeeklyCategoryTransactionsModal(
    BuildContext context,
    String category,
    int totalAmount,
    int count,
  ) {
    final transactions = getTransactionsForCategoryInWeek(
      records: records,
      category: category,
      isExpense: isExpense,
      weekOffset: weekOffset,
    );
    _showCategoryTransactionsModalCommon(
      context,
      category,
      totalAmount,
      count,
      transactions,
    );
  }

  void showYearlyCategoryTransactionsModal(
    BuildContext context,
    String category,
    int totalAmount,
    int count,
  ) {
    final transactions = getTransactionsForCategoryInYear(
      records: records,
      year: selectedYear,
      category: category,
      isExpense: isExpense,
    );
    _showCategoryTransactionsModalCommon(
      context,
      category,
      totalAmount,
      count,
      transactions,
    );
  }

  void showYearlyMonthTransactionsModal(
    BuildContext context,
    int month,
    int totalAmount,
  ) {
    final transactions = getTransactionsForYearMonth(
      records: records,
      year: selectedYear,
      month: month,
      isExpense: isExpense,
    );
    showAnalysisYearlyMonthTransactionsModal(
      context: context,
      selectedYear: selectedYear,
      month: month,
      totalAmount: totalAmount,
      isExpense: isExpense,
      currencyFormatter: currencyFormatter,
      transactions: transactions,
      onRefresh: onRefresh,
    );
  }

  void showDayTransactionsModal(
      BuildContext context, int day, int totalAmount) {
    final transactions = getTransactionsForDayInMonth(
      records: records,
      year: selectedYear,
      month: selectedMonth,
      day: day,
      isExpense: isExpense,
    );
    final now = DateTime.now();
    final isToday = now.year == selectedYear &&
        now.month == selectedMonth &&
        now.day == day;
    showAnalysisDayTransactionsModal(
      context: context,
      selectedMonth: selectedMonth,
      day: day,
      totalAmount: totalAmount,
      isExpense: isExpense,
      isToday: isToday,
      transactions: transactions,
      onRefresh: onRefresh,
    );
  }

  void showCategoryTransactionsModal(
    BuildContext context,
    String category,
    int totalAmount,
    int count,
  ) {
    final transactions = getTransactionsForCategoryInMonth(
      records: records,
      year: selectedYear,
      month: selectedMonth,
      category: category,
      isExpense: isExpense,
    );
    _showCategoryTransactionsModalCommon(
      context,
      category,
      totalAmount,
      count,
      transactions,
    );
  }

  void _showCategoryTransactionsModalCommon(
    BuildContext context,
    String category,
    int totalAmount,
    int count,
    List<TransactionRecord> transactions,
  ) {
    showAnalysisCategoryTransactionsModalCommon(
      context: context,
      category: category,
      totalAmount: totalAmount,
      count: count,
      transactions: transactions,
      isExpense: isExpense,
      currencyFormatter: currencyFormatter,
      onRefresh: onRefresh,
    );
  }
}
