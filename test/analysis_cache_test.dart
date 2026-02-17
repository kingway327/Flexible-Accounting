import 'package:flutter_test/flutter_test.dart';

import 'package:local_first_finance/data/analysis_helpers.dart';
import 'package:local_first_finance/models/models.dart';

TransactionRecord _record({
  required String id,
  required TransactionType type,
  required int amount,
  required DateTime date,
  String category = '测试分类',
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
  final cache = AnalysisCache.instance;

  setUp(() {
    cache.clear();
  });

  group('AnalysisCache', () {
    test('rebuild 后按月/年/日索引正确', () {
      final records = [
        _record(
          id: 'r1',
          type: TransactionType.expense,
          amount: 1000,
          date: DateTime(2025, 1, 10),
        ),
        _record(
          id: 'r2',
          type: TransactionType.income,
          amount: 2000,
          date: DateTime(2025, 1, 10),
        ),
        _record(
          id: 'r3',
          type: TransactionType.expense,
          amount: 3000,
          date: DateTime(2025, 2, 1),
        ),
      ];

      cache.rebuild(records);

      expect(cache.getMonthlyRecords(2025, 1).length, 2);
      expect(cache.getYearlyRecords(2025).length, 3);
      expect(cache.getDailyRecords(2025, 1, 10).length, 2);
    });

    test('getMonthlyTotal 按类型汇总月度总额', () {
      cache.rebuild([
        _record(
          id: 'r1',
          type: TransactionType.expense,
          amount: 1000,
          date: DateTime(2025, 3, 1),
        ),
        _record(
          id: 'r2',
          type: TransactionType.expense,
          amount: 2000,
          date: DateTime(2025, 3, 2),
        ),
        _record(
          id: 'r3',
          type: TransactionType.income,
          amount: 8000,
          date: DateTime(2025, 3, 3),
        ),
      ]);

      expect(cache.getMonthlyTotal(2025, 3, true), 3000);
      expect(cache.getMonthlyTotal(2025, 3, false), 8000);
    });

    test('getYearlyTotal 按类型汇总年度总额', () {
      cache.rebuild([
        _record(
          id: 'r1',
          type: TransactionType.expense,
          amount: 1500,
          date: DateTime(2025, 1, 1),
        ),
        _record(
          id: 'r2',
          type: TransactionType.expense,
          amount: 2500,
          date: DateTime(2025, 8, 1),
        ),
        _record(
          id: 'r3',
          type: TransactionType.income,
          amount: 9000,
          date: DateTime(2025, 6, 1),
        ),
      ]);

      expect(cache.getYearlyTotal(2025, true), 4000);
      expect(cache.getYearlyTotal(2025, false), 9000);
    });

    test('getDataRange 分别返回支出和收入边界', () {
      cache.rebuild([
        _record(
          id: 'e1',
          type: TransactionType.expense,
          amount: 100,
          date: DateTime(2024, 2, 1),
        ),
        _record(
          id: 'e2',
          type: TransactionType.expense,
          amount: 100,
          date: DateTime(2025, 1, 1),
        ),
        _record(
          id: 'i1',
          type: TransactionType.income,
          amount: 100,
          date: DateTime(2024, 6, 1),
        ),
        _record(
          id: 'i2',
          type: TransactionType.income,
          amount: 100,
          date: DateTime(2025, 3, 1),
        ),
      ]);

      final expenseRange = cache.getDataRange(true);
      final incomeRange = cache.getDataRange(false);

      expect(expenseRange?.minYear, 2024);
      expect(expenseRange?.minMonth, 2);
      expect(expenseRange?.maxYear, 2025);
      expect(expenseRange?.maxMonth, 1);

      expect(incomeRange?.minYear, 2024);
      expect(incomeRange?.minMonth, 6);
      expect(incomeRange?.maxYear, 2025);
      expect(incomeRange?.maxMonth, 3);
    });

    test('clear 后所有查询返回空或零', () {
      cache.rebuild([
        _record(
          id: 'r1',
          type: TransactionType.expense,
          amount: 1000,
          date: DateTime(2025, 1, 1),
        ),
      ]);

      cache.clear();

      expect(cache.getMonthlyRecords(2025, 1), isEmpty);
      expect(cache.getYearlyRecords(2025), isEmpty);
      expect(cache.getDailyRecords(2025, 1, 1), isEmpty);
      expect(cache.getMonthlyTotal(2025, 1, true), 0);
      expect(cache.getYearlyTotal(2025, true), 0);
      expect(cache.getDataRange(true), isNull);
      expect(cache.getDataRange(false), isNull);
    });
  });
}
