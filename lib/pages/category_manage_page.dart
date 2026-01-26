import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../main.dart';
import '../models/models.dart';
import '../utils/category_icons.dart';
import '../widgets/category_grid.dart';
import '../widgets/filter_type_grid_item.dart';

/// 分类管理页面（包含账单分类和筛选类型两个 Tab）
class CategoryManagePage extends StatefulWidget {
  const CategoryManagePage({super.key});

  @override
  State<CategoryManagePage> createState() => _CategoryManagePageState();
}

class _CategoryManagePageState extends State<CategoryManagePage>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  late TabController _tabController;

  // 账单分类
  List<CustomCategory> _customCategories = [];
  // 筛选类型
  List<FilterType> _filterTypes = [];
  // 分组
  List<CategoryGroup> _categoryGroups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _customCategories = await _db.fetchCustomCategories();
    _filterTypes = await _db.fetchFilterTypes();
    _categoryGroups = await _db.fetchCategoryGroups();
    setState(() => _loading = false);
  }

  /// 判断筛选类型是否为系统分类（微信 8 类 + 支付宝 39 类）
  /// 系统分类禁止重命名和修改分组，但可以删除
  bool _isSystemFilterType(String name) {
    return kWechatTransactionTypes.contains(name) ||
        kAlipayCategories.contains(name);
  }

  // ==================== 账单分类操作 ====================

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入分类名称',
            border: OutlineInputBorder(),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分类名称不能为空')),
                );
                return;
              }

              // 检查是否与系统分类重复
              if (kSpendingCategories.contains(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('该分类已存在于系统分类中')),
                );
                return;
              }

              // 检查是否与自定义分类重复
              final exists = await _db.isCategoryNameExists(name);
              if (exists) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该分类名称已存在')),
                  );
                }
                return;
              }

              await _db.insertCustomCategory(name);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
                // 刷新 Provider 中的自定义分类
                if (context.mounted) {
                  context.read<FinanceProvider>().refreshCustomCategories();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已添加分类「$name」')),
                );
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(CustomCategory category) {
    final controller = TextEditingController(text: category.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入分类名称',
            border: OutlineInputBorder(),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分类名称不能为空')),
                );
                return;
              }

              if (name == category.name) {
                Navigator.pop(context);
                return;
              }

              // 检查是否与系统分类重复
              if (kSpendingCategories.contains(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('该分类已存在于系统分类中')),
                );
                return;
              }

              // 检查是否与自定义分类重复
              final exists = await _db.isCategoryNameExists(name);
              if (exists) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该分类名称已存在')),
                  );
                }
                return;
              }

              await _db.updateCustomCategory(category.id, name);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
                // 刷新 Provider 中的自定义分类
                if (context.mounted) {
                  context.read<FinanceProvider>().refreshCustomCategories();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已修改为「$name」')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryDialog(CustomCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除分类「${category.name}」吗？\n\n已使用该分类的账单不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await _db.deleteCustomCategory(category.id);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
                // 刷新 Provider 中的自定义分类
                if (context.mounted) {
                  context.read<FinanceProvider>().refreshCustomCategories();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除分类「${category.name}」')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ==================== 筛选类型操作 ====================

  void _showAddFilterTypeDialog() {
    // 计算可用分类：系统分类 + 自定义分类 - 已有筛选类型
    final existingFilterNames = _filterTypes.map((f) => f.name).toSet();
    
    // 分组计算可用分类
    final availableCustom = _customCategories
        .map((c) => c.name)
        .where((c) => !existingFilterNames.contains(c))
        .toList();
    final availableWechat = kWechatTransactionTypes
        .where((c) => !existingFilterNames.contains(c))
        .toList();
    final availableAlipay = kAlipayCategories
        .where((c) => !existingFilterNames.contains(c))
        .toList();

    if (availableCustom.isEmpty && availableWechat.isEmpty && availableAlipay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有分类都已添加为筛选类型')),
      );
      return;
    }

    // 颜色定义
    const wechatColor = Color(0xFF4CAF50);
    const alipayColor = Color(0xFF1976D2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7, // 限制最大高度为屏幕高度的 70%
      ),
      builder: (bottomSheetContext) {
        final theme = Theme.of(bottomSheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      '选择要添加的分类',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(bottomSheetContext),
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
                        if (availableCustom.isNotEmpty) ...[
                          Text(
                            '自定义分类',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CategoryGrid(
                            categories: availableCustom,
                            onCategoryTap: (category) => _addFilterType(category),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // 微信交易类型
                        if (availableWechat.isNotEmpty) ...[
                          Text(
                            '微信交易类型',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: wechatColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CategoryGrid(
                            categories: availableWechat,
                            groupColorMap: {for (var c in availableWechat) c: wechatColor},
                            onCategoryTap: (category) => _addFilterType(category),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // 支付宝交易分类
                        if (availableAlipay.isNotEmpty) ...[
                          Text(
                            '支付宝交易分类',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: alipayColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CategoryGrid(
                            categories: availableAlipay,
                            groupColorMap: {for (var c in availableAlipay) c: alipayColor},
                            onCategoryTap: (category) => _addFilterType(category),
                          ),
                        ],
                      ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 添加筛选类型的辅助方法
  Future<void> _addFilterType(String category) async {
    await _db.insertFilterType(category);
    if (mounted) {
      Navigator.pop(context);
      _loadData();
      // 刷新 Provider 中的筛选类型
      context.read<FinanceProvider>().refreshFilterTypes();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已添加筛选类型「$category」')),
      );
    }
  }

  void _showEditFilterTypeDialog(FilterType filterType) {
    // 系统分类禁止重命名
    if (_isSystemFilterType(filterType.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系统分类不能重命名')),
      );
      return;
    }

    final controller = TextEditingController(text: filterType.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑筛选类型'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '请输入筛选类型名称',
            border: OutlineInputBorder(),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('名称不能为空')),
                );
                return;
              }

              if (name == filterType.name) {
                Navigator.pop(context);
                return;
              }

              // 检查是否已存在
              final exists = await _db.isFilterTypeNameExists(name);
              if (exists) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该筛选类型已存在')),
                  );
                }
                return;
              }

              await _db.updateFilterType(filterType.id, name);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
                // 刷新 Provider 中的筛选类型
                context.read<FinanceProvider>().refreshFilterTypes();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已修改为「$name」')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFilterTypeDialog(FilterType filterType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除筛选类型'),
        content: Text('确定要删除筛选类型「${filterType.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await _db.deleteFilterType(filterType.id);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
                // 刷新 Provider 中的筛选类型
                context.read<FinanceProvider>().refreshFilterTypes();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除筛选类型「${filterType.name}」')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ==================== 分组操作 ====================

  // 预设颜色列表
  static const List<int> _presetColors = [
    0xFF4CAF50, // 绿色 (微信)
    0xFF1976D2, // 蓝色 (支付宝)
    0xFF9E9E9E, // 灰色
    0xFFF44336, // 红色
    0xFFFF9800, // 橙色
    0xFFFFEB3B, // 黄色
    0xFF9C27B0, // 紫色
    0xFF00BCD4, // 青色
    0xFF795548, // 棕色
    0xFF607D8B, // 蓝灰色
    0xFFE91E63, // 粉色
    0xFF3F51B5, // 靛蓝色
  ];

  void _showAddGroupDialog() {
    final controller = TextEditingController();
    int selectedColor = _presetColors[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加分组'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '请输入分组名称',
                  border: OutlineInputBorder(),
                ),
                maxLength: 20,
              ),
              const SizedBox(height: 16),
              const Text('选择颜色'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedColor = color);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分组名称不能为空')),
                  );
                  return;
                }

                // 检查是否重名
                final exists = _categoryGroups.any((g) => g.name == name);
                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该分组名称已存在')),
                  );
                  return;
                }

                await _db.insertCategoryGroup(name, selectedColor);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  context.read<FinanceProvider>().refreshCategoryGroups();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已添加分组「$name」')),
                  );
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupDialog(CategoryGroup group) {
    final controller = TextEditingController(text: group.name);
    int selectedColor = group.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑分组'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '请输入分组名称',
                  border: OutlineInputBorder(),
                ),
                maxLength: 20,
              ),
              const SizedBox(height: 16),
              const Text('选择颜色'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedColor = color);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('分组名称不能为空')),
                  );
                  return;
                }

                // 检查是否重名（排除自身）
                final exists = _categoryGroups.any((g) => g.name == name && g.id != group.id);
                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该分组名称已存在')),
                  );
                  return;
                }

                await _db.updateCategoryGroup(group.id, name: name, color: selectedColor);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  context.read<FinanceProvider>().refreshCategoryGroups();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已修改分组「$name」')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGroupColorDialog(CategoryGroup group) {
    int selectedColor = group.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('修改「${group.name}」颜色'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择颜色'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetColors.map((color) {
                  final isSelected = color == selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => selectedColor = color);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedColor == group.color) {
                  Navigator.pop(context);
                  return;
                }
                await _db.updateCategoryGroup(group.id, color: selectedColor);
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  context.read<FinanceProvider>().refreshCategoryGroups();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已修改「${group.name}」颜色')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetGroupDialog(FilterType filterType) {
    // 系统分类禁止修改分组
    if (_isSystemFilterType(filterType.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系统分类不能修改分组')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置筛选类型分组'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              // 无分组选项
              ListTile(
                leading: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                  ),
                ),
                title: const Text('无分组'),
                trailing: filterType.groupId == null
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () async {
                  await _db.updateFilterTypeGroup(filterType.id, null);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    context.read<FinanceProvider>().refreshFilterTypes();
                  }
                },
              ),
              const Divider(height: 1),
              // 分组列表
              ..._categoryGroups.map((group) {
                return ListTile(
                  leading: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(group.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(group.name),
                  trailing: filterType.groupId == group.id
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () async {
                    await _db.updateFilterTypeGroup(filterType.id, group.id);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                      context.read<FinanceProvider>().refreshFilterTypes();
                    }
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  /// 显示筛选类型操作菜单
  void _showFilterTypeActionSheet(FilterType filterType, String groupName, int groupColor) {
    final isSystem = _isSystemFilterType(filterType.name);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      getCategoryIcon(filterType.name),
                      size: 24,
                      color: Color(groupColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        filterType.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // 操作列表
              ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  // 设置分组（非系统分类）
                  if (!isSystem)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: const Text('设置分组'),
                      onTap: () {
                        Navigator.pop(context);
                        _showSetGroupDialog(filterType);
                      },
                    ),
                  // 重命名（非系统分类）
                  if (!isSystem)
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('重命名'),
                      onTap: () {
                        Navigator.pop(context);
                        _showEditFilterTypeDialog(filterType);
                      },
                    ),
                  // 删除（所有类型可用）
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('删除', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteFilterTypeDialog(filterType);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSetCategoryGroupDialog(CustomCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置账单分类分组'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              // 无分组选项
              ListTile(
                leading: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                  ),
                ),
                title: const Text('无分组'),
                trailing: category.groupId == null
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () async {
                  await _db.updateCustomCategoryGroup(category.id, null);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    context.read<FinanceProvider>().refreshCustomCategories();
                  }
                },
              ),
              const Divider(height: 1),
              // 分组列表
              ..._categoryGroups.map((group) {
                return ListTile(
                  leading: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Color(group.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(group.name),
                  trailing: category.groupId == group.id
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () async {
                    await _db.updateCustomCategoryGroup(category.id, group.id);
                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                      context.read<FinanceProvider>().refreshCustomCategories();
                    }
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showDeleteGroupDialog(CategoryGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定要删除分组「${group.name}」吗？\n\n该分组下的筛选类型将变为无分组状态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await _db.deleteCategoryGroup(group.id);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
                context.read<FinanceProvider>().refreshCategoryGroups();
                context.read<FinanceProvider>().refreshFilterTypes();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除分组「${group.name}」')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '账单分类'),
            Tab(text: '筛选类型'),
            Tab(text: '分组管理'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddCategoryDialog();
          } else if (_tabController.index == 1) {
            _showAddFilterTypeDialog();
          } else {
            _showAddGroupDialog();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: 账单分类
                _buildCategoryTab(theme),
                // Tab 2: 筛选类型
                _buildFilterTypeTab(theme),
                // Tab 3: 分组管理
                _buildGroupTab(theme),
              ],
            ),
    );
  }

  Widget _buildCategoryTab(ThemeData theme) {
    // 从分组中获取颜色（如果分组存在）
    Color wechatColor = const Color(0xFF4CAF50); // 默认绿色
    Color alipayColor = const Color(0xFF1976D2); // 默认蓝色
    for (final group in _categoryGroups) {
      if (group.name == '微信') {
        wechatColor = Color(group.color);
      } else if (group.name == '支付宝') {
        alipayColor = Color(group.color);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // 自定义分类
        Text(
          '自定义分类',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (_customCategories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '暂无自定义分类\n点击右下角按钮添加',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: _customCategories.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                final group = category.groupId != null 
                    ? _categoryGroups.firstWhere((g) => g.id == category.groupId, orElse: () => _categoryGroups[0]) // 简单回退
                    : null;
                
                return Column(
                  children: [
                    ListTile(
                      leading: group != null
                          ? Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(group.color),
                                shape: BoxShape.circle,
                              ),
                            )
                          : Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.outline,
                                  width: 1,
                                ),
                              ),
                            ),
                      title: Text(category.name),
                      subtitle: Text(group?.name ?? '无分组'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.folder_outlined),
                            tooltip: '设置分组',
                            onPressed: () => _showSetCategoryGroupDialog(category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showEditCategoryDialog(category),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _showDeleteCategoryDialog(category),
                          ),
                        ],
                      ),
                    ),
                    if (index < _customCategories.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 24),

        // 系统分类 - 微信
        Text(
          '微信交易类型',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: wechatColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '系统分类不可修改',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kWechatTransactionTypes.map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: wechatColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: wechatColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: wechatColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 系统分类 - 支付宝
        Text(
          '支付宝交易分类',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: alipayColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '系统分类不可修改',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kAlipayCategories.map((category) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: alipayColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: alipayColor.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: alipayColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTypeTab(ThemeData theme) {
    // 创建 groupId -> group 的映射
    final groupMap = {for (final g in _categoryGroups) g.id: g};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '筛选类型',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '用于首页的交易类型筛选，点击进行操作',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_filterTypes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Center(
              child: Text(
                '暂无筛选类型\n点击右下角按钮添加',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,       // 每行 4 个
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,  // 宽高比
              ),
              itemCount: _filterTypes.length,
              itemBuilder: (context, index) {
                final filterType = _filterTypes[index];
                final group = filterType.groupId != null ? groupMap[filterType.groupId] : null;
                return FilterTypeGridItem(
                  filterType: filterType,
                  groupName: group?.name ?? '无分组',
                  groupColor: group?.color ?? 0xFF9E9E9E,
                  onTap: () => _showFilterTypeActionSheet(
                    filterType,
                    group?.name ?? '无分组',
                    group?.color ?? 0xFF9E9E9E,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGroupTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '分组管理',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '为筛选类型设置分组和颜色标识',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (_categoryGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '暂无分组\n点击右下角按钮添加',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: _categoryGroups.asMap().entries.map((entry) {
                final index = entry.key;
                final group = entry.value;
                // 统计该分组下的筛选类型数量
                final filterCount = _filterTypes.where((f) => f.groupId == group.id).length;
                return Column(
                  children: [
                    ListTile(
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(group.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(group.name),
                          if (group.isSystem) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '系统',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('$filterCount 个筛选类型'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 颜色修改按钮（所有分组都可以）
                          IconButton(
                            icon: const Icon(Icons.palette_outlined),
                            tooltip: '修改颜色',
                            onPressed: () => _showEditGroupColorDialog(group),
                          ),
                          // 编辑按钮（仅非系统分组）
                          if (!group.isSystem)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: '编辑名称',
                              onPressed: () => _showEditGroupDialog(group),
                            ),
                          // 删除按钮（仅非系统分组）
                          if (!group.isSystem)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: '删除',
                              onPressed: () => _showDeleteGroupDialog(group),
                            ),
                        ],
                      ),
                    ),
                    if (index < _categoryGroups.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
