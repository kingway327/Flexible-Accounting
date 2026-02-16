import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/analysis_helpers.dart';

final NumberFormat kCurrencyFormatter =
    NumberFormat.currency(locale: 'zh_CN', symbol: '¥');

const Color kLightBlue = Color(0xFF90CAF9);
const Color kDarkBlue = Color(0xFF1976D2);
const Color kTodayBg = Color(0xFFE3F2FD);

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

class AnalysisReportHeader extends StatelessWidget {
  const AnalysisReportHeader({
    super.key,
    required this.periodLabel,
    required this.onPeriodTap,
    required this.isExpense,
    required this.onTypeChanged,
    required this.totalAmount,
    required this.currencyFormatter,
  });

  final String periodLabel;
  final VoidCallback onPeriodTap;
  final bool isExpense;
  final ValueChanged<bool> onTypeChanged;
  final int totalAmount;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onPeriodTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    periodLabel,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 24,
                    color: theme.colorScheme.onSurface,
                  ),
                ],
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('支出')),
                ButtonSegment(value: false, label: Text('收入')),
              ],
              selected: {isExpense},
              onSelectionChanged: (value) {
                if (value.isNotEmpty) {
                  onTypeChanged(value.first);
                }
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: totalAmount / 100),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Text(
                currencyFormatter.format(value),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color:
                      isExpense ? Colors.red.shade700 : Colors.green.shade700,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CategoryRankingSection extends StatelessWidget {
  const CategoryRankingSection({
    super.key,
    required this.categoryTotals,
    required this.totalAmount,
    required this.isExpense,
    required this.onCategoryTap,
  });

  final List<CategoryTotal> categoryTotals;
  final int totalAmount;
  final bool isExpense;
  final Function(String category, int amount, int count) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (categoryTotals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            '暂无数据',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...categoryTotals.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final percentage =
              totalAmount > 0 ? (data.amount / totalAmount * 100) : 0.0;

          return CategoryItem(
            rank: index + 1,
            category: data.category,
            percentage: percentage,
            amount: data.amount,
            count: data.count,
            isExpense: isExpense,
            onTap: () => onCategoryTap(data.category, data.amount, data.count),
          );
        }),
      ],
    );
  }
}
