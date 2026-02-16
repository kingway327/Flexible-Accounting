import '../models/models.dart';

List<TransactionRecord> getTransactionsForDayInMonth({
  required List<TransactionRecord> records,
  required int year,
  required int month,
  required int day,
  required bool isExpense,
}) {
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final filtered = records.where((record) {
    if (record.type != targetType) {
      return false;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    return date.year == year && date.month == month && date.day == day;
  }).toList();
  _sortByTimestampDesc(filtered);
  return filtered;
}

List<TransactionRecord> getTransactionsForCategoryInMonth({
  required List<TransactionRecord> records,
  required int year,
  required int month,
  required String category,
  required bool isExpense,
}) {
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final filtered = records.where((record) {
    if (record.type != targetType) {
      return false;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year != year || date.month != month) {
      return false;
    }
    return _normalizedCategory(record) == category;
  }).toList();
  _sortByTimestampDesc(filtered);
  return filtered;
}

List<TransactionRecord> getTransactionsForCategoryInYear({
  required List<TransactionRecord> records,
  required int year,
  required String category,
  required bool isExpense,
}) {
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final filtered = records.where((record) {
    if (record.type != targetType) {
      return false;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year != year) {
      return false;
    }
    return _normalizedCategory(record) == category;
  }).toList();
  _sortByTimestampDesc(filtered);
  return filtered;
}

List<TransactionRecord> getTransactionsForCategoryInWeek({
  required List<TransactionRecord> records,
  required String category,
  required bool isExpense,
  required int weekOffset,
  DateTime? referenceDate,
}) {
  final now = referenceDate ?? DateTime.now();
  final daysSinceMonday = now.weekday - 1;
  final monday = DateTime(now.year, now.month, now.day - daysSinceMonday);
  final targetMonday = monday.add(Duration(days: weekOffset * 7));
  final targetSunday = targetMonday.add(const Duration(days: 6));

  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final filtered = records.where((record) {
    if (record.type != targetType) {
      return false;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final dateOnly = DateTime(date.year, date.month, date.day);
    if (dateOnly.isBefore(targetMonday) || dateOnly.isAfter(targetSunday)) {
      return false;
    }
    return _normalizedCategory(record) == category;
  }).toList();
  _sortByTimestampDesc(filtered);
  return filtered;
}

List<TransactionRecord> getTransactionsForYearMonth({
  required List<TransactionRecord> records,
  required int year,
  required int month,
  required bool isExpense,
}) {
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final filtered = records.where((record) {
    if (record.type != targetType) {
      return false;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    return date.year == year && date.month == month;
  }).toList();
  _sortByTimestampDesc(filtered);
  return filtered;
}

String _normalizedCategory(TransactionRecord record) {
  return (record.category?.isNotEmpty == true) ? record.category! : '其他';
}

void _sortByTimestampDesc(List<TransactionRecord> records) {
  records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
}
