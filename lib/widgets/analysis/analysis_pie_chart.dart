import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/analysis_helpers.dart';
import 'analysis_common.dart';

class AnalysisPieChart extends StatefulWidget {
  final List<CategoryTotal> categoryTotals;
  final int totalAmount;
  final bool isExpense;

  const AnalysisPieChart({
    super.key,
    required this.categoryTotals,
    required this.totalAmount,
    required this.isExpense,
  });

  @override
  State<AnalysisPieChart> createState() => _AnalysisPieChartState();
}

class _AnalysisPieChartState extends State<AnalysisPieChart> {
  int? _touchedPieIndex;

  @override
  Widget build(BuildContext context) {
    // 复位选中状态当数据变化时?
    // 不，保持状态可能更好，或者在 didUpdateWidget 中重置?
    // 暂时简单处理

    if (widget.categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    // 只取前5名，其余合并为"其他"
    const maxDisplayCount = 5;
    List<CategoryTotal> displayCategories;
    if (widget.categoryTotals.length > maxDisplayCount) {
      displayCategories = widget.categoryTotals.take(maxDisplayCount).toList();
      // 计算"其他"的总金额和笔数
      int otherAmount = 0;
      int otherCount = 0;
      for (var i = maxDisplayCount; i < widget.categoryTotals.length; i++) {
        otherAmount += widget.categoryTotals[i].amount;
        otherCount += widget.categoryTotals[i].count;
      }
      if (otherAmount > 0) {
        displayCategories.add(CategoryTotal(
          category: '其他(总和)',
          amount: otherAmount,
          count: otherCount,
        ));
      }
    } else {
      displayCategories = widget.categoryTotals;
    }

    // 确定当前选中的分类索引（默认第一个即最大占比）
    final selectedIndex = (_touchedPieIndex != null &&
            _touchedPieIndex! >= 0 &&
            _touchedPieIndex! < displayCategories.length)
        ? _touchedPieIndex!
        : 0;

    final selectedCategory = displayCategories[selectedIndex];
    final displayPercentage = widget.totalAmount > 0
        ? (selectedCategory.amount / widget.totalAmount * 100)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isExpense ? '支出分类' : '收入分类',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event.isInterestedForInteractions &&
                          response?.touchedSection != null) {
                        final index =
                            response!.touchedSection!.touchedSectionIndex;
                        if (index >= 0 && index < displayCategories.length) {
                          setState(() {
                            _touchedPieIndex = index;
                          });
                        }
                      }
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: displayCategories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    final isSelected = index == selectedIndex;
                    final percentage = widget.totalAmount > 0
                        ? (data.amount / widget.totalAmount * 100)
                        : 0.0;
                    final color =
                        kCategoryColors[index % kCategoryColors.length];

                    // 是否有用户主动选中（非默认状态）
                    final hasUserSelection = _touchedPieIndex != null;

                    // 标签显示逻辑：
                    // - 有选中时：只显示选中的那个标签
                    // - 无选中时（默认）：显示占比 >= 5% 的标签
                    final shouldShowBadge =
                        hasUserSelection ? isSelected : percentage >= 5;

                    return PieChartSectionData(
                      color: color,
                      value: data.amount.toDouble(),
                      title: '',
                      radius: isSelected ? 40 : 32,
                      // 外部标签：带颜色边框的方框
                      badgeWidget: shouldShowBadge
                          ? _buildCategoryBadge(
                              theme: theme,
                              category: data.category,
                              percentage: percentage,
                              color: color,
                              isSelected: isSelected,
                            )
                          : null,
                      badgePositionPercentageOffset: 1.15,
                    );
                  }).toList(),
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              // 中间显示选中分类信息
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  key: ValueKey(
                      '${selectedCategory.category}-${selectedCategory.amount}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedCategory.category,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${displayPercentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      formatAmount(selectedCategory.amount),
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
        // 图例
        const SizedBox(height: 12),
        _buildPieLegend(
            theme, displayCategories, widget.totalAmount, selectedIndex),
      ],
    );
  }

  /// 构建分类标签（带颜色边框的方框）
  Widget _buildCategoryBadge({
    required ThemeData theme,
    required String category,
    required double percentage,
    required Color color,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        '$category ${percentage.toStringAsFixed(0)}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 10,
        ),
      ),
    );
  }

  /// 构建饼图图例
  Widget _buildPieLegend(
    ThemeData theme,
    List<CategoryTotal> categories,
    int totalAmount,
    int selectedIndex,
  ) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        final color = kCategoryColors[index % kCategoryColors.length];
        final percentage =
            totalAmount > 0 ? (data.amount / totalAmount * 100) : 0.0;
        final isSelected = index == selectedIndex;

        return GestureDetector(
          onTap: () {
            setState(() {
              _touchedPieIndex = index;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${data.category} ${percentage.toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
