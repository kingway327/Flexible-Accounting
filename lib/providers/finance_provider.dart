import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/analysis_helpers.dart';
import '../data/database_helper.dart';
import '../data/export_service.dart';
import '../data/parsers.dart';
import '../models/models.dart';

/// 来源筛选枚举
enum SourceFilter { all, alipay, wechat }

/// 收支类型筛选枚举
enum TypeFilter { all, expense, income, notCounted }

/// 财务数据状态管理 Provider
class FinanceProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _export = ExportService.instance;
  final _currencyFormatter =
      NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  List<TransactionRecord> _records = [];
  Map<String, int> _summary = {'expense': 0, 'income': 0};
  bool _loading = false;
  bool _initializing = true;
  SourceFilter _currentFilter = SourceFilter.all;
  int _selectedYear = DateTime.now().year;
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

  // 批量编辑状态
  bool _isBatchEditing = false;
  Set<String> _selectedIds = {};

  // ==================== 缓存优化 ====================
  bool _filterCacheDirty = true;
  List<TransactionRecord>? _filteredRecordsCache;
  List<TransactionRecord>? _dbFilteredRecords;
  String? _snackBarMessage;

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
      _dbFilteredRecords = await _db.fetchTransactionsWithFilters(
        source: _selectedSourceValue(),
        year: _selectedYear,
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
  int get selectedYear => _selectedYear;
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

  // 批量编辑 getters
  bool get isBatchEditing => _isBatchEditing;
  Set<String> get selectedIds => _selectedIds;
  int get selectedCount => _selectedIds.length;

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
    final selected = await _db.getHomeLastViewedMonthYear();
    if (selected == null) {
      await _persistSelectedMonthYear(
          year: _selectedYear, month: _selectedMonth);
      return;
    }

    final year = selected['year'];
    final month = selected['month'];
    if (year == null || month == null || month < 1 || month > 12) {
      return;
    }

    _selectedYear = year;
    _selectedMonth = month;
  }

  Future<void> _persistSelectedMonthYear({
    required int year,
    required int month,
  }) async {
    try {
      await _db.setHomeLastViewedMonthYear(year: year, month: month);
    } catch (e, stackTrace) {
      debugPrint('保存首页年月失败: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 加载分类分组
  Future<void> _loadCategoryGroups() async {
    _categoryGroups = await _db.fetchCategoryGroups();
  }

  /// 加载筛选类型选项
  Future<void> _loadFilterTypes() async {
    final types = await _db.fetchFilterTypes();
    _filterTypes = types;
    _filterTypeOptions = types.map((t) => t.name).toList();
  }

  /// 加载自定义分类
  Future<void> _loadCustomCategories() async {
    final categories = await _db.fetchCustomCategories();
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
        await _db.updateFilterTypeGroup(ft.id, targetGroupId);
        needsReload = true;
      }
    }

    if (needsReload) {
      await _loadFilterTypes();
    }
  }

  Future<void> importFile() async {
    _setLoading(true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        _setLoading(false);
        return;
      }
      final file = result.files.single;
      final bytes = file.bytes ?? Uint8List(0);
      final extension = file.extension?.toLowerCase();
      List<TransactionRecord> records;
      if (extension == 'xlsx' || extension == 'xls') {
        final rows = decodeExcelBytes(bytes);
        final source = FileTypeDetector.detectSourceFromRows(rows);
        records = source == 'WeChat'
            ? WechatParser.parseRows(rows)
            : AlipayParser.parseRows(rows);
      } else {
        final content = await decodeCsvBytes(bytes);
        final source = FileTypeDetector.detectSource(content);
        records = source == 'WeChat'
            ? WechatParser.parse(content)
            : AlipayParser.parse(content);
      }
      final inserted = await _db.insertTransactions(records);
      final duplicates = records.length - inserted;
      await _reload();
      _setLoading(false);
      _showResultSnack(inserted, duplicates);
    } catch (e, stackTrace) {
      _setLoading(false);
      _snackBarMessage = '导入失败，请检查文件格式后重试';
      debugPrint('导入文件失败: $e');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
    }
  }

  /// 清空所有数据
  Future<void> clearAllData() async {
    _setLoading(true);
    try {
      final deleted = await _db.clearAllTransactions();
      AnalysisCache.instance.clear();
      await _reload();
      _setLoading(false);
      _snackBarMessage = '已清空 $deleted 条记录';
      notifyListeners();
    } catch (e, stackTrace) {
      _setLoading(false);
      _snackBarMessage = '清空失败，请重试';
      debugPrint('清空数据失败: $e');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    _records = await _db.fetchTransactions();
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
    if (_selectedYear == year && _selectedMonth == month) return;
    _selectedYear = year;
    _selectedMonth = month;
    unawaited(_persistSelectedMonthYear(year: year, month: month));
    _scheduleDbFilterRefresh();
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
      final matchesYear = date.year == _selectedYear;
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

  /// 导出当前筛选的账单数据
  Future<void> exportCurrentData() async {
    _setLoading(true);
    try {
      final dataToExport = records;
      final success = await _export.exportToCsv(
        dataToExport,
        year: _selectedYear,
        month: _selectedMonth,
        filterByYear: _filterByYear,
      );
      _setLoading(false);
      _snackBarMessage =
          success ? '已导出 ${dataToExport.length} 条记录' : '导出失败，请重试';
      notifyListeners();
    } catch (e, stackTrace) {
      _setLoading(false);
      _snackBarMessage = '导出失败，请重试';
      debugPrint('导出当前数据失败: $e');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
    }
  }

  /// 获取所有未筛选的数据
  List<TransactionRecord> get allRecords => _records;

  // ==================== 批量编辑方法 ====================

  /// 切换批量编辑模式
  void toggleBatchEdit() {
    _isBatchEditing = !_isBatchEditing;
    if (!_isBatchEditing) _selectedIds.clear();
    notifyListeners();
  }

  /// 退出批量编辑模式
  void exitBatchEdit() {
    _isBatchEditing = false;
    _selectedIds.clear();
    notifyListeners();
  }

  /// 切换单条记录的选中状态
  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  /// 全选当前筛选后的所有记录
  void selectAll() {
    _selectedIds = records.map((r) => r.id).toSet();
    notifyListeners();
  }

  /// 清空选择
  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  /// 批量更新分类
  Future<void> updateBatchCategory(String category) async {
    if (_selectedIds.isEmpty) return;
    _setLoading(true);
    try {
      final count =
          await _db.batchUpdateCategory(_selectedIds.toList(), category);
      await _reload();
      _isBatchEditing = false;
      _selectedIds.clear();
      _snackBarMessage = '已更新 $count 条记录的分类';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// 批量更新备注
  Future<void> updateBatchNote(String note) async {
    if (_selectedIds.isEmpty) return;
    _setLoading(true);
    try {
      final count = await _db.batchUpdateNote(_selectedIds.toList(), note);
      await _reload();
      _isBatchEditing = false;
      _selectedIds.clear();
      _snackBarMessage = '已更新 $count 条记录的备注';
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}
