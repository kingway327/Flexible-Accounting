import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/category_dao.dart';
import '../data/transaction_dao.dart';
import '../constants/categories.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../utils/category_icons.dart';

/// 账单详情编辑页面
class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({
    super.key,
    required this.record,
  });

  final TransactionRecord record;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final _txDao = TransactionDao.instance;
  final _dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
  final _currencyFormatter =
      NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  late TransactionRecord _record;
  late TextEditingController _noteController;
  bool _hasChanges = false;
  bool _saving = false;

  // 来源图标和颜色
  Map<String, IconData> get _sourceIcons => {
        'WeChat': Icons.chat,
        'Alipay': Icons.account_balance_wallet,
      };

  Map<String, Color> get _sourceColors => {
        'WeChat': const Color(0xFF4CAF50),
        'Alipay': const Color(0xFF1976D2),
      };

  @override
  void initState() {
    super.initState();
    _record = widget.record;
    _noteController = TextEditingController(text: _record.note ?? '');
    _noteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    final newNote = _noteController.text.trim();
    final oldNote = _record.note ?? '';
    if (newNote != oldNote && !_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  void _showCategoryPickerSheet() {
    final financeProvider = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) => _CategoryPickerSheet(
        currentCategory: _record.category ?? '其他',
        onSelected: (category) async {
          Navigator.pop(bottomSheetContext);
          setState(() => _saving = true);
          try {
            await _txDao.updateTransaction(
              id: _record.id,
              category: category,
            );
            if (!mounted) return;
            await financeProvider.reload();
            if (!mounted) return;
            setState(() {
              _record = _record.copyWith(category: category);
              _saving = false;
            });
            messenger.showSnackBar(
              SnackBar(content: Text('分类已更改为「$category」')),
            );
          } catch (e) {
            if (!mounted) return;
            setState(() => _saving = false);
            messenger.showSnackBar(
              const SnackBar(content: Text('修改失败，请重试')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = _record.type == TransactionType.expense;
    final isIncome = _record.type == TransactionType.income;
    final amountColor = isExpense
        ? Colors.red.shade700
        : (isIncome ? Colors.green.shade700 : Colors.grey.shade700);
    final amountPrefix = isExpense ? '-' : (isIncome ? '+' : '');
    final time = DateTime.fromMillisecondsSinceEpoch(_record.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账单详情'),
        centerTitle: true,
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认退出'),
                    content: const Text('您的修改尚未保存，确定要退出吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text('确定退出'),
                      ),
                    ],
                  ),
                );
                if (!context.mounted) {
                  return;
                }
                if (confirmed == true) {
                  Navigator.pop(context);
                }
              },
              child: const Text('保存修改'),
            ),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    final financeProvider = context.read<FinanceProvider>();
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _saving = true);
                    try {
                      await _txDao.updateTransaction(
                        id: _record.id,
                        note: _noteController.text.trim(),
                      );
                      if (!mounted) return;
                      await financeProvider.reload();
                      if (!mounted) return;
                      setState(() {
                        _record = _record.copyWith(
                          note: _noteController.text.trim(),
                        );
                        _saving = false;
                        _hasChanges = false;
                      });
                      messenger.showSnackBar(
                        const SnackBar(content: Text('备注已保存')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      setState(() => _saving = false);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('保存失败，请重试')),
                      );
                    }
                  },
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : const Text('保存修改'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 金额类型卡片
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 来源标识
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_sourceColors[_record.source] ?? Colors.grey)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _sourceIcons[_record.source] ??
                                  Icons.info_outline,
                              size: 16,
                              color:
                                  _sourceColors[_record.source] ?? Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _record.source == 'WeChat' ? '微信' : '支付宝',
                              style: TextStyle(
                                fontSize: 12,
                                color: _sourceColors[_record.source] ??
                                    Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: amountColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getTypeString(_record.type),
                          style: TextStyle(
                            fontSize: 12,
                            color: amountColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 金额显示
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        amountPrefix,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          color: amountColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currencyFormatter.format(_record.amount.abs() / 100),
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 详细信息区域标题
            Text(
              '交易详情',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // 交易时间
            _buildDetailCard(
              theme: theme,
              icon: Icons.access_time_outlined,
              label: '交易时间',
              value: _dateFormatter.format(time),
            ),
            const SizedBox(height: 12),

            // 交易对手方
            _buildDetailCard(
              theme: theme,
              icon: Icons.person_outline,
              label: '交易对手方',
              value: _record.counterparty,
            ),
            const SizedBox(height: 12),

            // 交易账户
            _buildDetailCard(
              theme: theme,
              icon: Icons.account_balance_wallet_outlined,
              label: '交易账户',
              value: _record.account,
            ),
            const SizedBox(height: 12),

            // 交易描述
            _buildDetailCard(
              theme: theme,
              icon: Icons.description_outlined,
              label: '交易描述',
              value: _record.description,
            ),
            const SizedBox(height: 24),

            // 分类选择
            GestureDetector(
              onTap: () => _showCategoryPickerSheet(),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        getCategoryIcon(_record.category ?? '其他'),
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '分类',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _record.category ?? '其他',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 备注编辑区
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '备注',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: '输入备注（选填）',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                  ),
                  onChanged: (_) => _onNoteChanged(),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 构建详情卡片
  Widget _buildDetailCard({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTypeString(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
      case TransactionType.ignore:
        return '不计收支';
    }
  }
}

/// 分类选择弹窗
class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.currentCategory,
    required this.onSelected,
  });

  final String currentCategory;
  final ValueChanged<String> onSelected;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _categoryDao = CategoryDao.instance;
  late String _selected;
  List<CustomCategory> _customCategories = [];
  List<CategoryGroup> _categoryGroups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentCategory;
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadCustomCategories(),
      _loadCategoryGroups(),
    ]);
  }

  Future<void> _loadCustomCategories() async {
    _customCategories = await _categoryDao.fetchCustomCategories();
    setState(() => _loading = false);
  }

  Future<void> _loadCategoryGroups() async {
    _categoryGroups = await _categoryDao.fetchCategoryGroups();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 构建分组ID到颜色的映射
    final groupIdToColor = <int, Color>{};
    for (final group in _categoryGroups) {
      groupIdToColor[group.id] = Color(group.color);
    }

    // 构建分组ID到分组对象的映射
    final groupById = <int, CategoryGroup>{
      for (final g in _categoryGroups) g.id: g
    };

    // 获取系统分组
    final wechatGroup =
        _categoryGroups.where((g) => g.name == '微信').firstOrNull;
    final alipayGroup =
        _categoryGroups.where((g) => g.name == '支付宝').firstOrNull;

    // 将分类按分组组织
    final categoriesByGroup = <int?, List<String>>{};

    // 添加自定义分类（按其分组归类）
    for (final cat in _customCategories) {
      categoriesByGroup.putIfAbsent(cat.groupId, () => []).add(cat.name);
    }

    // 添加系统分类（微信和支付宝）
    if (wechatGroup != null) {
      categoriesByGroup
          .putIfAbsent(wechatGroup.id, () => [])
          .addAll(kWechatTransactionTypes);
    }
    if (alipayGroup != null) {
      categoriesByGroup
          .putIfAbsent(alipayGroup.id, () => [])
          .addAll(kAlipayCategories);
    }

    // 按分组排序：无分组放在最前面，然后按分组的 sortOrder 排序
    final sortedGroupIds = categoriesByGroup.keys.toList()
      ..sort((a, b) {
        if (a == null) return -1;
        if (b == null) return 1;
        final groupA = groupById[a];
        final groupB = groupById[b];
        if (groupA == null) return 1;
        if (groupB == null) return -1;
        return groupA.sortOrder.compareTo(groupB.sortOrder);
      });

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
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

            // 分类列表
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (int i = 0; i < sortedGroupIds.length; i++) ...[
                          if (i > 0) const SizedBox(height: 24),
                          Builder(
                            builder: (context) {
                              final groupId = sortedGroupIds[i];
                              final categories =
                                  categoriesByGroup[groupId] ?? [];
                              final group =
                                  groupId != null ? groupById[groupId] : null;
                              final groupName = group?.name ?? '无分组';
                              final groupColor = group != null
                                  ? Color(group.color)
                                  : Colors.grey.shade600;

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupName,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: groupColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: categories.map((category) {
                                      return _buildCategoryChip(
                                          theme, category, _categoryGroups);
                                    }).toList(),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  /// 获取分类颜色（从分组数据或系统默认颜色）
  Color? _getCategoryColor(String category) {
    // 自定义分类：使用其关联分组的颜色（如果有）
    if (!kWechatTransactionTypes.contains(category) &&
        !kAlipayCategories.contains(category)) {
      // 从当前分类名称判断（可能对应多个自定义分类）
      for (final customCat in _customCategories) {
        if (customCat.name == category && customCat.groupId != null) {
          final group = _categoryGroups
              .where((g) => g.id == customCat.groupId)
              .firstOrNull;
          return group != null ? Color(group.color) : null;
        }
      }
    }

    // 系统分类：从分组数据获取颜色（支持用户自定义颜色）
    if (kWechatTransactionTypes.contains(category)) {
      final wechatGroup =
          _categoryGroups.where((g) => g.name == '微信').firstOrNull;
      return wechatGroup != null
          ? Color(wechatGroup.color)
          : const Color(0xFF4CAF50);
    } else if (kAlipayCategories.contains(category)) {
      final alipayGroup =
          _categoryGroups.where((g) => g.name == '支付宝').firstOrNull;
      return alipayGroup != null
          ? Color(alipayGroup.color)
          : const Color(0xFF1976D2);
    }

    return null;
  }

  Widget _buildCategoryChip(
      ThemeData theme, String category, List<CategoryGroup> groups) {
    final isSelected = category == _selected;
    final icon = getCategoryIcon(category);
    final categoryColor =
        _getCategoryColor(category) ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() => _selected = category);
        widget.onSelected(category);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? categoryColor.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected
                ? categoryColor
                : categoryColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? categoryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              category,
              style: TextStyle(
                color: isSelected ? categoryColor : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
