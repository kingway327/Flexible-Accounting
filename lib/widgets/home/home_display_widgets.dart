import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/finance_provider.dart';

/// 来源筛选组件
class SourceFilterWidget extends StatelessWidget {
  const SourceFilterWidget({
    super.key,
    required this.current,
    required this.onChanged,
  });

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
        if (value.isNotEmpty) {
          onChanged(value.first);
        }
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
    final color =
        isExpense ? Colors.red : (isIncome ? Colors.green : Colors.grey);
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

/// 筛选按钮
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.hasActiveFilters,
    required this.onTap,
  });

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

/// 批量编辑底部操作栏
class BatchEditBottomBar extends StatelessWidget {
  const BatchEditBottomBar({
    super.key,
    required this.hasSelection,
    required this.onEditCategory,
    required this.onEditNote,
  });

  final bool hasSelection;
  final VoidCallback onEditCategory;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: hasSelection ? onEditCategory : null,
            icon: const Icon(Icons.category_outlined),
            label: const Text('修改分类'),
          ),
          TextButton.icon(
            onPressed: hasSelection ? onEditNote : null,
            icon: const Icon(Icons.note_outlined),
            label: const Text('修改备注'),
          ),
        ],
      ),
    );
  }
}

class HomeStartupSkeleton extends StatelessWidget {
  const HomeStartupSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget block({required double height, double radius = 12}) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            SizedBox(width: 110, child: block(height: 40, radius: 20)),
            const SizedBox(width: 12),
            Expanded(child: block(height: 44, radius: 22)),
          ],
        ),
        const SizedBox(height: 12),
        block(height: 56),
        const SizedBox(height: 10),
        block(height: 42, radius: 20),
        const SizedBox(height: 16),
        ...List.generate(7, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == 6 ? 0 : 12),
            child: block(height: 64),
          );
        }),
      ],
    );
  }
}

/// 筛选芯片
class FinanceFilterChip extends StatelessWidget {
  const FinanceFilterChip({
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
        : (groupColor?.withValues(alpha: 0.2) ??
            theme.colorScheme.surfaceContainerHighest);

    final Color borderColor = selected
        ? (groupColor ?? theme.colorScheme.primary)
        : (groupColor?.withValues(alpha: 0.5) ??
            theme.colorScheme.outline.withValues(alpha: 0.5));

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
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
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
