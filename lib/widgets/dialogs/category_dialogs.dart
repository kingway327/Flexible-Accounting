import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/category_dao.dart';
import '../../models/models.dart';
import '../../providers/finance_provider.dart';
import '../../constants/categories.dart';
import '../../utils/category_icons.dart';
import '../category_grid.dart';

/// 分类/分组管理相关的对话框工具类
class CategoryDialogs {
  /// 显示添加分组对话框
  static Future<void> showAddGroupDialog(
    BuildContext context, {
    required List<CategoryGroup> existingGroups,
    required VoidCallback onSuccess,
  }) async {
    final controller = TextEditingController();
    int selectedColor = kGoogleColors[9]; // 默认为 Green

    await showDialog(
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
                children: kGoogleColors.map((color) {
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
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
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
                final exists = existingGroups.any((g) => g.name == name);
                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该分组名称已存在')),
                  );
                  return;
                }

                await CategoryDao.instance
                    .insertCategoryGroup(name, selectedColor);
                if (context.mounted) {
                  Navigator.pop(context);
                  onSuccess();
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

  /// 显示编辑分组对话框
  static Future<void> showEditGroupDialog(
    BuildContext context, {
    required CategoryGroup group,
    required List<CategoryGroup> existingGroups,
    required VoidCallback onSuccess,
  }) async {
    final controller = TextEditingController(text: group.name);
    int selectedColor = group.color;

    await showDialog(
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
                children: kGoogleColors.map((color) {
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
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
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
                final exists = existingGroups
                    .any((g) => g.name == name && g.id != group.id);
                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该分组名称已存在')),
                  );
                  return;
                }

                await CategoryDao.instance.updateCategoryGroup(group.id,
                    name: name, color: selectedColor);
                if (context.mounted) {
                  Navigator.pop(context);
                  onSuccess();
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

  /// 显示修改分组颜色对话框
  static Future<void> showEditGroupColorDialog(
    BuildContext context, {
    required CategoryGroup group,
    required VoidCallback onSuccess,
  }) async {
    int selectedColor = group.color;

    await showDialog(
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
                children: kGoogleColors.map((color) {
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
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
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
                await CategoryDao.instance
                    .updateCategoryGroup(group.id, color: selectedColor);
                if (context.mounted) {
                  Navigator.pop(context);
                  onSuccess();
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

  /// 显示删除分组对话框
  static Future<void> showDeleteGroupDialog(
    BuildContext context, {
    required CategoryGroup group,
    required VoidCallback onSuccess,
  }) async {
    await showDialog(
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
              await CategoryDao.instance.deleteCategoryGroup(group.id);
              if (context.mounted) {
                Navigator.pop(context);
                onSuccess();
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

  /// 显示添加分类对话框
  static Future<void> showAddCategoryDialog(
    BuildContext context, {
    required VoidCallback onSuccess,
  }) async {
    final controller = TextEditingController();
    await showDialog(
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
              final exists =
                  await CategoryDao.instance.isCategoryNameExists(name);
              if (exists) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该分类名称已存在')),
                  );
                }
                return;
              }

              await CategoryDao.instance.insertCustomCategory(name);
              if (context.mounted) {
                Navigator.pop(context);
                onSuccess();
                // 刷新 Provider 中的自定义分类和筛选类型（同步添加）
                context.read<FinanceProvider>().refreshCustomCategories();
                context.read<FinanceProvider>().refreshFilterTypes();
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

  /// 显示编辑分类对话框
  static Future<void> showEditCategoryDialog(
    BuildContext context, {
    required CustomCategory category,
    required VoidCallback onSuccess,
  }) async {
    final controller = TextEditingController(text: category.name);
    await showDialog(
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
              final exists =
                  await CategoryDao.instance.isCategoryNameExists(name);
              if (exists) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该分类名称已存在')),
                  );
                }
                return;
              }

              await CategoryDao.instance
                  .updateCustomCategory(category.id, name);
              if (context.mounted) {
                Navigator.pop(context);
                onSuccess();
                context.read<FinanceProvider>().refreshCustomCategories();
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

  /// 显示删除分类对话框
  static Future<void> showDeleteCategoryDialog(
    BuildContext context, {
    required CustomCategory category,
    required VoidCallback onSuccess,
  }) async {
    await showDialog(
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
              await CategoryDao.instance.deleteCustomCategory(category.id);
              if (context.mounted) {
                Navigator.pop(context);
                onSuccess();
                context.read<FinanceProvider>().refreshCustomCategories();
                context.read<FinanceProvider>().refreshFilterTypes();
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

  /// 显示设置账单分类分组对话框
  static Future<void> showSetCategoryGroupDialog(
    BuildContext context, {
    required CustomCategory category,
    required List<CategoryGroup> existingGroups,
    required VoidCallback onSuccess,
  }) async {
    await showDialog(
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
                  await CategoryDao.instance
                      .updateCustomCategoryGroup(category.id, null);
                  if (context.mounted) {
                    Navigator.pop(context);
                    onSuccess();
                    context.read<FinanceProvider>().refreshCustomCategories();
                    context.read<FinanceProvider>().refreshFilterTypes();
                  }
                },
              ),
              const Divider(height: 1),
              // 分组列表
              ...existingGroups.map((group) {
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
                    await CategoryDao.instance
                        .updateCustomCategoryGroup(category.id, group.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      onSuccess();
                      context.read<FinanceProvider>().refreshCustomCategories();
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

  // ==================== 筛选类型操作 ====================

  /// 判断是否为系统筛选类型
  static bool _isSystemFilterType(String name) {
    return kWechatTransactionTypes.contains(name) ||
        kAlipayCategories.contains(name);
  }

  /// 显示添加筛选类型对话框
  static Future<void> showAddFilterTypeDialog(
    BuildContext context, {
    required List<CustomCategory> customCategories,
    required List<FilterType> existingFilterTypes,
    required List<CategoryGroup> existingGroups, // 新增参数
    required VoidCallback onSuccess,
  }) async {
    // 计算可用分类：系统分类 + 自定义分类 - 已有筛选类型
    final existingFilterNames = existingFilterTypes.map((f) => f.name).toSet();

    // 分组计算可用分类
    final availableCustom = customCategories
        .map((c) => c.name)
        .where((c) => !existingFilterNames.contains(c))
        .toList();
    final availableWechat = kWechatTransactionTypes
        .where((c) => !existingFilterNames.contains(c))
        .toList();
    final availableAlipay = kAlipayCategories
        .where((c) => !existingFilterNames.contains(c))
        .toList();

    if (availableCustom.isEmpty &&
        availableWechat.isEmpty &&
        availableAlipay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有分类都已添加为筛选类型')),
      );
      return;
    }

    // 颜色定义 (从 existingGroups 中获取)
    Color wechatColor = const Color(0xFF4CAF50); // 默认绿色
    Color alipayColor = const Color(0xFF1976D2); // 默认蓝色
    for (final group in existingGroups) {
      if (group.name == '微信') {
        wechatColor = Color(group.color);
      } else if (group.name == '支付宝') {
        alipayColor = Color(group.color);
      }
    }

    await showModalBottomSheet(
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
                          onCategoryTap: (category) async {
                            await CategoryDao.instance
                                .insertFilterType(category);
                            if (context.mounted) {
                              Navigator.pop(context);
                              onSuccess();
                              // 刷新 Provider 中的筛选类型
                              context
                                  .read<FinanceProvider>()
                                  .refreshFilterTypes();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('已添加筛选类型「$category」')),
                              );
                            }
                          },
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
                          groupColorMap: {
                            for (var c in availableWechat) c: wechatColor
                          },
                          onCategoryTap: (category) async {
                            await CategoryDao.instance
                                .insertFilterType(category);
                            if (context.mounted) {
                              Navigator.pop(context);
                              onSuccess();
                              context
                                  .read<FinanceProvider>()
                                  .refreshFilterTypes();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('已添加筛选类型「$category」')),
                              );
                            }
                          },
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
                          groupColorMap: {
                            for (var c in availableAlipay) c: alipayColor
                          },
                          onCategoryTap: (category) async {
                            await CategoryDao.instance
                                .insertFilterType(category);
                            if (context.mounted) {
                              Navigator.pop(context);
                              onSuccess();
                              context
                                  .read<FinanceProvider>()
                                  .refreshFilterTypes();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('已添加筛选类型「$category」')),
                              );
                            }
                          },
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

  /// 显示编辑筛选类型对话框
  static Future<void> showEditFilterTypeDialog(
    BuildContext context, {
    required FilterType filterType,
    required VoidCallback onSuccess,
  }) async {
    // 系统分类禁止重命名
    if (_isSystemFilterType(filterType.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系统分类不能重命名')),
      );
      return;
    }

    final controller = TextEditingController(text: filterType.name);
    await showDialog(
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
              final exists =
                  await CategoryDao.instance.isFilterTypeNameExists(name);
              if (exists) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('该筛选类型已存在')),
                  );
                }
                return;
              }

              await CategoryDao.instance.updateFilterType(filterType.id, name);
              if (context.mounted) {
                Navigator.pop(context);
                onSuccess();
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

  /// 显示删除筛选类型对话框
  static Future<void> showDeleteFilterTypeDialog(
    BuildContext context, {
    required FilterType filterType,
    required VoidCallback onSuccess,
  }) async {
    await showDialog(
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
              await CategoryDao.instance.deleteFilterType(filterType.id);
              if (context.mounted) {
                Navigator.pop(context);
                onSuccess();
                // 刷新 Provider 中的筛选类型和自定义分类（同步删除）
                context.read<FinanceProvider>().refreshFilterTypes();
                context.read<FinanceProvider>().refreshCustomCategories();
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

  /// 显示设置筛选类型分组对话框
  static Future<void> showSetGroupDialog(
    BuildContext context, {
    required FilterType filterType,
    required List<CategoryGroup> existingGroups,
    required VoidCallback onSuccess,
  }) async {
    // 系统分类禁止修改分组
    if (_isSystemFilterType(filterType.name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('系统分类不能修改分组')),
      );
      return;
    }

    await showDialog(
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
                  await CategoryDao.instance
                      .updateFilterTypeGroup(filterType.id, null);
                  if (context.mounted) {
                    Navigator.pop(context);
                    onSuccess();
                    context.read<FinanceProvider>().refreshFilterTypes();
                  }
                },
              ),
              const Divider(height: 1),
              // 分组列表
              ...existingGroups.map((group) {
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
                    await CategoryDao.instance
                        .updateFilterTypeGroup(filterType.id, group.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      onSuccess();
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
  static void showFilterTypeActionSheet(
    BuildContext context, {
    required FilterType filterType,
    required String groupName,
    required int groupColor,
    required List<CategoryGroup> existingGroups,
    required VoidCallback onSuccess,
  }) {
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
                        showSetGroupDialog(
                          context,
                          filterType: filterType,
                          existingGroups: existingGroups,
                          onSuccess: onSuccess,
                        );
                      },
                    ),
                  // 重命名（非系统分类）
                  if (!isSystem)
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('重命名'),
                      onTap: () {
                        Navigator.pop(context);
                        showEditFilterTypeDialog(
                          context,
                          filterType: filterType,
                          onSuccess: onSuccess,
                        );
                      },
                    ),
                  // 删除（所有类型可用）
                  ListTile(
                    leading:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    title:
                        const Text('删除', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      Navigator.pop(context);
                      showDeleteFilterTypeDialog(
                        context,
                        filterType: filterType,
                        onSuccess: onSuccess,
                      );
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
}
