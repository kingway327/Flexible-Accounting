import 'package:flutter/material.dart';

/// 自定义滚轮选择器
class WheelPicker extends StatelessWidget {
  final int itemCount;
  final int initialItem;
  final ValueChanged<int> onSelectedItemChanged;
  final Widget Function(int index) itemBuilder;

  const WheelPicker({
    super.key,
    required this.itemCount,
    required this.initialItem,
    required this.onSelectedItemChanged,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final controller = FixedExtentScrollController(initialItem: initialItem);

    return Stack(
      children: [
        // 选中指示器背景
        Positioned.fill(
          child: Center(
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        // 滚轮选择器
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 44,
          physics: const FixedExtentScrollPhysics(),
          perspective: 0.005,
          diameterRatio: 1.5,
          onSelectedItemChanged: onSelectedItemChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: itemCount,
            builder: (context, index) {
              return Center(child: itemBuilder(index));
            },
          ),
        ),
      ],
    );
  }
}

/// 构建选择器文字项（有数据黑色，无数据灰色）
Widget buildPickerItem({
  required String text,
  required bool hasData,
}) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 16,
      fontWeight: hasData ? FontWeight.w500 : FontWeight.normal,
      color: hasData ? Colors.black : Colors.grey.shade400,
    ),
  );
}

/// 显示月份年份选择器弹窗
/// 
/// [initialYear] 初始年份
/// [initialMonth] 初始月份
/// [onConfirm] 确认回调，返回选中的年份和月份
/// [hasDataForYearMonth] 可选，判断某年某月是否有数据的函数，用于高亮显示
/// [noDataWarning] 可选，选中无数据月份时显示的警告文字
void showMonthYearPicker(
  BuildContext context, {
  required int initialYear,
  required int initialMonth,
  required void Function(int year, int month) onConfirm,
  bool Function(int year, int month)? hasDataForYearMonth,
  String? noDataWarning,
}) {
  int selectedYear = initialYear;
  int selectedMonth = initialMonth;
  const int startYear = 2000;
  const int endYear = 2030;

  // 预计算每年有数据的月份数
  Map<int, int> yearDataMonthCount = {};
  if (hasDataForYearMonth != null) {
    for (int year = startYear; year <= endYear; year++) {
      int count = 0;
      for (int month = 1; month <= 12; month++) {
        if (hasDataForYearMonth(year, month)) {
          count++;
        }
      }
      yearDataMonthCount[year] = count;
    }
  }

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          // 检查当前选中的月份是否有数据
          final hasDataForSelected = hasDataForYearMonth == null ||
              hasDataForYearMonth(selectedYear, selectedMonth);

          return SizedBox(
            height: 380,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Spacer(),
                      const Text(
                        '月份选择',
                        style: TextStyle(
                          fontSize: 16,
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
                  child: Row(
                    children: [
                      // 年份选择器
                      Expanded(
                        child: WheelPicker(
                          itemCount: endYear - startYear + 1,
                          initialItem: selectedYear - startYear,
                          onSelectedItemChanged: (index) {
                            setState(() {
                              selectedYear = startYear + index;
                            });
                          },
                          itemBuilder: (index) {
                            final year = startYear + index;
                            final hasData = hasDataForYearMonth == null ||
                                (yearDataMonthCount[year] ?? 0) > 0;
                            return buildPickerItem(
                              text: '$year年',
                              hasData: hasData,
                            );
                          },
                        ),
                      ),
                      // 月份选择器
                      Expanded(
                        child: WheelPicker(
                          itemCount: 12,
                          initialItem: selectedMonth - 1,
                          onSelectedItemChanged: (index) {
                            setState(() {
                              selectedMonth = index + 1;
                            });
                          },
                          itemBuilder: (index) {
                            final month = index + 1;
                            final hasData = hasDataForYearMonth == null ||
                                hasDataForYearMonth(selectedYear, month);
                            return buildPickerItem(
                              text: '$month月',
                              hasData: hasData,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // 数据提示
                if (!hasDataForSelected && noDataWarning != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      noDataWarning,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm(selectedYear, selectedMonth);
                      },
                      child: const Text('确定'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
