import 'package:flutter/material.dart';

import '../utils/category_icons.dart';

/// 分类网格项（带图标）
///
/// 可配置项：
/// - [category]: 分类名称
/// - [onTap]: 点击回调
/// - [isSelected]: 是否选中状态
/// - [color]: 自定义颜色（如不提供则使用主题的 primary 颜色）
/// - [showIcon]: 是否显示图标（默认 true）
class CategoryGridItem extends StatelessWidget {
  const CategoryGridItem({
    super.key,
    required this.category,
    required this.onTap,
    this.isSelected = false,
    this.color,
    this.showIcon = true,
  });

  final String category;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? color;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = getCategoryIcon(category);
    final displayColor = color ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80, // 固定宽度，形成网格
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? displayColor.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color:
                isSelected ? displayColor : displayColor.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                icon,
                size: 24,
                color: (isSelected || color != null)
                    ? displayColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
            ],
            Text(
              category,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: (isSelected || color != null)
                    ? displayColor
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分类网格容器（自动换行）
///
/// 可配置项：
/// - [categories]: 分类列表
/// - [onCategoryTap]: 分类点击回调
/// - [selectedCategory]: 当前选中的分类
/// - [groupColorMap]: 分组颜色映射（分类名 -> 颜色），如微信/支付宝不同颜色
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onCategoryTap,
    this.selectedCategory,
    this.groupColorMap,
  });

  final List<String> categories;
  final ValueChanged<String> onCategoryTap;
  final String? selectedCategory;
  final Map<String, Color>? groupColorMap; // category -> color

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: categories.map((category) {
        return CategoryGridItem(
          category: category,
          isSelected: category == selectedCategory,
          color: groupColorMap?[category],
          onTap: () => onCategoryTap(category),
        );
      }).toList(),
    );
  }
}
