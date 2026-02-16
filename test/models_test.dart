import 'package:flutter_test/flutter_test.dart';

import 'package:local_first_finance/models/models.dart';

void main() {
  group('Model equality', () {
    test('CategoryGroup equality and hashCode', () {
      final a = CategoryGroup(
        id: 1,
        name: '微信',
        color: 0xFF4CAF50,
        sortOrder: 0,
        createdAt: 1,
        isSystem: true,
      );
      final b = CategoryGroup(
        id: 1,
        name: '微信',
        color: 0xFF4CAF50,
        sortOrder: 0,
        createdAt: 1,
        isSystem: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('TransactionRecord equality and hashCode', () {
      final a = TransactionRecord(
        id: 'id_1',
        source: 'WeChat',
        type: TransactionType.expense,
        amount: 1200,
        timestamp: 100,
        counterparty: '淘宝',
        description: '购物',
        account: '零钱',
        originalData: 'raw',
        category: '日用百货',
        transactionCategory: '商户消费',
        note: '备注',
      );
      final b = TransactionRecord(
        id: 'id_1',
        source: 'WeChat',
        type: TransactionType.expense,
        amount: 1200,
        timestamp: 100,
        counterparty: '淘宝',
        description: '购物',
        account: '零钱',
        originalData: 'raw',
        category: '日用百货',
        transactionCategory: '商户消费',
        note: '备注',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('TransactionRecord.copyWith', () {
    test('updates non-nullable fields', () {
      final base = TransactionRecord(
        id: 'id_1',
        source: 'WeChat',
        type: TransactionType.expense,
        amount: 1200,
        timestamp: 100,
        counterparty: '淘宝',
        description: '购物',
        account: '零钱',
        originalData: 'raw',
      );

      final updated = base.copyWith(
        source: 'Alipay',
        amount: 3400,
        description: '改描述',
      );

      expect(updated.source, equals('Alipay'));
      expect(updated.amount, equals(3400));
      expect(updated.description, equals('改描述'));
      expect(updated.id, equals(base.id));
    });

    test('supports clearing nullable fields', () {
      final base = TransactionRecord(
        id: 'id_1',
        source: 'WeChat',
        type: TransactionType.expense,
        amount: 1200,
        timestamp: 100,
        counterparty: '淘宝',
        description: '购物',
        account: '零钱',
        originalData: 'raw',
        category: '日用百货',
        transactionCategory: '商户消费',
        note: '备注',
      );

      final updated = base.copyWith(
        category: null,
        transactionCategory: null,
        note: null,
      );

      expect(updated.category, isNull);
      expect(updated.transactionCategory, isNull);
      expect(updated.note, isNull);
    });
  });
}
