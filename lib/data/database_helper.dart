import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// 微信交易类型（8 类，包含退款处理）
const kWechatFilterTypes = [
  '商户消费',
  '红包',
  '转账',
  '群收款',
  '二维码收付款',
  '充值提现',
  '信用卡还款',
  '退款',
];

/// 支付宝交易分类（39 类）
const kAlipayFilterTypes = [
  // 日常消费
  '餐饮美食',
  '服饰装扮',
  '日用百货',
  '家居家装',
  '数码电器',
  '运动户外',
  '美容美发',
  '母婴亲子',
  '宠物',
  '交通出行',
  '爱车养车',
  '住房物业',
  '酒店旅游',
  '文化休闲',
  '教育培训',
  '医疗健康',
  '生活服务',
  '公共服务',
  '商业服务',
  '公益捐赠',
  '互助保障',
  // 金融
  '投资理财',
  '保险',
  '信用借还',
  '充值缴费',
  // 潜账相关
  '收入',
  '转账红包',
  '亲友代付',
  '账户存取',
  '退款',
  // 其他
  '其他',
];

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _databaseName = 'finance.db';
  static const _databaseVersion = 10; // 修复「自定义」分组的 is_system 标记

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
        // 预置默认分组
        await _insertDefaultCategoryGroups(db);
        // 预置默认筛选类型
        await _insertDefaultFilterTypes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE transactions ADD COLUMN transaction_category TEXT');
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
          await db.execute('ALTER TABLE custom_categories ADD COLUMN group_id INTEGER');
          await db.execute('ALTER TABLE filter_types ADD COLUMN group_id INTEGER');

          // 为已有的筛选类型分配分组
          await _assignFilterTypesToGroups(db);
        }
        if (oldVersion < 8) {
          // 版本8: 为已存在的 category_groups 表添加 is_system 字段
          // 先尝试添加字段（如果表已存在且没有该字段）
          try {
            await db.execute('ALTER TABLE category_groups ADD COLUMN is_system INTEGER NOT NULL DEFAULT 0');
          } catch (_) {
            // 字段可能已存在，忽略错误
          }
          // 标记微信、支付宝为系统分组，自定义为非系统分组
          await db.execute("UPDATE category_groups SET is_system = 1 WHERE name IN ('微信', '支付宝')");
          await db.execute("UPDATE category_groups SET is_system = 0 WHERE name = '自定义'");

          // 为已存在的筛选类型分配分组
          await _assignFilterTypesToGroups(db);
        }
        if (oldVersion < 9) {
          // 版本9: 重新分配筛选类型的分组（修复之前分组逻辑不完整的问题）
          await _assignFilterTypesToGroups(db);
          // 修复：确保「自定义」分组的 is_system = 0
          await db.execute("UPDATE category_groups SET is_system = 0 WHERE name = '自定义'");
        }
        if (oldVersion < 10) {
          // 版本10: 再次确保「自定义」分组的 is_system = 0（修复之前可能遗漏的问题）
          await db.execute("UPDATE category_groups SET is_system = 0 WHERE name = '自定义'");
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
      for (final g in groups)
        g['name'] as String: g['id'] as int,
    };
    final wechatGroupId = groupMap['微信'];
    final alipayGroupId = groupMap['支付宝'];
    final customGroupId = groupMap['自定义'];

    final batch = db.batch();
    for (var i = 0; i < kWechatFilterTypes.length + kAlipayFilterTypes.length; i++) {
      final name = i < kWechatFilterTypes.length
          ? kWechatFilterTypes[i]
          : kAlipayFilterTypes[i - kWechatFilterTypes.length];
      int? groupId;
      if (kWechatFilterTypes.contains(name) && wechatGroupId != null) {
        groupId = wechatGroupId;
      } else if (kAlipayFilterTypes.contains(name) && alipayGroupId != null) {
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
      for (final g in groups)
        g['name'] as String: g['id'] as int,
    };
    final wechatGroupId = groupMap['微信'];
    final alipayGroupId = groupMap['支付宝'];
    final customGroupId = groupMap['自定义'];

    if (wechatGroupId == null || alipayGroupId == null || customGroupId == null) {
      return;
    }

    // 批量更新
    final batch = db.batch();

    // 更新微信类型的分组
    for (final name in kWechatFilterTypes) {
      batch.update(
        'filter_types',
        {'group_id': wechatGroupId},
        where: 'name = ?',
        whereArgs: [name],
      );
    }

    // 更新支付宝类型的分组
    for (final name in kAlipayFilterTypes) {
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
  Future<int> insertCustomCategory(String name) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    // 获取当前最大 sort_order
    final maxOrderResult = await db.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM custom_categories',
    );
    final maxOrder = (maxOrderResult.first['max_order'] as int?) ?? 0;
    return db.insert(
      'custom_categories',
      {
        'name': name,
        'sort_order': maxOrder + 1,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 更新自定义分类名称
  Future<int> updateCustomCategory(int id, String newName) async {
    final db = await database;
    return db.update(
      'custom_categories',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除自定义分类
  Future<int> deleteCustomCategory(int id) async {
    final db = await database;
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

  /// 添加筛选类型（自动分配到对应分组）
  /// 使用 main.dart 中定义的完整分类列表（kWechatTransactionTypes 和 kAlipayCategories）
  Future<int> insertFilterType(String name) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 自动分配分组：微信类型 → 微信分组，支付宝类型 → 支付宝分组
    final groups = await db.query('category_groups', columns: ['id', 'name']);
    final groupMap = {for (final g in groups) g['name'] as String: g['id'] as int};

    final wechatGroupId = groupMap['微信'];
    final alipayGroupId = groupMap['支付宝'];
    final customGroupId = groupMap['自定义'];

    // 根据筛选类型名称决定分组
    int? groupId;
    if (kWechatFilterTypes.contains(name) && wechatGroupId != null) {
      groupId = wechatGroupId;
    } else if (kAlipayFilterTypes.contains(name) && alipayGroupId != null) {
      groupId = alipayGroupId;
    } else if (customGroupId != null) {
      groupId = customGroupId;
    }

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
  /// 使用 main.dart 中定义的完整分类列表（kWechatTransactionTypes 和 kAlipayCategories）
  Future<int> updateFilterType(int id, String newName) async {
    final db = await database;

    // 获取分组映射
    final groups = await db.query('category_groups', columns: ['id', 'name']);
    final groupMap = {for (final g in groups) g['name'] as String: g['id'] as int};

    final wechatGroupId = groupMap['微信'];
    final alipayGroupId = groupMap['支付宝'];
    final customGroupId = groupMap['自定义'];

    // 根据新名称决定分组
    int? groupId;
    if (kWechatFilterTypes.contains(newName) && wechatGroupId != null) {
      groupId = wechatGroupId;
    } else if (kAlipayFilterTypes.contains(newName) && alipayGroupId != null) {
      groupId = alipayGroupId;
    } else if (customGroupId != null) {
      groupId = customGroupId;
    }

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
  Future<int> deleteFilterType(int id) async {
    final db = await database;
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
    await db.update('custom_categories', {'group_id': null}, where: 'group_id = ?', whereArgs: [id]);
    await db.update('filter_types', {'group_id': null}, where: 'group_id = ?', whereArgs: [id]);
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
  Future<int> updateCustomCategoryGroup(int categoryId, int? groupId) async {
    final db = await database;
    return db.update(
      'custom_categories',
      {'group_id': groupId},
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }
}
