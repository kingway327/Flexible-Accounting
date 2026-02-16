import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../constants/categories.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _databaseName = 'finance.db';
  static const _databaseVersion = 11; // 新增应用设置表

  Database? _database;

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }
    final db = await _initDatabase();
    _database = db;
    return db;
  }

  /// 根据筛选类型名称解析应归属的系统分组 ID（纯计算，不查数据库）
  ///
  /// 微信类型 → 微信分组，支付宝类型 → 支付宝分组，
  /// 非系统分类返回 [fallbackGroupId]（默认 null）。
  static int? resolveGroupIdFromMap(
    String name,
    Map<String, int> groupMap, {
    int? fallbackGroupId,
  }) {
    if (kWechatTransactionTypes.contains(name)) {
      return groupMap['微信'];
    } else if (kAlipayCategories.contains(name)) {
      return groupMap['支付宝'];
    }
    return fallbackGroupId;
  }

  /// 查询数据库获取分组名→ID 映射
  Future<Map<String, int>> _fetchGroupMap() async {
    final db = await database;
    final groups = await db.query('category_groups', columns: ['id', 'name']);
    return {for (final g in groups) g['name'] as String: g['id'] as int};
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            source TEXT NOT NULL,
            type TEXT NOT NULL,
            amount INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            counterparty TEXT NOT NULL,
            description TEXT NOT NULL,
            account TEXT NOT NULL,
            original_data TEXT NOT NULL,
            category TEXT,
            transaction_category TEXT,
            note TEXT
          )
        ''');
        // 添加索引以加速查询
        await _createIndexes(db);
        await db.execute('''
          CREATE TABLE custom_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            group_id INTEGER
          )
        ''');
        // 创建筛选类型表
        await db.execute('''
          CREATE TABLE filter_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            group_id INTEGER
          )
        ''');
        // 创建分类分组表
        await db.execute('''
          CREATE TABLE category_groups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            color INTEGER NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            is_system INTEGER NOT NULL DEFAULT 0
          )
        ''');
        // 创建应用设置表
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        // 预置默认分组
        await _insertDefaultCategoryGroups(db);
        // 预置默认筛选类型
        await _insertDefaultFilterTypes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE transactions ADD COLUMN transaction_category TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE transactions ADD COLUMN note TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS custom_categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
        }
        if (oldVersion < 5) {
          // 版本5: 添加索引以加速查询
          await _createIndexes(db);
        }
        if (oldVersion < 6) {
          // 版本6: 添加筛选类型表
          await db.execute('''
            CREATE TABLE IF NOT EXISTS filter_types (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
          // 预置默认筛选类型
          await _insertDefaultFilterTypes(db);
        }
        if (oldVersion < 7) {
          // 版本7: 添加分类分组表和 group_id 字段
          await db.execute('''
            CREATE TABLE IF NOT EXISTS category_groups (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL UNIQUE,
              color INTEGER NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              is_system INTEGER NOT NULL DEFAULT 0
            )
          ''');
          // 预置默认分组
          await _insertDefaultCategoryGroups(db);
          // 为现有表添加 group_id 字段
          await db.execute(
              'ALTER TABLE custom_categories ADD COLUMN group_id INTEGER');
          await db
              .execute('ALTER TABLE filter_types ADD COLUMN group_id INTEGER');

          // 为已有的筛选类型分配分组
          await _assignFilterTypesToGroups(db);
        }
        if (oldVersion < 8) {
          // 版本8: 为已存在的 category_groups 表添加 is_system 字段
          // 先尝试添加字段（如果表已存在且没有该字段）
          try {
            await db.execute(
                'ALTER TABLE category_groups ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0');
          } catch (_) {
            // 字段可能已存在，忽略错误
          }
          // 标记微信、支付宝为系统分组，自定义为非系统分组
          await db.execute(
              "UPDATE category_groups SET is_system = 1 WHERE name IN ('微信', '支付宝')");
          await db.execute(
              "UPDATE category_groups SET is_system = 0 WHERE name = '自定义'");

          // 为已存在的筛选类型分配分组
          await _assignFilterTypesToGroups(db);
        }
        if (oldVersion < 9) {
          // 版本9: 重新分配筛选类型的分组（修复之前分组逻辑不完整的问题）
          await _assignFilterTypesToGroups(db);
          // 修复：确保「自定义」分组的 is_system = 0
          await db.execute(
              "UPDATE category_groups SET is_system = 0 WHERE name = '自定义'");
        }
        if (oldVersion < 10) {
          // 版本10: 再次确保「自定义」分组的 is_system = 0（修复之前可能遗漏的问题）
          await db.execute(
              "UPDATE category_groups SET is_system = 0 WHERE name = '自定义'");
        }
        if (oldVersion < 11) {
          // 版本11: 新增应用设置表
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  /// 预置默认筛选类型（根据名称分配分组）
  static Future<void> _insertDefaultFilterTypes(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // 获取分组 ID
    final groups = await db.query('category_groups', columns: ['id', 'name']);
    final groupMap = {
      for (final g in groups) g['name'] as String: g['id'] as int,
    };
    final wechatGroupId = groupMap['微信'];
    final alipayGroupId = groupMap['支付宝'];
    final customGroupId = groupMap['自定义'];

    final batch = db.batch();
    for (var i = 0;
        i < kWechatTransactionTypes.length + kAlipayCategories.length;
        i++) {
      final name = i < kWechatTransactionTypes.length
          ? kWechatTransactionTypes[i]
          : kAlipayCategories[i - kWechatTransactionTypes.length];
      int? groupId;
      if (kWechatTransactionTypes.contains(name) && wechatGroupId != null) {
        groupId = wechatGroupId;
      } else if (kAlipayCategories.contains(name) && alipayGroupId != null) {
        groupId = alipayGroupId;
      } else if (customGroupId != null) {
        groupId = customGroupId;
      }

      batch.insert(
        'filter_types',
        {
          'name': name,
          'sort_order': i,
          'created_at': now,
          'group_id': groupId,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 为已存在的筛选类型分配分组
  static Future<void> _assignFilterTypesToGroups(Database db) async {
    // 获取分组 ID
    final groups = await db.query('category_groups', columns: ['id', 'name']);
    final groupMap = {
      for (final g in groups) g['name'] as String: g['id'] as int,
    };
    final wechatGroupId = groupMap['微信'];
    final alipayGroupId = groupMap['支付宝'];
    final customGroupId = groupMap['自定义'];

    if (wechatGroupId == null ||
        alipayGroupId == null ||
        customGroupId == null) {
      return;
    }

    // 批量更新
    final batch = db.batch();

    // 更新微信类型的分组
    for (final name in kWechatTransactionTypes) {
      batch.update(
        'filter_types',
        {'group_id': wechatGroupId},
        where: 'name = ?',
        whereArgs: [name],
      );
    }

    // 更新支付宝类型的分组
    for (final name in kAlipayCategories) {
      batch.update(
        'filter_types',
        {'group_id': alipayGroupId},
        where: 'name = ?',
        whereArgs: [name],
      );
    }

    await batch.commit(noResult: true);
  }

  /// 预置默认分类分组
  /// 微信绿: 0xFF4CAF50, 支付宝蓝: 0xFF1976D2, 自定义: 0xFF9E9E9E
  /// 注：微信、支付宝为系统分组，自定义为非系统分组
  static Future<void> _insertDefaultCategoryGroups(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaultGroups = [
      {'name': '微信', 'color': 0xFF4CAF50, 'sort_order': 0, 'is_system': 1},
      {'name': '支付宝', 'color': 0xFF1976D2, 'sort_order': 1, 'is_system': 1},
      {'name': '自定义', 'color': 0xFF9E9E9E, 'sort_order': 2, 'is_system': 0},
    ];
    final batch = db.batch();
    for (final group in defaultGroups) {
      batch.insert(
        'category_groups',
        {
          ...group,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 创建数据库索引以加速查询
  static Future<void> _createIndexes(Database db) async {
    // 时间戳索引 - 用于按时间范围查询和排序
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions(timestamp)',
    );
    // 类型索引 - 用于按收入/支出过滤
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)',
    );
    // 来源索引 - 用于按微信/支付宝过滤
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_source ON transactions(source)',
    );
    // 分类索引 - 用于按分类查询
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)',
    );
    // 复合索引 - 用于月度汇总查询 (type + timestamp)
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_transactions_type_timestamp ON transactions(type, timestamp)',
    );
  }

  /// 批量插入交易记录（使用 Batch 优化性能）
  Future<int> insertTransactions(List<TransactionRecord> records) async {
    if (records.isEmpty) {
      return 0;
    }
    final db = await database;
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
    final db = await database;
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
    final db = await database;

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
    final db = await database;
    return db.delete('transactions');
  }

  /// 更新交易记录（分类、备注）
  Future<int> updateTransaction({
    required String id,
    String? category,
    String? note,
  }) async {
    final db = await database;
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
    final db = await database;
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
    final db = await database;
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

  // ==================== 自定义分类相关方法 ====================

  /// 获取所有自定义分类
  Future<List<CustomCategory>> fetchCustomCategories() async {
    final db = await database;
    final rows = await db.query(
      'custom_categories',
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return rows.map(CustomCategory.fromMap).toList();
  }

  /// 添加自定义分类
  /// 同时添加到筛选类型表，保持两表状态一致
  Future<int> insertCustomCategory(String name) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    // 获取当前最大 sort_order
    final maxOrderResult = await db.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM custom_categories',
    );
    final maxOrder = (maxOrderResult.first['max_order'] as int?) ?? 0;

    final result = await db.insert(
      'custom_categories',
      {
        'name': name,
        'sort_order': maxOrder + 1,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // 同步添加到筛选类型（如果不存在）
    final filterExists = await isFilterTypeNameExists(name);
    if (!filterExists) {
      await insertFilterType(name);
    }

    return result;
  }

  /// 更新自定义分类名称
  /// 同时更新筛选类型中的同名记录，保持两表状态一致
  Future<int> updateCustomCategory(int id, String newName) async {
    final db = await database;
    // 先获取旧名称，用于同步更新筛选类型
    final rows = await db.query(
      'custom_categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
    );
    final oldName = rows.isNotEmpty ? rows.first['name'] as String : null;

    final result = await db.update(
      'custom_categories',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );

    // 同步更新筛选类型中的旧名称记录
    if (oldName != null && oldName != newName) {
      await db.update(
        'filter_types',
        {'name': newName},
        where: 'name = ?',
        whereArgs: [oldName],
      );
    }

    return result;
  }

  /// 删除自定义分类
  /// 同时删除筛选类型中的同名记录，保持两表状态一致
  Future<int> deleteCustomCategory(int id) async {
    final db = await database;
    // 先获取分类名称
    final rows = await db.query(
      'custom_categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      final name = rows.first['name'] as String;
      // 同步删除筛选类型中的同名记录
      await db.delete(
        'filter_types',
        where: 'name = ?',
        whereArgs: [name],
      );
    }
    return db.delete(
      'custom_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 检查分类名称是否已存在
  Future<bool> isCategoryNameExists(String name) async {
    final db = await database;
    final rows = await db.query(
      'custom_categories',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ==================== 筛选类型相关方法 ====================

  /// 获取所有筛选类型
  Future<List<FilterType>> fetchFilterTypes() async {
    final db = await database;
    final rows = await db.query(
      'filter_types',
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return rows.map(FilterType.fromMap).toList();
  }

  /// 添加筛选类型（系统分类自动分配到对应分组，用户自定义分类不分配分组）
  Future<int> insertFilterType(String name) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 使用共享方法解析分组
    final groupMap = await _fetchGroupMap();
    final groupId = resolveGroupIdFromMap(name, groupMap);

    // 获取当前最大 sort_order
    final maxOrderResult = await db.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM filter_types',
    );
    final maxOrder = (maxOrderResult.first['max_order'] as int?) ?? 0;

    return db.insert(
      'filter_types',
      {
        'name': name,
        'sort_order': maxOrder + 1,
        'created_at': now,
        if (groupId != null) 'group_id': groupId,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 更新筛选类型名称（自动更新分组）
  Future<int> updateFilterType(int id, String newName) async {
    final db = await database;

    // 使用共享方法解析分组（非系统分类回退到「自定义」分组）
    final groupMap = await _fetchGroupMap();
    final groupId = resolveGroupIdFromMap(
      newName,
      groupMap,
      fallbackGroupId: groupMap['自定义'],
    );

    return db.update(
      'filter_types',
      {
        'name': newName,
        if (groupId != null) 'group_id': groupId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除筛选类型
  /// 如果是用户自定义的筛选类型，同时删除自定义分类中的同名记录
  Future<int> deleteFilterType(int id) async {
    final db = await database;
    // 先获取筛选类型名称
    final rows = await db.query(
      'filter_types',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      final name = rows.first['name'] as String;
      // 只删除自定义分类（非系统分类）
      if (!kWechatTransactionTypes.contains(name) &&
          !kAlipayCategories.contains(name)) {
        await db.delete(
          'custom_categories',
          where: 'name = ?',
          whereArgs: [name],
        );
      }
    }
    return db.delete(
      'filter_types',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 检查筛选类型名称是否已存在
  Future<bool> isFilterTypeNameExists(String name) async {
    final db = await database;
    final rows = await db.query(
      'filter_types',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ==================== 批量更新方法 ====================

  /// 批量更新交易记录的分类
  Future<int> batchUpdateCategory(List<String> ids, String category) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.rawUpdate(
      'UPDATE transactions SET category = ? WHERE id IN ($placeholders)',
      [category, ...ids],
    );
  }

  /// 批量更新交易记录的备注
  Future<int> batchUpdateNote(List<String> ids, String note) async {
    if (ids.isEmpty) return 0;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.rawUpdate(
      'UPDATE transactions SET note = ? WHERE id IN ($placeholders)',
      [note, ...ids],
    );
  }

  // ==================== 分类分组相关方法 ====================

  /// 获取所有分类分组
  Future<List<CategoryGroup>> fetchCategoryGroups() async {
    final db = await database;
    final rows = await db.query(
      'category_groups',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(CategoryGroup.fromMap).toList();
  }

  /// 添加分类分组
  Future<int> insertCategoryGroup(String name, int color) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxOrderResult = await db.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM category_groups',
    );
    final maxOrder = (maxOrderResult.first['max_order'] as int?) ?? 0;
    return db.insert(
      'category_groups',
      {
        'name': name,
        'color': color,
        'sort_order': maxOrder + 1,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 更新分类分组
  Future<int> updateCategoryGroup(int id, {String? name, int? color}) async {
    final db = await database;
    final updates = <String, Object?>{};
    if (name != null) updates['name'] = name;
    if (color != null) updates['color'] = color;
    if (updates.isEmpty) return 0;
    return db.update(
      'category_groups',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除分类分组
  Future<int> deleteCategoryGroup(int id) async {
    final db = await database;
    // 先将使用该分组的分类和筛选类型的 group_id 置空
    await db.update('custom_categories', {'group_id': null},
        where: 'group_id = ?', whereArgs: [id]);
    await db.update('filter_types', {'group_id': null},
        where: 'group_id = ?', whereArgs: [id]);
    return db.delete(
      'category_groups',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新筛选类型的分组
  Future<int> updateFilterTypeGroup(int filterTypeId, int? groupId) async {
    final db = await database;
    return db.update(
      'filter_types',
      {'group_id': groupId},
      where: 'id = ?',
      whereArgs: [filterTypeId],
    );
  }

  /// 更新自定义分类的分组
  /// 同时更新筛选类型中同名记录的分组，保持两表状态一致
  Future<int> updateCustomCategoryGroup(int categoryId, int? groupId) async {
    final db = await database;

    // 先获取分类名称
    final rows = await db.query(
      'custom_categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [categoryId],
    );

    if (rows.isNotEmpty) {
      final name = rows.first['name'] as String;
      // 同步更新筛选类型中同名记录的分组
      await db.update(
        'filter_types',
        {'group_id': groupId},
        where: 'name = ?',
        whereArgs: [name],
      );
    }

    return db.update(
      'custom_categories',
      {'group_id': groupId},
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  /// 获取首页上次查看的年月（若不存在则返回 null）
  Future<Map<String, int>?> getHomeLastViewedMonthYear() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['key', 'value'],
      where: 'key IN (?, ?)',
      whereArgs: ['home_last_viewed_year', 'home_last_viewed_month'],
    );
    if (rows.length < 2) {
      return null;
    }

    int? year;
    int? month;
    for (final row in rows) {
      final key = row['key'] as String?;
      final value = int.tryParse((row['value'] as String?) ?? '');
      if (value == null || key == null) continue;
      if (key == 'home_last_viewed_year') {
        year = value;
      } else if (key == 'home_last_viewed_month') {
        month = value;
      }
    }

    if (year == null || month == null || month < 1 || month > 12) {
      return null;
    }
    return {'year': year, 'month': month};
  }

  /// 保存首页上次查看的年月
  Future<void> setHomeLastViewedMonthYear({
    required int year,
    required int month,
  }) async {
    if (month < 1 || month > 12) {
      return;
    }
    final db = await database;
    final batch = db.batch();
    batch.insert(
      'app_settings',
      {
        'key': 'home_last_viewed_year',
        'value': '$year',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'app_settings',
      {
        'key': 'home_last_viewed_month',
        'value': '$month',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  /// 启动动画总开关（默认 false）
  Future<bool> getStartupAnimationEnabled() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['startup_animation_enabled'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    final value = rows.first['value'] as String;
    return value == '1' || value.toLowerCase() == 'true';
  }

  /// 设置启动动画总开关
  Future<void> setStartupAnimationEnabled(bool enabled) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {
        'key': 'startup_animation_enabled',
        'value': enabled ? '1' : '0',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 启动动画是否已展示过一次（用于“首次默认展示一次”）
  Future<bool> hasShownStartupAnimationOnce() async {
    final db = await database;
    final onceRows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['startup_animation_shown_once'],
      limit: 1,
    );
    if (onceRows.isNotEmpty) {
      final value = onceRows.first['value'] as String;
      return value == '1' || value.toLowerCase() == 'true';
    }

    // 兼容旧逻辑：历史上任一时段已播放过，则视为已展示
    final legacyRows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key IN (?, ?)',
      whereArgs: [
        'startup_animation_played_day',
        'startup_animation_played_night'
      ],
    );
    for (final row in legacyRows) {
      final value = row['value'] as String;
      if (value == '1' || value.toLowerCase() == 'true') {
        return true;
      }
    }
    return false;
  }

  /// 标记启动动画已展示一次
  Future<void> markStartupAnimationShownOnce() async {
    final db = await database;
    await db.insert(
      'app_settings',
      {
        'key': 'startup_animation_shown_once',
        'value': '1',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 当前时段启动动画是否已经播放过（用于默认“仅播放一次”策略）
  Future<bool> hasPlayedStartupAnimation({required bool isDaytime}) async {
    final db = await database;
    final key = isDaytime
        ? 'startup_animation_played_day'
        : 'startup_animation_played_night';
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    final value = rows.first['value'] as String;
    return value == '1' || value.toLowerCase() == 'true';
  }

  /// 标记当前时段启动动画已播放
  Future<void> markStartupAnimationPlayed({required bool isDaytime}) async {
    final db = await database;
    final key = isDaytime
        ? 'startup_animation_played_day'
        : 'startup_animation_played_night';
    await db.insert(
      'app_settings',
      {
        'key': key,
        'value': '1',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 首页图标功能提示总开关（默认 false）
  Future<bool> getHomeIconGuideEnabled() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['home_icon_guide_every_launch'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    final value = rows.first['value'] as String;
    return value == '1' || value.toLowerCase() == 'true';
  }

  /// 设置首页图标功能提示总开关
  Future<void> setHomeIconGuideEnabled(bool enabled) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {
        'key': 'home_icon_guide_every_launch',
        'value': enabled ? '1' : '0',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 兼容旧调用：是否每次启动都显示首页图标功能提示
  Future<bool> getHomeIconGuideEveryLaunchEnabled() async {
    return getHomeIconGuideEnabled();
  }

  /// 兼容旧调用：设置是否每次启动都显示首页图标功能提示
  Future<void> setHomeIconGuideEveryLaunchEnabled(bool enabled) async {
    await setHomeIconGuideEnabled(enabled);
  }

  /// 首页图标功能提示是否已经展示过一次（默认 false）
  Future<bool> hasShownHomeIconGuide() async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['home_icon_guide_shown_once'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return false;
    }
    final value = rows.first['value'] as String;
    return value == '1' || value.toLowerCase() == 'true';
  }

  /// 标记首页图标功能提示已展示一次
  Future<void> markHomeIconGuideShown() async {
    final db = await database;
    await db.insert(
      'app_settings',
      {
        'key': 'home_icon_guide_shown_once',
        'value': '1',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
