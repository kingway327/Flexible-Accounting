import '../models/models.dart';

// ==================== 分析缓存系统 ====================

/// 分析数据缓存，避免重复遍历全部记录
/// 使用按年月索引的数据结构，将 O(n) 查询降为 O(1)
class AnalysisCache {
  AnalysisCache._();

  static final AnalysisCache instance = AnalysisCache._();

  // 缓存版本号，用于判断是否需要重建
  int _version = 0;

  // 按年月索引的记录：year -> month -> records
  final Map<int, Map<int, List<TransactionRecord>>> _monthlyIndex = {};

  // 按年索引的记录：year -> records
  final Map<int, List<TransactionRecord>> _yearlyIndex = {};

  // 按日期索引：'yyyy-MM-dd' -> records
  final Map<String, List<TransactionRecord>> _dailyIndex = {};

  // 数据范围缓存
  ({int minYear, int minMonth, int maxYear, int maxMonth})? _expenseRange;
  ({int minYear, int minMonth, int maxYear, int maxMonth})? _incomeRange;

  // 月度汇总缓存：'year-month-type' -> total
  final Map<String, int> _monthlyTotalCache = {};

  // 年度汇总缓存：'year-type' -> total
  final Map<String, int> _yearlyTotalCache = {};

  /// 获取当前缓存版本
  int get version => _version;

  /// 重建缓存（当数据变化时调用）
  void rebuild(List<TransactionRecord> records) {
    _version++;
    _monthlyIndex.clear();
    _yearlyIndex.clear();
    _dailyIndex.clear();
    _expenseRange = null;
    _incomeRange = null;
    _monthlyTotalCache.clear();
    _yearlyTotalCache.clear();

    int? expMinYear, expMinMonth, expMaxYear, expMaxMonth;
    int? incMinYear, incMinMonth, incMaxYear, incMaxMonth;

    for (final record in records) {
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      final year = date.year;
      final month = date.month;
      final day = date.day;

      // 按年月索引
      _monthlyIndex.putIfAbsent(year, () => {});
      _monthlyIndex[year]!.putIfAbsent(month, () => []);
      _monthlyIndex[year]![month]!.add(record);

      // 按年索引
      _yearlyIndex.putIfAbsent(year, () => []);
      _yearlyIndex[year]!.add(record);

      // 按日期索引
      final dateKey = '$year-$month-$day';
      _dailyIndex.putIfAbsent(dateKey, () => []);
      _dailyIndex[dateKey]!.add(record);

      // 更新数据范围
      if (record.type == TransactionType.expense) {
        if (expMinYear == null ||
            year < expMinYear ||
            (year == expMinYear && month < expMinMonth!)) {
          expMinYear = year;
          expMinMonth = month;
        }
        if (expMaxYear == null ||
            year > expMaxYear ||
            (year == expMaxYear && month > expMaxMonth!)) {
          expMaxYear = year;
          expMaxMonth = month;
        }
      } else {
        if (incMinYear == null ||
            year < incMinYear ||
            (year == incMinYear && month < incMinMonth!)) {
          incMinYear = year;
          incMinMonth = month;
        }
        if (incMaxYear == null ||
            year > incMaxYear ||
            (year == incMaxYear && month > incMaxMonth!)) {
          incMaxYear = year;
          incMaxMonth = month;
        }
      }
    }

    if (expMinYear != null) {
      _expenseRange = (
        minYear: expMinYear,
        minMonth: expMinMonth!,
        maxYear: expMaxYear!,
        maxMonth: expMaxMonth!
      );
    }
    if (incMinYear != null) {
      _incomeRange = (
        minYear: incMinYear,
        minMonth: incMinMonth!,
        maxYear: incMaxYear!,
        maxMonth: incMaxMonth!
      );
    }
  }

  /// 清空缓存
  void clear() {
    _version++;
    _monthlyIndex.clear();
    _yearlyIndex.clear();
    _dailyIndex.clear();
    _expenseRange = null;
    _incomeRange = null;
    _monthlyTotalCache.clear();
    _yearlyTotalCache.clear();
  }

  /// 获取指定月份的记录（O(1)查询）
  List<TransactionRecord> getMonthlyRecords(int year, int month) {
    return _monthlyIndex[year]?[month] ?? [];
  }

  /// 获取指定年份的记录（O(1)查询）
  List<TransactionRecord> getYearlyRecords(int year) {
    return _yearlyIndex[year] ?? [];
  }

  /// 获取指定日期的记录（O(1)查询）
  List<TransactionRecord> getDailyRecords(int year, int month, int day) {
    return _dailyIndex['$year-$month-$day'] ?? [];
  }

  /// 获取数据月份范围（O(1)查询）
  ({int minYear, int minMonth, int maxYear, int maxMonth})? getDataRange(
      bool isExpense) {
    return isExpense ? _expenseRange : _incomeRange;
  }

  /// 获取月度总金额（带缓存）
  int getMonthlyTotal(int year, int month, bool isExpense) {
    final key = '$year-$month-${isExpense ? 'exp' : 'inc'}';
    if (_monthlyTotalCache.containsKey(key)) {
      return _monthlyTotalCache[key]!;
    }

    final targetType =
        isExpense ? TransactionType.expense : TransactionType.income;
    final records = getMonthlyRecords(year, month);
    var total = 0;
    for (final record in records) {
      if (record.type == targetType) {
        total += record.amount;
      }
    }

    _monthlyTotalCache[key] = total;
    return total;
  }

  /// 获取年度总金额（带缓存）
  int getYearlyTotal(int year, bool isExpense) {
    final key = '$year-${isExpense ? 'exp' : 'inc'}';
    if (_yearlyTotalCache.containsKey(key)) {
      return _yearlyTotalCache[key]!;
    }

    final targetType =
        isExpense ? TransactionType.expense : TransactionType.income;
    final records = getYearlyRecords(year);
    var total = 0;
    for (final record in records) {
      if (record.type == targetType) {
        total += record.amount;
      }
    }

    _yearlyTotalCache[key] = total;
    return total;
  }

  /// 检查指定月份是否有数据（O(1)查询）
  bool hasMonthlyData(int year, int month, bool isExpense) {
    final targetType =
        isExpense ? TransactionType.expense : TransactionType.income;
    final records = getMonthlyRecords(year, month);
    return records.any((r) => r.type == targetType);
  }

  /// 检查指定年份是否有数据（O(1)查询）
  bool hasYearlyData(int year, bool isExpense) {
    final targetType =
        isExpense ? TransactionType.expense : TransactionType.income;
    final records = getYearlyRecords(year);
    return records.any((r) => r.type == targetType);
  }
}

// ==================== 数据模型 ====================

/// 每日汇总数据，供柱状图使用
class DailyTotal {
  DailyTotal({required this.day, required this.amount});

  final int day; // 1-31
  final int amount; // 单位：分
}

/// 分类汇总数据，供饼图和列表使用
class CategoryTotal {
  CategoryTotal({
    required this.category,
    required this.amount,
    required this.count,
  });

  final String category;
  final int amount; // 单位：分
  final int count; // 笔数
}

/// 获取指定月份的每日汇总
/// [records] 应该是已筛选到指定月份的记录
/// [isExpense] true=支出, false=收入
/// 优化：使用缓存索引，避免遍历全部记录
List<DailyTotal> getDailyTotals({
  required List<TransactionRecord> records,
  required int year,
  required int month,
  required bool isExpense,
}) {
  // 获取当月天数
  final daysInMonth = DateTime(year, month + 1, 0).day;

  // 初始化每日金额映射
  final dailyMap = <int, int>{};
  for (var i = 1; i <= daysInMonth; i++) {
    dailyMap[i] = 0;
  }

  // 优化：使用缓存获取当月记录
  final cache = AnalysisCache.instance;
  final monthlyRecords = cache.getMonthlyRecords(year, month);

  // 如果缓存为空，回退到原始方式
  final targetRecords = monthlyRecords.isNotEmpty ? monthlyRecords : records;

  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  for (final record in targetRecords) {
    if (record.type != targetType) continue;

    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year != year || date.month != month) continue;

    dailyMap[date.day] = (dailyMap[date.day] ?? 0) + record.amount;
  }

  // 转换为列表
  return dailyMap.entries
      .map((e) => DailyTotal(day: e.key, amount: e.value))
      .toList()
    ..sort((a, b) => a.day.compareTo(b.day));
}

/// 获取分类汇总
/// [records] 应该是已筛选到指定月份的记录
/// [isExpense] true=支出, false=收入
/// 优化：使用缓存索引，避免遍历全部记录
List<CategoryTotal> getCategoryTotals({
  required List<TransactionRecord> records,
  required int year,
  required int month,
  required bool isExpense,
}) {
  final categoryMap = <String, _CategoryAccumulator>{};

  // 优化：使用缓存获取当月记录
  final cache = AnalysisCache.instance;
  final monthlyRecords = cache.getMonthlyRecords(year, month);
  final targetRecords = monthlyRecords.isNotEmpty ? monthlyRecords : records;

  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  for (final record in targetRecords) {
    if (record.type != targetType) continue;

    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year != year || date.month != month) continue;

    // 使用 category 字段，如果为空则使用 "其他"
    final category =
        (record.category?.isNotEmpty == true) ? record.category! : '其他';

    if (!categoryMap.containsKey(category)) {
      categoryMap[category] = _CategoryAccumulator();
    }
    categoryMap[category]!.amount += record.amount;
    categoryMap[category]!.count += 1;
  }

  // 转换为列表并按金额降序排序
  return categoryMap.entries
      .map((e) => CategoryTotal(
            category: e.key,
            amount: e.value.amount,
            count: e.value.count,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
}

/// 计算指定月份的总金额
/// 优化：优先使用缓存
int getMonthlyTotal({
  required List<TransactionRecord> records,
  required int year,
  required int month,
  required bool isExpense,
}) {
  // 优化：尝试使用缓存
  final cache = AnalysisCache.instance;
  final monthlyRecords = cache.getMonthlyRecords(year, month);

  if (monthlyRecords.isNotEmpty) {
    return cache.getMonthlyTotal(year, month, isExpense);
  }

  // 回退到原始方式
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  var total = 0;

  for (final record in records) {
    if (record.type != targetType) continue;

    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year != year || date.month != month) continue;

    total += record.amount;
  }

  return total;
}

class _CategoryAccumulator {
  int amount = 0;
  int count = 0;
}

/// 月度汇总数据，供近5个月柱状图使用
class MonthlyTotal {
  MonthlyTotal({
    required this.year,
    required this.month,
    required this.amount,
    this.showYear = false,
  });

  final int year;
  final int month;
  final int amount; // 单位：分
  final bool showYear; // 是否显示年份

  /// 获取显示标签
  String get label {
    if (showYear) {
      return '$month月\n$year';
    }
    return '$month月';
  }
}

/// 获取近N个月的月度汇总
/// 选中月份默认居中（index=2），但会根据数据边界智能调整：
/// - 如果选中月份之后没有数据，则选中月份在最右边
/// - 如果选中月份之前没有数据，则选中月份在最左边
/// 跨年时会在12月和1月都显示年份，优化用户体验
List<MonthlyTotal> getRecentMonthlyTotals({
  required List<TransactionRecord> records,
  required int year,
  required int month,
  required bool isExpense,
  int monthCount = 5,
}) {
  final results = <MonthlyTotal>[];
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final cache = AnalysisCache.instance;

  // 获取数据的月份范围
  final dataRange = getDataMonthRange(records: records, isExpense: isExpense);

  // 计算选中月份之后有多少个月有数据
  int monthsAfterWithData = 0;
  if (dataRange != null) {
    // 计算选中月份到最晚数据月份的距离
    final selectedMonthValue = year * 12 + month;
    final maxMonthValue = dataRange.maxYear * 12 + dataRange.maxMonth;
    monthsAfterWithData = maxMonthValue - selectedMonthValue;
    if (monthsAfterWithData < 0) monthsAfterWithData = 0;
  }

  // 计算选中月份之前有多少个月有数据
  int monthsBeforeWithData = 0;
  if (dataRange != null) {
    final selectedMonthValue = year * 12 + month;
    final minMonthValue = dataRange.minYear * 12 + dataRange.minMonth;
    monthsBeforeWithData = selectedMonthValue - minMonthValue;
    if (monthsBeforeWithData < 0) monthsBeforeWithData = 0;
  }

  // 决定选中月份在5个柱子中的位置（0=最左，4=最右，2=居中）
  // 默认居中，但根据数据边界调整
  int selectedPosition = 2; // 默认居中

  final maxRightPosition = monthCount - 1; // 4
  final maxRightOffset = maxRightPosition - selectedPosition; // 2 (居中时右边有2个)

  if (monthsAfterWithData < maxRightOffset) {
    // 右边数据不够，选中月份需要往右移
    selectedPosition = monthCount - 1 - monthsAfterWithData;
  }
  if (monthsBeforeWithData < selectedPosition) {
    // 左边数据不够，选中月份需要往左移
    selectedPosition = monthsBeforeWithData;
  }

  // 确保 selectedPosition 在有效范围内
  if (selectedPosition < 0) selectedPosition = 0;
  if (selectedPosition > maxRightPosition) selectedPosition = maxRightPosition;

  // 先收集所有月份的年月信息
  final monthInfos = <({int year, int month, int amount})>[];

  // 计算起始月份：选中月份往前推 selectedPosition 个月
  for (var i = 0; i < monthCount; i++) {
    final offset = i - selectedPosition; // 相对于选中月份的偏移
    var targetMonth = month + offset;
    var targetYear = year;

    // 处理跨年
    while (targetMonth <= 0) {
      targetMonth += 12;
      targetYear -= 1;
    }
    while (targetMonth > 12) {
      targetMonth -= 12;
      targetYear += 1;
    }

    // 统计该月总金额
    final total = cache.version > 0
        ? cache.getMonthlyTotal(targetYear, targetMonth, isExpense)
        : _fallbackMonthlyTotal(
            records: records,
            year: targetYear,
            month: targetMonth,
            targetType: targetType,
          );

    monthInfos.add((year: targetYear, month: targetMonth, amount: total));
  }

  // 检测是否跨年：看是否有不同的年份
  final years = monthInfos.map((e) => e.year).toSet();
  final hasMultipleYears = years.length > 1;

  // 构建结果，跨年时在12月和1月显示年份
  for (var i = 0; i < monthInfos.length; i++) {
    final info = monthInfos[i];
    bool showYear = false;

    if (hasMultipleYears) {
      // 跨年时，在12月和1月显示年份
      if (info.month == 12 || info.month == 1) {
        showYear = true;
      }
    }

    results.add(MonthlyTotal(
      year: info.year,
      month: info.month,
      amount: info.amount,
      showYear: showYear,
    ));
  }

  return results;
}

int _fallbackMonthlyTotal({
  required List<TransactionRecord> records,
  required int year,
  required int month,
  required TransactionType targetType,
}) {
  var total = 0;
  for (final record in records) {
    if (record.type != targetType) continue;
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year == year && date.month == month) {
      total += record.amount;
    }
  }
  return total;
}

/// 获取用户数据的月份范围
/// 返回 (最早年月, 最晚年月)
/// 优化：优先使用缓存
({int minYear, int minMonth, int maxYear, int maxMonth})? getDataMonthRange({
  required List<TransactionRecord> records,
  required bool isExpense,
}) {
  // 优化：尝试使用缓存
  final cache = AnalysisCache.instance;
  final cachedRange = cache.getDataRange(isExpense);
  if (cachedRange != null) {
    return cachedRange;
  }

  // 回退到原始方式
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;

  int? minYear, minMonth, maxYear, maxMonth;

  for (final record in records) {
    if (record.type != targetType) continue;

    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    final y = date.year;
    final m = date.month;

    if (minYear == null || y < minYear || (y == minYear && m < minMonth!)) {
      minYear = y;
      minMonth = m;
    }
    if (maxYear == null || y > maxYear || (y == maxYear && m > maxMonth!)) {
      maxYear = y;
      maxMonth = m;
    }
  }

  if (minYear == null) return null;

  return (
    minYear: minYear,
    minMonth: minMonth!,
    maxYear: maxYear!,
    maxMonth: maxMonth!
  );
}

/// 检查指定月份是否有数据
/// 优化：优先使用缓存
bool hasDataForMonth({
  required List<TransactionRecord> records,
  required int year,
  required int month,
  required bool isExpense,
}) {
  // 优化：尝试使用缓存
  final cache = AnalysisCache.instance;
  final monthlyRecords = cache.getMonthlyRecords(year, month);

  if (monthlyRecords.isNotEmpty) {
    return cache.hasMonthlyData(year, month, isExpense);
  }

  // 缓存已建立且该月无记录时，直接返回 false，避免回退全量扫描
  if (cache.version > 0) {
    return false;
  }

  // 回退到原始方式
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;

  for (final record in records) {
    if (record.type != targetType) continue;

    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year == year && date.month == month) {
      return true;
    }
  }

  return false;
}

/// 检查指定月份是否有任意数据（不区分收支）
/// 优化：优先使用缓存
bool hasDataForMonthAny({
  required List<TransactionRecord> records,
  required int year,
  required int month,
}) {
  // 优化：尝试使用缓存
  final cache = AnalysisCache.instance;
  final monthlyRecords = cache.getMonthlyRecords(year, month);

  if (monthlyRecords.isNotEmpty) {
    return true;
  }

  // 缓存已建立且该月无记录时，直接返回 false，避免回退全量扫描
  if (cache.version > 0) {
    return false;
  }

  // 回退到原始方式
  for (final record in records) {
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year == year && date.month == month) {
      return true;
    }
  }

  return false;
}

// ==================== 周度相关 ====================

/// 周度每日汇总数据
class WeeklyDailyTotal {
  WeeklyDailyTotal({
    required this.date,
    required this.dayOfWeek,
    required this.amount,
    required this.isToday,
  });

  final DateTime date;
  final int dayOfWeek; // 1=周一, 7=周日
  final int amount; // 单位：分
  final bool isToday;

  String get dayLabel {
    const labels = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return labels[dayOfWeek];
  }

  String get dateLabel {
    if (isToday) return '今天';
    return '${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

/// 获取指定周的每日汇总（周一到周日）
/// [weekOffset] 0=本周, -1=上周, 1=下周
List<WeeklyDailyTotal> getWeeklyDailyTotals({
  required List<TransactionRecord> records,
  required DateTime referenceDate,
  required bool isExpense,
  int weekOffset = 0,
}) {
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final cache = AnalysisCache.instance;
  final useCache = cache.version > 0;
  final today = DateTime.now();

  // 计算本周周一
  final daysSinceMonday = (referenceDate.weekday - 1);
  final monday = DateTime(referenceDate.year, referenceDate.month,
      referenceDate.day - daysSinceMonday);

  // 应用周偏移
  final targetMonday = monday.add(Duration(days: weekOffset * 7));

  final results = <WeeklyDailyTotal>[];

  for (int i = 0; i < 7; i++) {
    final date = targetMonday.add(Duration(days: i));
    final dayOfWeek = i + 1; // 1=周一

    // 统计该日金额
    int amount = 0;
    final targetRecords = useCache
        ? cache.getDailyRecords(date.year, date.month, date.day)
        : records;
    for (final record in targetRecords) {
      if (record.type != targetType) continue;
      if (!useCache) {
        final recordDate =
            DateTime.fromMillisecondsSinceEpoch(record.timestamp);
        if (recordDate.year != date.year ||
            recordDate.month != date.month ||
            recordDate.day != date.day) {
          continue;
        }
      }
      amount += record.amount;
    }

    results.add(WeeklyDailyTotal(
      date: date,
      dayOfWeek: dayOfWeek,
      amount: amount,
      isToday: date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
    ));
  }

  return results;
}

/// 获取指定周的总金额
int getWeeklyTotal({
  required List<TransactionRecord> records,
  required DateTime referenceDate,
  required bool isExpense,
  int weekOffset = 0,
}) {
  final dailyTotals = getWeeklyDailyTotals(
    records: records,
    referenceDate: referenceDate,
    isExpense: isExpense,
    weekOffset: weekOffset,
  );
  return dailyTotals.fold(0, (sum, e) => sum + e.amount);
}

/// 获取周的日期范围字符串
String getWeekRangeString(DateTime referenceDate, {int weekOffset = 0}) {
  final daysSinceMonday = (referenceDate.weekday - 1);
  final monday = DateTime(referenceDate.year, referenceDate.month,
      referenceDate.day - daysSinceMonday);
  final targetMonday = monday.add(Duration(days: weekOffset * 7));
  final targetSunday = targetMonday.add(const Duration(days: 6));

  return '${targetMonday.month}.${targetMonday.day} - ${targetSunday.month}.${targetSunday.day}';
}

/// 获取周的分类汇总
List<CategoryTotal> getWeeklyCategoryTotals({
  required List<TransactionRecord> records,
  required DateTime referenceDate,
  required bool isExpense,
  int weekOffset = 0,
}) {
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final cache = AnalysisCache.instance;
  final useCache = cache.version > 0;
  final categoryMap = <String, _CategoryAccumulator>{};

  // 计算目标周的周一和周日
  final daysSinceMonday = (referenceDate.weekday - 1);
  final monday = DateTime(referenceDate.year, referenceDate.month,
      referenceDate.day - daysSinceMonday);
  final targetMonday = monday.add(Duration(days: weekOffset * 7));
  final targetSunday = targetMonday.add(const Duration(days: 6));

  if (useCache) {
    for (int i = 0; i < 7; i++) {
      final date = targetMonday.add(Duration(days: i));
      final dayRecords = cache.getDailyRecords(date.year, date.month, date.day);
      for (final record in dayRecords) {
        if (record.type != targetType) continue;
        final category =
            (record.category?.isNotEmpty == true) ? record.category! : '其他';
        if (!categoryMap.containsKey(category)) {
          categoryMap[category] = _CategoryAccumulator();
        }
        categoryMap[category]!.amount += record.amount;
        categoryMap[category]!.count += 1;
      }
    }
  } else {
    for (final record in records) {
      if (record.type != targetType) continue;

      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly.isBefore(targetMonday) || dateOnly.isAfter(targetSunday)) {
        continue;
      }

      final category =
          (record.category?.isNotEmpty == true) ? record.category! : '其他';

      if (!categoryMap.containsKey(category)) {
        categoryMap[category] = _CategoryAccumulator();
      }
      categoryMap[category]!.amount += record.amount;
      categoryMap[category]!.count += 1;
    }
  }

  return categoryMap.entries
      .map((e) => CategoryTotal(
            category: e.key,
            amount: e.value.amount,
            count: e.value.count,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
}

// ==================== 年度相关 ====================

/// 年度月度汇总数据
class YearlyMonthTotal {
  YearlyMonthTotal({
    required this.month,
    required this.amount,
    required this.isCurrentMonth,
  });

  final int month; // 1-12
  final int amount; // 单位：分
  final bool isCurrentMonth;
}

/// 获取指定年份的每月汇总
/// 优化：使用缓存索引
List<YearlyMonthTotal> getYearlyMonthlyTotals({
  required List<TransactionRecord> records,
  required int year,
  required bool isExpense,
  int? currentMonth, // 当前选中的月份
}) {
  final now = DateTime.now();
  final selectedMonth = currentMonth ?? (year == now.year ? now.month : 12);

  final cache = AnalysisCache.instance;
  final results = <YearlyMonthTotal>[];

  if (cache.version > 0) {
    for (int month = 1; month <= 12; month++) {
      results.add(
        YearlyMonthTotal(
          month: month,
          amount: cache.getMonthlyTotal(year, month, isExpense),
          isCurrentMonth: month == selectedMonth,
        ),
      );
    }
    return results;
  }

  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  for (int month = 1; month <= 12; month++) {
    int amount = 0;

    // 优化：使用缓存获取当月记录
    final monthlyRecords = cache.getMonthlyRecords(year, month);
    final targetRecords = monthlyRecords.isNotEmpty ? monthlyRecords : records;

    for (final record in targetRecords) {
      if (record.type != targetType) continue;
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      if (date.year == year && date.month == month) {
        amount += record.amount;
      }
    }

    results.add(YearlyMonthTotal(
      month: month,
      amount: amount,
      isCurrentMonth: month == selectedMonth,
    ));
  }

  return results;
}

/// 获取指定年份的总金额
/// 优化：优先使用缓存
int getYearlyTotal({
  required List<TransactionRecord> records,
  required int year,
  required bool isExpense,
}) {
  // 优化：尝试使用缓存
  final cache = AnalysisCache.instance;
  final yearlyRecords = cache.getYearlyRecords(year);

  if (yearlyRecords.isNotEmpty) {
    return cache.getYearlyTotal(year, isExpense);
  }

  // 回退到原始方式
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  int total = 0;

  for (final record in records) {
    if (record.type != targetType) continue;
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year == year) {
      total += record.amount;
    }
  }

  return total;
}

/// 获取指定年份的月均金额
int getYearlyMonthlyAverage({
  required List<TransactionRecord> records,
  required int year,
  required bool isExpense,
}) {
  final monthlyTotals = getYearlyMonthlyTotals(
    records: records,
    year: year,
    isExpense: isExpense,
  );

  // 只计算有数据的月份
  final monthsWithData = monthlyTotals.where((e) => e.amount > 0).toList();
  if (monthsWithData.isEmpty) return 0;

  final total = monthsWithData.fold(0, (sum, e) => sum + e.amount);
  return total ~/ monthsWithData.length;
}

/// 获取年度的分类汇总
/// 优化：使用缓存索引
List<CategoryTotal> getYearlyCategoryTotals({
  required List<TransactionRecord> records,
  required int year,
  required bool isExpense,
}) {
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final categoryMap = <String, _CategoryAccumulator>{};

  // 优化：使用缓存获取当年记录
  final cache = AnalysisCache.instance;
  final yearlyRecords = cache.getYearlyRecords(year);
  final targetRecords = yearlyRecords.isNotEmpty ? yearlyRecords : records;

  for (final record in targetRecords) {
    if (record.type != targetType) continue;

    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year != year) continue;

    final category =
        (record.category?.isNotEmpty == true) ? record.category! : '其他';

    if (!categoryMap.containsKey(category)) {
      categoryMap[category] = _CategoryAccumulator();
    }
    categoryMap[category]!.amount += record.amount;
    categoryMap[category]!.count += 1;
  }

  return categoryMap.entries
      .map((e) => CategoryTotal(
            category: e.key,
            amount: e.value.amount,
            count: e.value.count,
          ))
      .toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
}

/// 检查指定年份是否有数据
/// 优化：优先使用缓存
bool hasDataForYear({
  required List<TransactionRecord> records,
  required int year,
  required bool isExpense,
}) {
  // 优化：尝试使用缓存
  final cache = AnalysisCache.instance;
  final yearlyRecords = cache.getYearlyRecords(year);

  if (yearlyRecords.isNotEmpty) {
    return cache.hasYearlyData(year, isExpense);
  }

  // 缓存已建立且该年无记录时，直接返回 false，避免回退全量扫描
  if (cache.version > 0) {
    return false;
  }

  // 回退到原始方式
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;

  for (final record in records) {
    if (record.type != targetType) continue;
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year == year) {
      return true;
    }
  }

  return false;
}

/// 检查指定年份是否有任意数据（不区分收支）
/// 用于首页年份选择器
bool hasDataForYearAny({
  required List<TransactionRecord> records,
  required int year,
}) {
  // 优化：尝试使用缓存
  final cache = AnalysisCache.instance;
  final yearlyRecords = cache.getYearlyRecords(year);

  if (yearlyRecords.isNotEmpty) {
    return true;
  }

  // 缓存已建立且该年无记录时，直接返回 false，避免回退全量扫描
  if (cache.version > 0) {
    return false;
  }

  // 回退到原始方式
  for (final record in records) {
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (date.year == year) {
      return true;
    }
  }

  return false;
}

/// 检查指定周是否有数据
bool hasDataForWeek({
  required List<TransactionRecord> records,
  required DateTime referenceDate,
  required bool isExpense,
  int weekOffset = 0,
}) {
  final cache = AnalysisCache.instance;
  if (cache.version > 0) {
    final targetType =
        isExpense ? TransactionType.expense : TransactionType.income;
    final daysSinceMonday = (referenceDate.weekday - 1);
    final monday = DateTime(referenceDate.year, referenceDate.month,
        referenceDate.day - daysSinceMonday);
    final targetMonday = monday.add(Duration(days: weekOffset * 7));

    for (int i = 0; i < 7; i++) {
      final date = targetMonday.add(Duration(days: i));
      final dayRecords = cache.getDailyRecords(date.year, date.month, date.day);
      if (dayRecords.any((record) => record.type == targetType)) {
        return true;
      }
    }
    return false;
  }

  final dailyTotals = getWeeklyDailyTotals(
    records: records,
    referenceDate: referenceDate,
    isExpense: isExpense,
    weekOffset: weekOffset,
  );
  return dailyTotals.any((e) => e.amount > 0);
}
