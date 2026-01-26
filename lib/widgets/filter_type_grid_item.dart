import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/category_icons.dart';

/// 筛选类型网格项
class FilterTypeGridItem extends StatelessWidget {
  const FilterTypeGridItem({
    super.key,
    required this.filterType,
    required this.groupName,
    required this.groupColor,
    required this.onTap,
  });

  final FilterType filterType;
  final String groupName;
  final int groupColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = getCategoryIcon(filterType.name);
    final hasGroup = groupColor != 0xFF9E9E9E;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 移除固定宽度，让 GridView 控制
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: hasGroup
                ? Color(groupColor).withOpacity(0.4)
                : theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: hasGroup
                  ? Color(groupColor)
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              filterType.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              groupName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: hasGroup
                    ? Color(groupColor).withOpacity(0.8)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
