import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/analysis_helpers.dart';
import '../../models/models.dart';
import 'analysis_transaction_items.dart';

void showAnalysisWeekDayTransactionsModal({
  required BuildContext context,
  required WeeklyDailyTotal day,
  required List<TransactionRecord> allRecords,
  required bool isExpense,
  required VoidCallback onRefresh,
}) {
  final targetType =
      isExpense ? TransactionType.expense : TransactionType.income;
  final transactions = allRecords.where((record) {
    if (record.type != targetType) {
      return false;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    return date.year == day.date.year &&
        date.month == day.date.month &&
        date.day == day.date.day;
  }).toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  final theme = Theme.of(context);
  final dateFormatter = DateFormat('HH:mm');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${day.date.month}月${day.date.day}日 ${day.dayLabel} 共 ${transactions.length}笔',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${isExpense ? "支出" : "收入"}金额：${(day.amount / 100).toStringAsFixed(2)} 元',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: transactions.isEmpty
                    ? Center(
                        child: Text(
                          '暂无记录',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (context, index) {
                          final record = transactions[index];
                          final time = DateTime.fromMillisecondsSinceEpoch(
                            record.timestamp,
                          );
                          final timeStr = dateFormatter.format(time);
                          return AnalysisTransactionItem(
                            theme: theme,
                            record: record,
                            timeStr: timeStr,
                            modalContext: context,
                            onRefresh: onRefresh,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

void showAnalysisCategoryTransactionsModalCommon({
  required BuildContext context,
  required String category,
  required int totalAmount,
  required int count,
  required List<TransactionRecord> transactions,
  required bool isExpense,
  required NumberFormat currencyFormatter,
  required VoidCallback onRefresh,
}) {
  final theme = Theme.of(context);
  final dateFormatter = DateFormat('MM月dd日 HH:mm');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共 $count 笔，${isExpense ? "支出" : "收入"} ${currencyFormatter.format(totalAmount / 100)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: transactions.isEmpty
                    ? Center(
                        child: Text(
                          '暂无记录',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: transactions.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (context, index) {
                          if (index == transactions.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  '列表到底了',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }
                          final record = transactions[index];
                          final time = DateTime.fromMillisecondsSinceEpoch(
                            record.timestamp,
                          );
                          final timeStr = dateFormatter.format(time);
                          return AnalysisCategoryTransactionItem(
                            theme: theme,
                            record: record,
                            timeStr: timeStr,
                            modalContext: context,
                            isExpense: isExpense,
                            onRefresh: onRefresh,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

void showAnalysisDayTransactionsModal({
  required BuildContext context,
  required int selectedMonth,
  required int day,
  required int totalAmount,
  required bool isExpense,
  required bool isToday,
  required List<TransactionRecord> transactions,
  required VoidCallback onRefresh,
}) {
  final theme = Theme.of(context);
  final dateFormatter = DateFormat('HH:mm');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${selectedMonth.toString().padLeft(2, '0')}月${day.toString().padLeft(2, '0')}日 共 ${transactions.length}笔',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '今日${isExpense ? "支出" : "收入"}金额：${(totalAmount / 100).toStringAsFixed(2)} 元',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: transactions.isEmpty
                    ? Center(
                        child: Text(
                          '暂无记录',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: transactions.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (context, index) {
                          if (index == transactions.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  '列表到底了',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }
                          final record = transactions[index];
                          final time = DateTime.fromMillisecondsSinceEpoch(
                            record.timestamp,
                          );
                          final timeStr = isToday
                              ? '今天 ${dateFormatter.format(time)}'
                              : dateFormatter.format(time);
                          return AnalysisTransactionItem(
                            theme: theme,
                            record: record,
                            timeStr: timeStr,
                            modalContext: context,
                            onRefresh: onRefresh,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

void showAnalysisYearlyMonthTransactionsModal({
  required BuildContext context,
  required int selectedYear,
  required int month,
  required int totalAmount,
  required bool isExpense,
  required NumberFormat currencyFormatter,
  required List<TransactionRecord> transactions,
  required VoidCallback onRefresh,
}) {
  final theme = Theme.of(context);
  final dateFormatter = DateFormat('dd日 HH:mm');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$selectedYear年$month月',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '共 ${transactions.length} 笔，${isExpense ? "支出" : "收入"} ${currencyFormatter.format(totalAmount / 100)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: transactions.isEmpty
                    ? Center(
                        child: Text(
                          '暂无记录',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: transactions.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 24),
                        itemBuilder: (context, index) {
                          if (index == transactions.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  '列表到底了',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }
                          final record = transactions[index];
                          final time = DateTime.fromMillisecondsSinceEpoch(
                            record.timestamp,
                          );
                          final timeStr = dateFormatter.format(time);
                          return AnalysisCategoryTransactionItem(
                            theme: theme,
                            record: record,
                            timeStr: timeStr,
                            modalContext: context,
                            isExpense: isExpense,
                            onRefresh: onRefresh,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}
