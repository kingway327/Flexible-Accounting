import 'package:flutter_test/flutter_test.dart';

import 'package:local_first_finance/data/parsers.dart';
import 'package:local_first_finance/models/models.dart';

void main() {
  group('FileTypeDetector', () {
    test('正确识别支付宝和微信文本格式', () {
      expect(FileTypeDetector.detectSource('这是支付宝账单导出内容'), 'Alipay');
      expect(FileTypeDetector.detectSource('这是微信支付账单导出内容'), 'WeChat');
    });

    test('正确识别表格行格式', () {
      expect(
        FileTypeDetector.detectSourceFromRows([
          ['标题', '支付宝交易明细'],
        ]),
        'Alipay',
      );
      expect(
        FileTypeDetector.detectSourceFromRows([
          ['标题', '微信支付交易明细'],
        ]),
        'WeChat',
      );
    });
  });

  group('AlipayParser.parseRows', () {
    test('解析支付宝行数据', () {
      final rows = [
        [
          '交易订单号',
          '交易时间',
          '交易分类',
          '交易对方',
          '商品说明',
          '收/支',
          '金额',
          '收/付款方式',
          '交易状态',
        ],
        [
          '202502170001',
          '2025-02-17 10:20:30',
          '餐饮美食',
          '某商户',
          '午餐',
          '支出',
          '12.34',
          '余额',
          '交易成功',
        ],
      ];

      final records = AlipayParser.parseRows(rows);

      expect(records.length, 1);
      final record = records.first;
      expect(record.id, 'ALIPAY_202502170001');
      expect(record.type, TransactionType.expense);
      expect(record.amount, 1234);
      expect(record.source, 'Alipay');
      expect(record.category, '餐饮美食');
      expect(record.transactionCategory, '餐饮美食');
      expect(record.timestamp, greaterThan(0));
    });
  });

  group('WechatParser.parseRows', () {
    test('解析微信行数据', () {
      final rows = [
        [
          '交易单号',
          '交易时间',
          '交易类型',
          '交易对方',
          '商品',
          '收/支',
          '金额(元)',
          '支付方式',
          '当前状态',
        ],
        [
          '420000000001',
          '2025-02-16 08:00:00',
          '商户消费',
          '某超市',
          '日用品',
          '支出',
          '25.00',
          '零钱',
          '支付成功',
        ],
      ];

      final records = WechatParser.parseRows(rows);

      expect(records.length, 1);
      final record = records.first;
      expect(record.id, 'WECHAT_420000000001');
      expect(record.type, TransactionType.expense);
      expect(record.amount, 2500);
      expect(record.source, 'WeChat');
      expect(record.category, '商户消费');
      expect(record.transactionCategory, '商户消费');
      expect(record.timestamp, greaterThan(0));
    });
  });
}
