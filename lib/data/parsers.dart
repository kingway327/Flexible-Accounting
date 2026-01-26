import 'dart:convert';
import 'dart:typed_data';

import 'package:charset_converter/charset_converter.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';

// ==================== DateFormat 缓存 ====================
// 避免重复创建 DateFormat 实例，提升解析性能

final _dateTimeFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
final _dateFormatter = DateFormat('yyyy-MM-dd 00:00:00');

class ParseResult {
  ParseResult({required this.records, required this.duplicates});

  final List<TransactionRecord> records;
  final int duplicates;
}

class FileTypeDetector {
  static String detectSource(String content) {
    if (content.contains('微信支付')) {
      return 'WeChat';
    }
    if (content.contains('支付宝')) {
      return 'Alipay';
    }
    return 'WeChat';
  }

  static String detectSourceFromRows(List<List<dynamic>> rows) {
    for (final row in rows) {
      for (final cell in row) {
        final text = cell.toString();
        if (text.contains('微信支付')) {
          return 'WeChat';
        }
        if (text.contains('支付宝')) {
          return 'Alipay';
        }
      }
    }
    return 'WeChat';
  }
}

class AlipayParser {
  static List<TransactionRecord> parse(String content) {
    final rows = const CsvToListConverter(shouldParseNumbers: false)
        .convert(content, eol: '\n');
    return parseRows(rows);
  }

  static List<TransactionRecord> parseRows(List<List<dynamic>> rows) {
    final headerIndex = _findHeaderIndex(rows, '交易订单号');
    if (headerIndex == -1) {
      return [];
    }
    final header = rows[headerIndex];
    final tradeNoIndex = header.indexOf('交易订单号');
    final timeIndex = header.indexOf('交易时间');
    final categoryIndex = _findColumnIndex(header, ['交易分类', '商品分类']);
    final counterpartyIndex = header.indexOf('交易对方');
    final descriptionIndex = header.indexOf('商品说明');
    final typeIndex = header.indexOf('收/支');
    final amountIndex = header.indexOf('金额');
    final accountIndex = header.indexOf('收/付款方式');
    final statusIndex = header.indexOf('交易状态');

    final records = <TransactionRecord>[];
    for (var i = headerIndex + 1; i < rows.length; i += 1) {
      final row = rows[i];
      if (row.length <= tradeNoIndex || tradeNoIndex < 0) {
        continue;
      }
      final tradeNo = _safeCell(row, tradeNoIndex).replaceAll(' ', '');
      if (tradeNo.isEmpty) {
        continue;
      }
      final status = _safeCell(row, statusIndex);
      final rawType = _safeCell(row, typeIndex);
      final type = _mapAlipayType(rawType, status);
      final amount = _parseAmount(_safeCell(row, amountIndex));
      final timestamp = _parseTime(_safeCell(row, timeIndex));
      final category = _safeCell(row, categoryIndex);
      
      // 支付宝：category = 交易分类（餐饮美食等），transactionCategory = category（用于筛选）
      final record = TransactionRecord(
        id: 'ALIPAY_$tradeNo',
        source: 'Alipay',
        type: type,
        amount: amount,
        timestamp: timestamp,
        counterparty: _safeCell(row, counterpartyIndex),
        description: _safeCell(row, descriptionIndex),
        account: _safeCell(row, accountIndex),
        originalData: encodeOriginalData(row),
        category: category.isNotEmpty ? category : null,
        transactionCategory: category.isNotEmpty ? category : null, // 使用交易分类作为筛选依据
      );
      records.add(record);
    }
    return records;
  }

  static TransactionType _mapAlipayType(String rawType, String status) {
    if (status == '交易关闭') {
      return TransactionType.ignore;
    }
    if (rawType == '支出') {
      return TransactionType.expense;
    }
    if (rawType == '收入') {
      return TransactionType.income;
    }
    if (rawType == '不计收支') {
      return TransactionType.transfer;
    }
    return TransactionType.ignore;
  }
}

class WechatParser {
  static List<TransactionRecord> parse(String content) {
    final rows = const CsvToListConverter(shouldParseNumbers: false)
        .convert(content, eol: '\n');
    return parseRows(rows);
  }

  static List<TransactionRecord> parseRows(List<List<dynamic>> rows) {
    final headerIndex = _findHeaderIndex(rows, '交易单号');
    if (headerIndex == -1) {
      return [];
    }
    final header = rows[headerIndex];
    final tradeNoIndex = header.indexOf('交易单号');
    final timeIndex = header.indexOf('交易时间');
    final transactionTypeIndex = header.indexOf('交易类型');
    final counterpartyIndex = header.indexOf('交易对方');
    final descriptionIndex = header.indexOf('商品');
    final directionIndex = header.indexOf('收/支');
    final amountIndex = header.indexOf('金额(元)');
    final accountIndex = header.indexOf('支付方式');
    final statusIndex = header.indexOf('当前状态');

    final records = <TransactionRecord>[];
    for (var i = headerIndex + 1; i < rows.length; i += 1) {
      final row = rows[i];
      if (row.length <= tradeNoIndex || tradeNoIndex < 0) {
        continue;
      }
      final tradeNo = _safeCell(row, tradeNoIndex).replaceAll(' ', '');
      if (tradeNo.isEmpty) {
        continue;
      }
      final status = _safeCell(row, statusIndex);
      final direction = _safeCell(row, directionIndex);
      final description = _safeCell(row, descriptionIndex);
      final transactionType = _safeCell(row, transactionTypeIndex);
      final type = _mapWechatType(
        direction,
        status,
        _cleanTransactionType(direction, status, description),
      );
      final amount = _parseAmount(_safeCell(row, amountIndex));
      final timestamp = _parseTime(_safeCell(row, timeIndex));
      
      // 微信：category = 交易类型（用于分析），transactionCategory = 交易类型（用于筛选）
      // 两者相同，因为微信只有交易类型字段
      final record = TransactionRecord(
        id: 'WECHAT_$tradeNo',
        source: 'WeChat',
        type: type,
        amount: amount,
        timestamp: timestamp,
        counterparty: _safeCell(row, counterpartyIndex),
        description: description,
        account: _safeCell(row, accountIndex),
        originalData: encodeOriginalData(row),
        category: transactionType.isNotEmpty ? transactionType : null,
        transactionCategory: transactionType.isNotEmpty ? transactionType : null,
      );
      records.add(record);
    }
    return records;
  }

  static TransactionType _mapWechatType(
    String direction,
    String status,
    String description,
  ) {
    // 清洗交易类型：如果包含"-退款"后缀，统一归为"退款"
    final cleanedType = _cleanTransactionType(direction, status, description);
    
    if (cleanedType == '支出') {
      return TransactionType.expense;
    }
    if (cleanedType == '收入') {
      return TransactionType.income;
    }
    if (cleanedType == '不计收支' || cleanedType == '退款') {
      return TransactionType.ignore;
    }
    return TransactionType.ignore;
  }

  /// 清洗微信交易类型
  /// 将"转账-退款"等类型统一为"退款"
  static String _cleanTransactionType(
    String direction,
    String status,
    String description,
  ) {
    final type = direction; // 优先使用"收/支"字段判断
    
    // 如果包含"-退款"后缀，统一归为"退款"
    if (type.contains('-退款')) {
      return '退款';
    }
    
    return type;
  }
}

Future<String> decodeCsvBytes(Uint8List bytes) async {
  try {
    return await CharsetConverter.decode('gbk', bytes);
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}

List<List<dynamic>> decodeExcelBytes(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final rows = <List<dynamic>>[];
  for (final sheet in excel.tables.values) {
    for (final row in sheet.rows) {
      rows.add(row.map(_cellToText).toList());
    }
    if (rows.isNotEmpty) {
      break;
    }
  }
  return rows;
}

int _findHeaderIndex(List<List<dynamic>> rows, String headerName) {
  for (var i = 0; i < rows.length; i += 1) {
    if (rows[i].contains(headerName)) {
      return i;
    }
  }
  return -1;
}

String _safeCell(List<dynamic> row, int index) {
  if (index < 0 || index >= row.length) {
    return '';
  }
  return row[index].toString().trim();
}

int _parseAmount(String raw) {
  final cleaned = raw.replaceAll('¥', '').replaceAll(',', '').trim();
  final value = double.tryParse(cleaned) ?? 0.0;
  return (value * 100).round();
}

int _parseTime(String raw) {
  if (raw.isEmpty) {
    return 0;
  }
  // 使用缓存的 DateFormat 实例
  final parsed = _dateTimeFormatter.parse(raw, true);
  return parsed.millisecondsSinceEpoch;
}

String _cellToText(Data? cell) {
  if (cell == null || cell.value == null) {
    return '';
  }
  final value = cell.value;
  if (value is DateTimeCellValue) {
    final dt = value.asDateTimeLocal();
    // 使用缓存的 DateFormat 实例
    return _dateTimeFormatter.format(dt);
  }
  if (value is DateCellValue) {
    final dt = value.asDateTimeLocal();
    // 使用缓存的 DateFormat 实例
    return _dateFormatter.format(dt);
  }
  if (value is TimeCellValue) {
    return value.toString();
  }
  return value.toString().trim();
}

/// 查找列索引，支持多个可能的列名
int _findColumnIndex(List<dynamic> header, List<String> possibleNames) {
  for (final name in possibleNames) {
    final index = header.indexOf(name);
    if (index >= 0) {
      return index;
    }
  }
  return -1;
}
