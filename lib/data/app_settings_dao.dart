import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';

class AppSettingsDao {
  AppSettingsDao._();

  static final AppSettingsDao instance = AppSettingsDao._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// 获取首页上次查看的年月（若不存在则返回 null）
  Future<Map<String, int>?> getHomeLastViewedMonthYear() async {
    final db = await _db;
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
    final db = await _db;
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

  /// 获取首页“按年”模式上次选择的年份（若不存在则返回 null）
  Future<int?> getHomeLastViewedYearModeYear() async {
    final db = await _db;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['home_last_viewed_year_mode_year'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return int.tryParse((rows.first['value'] as String?) ?? '');
  }

  /// 保存首页“按年”模式上次选择的年份
  Future<void> setHomeLastViewedYearModeYear({required int year}) async {
    final db = await _db;
    await db.insert(
      'app_settings',
      {
        'key': 'home_last_viewed_year_mode_year',
        'value': '$year',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取首页上次使用的时间筛选模式（按月/按年）
  /// 若不存在返回 null
  Future<bool?> getHomeLastFilterByYear() async {
    final db = await _db;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['home_last_filter_by_year'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final value = rows.first['value'] as String;
    return value == '1' || value.toLowerCase() == 'true';
  }

  /// 保存首页当前时间筛选模式（按月/按年）
  Future<void> setHomeLastFilterByYear({required bool filterByYear}) async {
    final db = await _db;
    await db.insert(
      'app_settings',
      {
        'key': 'home_last_filter_by_year',
        'value': filterByYear ? '1' : '0',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 启动动画总开关（默认 false）
  Future<bool> getStartupAnimationEnabled() async {
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
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
    final db = await _db;
    await db.insert(
      'app_settings',
      {
        'key': 'home_icon_guide_shown_once',
        'value': '1',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取分析页面上次的状态
  /// 返回 Map: {tabIndex, weekOffset, isExpense, selectedYearlyMonth,
  /// selectedYear, selectedMonth, selectedYearlyYear}
  /// 若某个值不存在则返回 null
  Future<Map<String, dynamic>> getAnalysisLastViewState() async {
    final db = await _db;
    final rows = await db.query(
      'app_settings',
      columns: ['key', 'value'],
      where: 'key IN (?, ?, ?, ?, ?, ?, ?)',
      whereArgs: [
        'analysis_last_tab_index',
        'analysis_last_week_offset',
        'analysis_last_is_expense',
        'analysis_last_yearly_month',
        'analysis_last_selected_year',
        'analysis_last_selected_month',
        'analysis_last_yearly_year',
      ],
    );

    final result = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String?;
      final value = row['value'] as String?;
      if (key == null || value == null) continue;

      switch (key) {
        case 'analysis_last_tab_index':
          result['tabIndex'] = int.tryParse(value);
        case 'analysis_last_week_offset':
          result['weekOffset'] = int.tryParse(value);
        case 'analysis_last_is_expense':
          result['isExpense'] = value == '1' || value.toLowerCase() == 'true';
        case 'analysis_last_yearly_month':
          result['selectedYearlyMonth'] = int.tryParse(value);
        case 'analysis_last_selected_year':
          result['selectedYear'] = int.tryParse(value);
        case 'analysis_last_selected_month':
          result['selectedMonth'] = int.tryParse(value);
        case 'analysis_last_yearly_year':
          result['selectedYearlyYear'] = int.tryParse(value);
      }
    }

    return result;
  }

  /// 保存分析页面状态
  Future<void> setAnalysisLastViewState({
    int? tabIndex,
    int? weekOffset,
    bool? isExpense,
    int? selectedYearlyMonth,
    int? selectedYear,
    int? selectedMonth,
    int? selectedYearlyYear,
  }) async {
    final db = await _db;
    final batch = db.batch();

    if (tabIndex != null) {
      batch.insert(
        'app_settings',
        {'key': 'analysis_last_tab_index', 'value': '$tabIndex'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (weekOffset != null) {
      batch.insert(
        'app_settings',
        {'key': 'analysis_last_week_offset', 'value': '$weekOffset'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (isExpense != null) {
      batch.insert(
        'app_settings',
        {'key': 'analysis_last_is_expense', 'value': isExpense ? '1' : '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (selectedYearlyMonth != null) {
      batch.insert(
        'app_settings',
        {'key': 'analysis_last_yearly_month', 'value': '$selectedYearlyMonth'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (selectedYear != null) {
      batch.insert(
        'app_settings',
        {'key': 'analysis_last_selected_year', 'value': '$selectedYear'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (selectedMonth != null && selectedMonth >= 1 && selectedMonth <= 12) {
      batch.insert(
        'app_settings',
        {'key': 'analysis_last_selected_month', 'value': '$selectedMonth'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (selectedYearlyYear != null) {
      batch.insert(
        'app_settings',
        {'key': 'analysis_last_yearly_year', 'value': '$selectedYearlyYear'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    if (batch.length > 0) {
      await batch.commit(noResult: true);
    }
  }
}
