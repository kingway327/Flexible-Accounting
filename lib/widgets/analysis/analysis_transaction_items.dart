import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../pages/transaction_detail_page.dart';

class AnalysisTransactionItem extends StatelessWidget {
  const AnalysisTransactionItem({
    super.key,
    required this.theme,
    required this.record,
    required this.timeStr,
    required this.modalContext,
    required this.onRefresh,
  });

  final ThemeData theme;
  final TransactionRecord record;
  final String timeStr;
  final BuildContext modalContext;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final amountStr = '-${(record.amount / 100).toStringAsFixed(2)}';
    final category = record.category ?? '其他';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          modalContext,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(record: record),
          ),
        ).then((_) => onRefresh());
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                record.source == 'Alipay' ? '支' : '微',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.counterparty.isNotEmpty
                      ? record.counterparty
                      : record.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amountStr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
    );
  }
}

class AnalysisCategoryTransactionItem extends StatelessWidget {
  const AnalysisCategoryTransactionItem({
    super.key,
    required this.theme,
    required this.record,
    required this.timeStr,
    required this.modalContext,
    required this.isExpense,
    required this.onRefresh,
  });

  final ThemeData theme;
  final TransactionRecord record;
  final String timeStr;
  final BuildContext modalContext;
  final bool isExpense;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final amountStr = isExpense
        ? '-${(record.amount / 100).toStringAsFixed(2)}'
        : '+${(record.amount / 100).toStringAsFixed(2)}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          modalContext,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(record: record),
          ),
        ).then((_) => onRefresh());
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: record.source == 'Alipay'
                  ? Colors.blue.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                record.source == 'Alipay' ? '支' : '微',
                style: TextStyle(
                  color: record.source == 'Alipay'
                      ? Colors.blue.shade700
                      : Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.counterparty.isNotEmpty
                      ? record.counterparty
                      : record.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amountStr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isExpense ? null : Colors.green.shade700,
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
    );
  }
}
