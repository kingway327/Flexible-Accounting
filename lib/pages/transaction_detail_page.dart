import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../main.dart';
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
  final _db = DatabaseHelper.instance;
  final _dateFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
  final _currencyFormatter = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  late TransactionRecord _record;
  late TextEditingController _noteController;
  bool _hasChanges = false;
  bool _saving = false;

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

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _CategoryPickerSheet(
        currentCategory: _record.category ?? '其他',
        onSelected: (category) async {
          Navigator.pop(context);
          setState(() => _saving = true);
          try {
            await _db.updateTransaction(
              id: _record.id,
              category: category,
            );
            if (mounted) {
              await context.read<FinanceProvider>().loadInitial();
              setState(() {
                _record = _record.copyWith(category: category);
                _saving = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('分类已更改为「$category」')),
              );
            }
          } catch (e) {
            if (mounted) {
              setState(() => _saving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('修改失败，请重试')),
              );
            }
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
    final amountColor = isExpense ? Colors.red : (isIncome ? Colors.green : Colors.grey);
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
                if (confirmed == true && mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('保存修改'),
            ),
          FilledButton(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    try {
                      await _db.updateTransaction(
                        id: _record.id,
                        note: _noteController.text.trim(),
                      );
                      if (mounted) {
                        await context.read<FinanceProvider>().loadInitial();
                        setState(() {
                          _record = _record.copyWith(
                            note: _noteController.text.trim(),
                          );
                          _saving = false;
                          _hasChanges = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('备注已保存')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('保存失败，请重试')),
                        );
                      }
                    }
                  },
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
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
            // 金额类型
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '金额',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              amountPrefix,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: amountColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _currencyFormatter.format(_record.amount.abs()),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTypeString(_record.type),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],
                ),
            ),
            const SizedBox(height: 16),

            // 备注
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
              decoration: const InputDecoration(
                hintText: '输入备注（选填）',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _onNoteChanged(),
            ),
            const SizedBox(height: 24),

            // 分类选择
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _CategoryPickerSheet(
                currentCategory: _record.category ?? '其他',
                onSelected: (category) async {
                  Navigator.pop(context);
                  setState(() => _saving = true);
                  try {
                    await _db.updateTransaction(
                      id: _record.id,
                      category: category,
                    );
                    if (mounted) {
                      await context.read<FinanceProvider>().loadInitial();
                      setState(() {
                        _record = _record.copyWith(category: category);
                        _saving = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('分类已更改为「$category」')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('修改失败，请重试')),
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
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
  final _db = DatabaseHelper.instance;
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
    _customCategories = await _db.fetchCustomCategories();
    setState(() => _loading = false);
  }

  Future<void> _loadCategoryGroups() async {
    _categoryGroups = await _db.fetchCategoryGroups();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customCategoryNames = _customCategories.map((c) => c.name).toList();

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
                        // 自定义分类
                        if (customCategoryNames.isNotEmpty) ...[
                          Text(
                            '自定义分类',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: customCategoryNames.map((category) {
                              return _buildCategoryChip(theme, category, _categoryGroups);
                            }).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // 微信分类
                        Builder(
                          builder: (context) {
                            final wechatGroup = _categoryGroups.where((g) => g.name == '微信').firstOrNull;
                            final wechatColor = wechatGroup != null ? Color(wechatGroup.color) : const Color(0xFF4CAF50);
                            return Text(
                              '微信交易类型',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: wechatColor,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: kWechatTransactionTypes.map((category) {
                            return _buildCategoryChip(theme, category, _categoryGroups);
                          }).toList(),
                        ),
                        const SizedBox(height: 24),

                        // 支付宝分类
                        Builder(
                          builder: (context) {
                            final alipayGroup = _categoryGroups.where((g) => g.name == '支付宝').firstOrNull;
                            final alipayColor = alipayGroup != null ? Color(alipayGroup.color) : const Color(0xFF1976D2);
                            return Text(
                              '支付宝交易分类',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: alipayColor,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: kAlipayCategories.map((category) {
                            return _buildCategoryChip(theme, category, _categoryGroups);
                          }).toList(),
                        ),
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
    if (!kWechatTransactionTypes.contains(category) && !kAlipayCategories.contains(category)) {
      // 从当前分类名称判断（可能对应多个自定义分类）
      for (final customCat in _customCategories) {
        if (customCat.name == category && customCat.groupId != null) {
          final group = _categoryGroups.where((g) => g.id == customCat.groupId).firstOrNull;
          return group != null ? Color(group.color) : null;
        }
      }
    }

    // 系统分类：从分组数据获取颜色（支持用户自定义颜色）
    if (kWechatTransactionTypes.contains(category)) {
      final wechatGroup = _categoryGroups.where((g) => g.name == '微信').firstOrNull;
      return wechatGroup != null ? Color(wechatGroup.color) : const Color(0xFF4CAF50);
    } else if (kAlipayCategories.contains(category)) {
      final alipayGroup = _categoryGroups.where((g) => g.name == '支付宝').firstOrNull;
      return alipayGroup != null ? Color(alipayGroup.color) : const Color(0xFF1976D2);
    }

    return null;
  }

  Widget _buildCategoryChip(ThemeData theme, String category, List<CategoryGroup> groups) {
    final isSelected = category == _selected;
    final icon = getCategoryIcon(category);
    final categoryColor = _getCategoryColor(category) ?? theme.colorScheme.primary;

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
              ? categoryColor.withOpacity(0.15)
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected ? categoryColor : categoryColor.withOpacity(0.3),
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
              color: isSelected ? categoryColor : theme.colorScheme.onSurfaceVariant,
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
