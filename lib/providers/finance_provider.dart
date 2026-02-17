import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/analysis_helpers.dart';
import '../data/app_settings_dao.dart';
import '../data/category_dao.dart';
import '../data/database_helper.dart';
import '../data/export_service.dart';
import '../data/transaction_dao.dart';
import '../models/models.dart';
import 'batch_edit_mixin.dart';
import 'import_export_mixin.dart';

/// 来源筛选枚举
enum SourceFilter { all, alipay, wechat }

/// 收支类型筛选枚举
enum TypeFilter { all, expense, income, notCounted }

/// 财务数据状态管理 Provider
class FinanceProvider extends ChangeNotifier
    with BatchEditMixin, ImportExportMixin {
  final _txDao = TransactionDao.instance;
  final _categoryDao = CategoryDao.instance;
  final _settingsDao = AppSettingsDao.instance;
  final _export = ExportService.instance;
  final _currencyFormatter =
      NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  List<TransactionRecord> _records = [];
  Map<String, int> _summary = {'expense': 0, 'income': 0};
  bool _loading = false;
  bool _initializing = true;
  SourceFilter _currentFilter = SourceFilter.all;
  int _selectedMonthModeYear = DateTime.now().year;
  int _selectedYearModeYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _filterByYear = false;

  // 搜索和高级筛选
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  TypeFilter _typeFilter = TypeFilter.all;
  Set<String> _selectedCategories = {};

  // 筛选类型选项（从数据库加载）
  List<String> _filterTypeOptions = [];

  // 筛选类型完整数据（包含 groupId）
  List<FilterType> _filterTypes = [];

  // 自定义分类名称列表（从数据库加载）
  List<String> _customCategories = [];

  // 自定义分类完整对象列表（包含 groupId）
  List<CustomCategory> _customCategoryObjects = [];

  // 分类分组（从数据库加载）
  List<CategoryGroup> _categoryGroups = [];

  // ==================== 缓存优化 ====================
  bool _filterCacheDirty = true;
  List<TransactionRecord>? _filteredRecordsCache;
  List<TransactionRecord>? _dbFilteredRecords;
  String? _snackBarMessage;

  int get _activeSelectedYear =>
      _filterByYear ? _selectedYearModeYear : _selectedMonthModeYear;

  /// 获取筛选后的记录（带缓存）
  List<TransactionRecord> get records {
    if (_filterCacheDirty || _filteredRecordsCache == null) {
      if (_dbFilteredRecords != null) {
        _filteredRecordsCache = _dbFilteredRecords!;
      } else {
        _filteredRecordsCache = _applyFilter(_records);
      }
      _summary = _calculateSummary(_filteredRecordsCache!);
      _filterCacheDirty = false;
    }
    return _filteredRecordsCache!;
  }

  /// 标记筛选缓存为脏，需要重新计算
  void _invalidateFilterCache() {
    _filterCacheDirty = true;
  }

  String? _selectedSourceValue() {
    switch (_currentFilter) {
      case SourceFilter.all:
        return null;
      case SourceFilter.alipay:
        return 'Alipay';
      case SourceFilter.wechat:
        return 'WeChat';
    }
  }

  String? _selectedTypeValue() {
    switch (_typeFilter) {
      case TypeFilter.all:
        return null;
      case TypeFilter.expense:
        return 'EXPENSE';
      case TypeFilter.income:
        return 'INCOME';
      case TypeFilter.notCounted:
        return 'IGNORE';
    }
  }

  Future<void> _refreshDbFilteredRecords({bool notify = true}) async {
    try {
      _dbFilteredRecords = await _txDao.fetchTransactionsWithFilters(
        source: _selectedSourceValue(),
        year: _activeSelectedYear,
        month: _selectedMonth,
        filterByYear: _filterByYear,
        type: _selectedTypeValue(),
        categories: _selectedCategories,
        searchQuery: _searchQuery,
      );
    } catch (e, stackTrace) {
      debugPrint('SQL筛选回退到内存筛选: $e');
      debugPrintStack(stackTrace: stackTrace);
      _dbFilteredRecords = null;
    }
    _invalidateFilterCache();
    if (notify) {
      notifyListeners();
    }
  }

  void _scheduleDbFilterRefresh() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    _dbFilteredRecords = null;
    _invalidateFilterCache();
    notifyListeners();
    unawaited(_refreshDbFilteredRecords());
  }

  Map<String, int> get summary {
    if (_filterCacheDirty) {
      final _ = records; // 触发缓存更新
    }
    return _summary;
  }

  bool get loading => _loading;
  bool get initializing => _initializing;
  SourceFilter get currentFilter => _currentFilter;
  int get selectedYear => _activeSelectedYear;
  int get selectedMonthModeYear => _selectedMonthModeYear;
  int get selectedYearModeYear => _selectedYearModeYear;
  int get selectedMonth => _selectedMonth;
  bool get filterByYear => _filterByYear;
  String get searchQuery => _searchQuery;
  TypeFilter get typeFilter => _typeFilter;
  Set<String> get selectedCategories => _selectedCategories;
  List<String> get filterTypeOptions => _filterTypeOptions;
  List<FilterType> get filterTypes => _filterTypes;
  List<String> get customCategories => _customCategories;
  List<CustomCategory> get customCategoryObjects => _customCategoryObjects;
  List<CategoryGroup> get categoryGroups => _categoryGroups;
  bool get hasActiveFilters =>
      _typeFilter != TypeFilter.all || _selectedCategories.isNotEmpty;
  String formatAmount(int cents) => _currencyFormatter.format(cents / 100);

  @override
  TransactionDao get transactionDao => _txDao;

  @override
  ExportService get exportService => _export;

  @override
  Future<void> reloadData() => _reload();

  @override
  void setLoadingState(bool value) => _setLoading(value);

  @override
  void showImportResultSnack(int inserted, int duplicates) {
    _showResultSnack(inserted, duplicates);
  }

  @override
  set snackBarMessage(String? message) {
    _snackBarMessage = message;
  }

  @override
  Set<String> get recordIdsInCurrentView => records.map((r) => r.id).toSet();

  @override
  List<TransactionRecord> get recordsForExport => records;

  @override
  int get exportSelectedYear => _activeSelectedYear;

  @override
  int get exportSelectedMonth => _selectedMonth;

  @override
  bool get exportFilterByYear => _filterByYear;

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _showResultSnack(int inserted, int duplicates) {
    _snackBarMessage = '已导入 $inserted 条，重复跳过 $duplicates 条';
    notifyListeners();
  }

  String? consumeSnackMessage() {
    final message = _snackBarMessage;
    _snackBarMessage = null;
    return message;
  }

  Future<void> loadInitial() async {
    final isFirstLoad = _initializing;
    try {
      await Future.wait([
        _restoreSelectedMonthYear(),
        _loadCategoryGroups(),
        _loadFilterTypes(),
        _loadCustomCategories(),
      ]);
      await _ensureFilterTypesHaveGroups();
      await _reload();
    } finally {
      if (isFirstLoad) {
        _initializing = false;
        notifyListeners();
      }
    }
  }

  Future<void> _restoreSelectedMonthYear() async {
    final selectedMonthState = await _settingsDao.getHomeLastViewedMonthYear();
    if (selectedMonthState == null) {
      await _persistMonthModeMonthYear(
        year: _selectedMonthModeYear,
        month: _selectedMonth,
      );
    } else {
      final monthModeYear = selectedMonthState['year'];
      final month = selectedMonthState['month'];
      if (monthModeYear != null && month != null && month >= 1 && month <= 12) {
        _selectedMonthModeYear = monthModeYear;
        _selectedMonth = month;
      }
    }

    final yearModeYear = await _settingsDao.getHomeLastViewedYearModeYear();
    if (yearModeYear != null) {
      _selectedYearModeYear = yearModeYear;
    } else {
      _selectedYearModeYear = _selectedMonthModeYear;
      unawaited(_persistYearModeYear(_selectedYearModeYear));
    }

    final lastFilterByYear = await _settingsDao.getHomeLastFilterByYear();
    if (lastFilterByYear != null) {
      _filterByYear = lastFilterByYear;
    }
  }

  Future<void> _persistMonthModeMonthYear({
    required int year,
    required int month,
  }) async {
    try {
      await _settingsDao.setHomeLastViewedMonthYear(year: year, month: month);
    } catch (e, stackTrace) {
      debugPrint('保存首页年月失败: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _persistYearModeYear(int year) async {
    try {
      await _settingsDao.setHomeLastViewedYearModeYear(year: year);
    } catch (e, stackTrace) {
      debugPrint('保存首页按年年份失败: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _persistFilterByYearMode(bool filterByYear) async {
    try {
      await _settingsDao.setHomeLastFilterByYear(filterByYear: filterByYear);
    } catch (e, stackTrace) {
      debugPrint('保存首页筛选模式失败: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 加载分类分组
  Future<void> _loadCategoryGroups() async {
    _categoryGroups = await _categoryDao.fetchCategoryGroups();
  }

  /// 加载筛选类型选项
  Future<void> _loadFilterTypes() async {
    final types = await _categoryDao.fetchFilterTypes();
    _filterTypes = types;
    _filterTypeOptions = types.map((t) => t.name).toList();
  }

  /// 加载自定义分类
  Future<void> _loadCustomCategories() async {
    final categories = await _categoryDao.fetchCustomCategories();
    _customCategoryObjects = categories;
    _customCategories = categories.map((c) => c.name).toList();
  }

  /// 刷新分类分组（供外部调用）
  Future<void> refreshCategoryGroups() async {
    await _loadCategoryGroups();
    notifyListeners();
  }

  /// 刷新筛选类型（供外部调用）
  Future<void> refreshFilterTypes() async {
    await _loadFilterTypes();
    notifyListeners();
  }

  /// 刷新自定义分类（供外部调用）
  Future<void> refreshCustomCategories() async {
    await _loadCustomCategories();
    notifyListeners();
  }

  /// 确保筛选类型都有分组关联（仅系统分类）
  Future<void> _ensureFilterTypesHaveGroups() async {
    final groupMap = {for (final g in _categoryGroups) g.name: g.id};

    bool needsReload = false;
    for (final ft in _filterTypes) {
      final targetGroupId =
          DatabaseHelper.resolveGroupIdFromMap(ft.name, groupMap);

      if (targetGroupId != null && ft.groupId != targetGroupId) {
        await _categoryDao.updateFilterTypeGroup(ft.id, targetGroupId);
        needsReload = true;
      }
    }

    if (needsReload) {
      await _loadFilterTypes();
    }
  }

  Future<void> _reload() async {
    _records = await _txDao.fetchTransactions();
    AnalysisCache.instance.rebuild(_records);
    await _refreshDbFilteredRecords(notify: false);
    _invalidateFilterCache();
    notifyListeners();
  }

  Future<void> reload() async {
    await _reload();
  }

  void updateFilter(SourceFilter filter) {
    if (_currentFilter == filter) return;
    _currentFilter = filter;
    _scheduleDbFilterRefresh();
  }

  void updateMonthYear(int year, int month) {
    if (_selectedMonthModeYear == year && _selectedMonth == month) return;
    _selectedMonthModeYear = year;
    _selectedMonth = month;
    unawaited(_persistMonthModeMonthYear(year: year, month: month));
    if (_filterByYear) {
      notifyListeners();
      return;
    }
    _scheduleDbFilterRefresh();
  }

  void updateYearModeYear(int year) {
    if (_selectedYearModeYear == year) return;
    _selectedYearModeYear = year;
    unawaited(_persistYearModeYear(year));
    if (_filterByYear) {
      _scheduleDbFilterRefresh();
      return;
    }
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(
      const Duration(milliseconds: 300),
      _scheduleDbFilterRefresh,
    );
  }

  void updateAdvancedFilters({
    required TypeFilter typeFilter,
    required Set<String> categories,
  }) {
    _typeFilter = typeFilter;
    _selectedCategories = categories;
    _scheduleDbFilterRefresh();
  }

  void clearAdvancedFilters() {
    _typeFilter = TypeFilter.all;
    _selectedCategories = {};
    _scheduleDbFilterRefresh();
  }

  void updateFilterByYear(bool value) {
    if (_filterByYear == value) return;
    _filterByYear = value;
    unawaited(_persistFilterByYearMode(value));
    _scheduleDbFilterRefresh();
  }

  List<TransactionRecord> _applyFilter(List<TransactionRecord> records) {
    return records.where((record) {
      // 来源筛选
      final matchesSource = _currentFilter == SourceFilter.all ||
          (_currentFilter == SourceFilter.alipay &&
              record.source == 'Alipay') ||
          (_currentFilter == SourceFilter.wechat && record.source == 'WeChat');
      if (!matchesSource) return false;

      // 年月筛选
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      final matchesYear = date.year == _activeSelectedYear;
      if (_filterByYear) {
        if (!matchesYear) return false;
      } else {
        if (!matchesYear || date.month != _selectedMonth) return false;
      }

      // 收支类型筛选
      if (_typeFilter == TypeFilter.expense &&
          record.type != TransactionType.expense) {
        return false;
      }
      if (_typeFilter == TypeFilter.income &&
          record.type != TransactionType.income) {
        return false;
      }
      if (_typeFilter == TypeFilter.notCounted &&
          record.type != TransactionType.ignore) {
        return false;
      }

      // 交易类型筛选（多选）
      if (_selectedCategories.isNotEmpty) {
        final transactionCategory = record.transactionCategory ?? '';
        final matchesCategory = _selectedCategories.any(
          (selected) => transactionCategory.contains(selected),
        );
        if (!matchesCategory) return false;
      }

      // 搜索关键词筛选
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch =
            record.counterparty.toLowerCase().contains(query) ||
                record.description.toLowerCase().contains(query) ||
                (record.category ?? '').toLowerCase().contains(query);
        if (!matchesSearch) return false;
      }

      return true;
    }).toList();
  }

  Map<String, int> _calculateSummary(List<TransactionRecord> records) {
    var expense = 0;
    var income = 0;
    for (final record in records) {
      if (record.type == TransactionType.expense) {
        expense += record.amount;
      } else if (record.type == TransactionType.income) {
        income += record.amount;
      }
    }
    return {'expense': expense, 'income': income};
  }

  /// 获取所有未筛选的数据
  List<TransactionRecord> get allRecords => _records;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}
