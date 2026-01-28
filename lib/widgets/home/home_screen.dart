import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/categories.dart';
import '../../data/analysis_helpers.dart';
import '../../models/models.dart';
import '../../pages/analysis_page.dart';
import '../../pages/category_manage_page.dart';
import '../../pages/transaction_detail_page.dart';
import '../../providers/finance_provider.dart';
import '../category_grid.dart';
import '../month_picker.dart';

/// 首页主界面
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

        final appBar = provider.isBatchEditing
            ? _buildBatchEditAppBar(context, provider)
            : _buildNormalAppBar(context, provider);

        return Scaffold(
          appBar: appBar,
          floatingActionButton: provider.isBatchEditing
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'edit_fab',
                      onPressed: provider.loading ? null : provider.toggleBatchEdit,
                      child: const Icon(Icons.edit_outlined),
                    ),
                    const SizedBox(height: 12),
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
          bottomNavigationBar: provider.isBatchEditing
              ? BatchEditBottomBar(provider: provider)
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
                  Row(
                    children: [
                      FilterButton(
                        hasActiveFilters: provider.hasActiveFilters,
                        onTap: () => showAdvancedFilterModal(
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
                        child: SearchBarWidget(onChanged: provider.updateSearchQuery),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MonthSummaryRow(
                    year: provider.selectedYear,
                    month: provider.selectedMonth,
                    summary: provider.summary,
                    filterByYear: provider.filterByYear,
                    onMonthTap: () {
                      if (provider.filterByYear) {
                        showYearPicker(context, provider);
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
                  SourceFilterWidget(
                    current: provider.currentFilter,
                    onChanged: provider.updateFilter,
                  ),
                  const SizedBox(height: 16),
                  ...provider.records.map(
                    (record) => TransactionTile(
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

  AppBar _buildNormalAppBar(BuildContext context, FinanceProvider provider) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('记账'),
          const SizedBox(width: 12),
          DateRangeRadio(
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

/// 来源筛选组件
class SourceFilterWidget extends StatelessWidget {
  const SourceFilterWidget({super.key, required this.current, required this.onChanged});

  final SourceFilter current;
  final ValueChanged<SourceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<SourceFilter>(
      segments: const [
        ButtonSegment(value: SourceFilter.all, label: Text('总计')),
        ButtonSegment(value: SourceFilter.alipay, label: Text('支付宝')),
        ButtonSegment(value: SourceFilter.wechat, label: Text('微信')),
      ],
      selected: {current},
      onSelectionChanged: (value) {
        if (value.isNotEmpty) onChanged(value.first);
      },
    );
  }
}

/// 交易记录列表项
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
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
              child: Checkbox(value: isSelected, onChanged: (_) {}),
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
class BatchEditBottomBar extends StatelessWidget {
  const BatchEditBottomBar({super.key, required this.provider});

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
                ? () => showBatchCategoryModal(context, provider)
                : null,
            icon: const Icon(Icons.category_outlined),
            label: const Text('修改分类'),
          ),
          TextButton.icon(
            onPressed: hasSelection
                ? () => showBatchNoteModal(context, provider)
                : null,
            icon: const Icon(Icons.note_outlined),
            label: const Text('修改备注'),
          ),
        ],
      ),
    );
  }
}

/// 年月选择器
class MonthYearSelector extends StatelessWidget {
  const MonthYearSelector({
    super.key,
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

/// 年月选择 + 汇总信息行
class MonthSummaryRow extends StatelessWidget {
  const MonthSummaryRow({
    super.key,
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
        MonthYearSelector(
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

/// 搜索栏组件
class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({super.key, required this.onChanged});

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

/// 筛选按钮
class FilterButton extends StatelessWidget {
  const FilterButton({super.key, required this.hasActiveFilters, required this.onTap});

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

/// 筛选芯片
class FilterChip extends StatelessWidget {
  const FilterChip({
    super.key,
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
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// 月份/年份切换单选按钮
class DateRangeRadio extends StatelessWidget {
  const DateRangeRadio({
    super.key,
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

// ==================== 弹窗函数 ====================

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

/// 显示清空数据对话框
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
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('清空'),
        ),
      ],
    ),
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

    // 对筛选类型进行排序：优先按分组顺序，同分组按各自顺序
    final sortedFilterTypes = List<FilterType>.from(filterTypes);
    sortedFilterTypes.sort((a, b) {
      // 1. 比较分组
      final groupA = a.groupId != null ? groupMap[a.groupId] : null;
      final groupB = b.groupId != null ? groupMap[b.groupId] : null;

      if (groupA == null && groupB != null) return -1; // 无分组排最前
      if (groupA != null && groupB == null) return 1;

      if (groupA != null && groupB != null) {
        final groupCompare = groupA.sortOrder.compareTo(groupB.sortOrder);
        if (groupCompare != 0) return groupCompare;
      }

      // 2. 同分组内比较 (按 sortOrder 或 id)
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
                          const Text(
                            '收支类型',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              FilterChip(
                                label: '全部',
                                selected: typeFilter == TypeFilter.all,
                                onTap: () => setState(() => typeFilter = TypeFilter.all),
                              ),
                              const SizedBox(width: 12),
                              FilterChip(
                                label: '支出',
                                selected: typeFilter == TypeFilter.expense,
                                onTap: () => setState(() => typeFilter = TypeFilter.expense),
                              ),
                              const SizedBox(width: 12),
                              FilterChip(
                                label: '收入',
                                selected: typeFilter == TypeFilter.income,
                                onTap: () => setState(() => typeFilter = TypeFilter.income),
                              ),
                              const SizedBox(width: 12),
                              FilterChip(
                                label: '不计收支',
                                selected: typeFilter == TypeFilter.notCounted,
                                onTap: () => setState(() => typeFilter = TypeFilter.notCounted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            '交易类型',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilterChip(
                                label: '全部',
                                selected: selectedCategories.isEmpty,
                                onTap: () => setState(() => selectedCategories.clear()),
                              ),
                              ...sortedFilterTypes.map(
                                (ft) => FilterChip(
                                  label: ft.name,
                                  selected: selectedCategories.contains(ft.name),
                                  groupColor: ft.groupId != null
                                      ? Color(groupMap[ft.groupId]?.color ?? 0xFF9E9E9E)
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

/// 批量修改分类弹窗
/// 动态根据分组管理中的所有分组和自定义分类的分组设置来布局
void showBatchCategoryModal(BuildContext context, FinanceProvider provider) {
  final customCategoryObjects = provider.customCategoryObjects;
  final groups = provider.categoryGroups;
  
  // 构建分组ID到颜色的映射
  final groupIdToColor = <int, Color>{};
  for (final group in groups) {
    groupIdToColor[group.id] = Color(group.color);
  }
  
  // 构建分类名称到颜色的映射
  final categoryColorMap = <String, Color>{};
  
  // 为自定义分类设置颜色（根据其分组）
  for (final cat in customCategoryObjects) {
    if (cat.groupId != null && groupIdToColor.containsKey(cat.groupId)) {
      categoryColorMap[cat.name] = groupIdToColor[cat.groupId]!;
    }
  }
  
  // 为系统分类设置颜色
  final wechatGroup = groups.where((g) => g.name == '微信').firstOrNull;
  final alipayGroup = groups.where((g) => g.name == '支付宝').firstOrNull;
  final wechatColor = wechatGroup != null ? Color(wechatGroup.color) : const Color(0xFF4CAF50);
  final alipayColor = alipayGroup != null ? Color(alipayGroup.color) : const Color(0xFF1976D2);
  
  for (final cat in kWechatTransactionTypes) {
    categoryColorMap[cat] = wechatColor;
  }
  for (final cat in kAlipayCategories) {
    categoryColorMap[cat] = alipayColor;
  }
  
  // 将分类按分组组织
  // 结构：groupId -> List<String> (分类名称列表)
  // groupId 为 null 表示无分组
  final categoriesByGroup = <int?, List<String>>{};
  
  // 添加自定义分类（按其分组归类）
  for (final cat in customCategoryObjects) {
    categoriesByGroup.putIfAbsent(cat.groupId, () => []).add(cat.name);
  }
  
  // 添加系统分类（微信和支付宝）
  if (wechatGroup != null) {
    categoriesByGroup.putIfAbsent(wechatGroup.id, () => []).addAll(kWechatTransactionTypes);
  }
  if (alipayGroup != null) {
    categoriesByGroup.putIfAbsent(alipayGroup.id, () => []).addAll(kAlipayCategories);
  }
  
  // 构建分组ID到分组对象的映射
  final groupById = <int, CategoryGroup>{for (final g in groups) g.id: g};
  
  // 按分组排序键创建有序列表
  // 无分组放在最前面，然后按分组的 sortOrder 排序
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
                        final group = groupId != null ? groupById[groupId] : null;
                        final groupName = group?.name ?? '无分组';
                        final groupColor = group != null 
                            ? Color(group.color) 
                            : Colors.grey.shade600;
                        
                        // 为当前分组的分类设置颜色
                        final localColorMap = Map<String, Color>.from(categoryColorMap);
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
