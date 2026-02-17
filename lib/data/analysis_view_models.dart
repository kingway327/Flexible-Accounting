import '../models/models.dart';
import 'analysis_helpers.dart';

class WeeklyTabViewData {
  const WeeklyTabViewData({
    required this.weeklyDailyTotals,
    required this.lastWeekDailyTotals,
    required this.weeklyTotal,
    required this.weeklyCategoryTotals,
    required this.weekRangeStr,
  });

  final List<WeeklyDailyTotal> weeklyDailyTotals;
  final List<WeeklyDailyTotal> lastWeekDailyTotals;
  final int weeklyTotal;
  final List<CategoryTotal> weeklyCategoryTotals;
  final String weekRangeStr;
}

class MonthlyTabViewData {
  const MonthlyTabViewData({
    required this.dailyTotals,
    required this.categoryTotals,
    required this.totalAmount,
    required this.monthlyTotals,
  });

  final List<DailyTotal> dailyTotals;
  final List<CategoryTotal> categoryTotals;
  final int totalAmount;
  final List<MonthlyTotal> monthlyTotals;
}

class YearlyTabViewData {
  const YearlyTabViewData({
    required this.yearlyMonthlyTotals,
    required this.yearlyTotal,
    required this.yearlyAverage,
    required this.yearlyCategoryTotals,
  });

  final List<YearlyMonthTotal> yearlyMonthlyTotals;
  final int yearlyTotal;
  final int yearlyAverage;
  final List<CategoryTotal> yearlyCategoryTotals;
}

WeeklyTabViewData buildWeeklyTabViewData({
  required List<TransactionRecord> records,
  required DateTime referenceDate,
  required bool isExpense,
  required int weekOffset,
}) {
  final weeklyDailyTotals = getWeeklyDailyTotals(
    records: records,
    referenceDate: referenceDate,
    isExpense: isExpense,
    weekOffset: weekOffset,
  );
  final lastWeekDailyTotals = getWeeklyDailyTotals(
    records: records,
    referenceDate: referenceDate,
    isExpense: isExpense,
    weekOffset: weekOffset - 1,
  );
  final weeklyTotal = weeklyDailyTotals.fold(0, (sum, e) => sum + e.amount);
  final weeklyCategoryTotals = getWeeklyCategoryTotals(
    records: records,
    referenceDate: referenceDate,
    isExpense: isExpense,
    weekOffset: weekOffset,
  );

  return WeeklyTabViewData(
    weeklyDailyTotals: weeklyDailyTotals,
    lastWeekDailyTotals: lastWeekDailyTotals,
    weeklyTotal: weeklyTotal,
    weeklyCategoryTotals: weeklyCategoryTotals,
    weekRangeStr: getWeekRangeString(referenceDate, weekOffset: weekOffset),
  );
}

MonthlyTabViewData buildMonthlyTabViewData({
  required List<TransactionRecord> records,
  required int selectedYear,
  required int selectedMonth,
  required bool isExpense,
}) {
  return MonthlyTabViewData(
    dailyTotals: getDailyTotals(
      records: records,
      year: selectedYear,
      month: selectedMonth,
      isExpense: isExpense,
    ),
    categoryTotals: getCategoryTotals(
      records: records,
      year: selectedYear,
      month: selectedMonth,
      isExpense: isExpense,
    ),
    totalAmount: getMonthlyTotal(
      records: records,
      year: selectedYear,
      month: selectedMonth,
      isExpense: isExpense,
    ),
    monthlyTotals: getRecentMonthlyTotals(
      records: records,
      year: selectedYear,
      month: selectedMonth,
      isExpense: isExpense,
      monthCount: 5,
    ),
  );
}

YearlyTabViewData buildYearlyTabViewData({
  required List<TransactionRecord> records,
  required int selectedYear,
  required bool isExpense,
  required int? selectedYearlyMonth,
}) {
  return YearlyTabViewData(
    yearlyMonthlyTotals: getYearlyMonthlyTotals(
      records: records,
      year: selectedYear,
      isExpense: isExpense,
      currentMonth: selectedYearlyMonth,
    ),
    yearlyTotal: getYearlyTotal(
      records: records,
      year: selectedYear,
      isExpense: isExpense,
    ),
    yearlyAverage: getYearlyMonthlyAverage(
      records: records,
      year: selectedYear,
      isExpense: isExpense,
    ),
    yearlyCategoryTotals: getYearlyCategoryTotals(
      records: records,
      year: selectedYear,
      isExpense: isExpense,
    ),
  );
}
