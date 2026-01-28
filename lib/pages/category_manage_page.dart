import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../constants/categories.dart';
import '../providers/finance_provider.dart';
import '../models/models.dart';
import '../utils/category_icons.dart';
import '../widgets/category_grid.dart';
import '../widgets/filter_type_grid_item.dart';
import '../widgets/dialogs/category_dialogs.dart';

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
            CategoryDialogs.showAddCategoryDialog(context, onSuccess: _loadData);
          } else if (_tabController.index == 1) {
            CategoryDialogs.showAddFilterTypeDialog(
              context,
              customCategories: _customCategories,
              existingFilterTypes: _filterTypes,
              existingGroups: _categoryGroups, // 传递分组列表
              onSuccess: _loadData,
            );
          } else {
            CategoryDialogs.showAddGroupDialog(
              context,
              existingGroups: _categoryGroups,
              onSuccess: _loadData,
            );
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
                            onPressed: () => CategoryDialogs.showSetCategoryGroupDialog(
                              context,
                              category: category,
                              existingGroups: _categoryGroups,
                              onSuccess: _loadData,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => CategoryDialogs.showEditCategoryDialog(
                              context,
                              category: category,
                              onSuccess: _loadData,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => CategoryDialogs.showDeleteCategoryDialog(
                              context,
                              category: category,
                              onSuccess: _loadData,
                            ),
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

    // 将筛选类型按分组归类
    final filterTypesByGroup = <int?, List<FilterType>>{};
    for (final ft in _filterTypes) {
      filterTypesByGroup.putIfAbsent(ft.groupId, () => []).add(ft);
    }
    
    // 获取所有分组ID并排序
    // 无分组放在最前面，其他按 sortOrder 排序
    final sortedGroupIds = filterTypesByGroup.keys.toList()
      ..sort((a, b) {
        if (a == null) return -1;
        if (b == null) return 1;
        final groupA = groupMap[a];
        final groupB = groupMap[b];
        if (groupA == null) return 1;
        if (groupB == null) return -1;
        return groupA.sortOrder.compareTo(groupB.sortOrder);
      });

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
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80), // 底部留出 FAB 空间
              itemCount: sortedGroupIds.length,
              itemBuilder: (context, index) {
                final groupId = sortedGroupIds[index];
                final types = filterTypesByGroup[groupId] ?? [];
                final group = groupId != null ? groupMap[groupId] : null;
                final groupName = group?.name ?? '无分组';
                final groupColor = group?.color ?? 0xFF9E9E9E;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 8),
                      child: Text(
                        groupName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(groupColor),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: types.length,
                      itemBuilder: (context, typeIndex) {
                        final filterType = types[typeIndex];
                        return FilterTypeGridItem(
                          filterType: filterType,
                          groupName: groupName,
                          groupColor: groupColor,
                          onTap: () => CategoryDialogs.showFilterTypeActionSheet(
                            context,
                            filterType: filterType,
                            groupName: groupName,
                            groupColor: groupColor,
                            existingGroups: _categoryGroups,
                            onSuccess: _loadData,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
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
                            onPressed: () => CategoryDialogs.showEditGroupColorDialog(
                              context,
                              group: group,
                              onSuccess: _loadData,
                            ),
                          ),
                          // 编辑按钮（仅非系统分组）
                          if (!group.isSystem)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: '编辑名称',
                              onPressed: () => CategoryDialogs.showEditGroupDialog(
                                context,
                                group: group,
                                existingGroups: _categoryGroups,
                                onSuccess: _loadData,
                              ),
                            ),
                          // 删除按钮（仅非系统分组）
                          if (!group.isSystem)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              tooltip: '删除',
                              onPressed: () => CategoryDialogs.showDeleteGroupDialog(
                                context,
                                group: group,
                                onSuccess: _loadData,
                              ),
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
