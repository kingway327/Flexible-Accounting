import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/analysis_helpers.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../widgets/analysis/analysis_common.dart';
import '../widgets/analysis/weekly_report_view.dart';
import '../widgets/analysis/monthly_report_view.dart';
import '../widgets/analysis/yearly_report_view.dart';
import '../widgets/month_picker.dart';
import 'transaction_detail_page.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

// 颜色常量
const Color kLightBlue = Color(0xFF90CAF9);
const Color kDarkBlue = Color(0xFF1976D2);
const Color kTodayBg = Color(0xFFE3F2FD);

class _AnalysisPageState extends State<AnalysisPage> with TickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  final _currencyFormatter = NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  List<TransactionRecord> _allRecords = [];
  bool _loading = true;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _isExpense = true; // true=支出, false=收入

  
  // Tab 控制
  late TabController _tabController;
  
  // 周度状态
  int _weekOffset = 0; // 0=本周, -1=上周, 1=下周
  
  // 年度状态
  int? _selectedYearlyMonth; // 年度视图中选中的月份
  
  // 动画控制
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _allRecords = await _db.fetchTransactions();
    setState(() => _loading = false);
    _animationController.forward(from: 0.0);
  }

  /// 轻量级刷新数据，不重置UI状态和动画
  /// 用于从详情页返回时刷新数据
  Future<void> _refreshData() async {
    final newRecords = await _db.fetchTransactions();
    if (mounted) {
      setState(() {
        _allRecords = newRecords;
      });
    }
  }
  
  /// 切换月份时触发动画
  void _switchMonth(int year, int month) {
    if (year == _selectedYear && month == _selectedMonth) return;
    
    _animationController.reverse().then((_) {
      setState(() {
        _selectedYear = year;
        _selectedMonth = month;

      });
      _animationController.forward();
    });
  }
  
  /// 切换收支类型时触发动画
  void _switchExpenseType(bool isExpense) {
    if (isExpense == _isExpense) return;
    
    _animationController.reverse().then((_) {
      setState(() {
        _isExpense = isExpense;

      });
      _animationController.forward();
    });
  }

  /// 格式化金额为简洁形式（如 ¥1.8万）
  String _formatAmountShort(int cents) {
    final yuan = cents / 100;
    if (yuan >= 10000) {
      return '¥${(yuan / 10000).toStringAsFixed(1)}万';
    }
    return '¥${yuan.toStringAsFixed(2)}';
  }

  /// 获取指定日期的交易记录
  List<TransactionRecord> _getTransactionsForDay(int day) {
    final targetType = _isExpense ? TransactionType.expense : TransactionType.income;
    return _allRecords.where((record) {
      if (record.type != targetType) return false;
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      return date.year == _selectedYear &&
          date.month == _selectedMonth &&
          date.day == day;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // 按时间降序
  }

  /// 获取指定分类的交易记录
  List<TransactionRecord> _getTransactionsForCategory(String category) {
    final targetType = _isExpense ? TransactionType.expense : TransactionType.income;
    return _allRecords.where((record) {
      if (record.type != targetType) return false;
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      if (date.year != _selectedYear || date.month != _selectedMonth) return false;
      // 匹配分类（如果 category 为空则归入"其他"）
      final recordCategory = (record.category?.isNotEmpty == true) ? record.category! : '其他';
      return recordCategory == category;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // 按时间降序
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('收支分析'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: kDarkBlue,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: kDarkBlue,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: '周度'),
            Tab(text: '月度'),
            Tab(text: '年度'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyTab(theme),
                _buildMonthlyTab(theme),
                _buildYearlyTab(theme),
              ],
            ),
    );
  }

  /// 周度 Tab
  Widget _buildWeeklyTab(ThemeData theme) {
    final now = DateTime.now();
    final weeklyDailyTotals = getWeeklyDailyTotals(
      records: _allRecords,
      referenceDate: now,
      isExpense: _isExpense,
      weekOffset: _weekOffset,
    );
    final lastWeekDailyTotals = getWeeklyDailyTotals(
      records: _allRecords,
      referenceDate: now,
      isExpense: _isExpense,
      weekOffset: _weekOffset - 1,
    );
    final weeklyTotal = getWeeklyTotal(
      records: _allRecords,
      referenceDate: now,
      isExpense: _isExpense,
      weekOffset: _weekOffset,
    );
    final weeklyCategoryTotals = getWeeklyCategoryTotals(
      records: _allRecords,
      referenceDate: now,
      isExpense: _isExpense,
      weekOffset: _weekOffset,
    );
    final weekRangeStr = getWeekRangeString(now, weekOffset: _weekOffset);

    // FadeTransition is handled by TabBarView usually, but here it was explicit.
    // We can wrap the whole view in FadeTransition.
    return FadeTransition(
      opacity: _fadeAnimation,
      child: WeeklyReportView(
        isExpense: _isExpense,
        totalAmount: weeklyTotal,
        weekRangeStr: weekRangeStr,
        weeklyDailyTotals: weeklyDailyTotals,
        lastWeekDailyTotals: lastWeekDailyTotals,
        categoryTotals: weeklyCategoryTotals,
        onWeekPickerTap: () => _showWeekPicker(context),
        onTypeChanged: (isExpense) => _switchExpenseType(isExpense),
        onDayTap: (day) => _showWeekDayTransactionsModal(context, day),
        onCategoryTap: (category, amount, count) => _showWeeklyCategoryTransactionsModal(
          context,
          category,
          amount,
          count,
        ),
        currencyFormatter: _currencyFormatter,
      ),
    );
  }

  /// 月度 Tab（原有内容）
  Widget _buildMonthlyTab(ThemeData theme) {
    final dailyTotals = getDailyTotals(
      records: _allRecords,
      year: _selectedYear,
      month: _selectedMonth,
      isExpense: _isExpense,
    );
    final categoryTotals = getCategoryTotals(
      records: _allRecords,
      year: _selectedYear,
      month: _selectedMonth,
      isExpense: _isExpense,
    );
    final totalAmount = getMonthlyTotal(
      records: _allRecords,
      year: _selectedYear,
      month: _selectedMonth,
      isExpense: _isExpense,
    );
    final monthlyTotals = getRecentMonthlyTotals(
      records: _allRecords,
      year: _selectedYear,
      month: _selectedMonth,
      isExpense: _isExpense,
      monthCount: 5,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: MonthlyReportView(
        selectedYear: _selectedYear,
        selectedMonth: _selectedMonth,
        isExpense: _isExpense,
        totalAmount: totalAmount,
        dailyTotals: dailyTotals,
        categoryTotals: categoryTotals,
        monthlyTotals: monthlyTotals,
        onMonthPickerTap: () => _showMonthYearPicker(context),
        onTypeChanged: (isExpense) => _switchExpenseType(isExpense),
        onMonthSwitched: (year, month) => _switchMonth(year, month),
        onDayTap: (day, amount) => _showDayTransactionsModal(context, day, amount),
        onCategoryTap: (category, amount, count) => _showCategoryTransactionsModal(
          context,
          category,
          amount,
          count,
        ),
        currencyFormatter: _currencyFormatter,
        hasDataForMonth: (year, month) => hasDataForMonth(
          records: _allRecords,
          year: year,
          month: month,
          isExpense: _isExpense,
        ),
      ),
    );
  }

  /// 年度 Tab
  Widget _buildYearlyTab(ThemeData theme) {
    final yearlyMonthlyTotals = getYearlyMonthlyTotals(
      records: _allRecords,
      year: _selectedYear,
      isExpense: _isExpense,
      currentMonth: _selectedYearlyMonth,
    );
    final yearlyTotal = getYearlyTotal(
      records: _allRecords,
      year: _selectedYear,
      isExpense: _isExpense,
    );
    final yearlyAverage = getYearlyMonthlyAverage(
      records: _allRecords,
      year: _selectedYear,
      isExpense: _isExpense,
    );
    final yearlyCategoryTotals = getYearlyCategoryTotals(
      records: _allRecords,
      year: _selectedYear,
      isExpense: _isExpense,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: YearlyReportView(
        selectedYear: _selectedYear,
        isExpense: _isExpense,
        totalAmount: yearlyTotal,
        selectedYearlyMonth: _selectedYearlyMonth ?? DateTime.now().month,
        averageAmount: yearlyAverage,
        yearlyMonthlyTotals: yearlyMonthlyTotals,
        categoryTotals: yearlyCategoryTotals,
        onYearPickerTap: () => _showYearPicker(context),
        onTypeChanged: (isExpense) => _switchExpenseType(isExpense),
        onMonthChanged: (month) {
          setState(() {
            _selectedYearlyMonth = month;
            // No need to reset _touchedPieIndex (handled in widget state)
          });
        },
        onMonthTap: (month, amount) => _showYearlyMonthTransactionsModal(context, month, amount),
        onCategoryTap: (category, amount, count) => _showYearlyCategoryTransactionsModal(
          context,
          category,
          amount,
          count,
        ),
        currencyFormatter: _currencyFormatter,
      ),
    );
  }


  /// 周选择器弹窗
  void _showWeekPicker(BuildContext context) {
    final theme = Theme.of(context);
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
                  '选择周',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('本周'),
                trailing: _weekOffset == 0 ? const Icon(Icons.check, color: kDarkBlue) : null,
                onTap: () {
                  Navigator.pop(context);
                  _switchWeek(0);
                },
              ),
              ListTile(
                title: const Text('上周'),
                trailing: _weekOffset == -1 ? const Icon(Icons.check, color: kDarkBlue) : null,
                onTap: () {
                  Navigator.pop(context);
                  _switchWeek(-1);
                },
              ),
              ListTile(
                title: const Text('上上周'),
                trailing: _weekOffset == -2 ? const Icon(Icons.check, color: kDarkBlue) : null,
                onTap: () {
                  Navigator.pop(context);
                  _switchWeek(-2);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// 年份选择器弹窗
  void _showYearPicker(BuildContext context) {
    final theme = Theme.of(context);
    // 年份范围：2000-2030，降序排列
    final years = List.generate(31, (i) => 2030 - i);
    // 找到当前选中年份的索引，用于初始滚动位置
    final initialIndex = years.indexOf(_selectedYear);
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
                    final hasData = hasDataForYear(
                      records: _allRecords,
                      year: year,
                      isExpense: _isExpense,
                    );
                    return ListTile(
                      title: Text(
                        '$year年',
                        style: TextStyle(
                          // 使用与月份选择器相同的黑/灰色对比
                          color: hasData ? Colors.black : Colors.grey.shade400,
                          fontWeight: hasData ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                      trailing: _selectedYear == year ? const Icon(Icons.check, color: kDarkBlue) : null,
                      onTap: () {
                        Navigator.pop(context);
                        _switchYear(year);
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

  void _switchWeek(int offset) {
    if (offset == _weekOffset) return;
    _animationController.reverse().then((_) {
      setState(() {
        _weekOffset = offset;

      });
      _animationController.forward();
    });
  }

  void _switchYear(int year) {
    if (year == _selectedYear) return;
    _animationController.reverse().then((_) {
      setState(() {
        _selectedYear = year;
        _selectedYearlyMonth = null;

      });
      _animationController.forward();
    });
  }

  /// 显示周日交易详情弹窗
  void _showWeekDayTransactionsModal(BuildContext context, WeeklyDailyTotal day) {
    final targetType = _isExpense ? TransactionType.expense : TransactionType.income;
    final transactions = _allRecords.where((record) {
      if (record.type != targetType) return false;
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
                              '${_isExpense ? "支出" : "收入"}金额：${(day.amount / 100).toStringAsFixed(2)} 元',
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
                            final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
                            final timeStr = dateFormatter.format(time);
                            return _buildTransactionItem(
                              theme: theme,
                              record: record,
                              timeStr: timeStr,
                              modalContext: context,
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

  /// 显示周度分类交易详情弹窗
  void _showWeeklyCategoryTransactionsModal(
    BuildContext context,
    String category,
    int totalAmount,
    int count,
  ) {
    final now = DateTime.now();
    final daysSinceMonday = (now.weekday - 1);
    final monday = DateTime(now.year, now.month, now.day - daysSinceMonday);
    final targetMonday = monday.add(Duration(days: _weekOffset * 7));
    final targetSunday = targetMonday.add(const Duration(days: 6));

    final targetType = _isExpense ? TransactionType.expense : TransactionType.income;
    final transactions = _allRecords.where((record) {
      if (record.type != targetType) return false;
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      final dateOnly = DateTime(date.year, date.month, date.day);
      if (dateOnly.isBefore(targetMonday) || dateOnly.isAfter(targetSunday)) return false;
      final recordCategory = (record.category?.isNotEmpty == true) ? record.category! : '其他';
      return recordCategory == category;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    _showCategoryTransactionsModalCommon(context, category, totalAmount, count, transactions);
  }

  /// 显示年度分类交易详情弹窗
  void _showYearlyCategoryTransactionsModal(
    BuildContext context,
    String category,
    int totalAmount,
    int count,
  ) {
    final targetType = _isExpense ? TransactionType.expense : TransactionType.income;
    final transactions = _allRecords.where((record) {
      if (record.type != targetType) return false;
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      if (date.year != _selectedYear) return false;
      final recordCategory = (record.category?.isNotEmpty == true) ? record.category! : '其他';
      return recordCategory == category;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    _showCategoryTransactionsModalCommon(context, category, totalAmount, count, transactions);
  }

  /// 显示年度板块某月的交易详情弹窗
  void _showYearlyMonthTransactionsModal(
    BuildContext context,
    int month,
    int totalAmount,
  ) {
    final targetType = _isExpense ? TransactionType.expense : TransactionType.income;
    final transactions = _allRecords.where((record) {
      if (record.type != targetType) return false;
      final date = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
      return date.year == _selectedYear && date.month == month;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
                              '$_selectedYear年$month月',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '共 ${transactions.length} 笔，${_isExpense ? "支出" : "收入"} ${_currencyFormatter.format(totalAmount / 100)}',
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
                            final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
                            final timeStr = dateFormatter.format(time);
                            return _buildCategoryTransactionItem(
                              theme: theme,
                              record: record,
                              timeStr: timeStr,
                              modalContext: context,
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

  /// 通用分类交易详情弹窗
  void _showCategoryTransactionsModalCommon(
    BuildContext context,
    String category,
    int totalAmount,
    int count,
    List<TransactionRecord> transactions,
  ) {
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
                              '共 $count 笔，${_isExpense ? "支出" : "收入"} ${_currencyFormatter.format(totalAmount / 100)}',
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
                            final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
                            final timeStr = dateFormatter.format(time);
                            return _buildCategoryTransactionItem(
                              theme: theme,
                              record: record,
                              timeStr: timeStr,
                              modalContext: context,
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

  /// Header Section: 日期选择、收支切换、总金额

  /// 显示当日交易详情弹窗
  void _showDayTransactionsModal(BuildContext context, int day, int totalAmount) {
    final transactions = _getTransactionsForDay(day);
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('HH:mm');

    // 判断是否是今天
    final today = DateTime.now();
    final isToday = today.year == _selectedYear &&
        today.month == _selectedMonth &&
        today.day == day;

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
                // 标题栏
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_selectedMonth.toString().padLeft(2, '0')}月${day.toString().padLeft(2, '0')}日 共 ${transactions.length}笔',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '今日${_isExpense ? "支出" : "收入"}金额：${(totalAmount / 100).toStringAsFixed(2)} 元',
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
                // 交易列表
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
                          itemCount: transactions.length + 1, // +1 for footer
                          separatorBuilder: (_, __) => const Divider(height: 24),
                          itemBuilder: (context, index) {
                            if (index == transactions.length) {
                              // 底部提示
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
                            final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
                            final timeStr = isToday
                                ? '今天 ${dateFormatter.format(time)}'
                                : dateFormatter.format(time);
                            return _buildTransactionItem(
                              theme: theme,
                              record: record,
                              timeStr: timeStr,
                              modalContext: context,
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

  /// 构建单个交易项（可点击跳转详情）
  Widget _buildTransactionItem({
    required ThemeData theme,
    required TransactionRecord record,
    required String timeStr,
    required BuildContext modalContext,
  }) {
    final amountStr = '-${(record.amount / 100).toStringAsFixed(2)}';
    final category = record.category ?? '其他';

    return GestureDetector(
      onTap: () {
        // 不关闭弹窗，直接跳转到详情页，返回时回到弹窗
        Navigator.push(
          modalContext,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(record: record),
          ),
        ).then((_) => _refreshData()); // 返回时静默刷新数据
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标
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
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.counterparty.isNotEmpty ? record.counterparty : record.description,
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
          // 金额
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

  /// 支出分类：饼图（甜甜圈样式，外部标签）

  /// 显示分类交易详情弹窗
  void _showCategoryTransactionsModal(
    BuildContext context,
    String category,
    int totalAmount,
    int count,
  ) {
    final transactions = _getTransactionsForCategory(category);
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
                // 标题栏
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
                              '共 $count 笔，${_isExpense ? "支出" : "收入"} ${_currencyFormatter.format(totalAmount / 100)}',
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
                // 交易列表
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
                          itemCount: transactions.length + 1, // +1 for footer
                          separatorBuilder: (_, __) => const Divider(height: 24),
                          itemBuilder: (context, index) {
                            if (index == transactions.length) {
                              // 底部提示
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
                            final time = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
                            final timeStr = dateFormatter.format(time);
                            return _buildCategoryTransactionItem(
                              theme: theme,
                              record: record,
                              timeStr: timeStr,
                              modalContext: context,
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

  /// 构建分类交易列表项（可点击跳转详情）
  Widget _buildCategoryTransactionItem({
    required ThemeData theme,
    required TransactionRecord record,
    required String timeStr,
    required BuildContext modalContext,
  }) {
    final amountStr = _isExpense
        ? '-${(record.amount / 100).toStringAsFixed(2)}'
        : '+${(record.amount / 100).toStringAsFixed(2)}';

    return GestureDetector(
      onTap: () {
        // 不关闭弹窗，直接跳转到详情页，返回时回到弹窗
        Navigator.push(
          modalContext,
          MaterialPageRoute(
            builder: (_) => TransactionDetailPage(record: record),
          ),
        ).then((_) => _refreshData()); // 返回时静默刷新数据
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标
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
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.counterparty.isNotEmpty ? record.counterparty : record.description,
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
          // 金额
          Text(
            amountStr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: _isExpense ? null : Colors.green.shade700,
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

  /// 年月选择器弹窗
  void _showMonthYearPicker(BuildContext context) {
    showMonthYearPicker(
      context,
      initialYear: _selectedYear,
      initialMonth: _selectedMonth,
      onConfirm: (year, month) => _switchMonth(year, month),
      hasDataForYearMonth: (year, month) => hasDataForMonth(
        records: _allRecords,
        year: year,
        month: month,
        isExpense: _isExpense,
      ),
      noDataWarning: '该月份暂无数据',
    );
  }
}
