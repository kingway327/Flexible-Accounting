import 'package:flutter_test/flutter_test.dart';

import 'package:local_first_finance/data/analysis_helpers.dart';
import 'package:local_first_finance/models/models.dart';

TransactionRecord _record({
  required String id,
  required TransactionType type,
  required int amount,
  required DateTime date,
  String category = '默认分类',
}) {
  return TransactionRecord(
    id: id,
    source: 'WeChat',
    type: type,
    amount: amount,
    timestamp: date.millisecondsSinceEpoch,
    counterparty: '测试对象',
    description: '测试描述',
    account: '零钱',
    originalData: 'raw',
    category: category,
    transactionCategory: category,
  );
}

void main() {
  setUp(() {
    AnalysisCache.instance.clear();
  });

  group('analysis_helpers', () {
    test('getDailyTotals 指定月份每日汇总正确', () {
      final records = [
        _record(
          id: 'd1',
          type: TransactionType.expense,
          amount: 100,
          date: DateTime(2025, 3, 1),
        ),
        _record(
          id: 'd2',
          type: TransactionType.expense,
          amount: 250,
          date: DateTime(2025, 3, 1),
        ),
        _record(
          id: 'd3',
          type: TransactionType.expense,
          amount: 500,
          date: DateTime(2025, 3, 3),
        ),
        _record(
          id: 'd4',
          type: TransactionType.income,
          amount: 999,
          date: DateTime(2025, 3, 1),
        ),
      ];

      AnalysisCache.instance.rebuild(records);

      final totals = getDailyTotals(
        records: records,
        year: 2025,
        month: 3,
        isExpense: true,
      );

      expect(totals.length, 31);
      expect(totals.first.day, 1);
      expect(totals.first.amount, 350);
      expect(totals[2].day, 3);
      expect(totals[2].amount, 500);
      expect(totals[1].amount, 0);
    });

    test('getCategoryTotals 分类按金额降序排列', () {
      final records = [
        _record(
          id: 'c1',
          type: TransactionType.expense,
          amount: 400,
          date: DateTime(2025, 5, 1),
          category: '餐饮',
        ),
        _record(
          id: 'c2',
          type: TransactionType.expense,
          amount: 100,
          date: DateTime(2025, 5, 2),
          category: '交通',
        ),
        _record(
          id: 'c3',
          type: TransactionType.expense,
          amount: 300,
          date: DateTime(2025, 5, 3),
          category: '餐饮',
        ),
      ];

      AnalysisCache.instance.rebuild(records);

      final totals = getCategoryTotals(
        records: records,
        year: 2025,
        month: 5,
        isExpense: true,
      );

      expect(totals.length, 2);
      expect(totals[0].category, '餐饮');
      expect(totals[0].amount, 700);
      expect(totals[1].category, '交通');
      expect(totals[1].amount, 100);
    });

    test('getWeeklyDailyTotals 7 天数据正确映射', () {
      final records = [
        _record(
          id: 'w1',
          type: TransactionType.expense,
          amount: 120,
          date: DateTime(2025, 1, 6),
        ), // 周一
        _record(
          id: 'w2',
          type: TransactionType.expense,
          amount: 80,
          date: DateTime(2025, 1, 8),
        ), // 周三
      ];

      AnalysisCache.instance.rebuild(records);

      final totals = getWeeklyDailyTotals(
        records: records,
        referenceDate: DateTime(2025, 1, 8),
        isExpense: true,
      );

      expect(totals.length, 7);
      expect(totals[0].dayOfWeek, 1);
      expect(totals[0].amount, 120);
      expect(totals[2].dayOfWeek, 3);
      expect(totals[2].amount, 80);
      expect(totals[1].amount, 0);
    });

    test('getRecentMonthlyTotals 5 个月自适应居中', () {
      final records = [
        _record(
          id: 'm1',
          type: TransactionType.expense,
          amount: 100,
          date: DateTime(2024, 12, 1),
        ),
        _record(
          id: 'm2',
          type: TransactionType.expense,
          amount: 200,
          date: DateTime(2025, 1, 1),
        ),
        _record(
          id: 'm3',
          type: TransactionType.expense,
          amount: 300,
          date: DateTime(2025, 2, 1),
        ),
      ];

      AnalysisCache.instance.rebuild(records);

      final totals = getRecentMonthlyTotals(
        records: records,
        year: 2025,
        month: 2,
        isExpense: true,
      );

      expect(totals.length, 5);
      expect(totals[0].year, 2024);
      expect(totals[0].month, 12);
      expect(totals[2].year, 2025);
      expect(totals[2].month, 2);
      expect(totals[2].amount, 300);
      expect(totals[4].year, 2025);
      expect(totals[4].month, 4);
    });
  });
}
