import 'package:flutter/material.dart';

typedef AnalysisSetState = void Function(VoidCallback fn);

void runAnalysisAnimatedTransition({
  required AnimationController controller,
  required AnalysisSetState setState,
  required VoidCallback applyState,
  bool Function()? canApply,
}) {
  controller.reverse().then((_) {
    if (canApply != null && !canApply()) {
      return;
    }
    setState(applyState);
    controller.forward();
  });
}

bool isSameMonthSelection({
  required int currentYear,
  required int currentMonth,
  required int nextYear,
  required int nextMonth,
}) {
  return currentYear == nextYear && currentMonth == nextMonth;
}

bool isSameExpenseType({
  required bool currentIsExpense,
  required bool nextIsExpense,
}) {
  return currentIsExpense == nextIsExpense;
}

bool isSameWeekOffset({required int currentOffset, required int nextOffset}) {
  return currentOffset == nextOffset;
}

bool isSameYearSelection({required int currentYear, required int nextYear}) {
  return currentYear == nextYear;
}
