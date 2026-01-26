import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

/// 导出服务：支持导出账单为 CSV 格式
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  final _dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// 导出账单为 CSV 并分享
  /// [year] 和 [month] 用于文件命名
  /// [filterByYear] 为 true 时文件名只包含年份，否则包含年月
  Future<bool> exportToCsv(
    List<TransactionRecord> records, {
    required int year,
    int? month,
    required bool filterByYear,
  }) async {
    if (records.isEmpty) {
      return false;
    }

    try {
      // 构建 CSV 数据
      final rows = <List<String>>[
        // 表头
        [
          '交易时间',
          '交易类型',
          '金额(元)',
          '交易对方',
          '商品说明',
          '收支分类',
          '交易分类',
          '支付方式',
          '来源',
        ],
        // 数据行
        ...records.map((record) {
          final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
          final typeStr = _getTypeString(record.type);
          final amount = (record.amount / 100).toStringAsFixed(2);

          return [
            _dateFormatter.format(time),
            typeStr,
            amount,
            record.counterparty,
            record.description,
            record.category ?? '',
            record.transactionCategory ?? '',
            record.account,
            record.source == 'Alipay' ? '支付宝' : '微信',
          ];
        }),
      ];

      // 转换为 CSV 字符串
      const converter = ListToCsvConverter();
      final csvString = converter.convert(rows);

      // 添加 BOM 以支持 Excel 正确识别 UTF-8
      final csvWithBom = '\uFEFF$csvString';

      // 保存到临时文件
      final directory = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd').format(now);
      
      // 文件名格式：账单导出_年份(月份)_当前日期.csv
      String fileName;
      if (filterByYear) {
        fileName = '账单导出_$year年_$dateStr.csv';
      } else {
        final monthStr = month != null ? '$month'.padLeft(2, '0') : '';
        fileName = '账单导出_$year年$monthStr月_$dateStr.csv';
      }
      
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvWithBom);

      // 使用系统分享
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '账单导出',
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 导出指定月份的账单
  Future<bool> exportMonthToCsv(
    List<TransactionRecord> allRecords, {
    required int year,
    required int month,
  }) async {
    final filtered = allRecords.where((record) {
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      return date.year == year && date.month == month;
    }).toList();

    return exportToCsv(
      filtered,
      year: year,
      month: month,
      filterByYear: false,
    );
  }

  String _getTypeString(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
      case TransactionType.ignore:
        return '不计收支';
    }
  }
}
