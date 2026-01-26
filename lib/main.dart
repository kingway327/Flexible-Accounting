import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/analysis_helpers.dart';
import 'data/database_helper.dart';
import 'data/export_service.dart';
import 'widgets/category_grid.dart';
import 'data/parsers.dart';
import 'models/models.dart';
import 'pages/analysis_page.dart';
import 'pages/category_manage_page.dart';
import 'pages/transaction_detail_page.dart';
import 'widgets/month_picker.dart';

void main() {
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FinanceProvider()..loadInitial(),
      child: MaterialApp(
        title: '我的记账',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

enum SourceFilter { all, alipay, wechat }

enum TypeFilter { all, expense, income, notCounted }

/// 微信交易类型（8 类，包含退款处理）
const List<String> kWechatTransactionTypes = [
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
const List<String> kAlipayCategories = [
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
  // 潬账相关
  '收入',
  '转账红包',
  '亲友代付',
  '账户存取',
  '退款',
  // 其他
  '其他',
];

/// 所有系统分类（微信 8 类 + 支付宝 39 类 = 47 类）
const List<String> kSystemCategories = [
  ...kWechatTransactionTypes,  // 8 类
  ...kAlipayCategories,         // 39 类
];

/// 消费分类（用于收支分析页的分类统计）
/// 支付宝：使用账单的「交易分类」字段
/// 微信：使用账单的「交易类型」字段
const List<String> kSpendingCategories = kSystemCategories;

/// 兼容旧代码
@Deprecated('Use kWechatTransactionTypes and kAlipayCategories instead')
const List<String> kTransactionCategories = [
  ...kWechatTransactionTypes,
  ...kAlipayCategories,
];

class FinanceProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  final _export = ExportService.instance;
  final _currencyFormatter = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  List<TransactionRecord> _records = [];
  Map<String, int> _summary = {'expense': 0, 'income': 0};
  bool _loading = false;
  SourceFilter _currentFilter = SourceFilter.all;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _filterByYear = false;

  // 搜索和高级筛选
  String _searchQuery = '';
  TypeFilter _typeFilter = TypeFilter.all;
  Set<String> _selectedCategories = {};

  // 筛选类型选项（从数据库加载）
  List<String> _filterTypeOptions = [];

  // 筛选类型完整数据（包含 groupId）
  List<FilterType> _filterTypes = [];

  // 自定义分类（从数据库加载）
  List<String> _customCategories = [];

  // 分类分组（从数据库加载）
  List<CategoryGroup> _categoryGroups = [];

  // 批量编辑状态
  bool _isBatchEditing = false;
  Set<String> _selectedIds = {};

  // ==================== 缓存优化 ====================
  bool _filterCacheDirty = true;
  List<TransactionRecord>? _filteredRecordsCache;
  String? _snackBarMessage;

  /// 获取筛选后的记录（带缓存）
  List<TransactionRecord> get records {
    if (_filterCacheDirty || _filteredRecordsCache == null) {
      _filteredRecordsCache = _applyFilter(_records);
      _summary = _calculateSummary(_filteredRecordsCache!);
      _filterCacheDirty = false;
    }
    return _filteredRecordsCache!;
  }

  /// 标记筛选缓存为脏，需要重新计算
  void _invalidateFilterCache() {
    _filterCacheDirty = true;
  }

  Map<String, int> get summary {
    // 确保 records getter 被调用以更新缓存
    if (_filterCacheDirty) {
      final _ = records; // 触发缓存更新
    }
    return _summary;
  }


  bool get loading => _loading;
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
  List<CategoryGroup> get categoryGroups => _categoryGroups;
  bool get hasActiveFilters => _typeFilter != TypeFilter.all || _selectedCategories.isNotEmpty;
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
    await _loadCategoryGroups();
    await _loadFilterTypes();
    await _loadCustomCategories();
    // 修复：检查并修复筛选类型的分组关联
    await _ensureFilterTypesHaveGroups();
    await _reload();
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

  /// 确保筛选类型都有分组关联（修复数据）
  /// 使用 main.dart 中定义的完整分类列表
  Future<void> _ensureFilterTypesHaveGroups() async {
    // 获取分组ID映射
    final groupMap = {for (final g in _categoryGroups) g.name: g.id};
    final wechatGroupId = groupMap['微信'];
    final alipayGroupId = groupMap['支付宝'];
    final customGroupId = groupMap['自定义'];

    // 检查筛选类型并修复
    bool needsReload = false;
    for (final ft in _filterTypes) {
      int? targetGroupId;

      // 只对系统分类强制分组（微信/支付宝）
      if (kWechatTransactionTypes.contains(ft.name) && wechatGroupId != null) {
        targetGroupId = wechatGroupId;
      } else if (kAlipayCategories.contains(ft.name) && alipayGroupId != null) {
        targetGroupId = alipayGroupId;
      }
      // 用户自定义分类保持用户选择，不强制分配到任何分组

      // 如果需要更新（只有系统分类需要强制更新）
      if (targetGroupId != null && ft.groupId != targetGroupId) {
        await _db.updateFilterTypeGroup(ft.id, targetGroupId);
        needsReload = true;
      }
    }

    // 如果有更新，重新加载筛选类型
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
    } catch (_) {
      _setLoading(false);
    }
  }

  /// 清空所有数据
  Future<void> clearAllData() async {
    _setLoading(true);
    try {
      final deleted = await _db.clearAllTransactions();
      // 清空分析缓存
      AnalysisCache.instance.clear();
      await _reload();
      _setLoading(false);
      _snackBarMessage = '已清空 $deleted 条记录';
      notifyListeners();
    } catch (_) {
      _setLoading(false);
    }
  }

  Future<void> _reload() async {
    _records = await _db.fetchTransactions();
    // 重建分析缓存
    AnalysisCache.instance.rebuild(_records);
    // 标记筛选缓存为脏
    _invalidateFilterCache();
    notifyListeners();
  }

  void updateFilter(SourceFilter filter) {
    if (_currentFilter == filter) {
      return;
    }
    _currentFilter = filter;
    _invalidateFilterCache();
    notifyListeners();
  }

  void updateMonthYear(int year, int month) {
    if (_selectedYear == year && _selectedMonth == month) {
      return;
    }
    _selectedYear = year;
    _selectedMonth = month;
    _invalidateFilterCache();
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    _invalidateFilterCache();
    notifyListeners();
  }

  void updateAdvancedFilters({
    required TypeFilter typeFilter,
    required Set<String> categories,
  }) {
    _typeFilter = typeFilter;
    _selectedCategories = categories;
    _invalidateFilterCache();
    notifyListeners();
  }

  void clearAdvancedFilters() {
    _typeFilter = TypeFilter.all;
    _selectedCategories = {};
    _invalidateFilterCache();
    notifyListeners();
  }

  void updateFilterByYear(bool value) {
    if (_filterByYear == value) {
      return;
    }
    _filterByYear = value;
    _invalidateFilterCache();
    notifyListeners();
  }

  List<TransactionRecord> _applyFilter(List<TransactionRecord> records) {
    return records.where((record) {
      // 来源筛选
      final matchesSource = _currentFilter == SourceFilter.all ||
          (_currentFilter == SourceFilter.alipay && record.source == 'Alipay') ||
          (_currentFilter == SourceFilter.wechat && record.source == 'WeChat');
      if (!matchesSource) {
        return false;
      }

      // 年月筛选
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      final matchesYear = date.year == _selectedYear;
      if (_filterByYear) {
        if (!matchesYear) {
          return false;
        }
      } else {
        if (!matchesYear || date.month != _selectedMonth) {
          return false;
        }
      }

      // 收支类型筛选
      if (_typeFilter == TypeFilter.expense && record.type != TransactionType.expense) {
        return false;
      }
      if (_typeFilter == TypeFilter.income && record.type != TransactionType.income) {
        return false;
      }
      if (_typeFilter == TypeFilter.notCounted && record.type != TransactionType.ignore) {
        return false;
      }

      // 交易类型筛选（多选）
      if (_selectedCategories.isNotEmpty) {
        final transactionCategory = record.transactionCategory ?? '';
        final matchesCategory = _selectedCategories.any(
          (selected) => transactionCategory.contains(selected),
        );
        if (!matchesCategory) {
          return false;
        }
      }

      // 搜索关键词筛选
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch = record.counterparty.toLowerCase().contains(query) ||
            record.description.toLowerCase().contains(query) ||
            (record.category ?? '').toLowerCase().contains(query);
        if (!matchesSearch) {
          return false;
        }
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
      final dataToExport = records; // 已经应用了筛选的数据
      final success = await _export.exportToCsv(
        dataToExport,
        year: _selectedYear,
        month: _selectedMonth,
        filterByYear: _filterByYear,
      );
      _setLoading(false);
      if (success) {
        _snackBarMessage = '已导出 ${dataToExport.length} 条记录';
      } else {
        _snackBarMessage = '导出失败，请重试';
      }
      notifyListeners();
    } catch (_) {
      _setLoading(false);
      _snackBarMessage = '导出失败，请重试';
      notifyListeners();
    }
  }

  /// 获取所有未筛选的数据（用于账单详情编辑后刷新）
  List<TransactionRecord> get allRecords => _records;

  // ==================== 批量编辑方法 ====================

  /// 切换批量编辑模式
  void toggleBatchEdit() {
    _isBatchEditing = !_isBatchEditing;
    if (!_isBatchEditing) {
      _selectedIds.clear();
    }
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
      final count = await _db.batchUpdateCategory(_selectedIds.toList(), category);
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
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final snack = provider.consumeSnackMessage();
        if (snack != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(snack)),
            );
          });
        }

        // 根据是否处于批量编辑模式显示不同的 AppBar
        final appBar = provider.isBatchEditing
            ? _buildBatchEditAppBar(context, provider)
            : _buildNormalAppBar(context, provider);

        return Scaffold(
          appBar: appBar,
          floatingActionButton: provider.isBatchEditing
              ? null // 编辑模式下隐藏 FAB
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 小号编辑按钮
                    FloatingActionButton.small(
                      heroTag: 'edit_fab',
                      onPressed: provider.loading ? null : provider.toggleBatchEdit,
                      child: const Icon(Icons.edit_outlined),
                    ),
                    const SizedBox(height: 12),
                    // 主 FAB（导入）
                    GestureDetector(
                      onLongPress: provider.loading
                          ? null
                          : () => _showClearDataDialog(context, provider),
                      child: FloatingActionButton(
                        heroTag: 'import_fab',
                        onPressed: provider.loading ? null : provider.importFile,
                        child: const Icon(Icons.upload_file),
                      ),
                    ),
                  ],
                ),
          // 编辑模式下显示底部操作栏
          bottomNavigationBar: provider.isBatchEditing
              ? _BatchEditBottomBar(provider: provider)
              : null,
          body: Stack(
            children: [
              ListView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: provider.isBatchEditing ? 80 : 16,
                ),
                children: [
                  // 筛选按钮 + 搜索栏
                  Row(
                    children: [
                      _FilterButton(
                        hasActiveFilters: provider.hasActiveFilters,
                        onTap: () => _showAdvancedFilterModal(
                          context,
                          initialTypeFilter: provider.typeFilter,
                          initialCategories: provider.selectedCategories,
                          filterTypes: provider.filterTypes,
                          categoryGroups: provider.categoryGroups,
                          onConfirm: (typeFilter, categories) {
                            provider.updateAdvancedFilters(
                              typeFilter: typeFilter,
                              categories: categories,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SearchBar(onChanged: provider.updateSearchQuery),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 年月选择 + 汇总信息
                  _MonthSummaryRow(
                    year: provider.selectedYear,
                    month: provider.selectedMonth,
                    summary: provider.summary,
                    filterByYear: provider.filterByYear,
                    onMonthTap: () {
                      if (provider.filterByYear) {
                        _showYearPicker(context, provider);
                      } else {
                        showMonthYearPicker(
                          context,
                          initialYear: provider.selectedYear,
                          initialMonth: provider.selectedMonth,
                          onConfirm: provider.updateMonthYear,
                          hasDataForYearMonth: (year, month) => hasDataForMonthAny(
                            records: provider.allRecords,
                            year: year,
                            month: month,
                          ),
                          noDataWarning: '该月份暂无数据',
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // 来源筛选
                  _SourceFilter(
                    current: provider.currentFilter,
                    onChanged: provider.updateFilter,
                  ),
                  const SizedBox(height: 16),
                  ...provider.records.map(
                    (record) => _TransactionTile(
                      record: record,
                      isEditing: provider.isBatchEditing,
                      isSelected: provider.selectedIds.contains(record.id),
                      onTap: provider.isBatchEditing
                          ? () => provider.toggleSelection(record.id)
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TransactionDetailPage(record: record),
                                ),
                              );
                            },
                    ),
                  ),
                ],
              ),
              if (provider.loading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建普通模式的 AppBar
  AppBar _buildNormalAppBar(BuildContext context, FinanceProvider provider) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('记账'),
          const SizedBox(width: 12),
          _DateRangeRadio(
            filterByYear: provider.filterByYear,
            onChanged: provider.updateFilterByYear,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: '导出账单',
          onPressed: provider.loading ? null : provider.exportCurrentData,
        ),
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          tooltip: '收支分析',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalysisPage()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: '分类管理',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryManagePage()),
            );
          },
        ),
      ],
    );
  }

  /// 构建批量编辑模式的 AppBar
  AppBar _buildBatchEditAppBar(BuildContext context, FinanceProvider provider) {
    final allSelected = provider.selectedCount == provider.records.length &&
        provider.records.isNotEmpty;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: provider.exitBatchEdit,
      ),
      title: Text('已选择 ${provider.selectedCount} 项'),
      actions: [
        TextButton(
          onPressed: allSelected ? provider.clearSelection : provider.selectAll,
          child: Text(allSelected ? '取消全选' : '全选'),
        ),
      ],
    );
  }
}

class _SourceFilter extends StatelessWidget {
  const _SourceFilter({required this.current, required this.onChanged});

  final SourceFilter current;
  final ValueChanged<SourceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SourceFilter>(
      segments: const [
        ButtonSegment(
          value: SourceFilter.all,
          label: Text('总计'),
        ),
        ButtonSegment(
          value: SourceFilter.alipay,
          label: Text('支付宝'),
        ),
        ButtonSegment(
          value: SourceFilter.wechat,
          label: Text('微信'),
        ),
      ],
      selected: {current},
      onSelectionChanged: (value) {
        if (value.isEmpty) {
          return;
        }
        onChanged(value.first);
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.record,
    this.onTap,
    this.isEditing = false,
    this.isSelected = false,
  });

  final TransactionRecord record;
  final VoidCallback? onTap;
  final bool isEditing;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final isExpense = record.type == TransactionType.expense;
    final isIncome = record.type == TransactionType.income;
    final color = isExpense ? Colors.red : (isIncome ? Colors.green : Colors.grey);
    final time = DateFormat('MM-dd HH:mm').format(
      DateTime.fromMillisecondsSinceEpoch(record.timestamp),
    );
    final amount = NumberFormat.currency(symbol: '¥', decimalDigits: 2)
        .format(record.amount / 100);

    return ListTile(
      onTap: onTap,
      leading: isEditing
          ? IgnorePointer(
              child: Checkbox(
                value: isSelected,
                onChanged: (_) {},
              ),
            )
          : CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(Icons.account_balance_wallet, color: color),
            ),
      title: Text(record.counterparty),
      subtitle: Text('$time · ${record.description}'),
      trailing: Text(amount, style: TextStyle(color: color)),
    );
  }
}

/// 批量编辑底部操作栏
class _BatchEditBottomBar extends StatelessWidget {
  const _BatchEditBottomBar({required this.provider});

  final FinanceProvider provider;

  @override
  Widget build(BuildContext context) {
    final hasSelection = provider.selectedCount > 0;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: hasSelection
                ? () => _showBatchCategoryModal(context, provider)
                : null,
            icon: const Icon(Icons.category_outlined),
            label: const Text('修改分类'),
          ),
          TextButton.icon(
            onPressed: hasSelection
                ? () => _showBatchNoteModal(context, provider)
                : null,
            icon: const Icon(Icons.note_outlined),
            label: const Text('修改备注'),
          ),
        ],
      ),
    );
  }
}

class _MonthYearSelector extends StatelessWidget {
  const _MonthYearSelector({
    required this.year,
    required this.month,
    required this.onTap,
    this.filterByYear = false,
  });

  final int year;
  final int month;
  final VoidCallback onTap;
  final bool filterByYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = filterByYear ? '$year年' : '$year年$month月';
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayText,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down,
            size: 20,
            color: theme.colorScheme.onSurface,
          ),
        ],
      ),
    );
  }
}

/// 年月选择 + 汇总信息（参考截图布局）
class _MonthSummaryRow extends StatelessWidget {
  const _MonthSummaryRow({
    required this.year,
    required this.month,
    required this.summary,
    required this.onMonthTap,
    this.filterByYear = false,
  });

  final int year;
  final int month;
  final Map<String, int> summary;
  final VoidCallback onMonthTap;
  final bool filterByYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(symbol: '¥', decimalDigits: 2);
    final expense = formatter.format((summary['expense'] ?? 0) / 100);
    final income = formatter.format((summary['income'] ?? 0) / 100);

    return Row(
      children: [
        _MonthYearSelector(
          year: year,
          month: month,
          onTap: onMonthTap,
          filterByYear: filterByYear,
        ),
        const Spacer(),
        Text(
          '支出$expense',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '收入$income',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: '查找交易',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.hasActiveFilters, required this.onTap});

  final bool hasActiveFilters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasActiveFilters
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasActiveFilters ? '已筛选' : '全部账单',
              style: TextStyle(
                color: hasActiveFilters
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: hasActiveFilters
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
            if (hasActiveFilters) ...[
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

void _showYearPicker(BuildContext context, FinanceProvider provider) {
  final theme = Theme.of(context);
  // 年份范围：2000-2030，降序排列
  final years = List.generate(31, (i) => 2030 - i);
  // 找到当前选中年份的索引，用于初始滚动位置
  final initialIndex = years.indexOf(provider.selectedYear);
  final scrollController = ScrollController(
    initialScrollOffset: initialIndex > 0 ? (initialIndex * 56.0) : 0,
  );

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '选择年份',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 300,
              child: ListView.builder(
                controller: scrollController,
                itemCount: years.length,
                itemBuilder: (context, index) {
                  final year = years[index];
                  final hasData = hasDataForYearAny(
                    records: provider.allRecords,
                    year: year,
                  );
                  return ListTile(
                    title: Text(
                      '$year年',
                      style: TextStyle(
                        color: hasData ? Colors.black : Colors.grey.shade400,
                        fontWeight: hasData ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    trailing: provider.selectedYear == year
                        ? Icon(Icons.check, color: theme.colorScheme.primary)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      provider.updateMonthYear(year, provider.selectedMonth);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showClearDataDialog(BuildContext context, FinanceProvider provider) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('清空数据'),
      content: const Text('确定要清空所有交易记录吗？\n\n清空后需要重新导入账单文件。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            provider.clearAllData();
          },
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('清空'),
        ),
      ],
    ),
  );
}

void _showAdvancedFilterModal(
  BuildContext context, {
  required TypeFilter initialTypeFilter,
  required Set<String> initialCategories,
  required List<FilterType> filterTypes,
  required List<CategoryGroup> categoryGroups,
  required void Function(TypeFilter, Set<String>) onConfirm,
}) {
  var typeFilter = initialTypeFilter;
  var selectedCategories = Set<String>.from(initialCategories);

  // 构建 groupId -> color 的映射
  final groupColorMap = <int, int>{};
  for (final group in categoryGroups) {
    groupColorMap[group.id] = group.color;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SizedBox(
              height: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          '选择筛选选项',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 收支类型
                          const Text(
                            '收支类型',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _FilterChip(
                                label: '全部',
                                selected: typeFilter == TypeFilter.all,
                                onTap: () => setState(() => typeFilter = TypeFilter.all),
                              ),
                              const SizedBox(width: 12),
                              _FilterChip(
                                label: '支出',
                                selected: typeFilter == TypeFilter.expense,
                                onTap: () => setState(() => typeFilter = TypeFilter.expense),
                              ),
                              const SizedBox(width: 12),
                              _FilterChip(
                                label: '收入',
                                selected: typeFilter == TypeFilter.income,
                                onTap: () => setState(() => typeFilter = TypeFilter.income),
                              ),
                              const SizedBox(width: 12),
                              _FilterChip(
                                label: '不计收支',
                                selected: typeFilter == TypeFilter.notCounted,
                                onTap: () => setState(() => typeFilter = TypeFilter.notCounted),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // 交易类型
                          const Text(
                            '交易类型',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _FilterChip(
                                label: '全部',
                                selected: selectedCategories.isEmpty,
                                onTap: () => setState(() => selectedCategories.clear()),
                              ),
                              ...filterTypes.map(
                                (ft) => _FilterChip(
                                  label: ft.name,
                                  selected: selectedCategories.contains(ft.name),
                                  groupColor: ft.groupId != null
                                      ? Color(groupColorMap[ft.groupId] ?? 0xFF9E9E9E)
                                      : null,
                                  onTap: () => setState(() {
                                    if (selectedCategories.contains(ft.name)) {
                                      selectedCategories.remove(ft.name);
                                    } else {
                                      selectedCategories.add(ft.name);
                                    }
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 底部按钮
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              onConfirm(typeFilter, selectedCategories);
                              Navigator.pop(context);
                            },
                            child: const Text('确定'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// 批量修改分类弹窗
void _showBatchCategoryModal(BuildContext context, FinanceProvider provider) {
  final customCategories = provider.customCategories;

  // 构建颜色映射
  final groupColorMap = <String, Color>{};
  final groups = provider.categoryGroups;

  // 1. 获取基础分组颜色
  final wechatGroup = groups.firstWhere((g) => g.name == '微信', orElse: () => CategoryGroup(id: -1, name: '微信', color: 0xFF4CAF50, sortOrder: 0, createdAt: DateTime.now().millisecondsSinceEpoch));
  final alipayGroup = groups.firstWhere((g) => g.name == '支付宝', orElse: () => CategoryGroup(id: -1, name: '支付宝', color: 0xFF1976D2, sortOrder: 0, createdAt: DateTime.now().millisecondsSinceEpoch));
  
  final wechatColor = Color(wechatGroup.color);
  final alipayColor = Color(alipayGroup.color);

  // 2. 预填充所有系统分类的颜色
  for (final cat in kWechatTransactionTypes) {
    groupColorMap[cat] = wechatColor;
  }
  for (final cat in kAlipayCategories) {
    groupColorMap[cat] = alipayColor;
  }

  // 3. 用用户的筛选类型配置覆盖（如果有特殊分组设置）
  final filterTypes = provider.filterTypes;
  for (final ft in filterTypes) {
    if (ft.groupId != null) {
      final group = groups.where((g) => g.id == ft.groupId).firstOrNull;
      if (group != null) {
        groupColorMap[ft.name] = Color(group.color);
      }
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.75, // 限制最大高度为屏幕高度的 75%
    ),
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  '选择分类',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 自定义分类
                  if (customCategories.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '自定义分类',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    CategoryGrid(
                      categories: customCategories,
                      groupColorMap: groupColorMap,
                      onCategoryTap: (category) {
                        Navigator.pop(context);
                        provider.updateBatchCategory(category);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  // 微信分类
                  Builder(
                    builder: (context) {
                      final wechatGroup = provider.categoryGroups
                          .where((g) => g.name == '微信')
                          .firstOrNull;
                      // 这里的 wechatColor 从分组配置读取，如果为空则用默认绿色
                      final wechatColor = wechatGroup != null
                          ? Color(wechatGroup.color)
                          : const Color(0xFF4CAF50);
                      
                      // 构建微信专用的颜色映射：基于全局映射，但强制将微信列表中的分类设为 wechatColor
                      final wechatColorMap = Map<String, Color>.from(groupColorMap);
                      for (final cat in kWechatTransactionTypes) {
                        wechatColorMap[cat] = wechatColor;
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '微信交易类型',
                              style: TextStyle(
                                fontSize: 13,
                                color: wechatColor, // 使用动态获取的颜色
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          CategoryGrid(
                            categories: kWechatTransactionTypes,
                            groupColorMap: wechatColorMap, // 使用专用 map
                            onCategoryTap: (category) {
                              Navigator.pop(context);
                              provider.updateBatchCategory(category);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // 支付宝分类
                  Builder(
                    builder: (context) {
                      final alipayGroup = provider.categoryGroups
                          .where((g) => g.name == '支付宝')
                          .firstOrNull;
                      final alipayColor = alipayGroup != null
                          ? Color(alipayGroup.color)
                          : const Color(0xFF1976D2);

                      // 构建支付宝专用的颜色映射
                      final alipayColorMap = Map<String, Color>.from(groupColorMap);
                      for (final cat in kAlipayCategories) {
                        alipayColorMap[cat] = alipayColor;
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '支付宝交易分类',
                              style: TextStyle(
                                fontSize: 13,
                                color: alipayColor, // 使用动态获取的颜色
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          CategoryGrid(
                            categories: kAlipayCategories,
                            groupColorMap: alipayColorMap, // 使用专用 map
                            onCategoryTap: (category) {
                              Navigator.pop(context);
                              provider.updateBatchCategory(category);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// 批量修改备注弹窗
void _showBatchNoteModal(BuildContext context, FinanceProvider provider) {
  final controller = TextEditingController();
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '修改备注',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '请输入备注内容',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      provider.updateBatchNote(controller.text);
                    },
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.groupColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? groupColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 如果有分组颜色，使用分组颜色作为背景（带透明度或直接填充）
    // 需求要求填充颜色，文字黑色
    final Color backgroundColor = selected
        ? (groupColor ?? theme.colorScheme.primaryContainer)
        : (groupColor?.withValues(alpha: 0.2) ?? theme.colorScheme.surfaceContainerHighest);
    
    final Color borderColor = selected
        ? (groupColor ?? theme.colorScheme.primary)
        : (groupColor?.withValues(alpha: 0.5) ?? theme.colorScheme.outline.withValues(alpha: 0.5));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(
            color: borderColor,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black, // 需求要求文字统一为黑色
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// 月份/年份切换单选按钮（仿 Uiverse CSS 样式）
class _DateRangeRadio extends StatelessWidget {
  const _DateRangeRadio({
    required this.filterByYear,
    required this.onChanged,
  });

  final bool filterByYear;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 0,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadioOption(
            label: '按月',
            selected: !filterByYear,
            onTap: () => onChanged(false),
          ),
          _RadioOption(
            label: '按年',
            selected: filterByYear,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  const _RadioOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF334155),
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
