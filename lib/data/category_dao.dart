import 'package:sqflite/sqflite.dart';

import '../constants/categories.dart';
import '../models/models.dart';
import 'database_helper.dart';

class CategoryDao {
  CategoryDao._();

  static final CategoryDao instance = CategoryDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<Map<String, int>> _fetchGroupMap() async {
    final db = await _db;
    final groups = await db.query('category_groups', columns: ['id', 'name']);
    return {for (final g in groups) g['name'] as String: g['id'] as int};
  }

  /// 获取所有自定义分类
  Future<List<CustomCategory>> fetchCustomCategories() async {
    final db = await _db;
    final rows = await db.query(
      'custom_categories',
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return rows.map(CustomCategory.fromMap).toList();
  }

  /// 添加自定义分类
  /// 同时添加到筛选类型表，保持两表状态一致
  Future<int> insertCustomCategory(String name) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
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

    final filterExists = await isFilterTypeNameExists(name);
    if (!filterExists) {
      await insertFilterType(name);
    }

    return result;
  }

  /// 更新自定义分类名称
  /// 同时更新筛选类型中的同名记录，保持两表状态一致
  Future<int> updateCustomCategory(int id, String newName) async {
    final db = await _db;
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
    final db = await _db;
    final rows = await db.query(
      'custom_categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      final name = rows.first['name'] as String;
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
    final db = await _db;
    final rows = await db.query(
      'custom_categories',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 获取所有筛选类型
  Future<List<FilterType>> fetchFilterTypes() async {
    final db = await _db;
    final rows = await db.query(
      'filter_types',
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return rows.map(FilterType.fromMap).toList();
  }

  /// 添加筛选类型（系统分类自动分配到对应分组，用户自定义分类不分配分组）
  Future<int> insertFilterType(String name) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final groupMap = await _fetchGroupMap();
    final groupId = DatabaseHelper.resolveGroupIdFromMap(name, groupMap);

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
    final db = await _db;

    final groupMap = await _fetchGroupMap();
    final groupId = DatabaseHelper.resolveGroupIdFromMap(
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
    final db = await _db;
    final rows = await db.query(
      'filter_types',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isNotEmpty) {
      final name = rows.first['name'] as String;
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
    final db = await _db;
    final rows = await db.query(
      'filter_types',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 获取所有分类分组
  Future<List<CategoryGroup>> fetchCategoryGroups() async {
    final db = await _db;
    final rows = await db.query(
      'category_groups',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(CategoryGroup.fromMap).toList();
  }

  /// 添加分类分组
  Future<int> insertCategoryGroup(String name, int color) async {
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
    final rows = await db.query(
      'custom_categories',
      columns: ['name'],
      where: 'id = ?',
      whereArgs: [categoryId],
    );

    if (rows.isNotEmpty) {
      final name = rows.first['name'] as String;
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
}
