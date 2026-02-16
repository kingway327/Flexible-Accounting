import 'package:flutter/material.dart';

import '../../constants/categories.dart';
import '../../data/analysis_helpers.dart';
import '../../models/models.dart';
import '../../providers/finance_provider.dart';
import '../category_grid.dart';
import 'home_display_widgets.dart';

/// 批量修改分类弹窗
/// 动态根据分组管理中的所有分组和自定义分类的分组设置来布局
void showBatchCategoryModal(BuildContext context, FinanceProvider provider) {
  final customCategoryObjects = provider.customCategoryObjects;
  final groups = provider.categoryGroups;

  final groupIdToColor = <int, Color>{};
  for (final group in groups) {
    groupIdToColor[group.id] = Color(group.color);
  }

  final categoryColorMap = <String, Color>{};
  for (final cat in customCategoryObjects) {
    if (cat.groupId != null && groupIdToColor.containsKey(cat.groupId)) {
      categoryColorMap[cat.name] = groupIdToColor[cat.groupId]!;
    }
  }

  final wechatGroup = groups.where((g) => g.name == '微信').firstOrNull;
  final alipayGroup = groups.where((g) => g.name == '支付宝').firstOrNull;
  final wechatColor =
      wechatGroup != null ? Color(wechatGroup.color) : const Color(0xFF4CAF50);
  final alipayColor =
      alipayGroup != null ? Color(alipayGroup.color) : const Color(0xFF1976D2);

  for (final cat in kWechatTransactionTypes) {
    categoryColorMap[cat] = wechatColor;
  }
  for (final cat in kAlipayCategories) {
    categoryColorMap[cat] = alipayColor;
  }

  final categoriesByGroup = <int?, List<String>>{};
  for (final cat in customCategoryObjects) {
    categoriesByGroup.putIfAbsent(cat.groupId, () => []).add(cat.name);
  }
  if (wechatGroup != null) {
    categoriesByGroup.putIfAbsent(wechatGroup.id, () => []).addAll(
          kWechatTransactionTypes,
        );
  }
  if (alipayGroup != null) {
    categoriesByGroup.putIfAbsent(alipayGroup.id, () => []).addAll(
          kAlipayCategories,
        );
  }

  final groupById = <int, CategoryGroup>{for (final g in groups) g.id: g};
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

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.75,
    ),
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  '选择分类',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                  for (int i = 0; i < sortedGroupIds.length; i++) ...[
                    if (i > 0) const SizedBox(height: 24),
                    Builder(
                      builder: (context) {
                        final groupId = sortedGroupIds[i];
                        final categories = categoriesByGroup[groupId] ?? [];
                        final group =
                            groupId != null ? groupById[groupId] : null;
                        final groupName = group?.name ?? '无分组';
                        final groupColor = group != null
                            ? Color(group.color)
                            : Colors.grey.shade600;

                        final localColorMap = Map<String, Color>.from(
                          categoryColorMap,
                        );
                        if (group != null) {
                          for (final cat in categories) {
                            localColorMap[cat] = groupColor;
                          }
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                groupName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: groupColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            CategoryGrid(
                              categories: categories,
                              groupColorMap: localColorMap,
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
void showBatchNoteModal(BuildContext context, FinanceProvider provider) {
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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

/// 显示年份选择器
void showYearPicker(BuildContext context, FinanceProvider provider) {
  final theme = Theme.of(context);
  final years = List.generate(31, (i) => 2030 - i);
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
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
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
                        fontWeight:
                            hasData ? FontWeight.w500 : FontWeight.normal,
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

/// 显示高级筛选弹窗
void showAdvancedFilterModal(
  BuildContext context, {
  required TypeFilter initialTypeFilter,
  required Set<String> initialCategories,
  required List<FilterType> filterTypes,
  required List<CategoryGroup> categoryGroups,
  required void Function(TypeFilter, Set<String>) onConfirm,
}) {
  var typeFilter = initialTypeFilter;
  var selectedCategories = Set<String>.from(initialCategories);

  final groupMap = {for (final group in categoryGroups) group.id: group};

  final sortedFilterTypes = List<FilterType>.from(filterTypes);
  sortedFilterTypes.sort((a, b) {
    final groupA = a.groupId != null ? groupMap[a.groupId] : null;
    final groupB = b.groupId != null ? groupMap[b.groupId] : null;

    if (groupA == null && groupB != null) return -1;
    if (groupA != null && groupB == null) return 1;

    if (groupA != null && groupB != null) {
      final groupCompare = groupA.sortOrder.compareTo(groupB.sortOrder);
      if (groupCompare != 0) return groupCompare;
    }

    return a.sortOrder.compareTo(b.sortOrder);
  });

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
                              FinanceFilterChip(
                                label: '全部',
                                selected: typeFilter == TypeFilter.all,
                                onTap: () =>
                                    setState(() => typeFilter = TypeFilter.all),
                              ),
                              const SizedBox(width: 12),
                              FinanceFilterChip(
                                label: '支出',
                                selected: typeFilter == TypeFilter.expense,
                                onTap: () => setState(
                                    () => typeFilter = TypeFilter.expense),
                              ),
                              const SizedBox(width: 12),
                              FinanceFilterChip(
                                label: '收入',
                                selected: typeFilter == TypeFilter.income,
                                onTap: () => setState(
                                    () => typeFilter = TypeFilter.income),
                              ),
                              const SizedBox(width: 12),
                              FinanceFilterChip(
                                label: '不计收支',
                                selected: typeFilter == TypeFilter.notCounted,
                                onTap: () => setState(
                                  () => typeFilter = TypeFilter.notCounted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
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
                              FinanceFilterChip(
                                label: '全部',
                                selected: selectedCategories.isEmpty,
                                onTap: () =>
                                    setState(() => selectedCategories.clear()),
                              ),
                              ...sortedFilterTypes.map(
                                (ft) => FinanceFilterChip(
                                  label: ft.name,
                                  selected:
                                      selectedCategories.contains(ft.name),
                                  groupColor: ft.groupId != null
                                      ? Color(
                                          groupMap[ft.groupId]?.color ??
                                              0xFF9E9E9E,
                                        )
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
