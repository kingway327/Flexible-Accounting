import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

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
  // ignore: unused_element
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
}
