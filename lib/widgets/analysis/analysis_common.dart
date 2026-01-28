import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat kCurrencyFormatter = NumberFormat.currency(locale: 'zh_CN', symbol: '¥');

/// 分类对应的颜色（柔和色系，参考支付宝风格）
const List<Color> kCategoryColors = [
  Color(0xFF5B8FF9), // 蓝色
  Color(0xFF5AD8A6), // 绿色
  Color(0xFFF6BD16), // 黄色
  Color(0xFFE8684A), // 红色
  Color(0xFF6DC8EC), // 浅蓝
  Color(0xFF9270CA), // 紫色
  Color(0xFFFF9D4D), // 橙色
  Color(0xFFFF99C3), // 粉色
  Color(0xFF269A99), // 青色
  Color(0xFFBDD2FD), // 淡蓝
];

String formatAmount(int amount) {
  return kCurrencyFormatter.format(amount / 100);
}

/// 构建单个分类项（支付宝风格：序号.名称 百分比 | 金额(笔数)）
class CategoryItem extends StatelessWidget {
  final int rank;
  final String category;
  final double percentage;
  final int amount;
  final int count;
  final VoidCallback onTap;
  final bool isExpense;

  const CategoryItem({
    super.key,
    required this.rank,
    required this.category,
    required this.percentage,
    required this.amount,
    required this.count,
    required this.onTap,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            // 左侧：序号 + 名称 + 百分比
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$rank.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: ' $category ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: '${percentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 右侧：金额 + 笔数
            Text(
              '${formatAmount(amount)}($count笔)',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
