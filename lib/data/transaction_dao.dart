import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'database_helper.dart';

class TransactionDao {
  TransactionDao._();

  static final TransactionDao instance = TransactionDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// 批量插入交易记录（使用 Batch 优化性能）
  Future<int> insertTransactions(List<TransactionRecord> records) async {
    if (records.isEmpty) {
      return 0;
    }
    final db = await _db;
    var inserted = 0;

    // 使用 batch 批量插入，性能比循环单条插入快10倍以上
    final batch = db.batch();
    for (final record in records) {
      batch.insert(
        'transactions',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // 执行批量操作，noResult: false 以获取每条插入的结果
    final results = await batch.commit(noResult: false);

    // 统计成功插入的数量（非0表示成功插入）
    for (final result in results) {
      if (result is int && result > 0) {
        inserted += 1;
      }
    }

    return inserted;
  }

  Future<List<TransactionRecord>> fetchTransactions() async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      orderBy: 'timestamp DESC',
    );
    return rows.map(TransactionRecord.fromMap).toList();
  }

  Future<List<TransactionRecord>> fetchTransactionsWithFilters({
    String? source,
    int? year,
    int? month,
    bool filterByYear = false,
    String? type,
    Set<String>? categories,
    String? searchQuery,
  }) async {
    final db = await _db;

    final whereClauses = <String>[];
    final whereArgs = <Object?>[];

    if (source != null && source.isNotEmpty) {
      whereClauses.add('source = ?');
      whereArgs.add(source);
    }

    if (year != null) {
      late final DateTime start;
      late final DateTime end;
      if (filterByYear || month == null) {
        start = DateTime(year, 1, 1);
        end = DateTime(year + 1, 1, 1);
      } else {
        start = DateTime(year, month, 1);
        end = DateTime(year, month + 1, 1);
      }
      whereClauses.add('timestamp >= ? AND timestamp < ?');
      whereArgs.add(start.millisecondsSinceEpoch);
      whereArgs.add(end.millisecondsSinceEpoch);
    }

    if (type != null && type.isNotEmpty) {
      whereClauses.add('type = ?');
      whereArgs.add(type.toUpperCase());
    }

    if (categories != null && categories.isNotEmpty) {
      final categoryClauses = <String>[];
      for (final category in categories) {
        categoryClauses.add('transaction_category LIKE ?');
        whereArgs.add('%$category%');
      }
      whereClauses.add('(${categoryClauses.join(' OR ')})');
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final normalized = searchQuery.toLowerCase();
      whereClauses.add(
        '(LOWER(counterparty) LIKE ? OR LOWER(description) LIKE ? OR LOWER(COALESCE(category, "")) LIKE ?)',
      );
      whereArgs.add('%$normalized%');
      whereArgs.add('%$normalized%');
      whereArgs.add('%$normalized%');
    }

    final where = whereClauses.isEmpty ? null : whereClauses.join(' AND ');
    final rows = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    return rows.map(TransactionRecord.fromMap).toList();
  }

  /// 清空所有交易记录
  Future<int> clearAllTransactions() async {
    final db = await _db;
    return db.delete('transactions');
  }

  /// 更新交易记录（分类、备注）
  Future<int> updateTransaction({
    required String id,
    String? category,
    String? note,
  }) async {
    final db = await _db;
    final updates = <String, Object?>{};
    if (category != null) {
      updates['category'] = category;
    }
    if (note != null) {
      updates['note'] = note;
    }
    if (updates.isEmpty) {
      return 0;
    }
    return db.update(
      'transactions',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取单条交易记录
  Future<TransactionRecord?> fetchTransaction(String id) async {
    final db = await _db;
    final rows = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TransactionRecord.fromMap(rows.first);
  }

  Future<Map<String, int>> fetchMonthlySummary(DateTime month) async {
    final db = await _db;
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final rows = await db.rawQuery(
      '''
        SELECT type, SUM(amount) as total
        FROM transactions
        WHERE timestamp >= ? AND timestamp < ?
        GROUP BY type
      ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    var expense = 0;
    var income = 0;
    for (final row in rows) {
      final type = (row['type'] as String).toUpperCase();
      final total = (row['total'] as int?) ?? 0;
      if (type == 'EXPENSE') {
        expense = total;
      } else if (type == 'INCOME') {
        income = total;
      }
    }
    return {'expense': expense, 'income': income};
  }

  /// 批量更新交易记录的分类
  Future<int> batchUpdateCategory(List<String> ids, String category) async {
    if (ids.isEmpty) return 0;
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.rawUpdate(
      'UPDATE transactions SET category = ? WHERE id IN ($placeholders)',
      [category, ...ids],
    );
  }

  /// 批量更新交易记录的备注
  Future<int> batchUpdateNote(List<String> ids, String note) async {
    if (ids.isEmpty) return 0;
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.rawUpdate(
      'UPDATE transactions SET note = ? WHERE id IN ($placeholders)',
      [note, ...ids],
    );
  }
}
