import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/analysis_view_models.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../widgets/analysis/analysis_common.dart';
import '../widgets/analysis/analysis_modal_invoker.dart';
import '../widgets/analysis/analysis_picker_invoker.dart';
import '../widgets/analysis/analysis_state_transitions.dart';
import '../widgets/analysis/weekly_report_view.dart';
import '../widgets/analysis/monthly_report_view.dart';
import '../widgets/analysis/yearly_report_view.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage>
    with TickerProviderStateMixin {
  final _db = DatabaseHelper.instance;
  final _currencyFormatter =
      NumberFormat.currency(symbol: '¥', decimalDigits: 2);

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

  AnalysisModalInvoker get _modalInvoker => AnalysisModalInvoker(
        records: _allRecords,
        selectedYear: _selectedYear,
        selectedMonth: _selectedMonth,
        isExpense: _isExpense,
        weekOffset: _weekOffset,
        currencyFormatter: _currencyFormatter,
        onRefresh: _refreshData,
      );

  AnalysisPickerInvoker get _pickerInvoker => AnalysisPickerInvoker(
        allRecords: _allRecords,
        selectedYear: _selectedYear,
        selectedMonth: _selectedMonth,
        isExpense: _isExpense,
        weekOffset: _weekOffset,
        selectedColor: kDarkBlue,
      );

  /// 切换月份时触发动画
  void _switchMonth(int year, int month) {
    if (isSameMonthSelection(
      currentYear: _selectedYear,
      currentMonth: _selectedMonth,
      nextYear: year,
      nextMonth: month,
    )) {
      return;
    }

    runAnalysisAnimatedTransition(
      controller: _animationController,
      setState: setState,
      canApply: () => mounted,
      applyState: () {
        _selectedYear = year;
        _selectedMonth = month;
      },
    );
  }

  /// 切换收支类型时触发动画
  void _switchExpenseType(bool isExpense) {
    if (isSameExpenseType(
      currentIsExpense: _isExpense,
      nextIsExpense: isExpense,
    )) {
      return;
    }

    runAnalysisAnimatedTransition(
      controller: _animationController,
      setState: setState,
      canApply: () => mounted,
      applyState: () {
        _isExpense = isExpense;
      },
    );
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
    final data = buildWeeklyTabViewData(
      records: _allRecords,
      referenceDate: DateTime.now(),
      isExpense: _isExpense,
      weekOffset: _weekOffset,
    );

    // FadeTransition is handled by TabBarView usually, but here it was explicit.
    // We can wrap the whole view in FadeTransition.
    return FadeTransition(
      opacity: _fadeAnimation,
      child: WeeklyReportView(
        isExpense: _isExpense,
        totalAmount: data.weeklyTotal,
        weekRangeStr: data.weekRangeStr,
        weeklyDailyTotals: data.weeklyDailyTotals,
        lastWeekDailyTotals: data.lastWeekDailyTotals,
        categoryTotals: data.weeklyCategoryTotals,
        onWeekPickerTap: () =>
            _pickerInvoker.showWeekPicker(context, _switchWeek),
        onTypeChanged: (isExpense) => _switchExpenseType(isExpense),
        onDayTap: (day) =>
            _modalInvoker.showWeekDayTransactionsModal(context, day),
        onCategoryTap: (category, amount, count) =>
            _modalInvoker.showWeeklyCategoryTransactionsModal(
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
    final data = buildMonthlyTabViewData(
      records: _allRecords,
      selectedYear: _selectedYear,
      selectedMonth: _selectedMonth,
      isExpense: _isExpense,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: MonthlyReportView(
        selectedYear: _selectedYear,
        selectedMonth: _selectedMonth,
        isExpense: _isExpense,
        totalAmount: data.totalAmount,
        dailyTotals: data.dailyTotals,
        categoryTotals: data.categoryTotals,
        monthlyTotals: data.monthlyTotals,
        onMonthPickerTap: () =>
            _pickerInvoker.showMonthYearPicker(context, _switchMonth),
        onTypeChanged: (isExpense) => _switchExpenseType(isExpense),
        onMonthSwitched: (year, month) => _switchMonth(year, month),
        onDayTap: (day, amount) => _modalInvoker.showDayTransactionsModal(
          context,
          day,
          amount,
        ),
        onCategoryTap: (category, amount, count) =>
            _modalInvoker.showCategoryTransactionsModal(
          context,
          category,
          amount,
          count,
        ),
        currencyFormatter: _currencyFormatter,
      ),
    );
  }

  /// 年度 Tab
  Widget _buildYearlyTab(ThemeData theme) {
    final data = buildYearlyTabViewData(
      records: _allRecords,
      selectedYear: _selectedYear,
      isExpense: _isExpense,
      selectedYearlyMonth: _selectedYearlyMonth,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: YearlyReportView(
        selectedYear: _selectedYear,
        isExpense: _isExpense,
        totalAmount: data.yearlyTotal,
        selectedYearlyMonth: _selectedYearlyMonth ?? DateTime.now().month,
        averageAmount: data.yearlyAverage,
        yearlyMonthlyTotals: data.yearlyMonthlyTotals,
        categoryTotals: data.yearlyCategoryTotals,
        onYearPickerTap: () =>
            _pickerInvoker.showYearPicker(context, _switchYear),
        onTypeChanged: (isExpense) => _switchExpenseType(isExpense),
        onMonthChanged: (month) {
          setState(() {
            _selectedYearlyMonth = month;
            // No need to reset _touchedPieIndex (handled in widget state)
          });
        },
        onMonthTap: (month, amount) => _modalInvoker
            .showYearlyMonthTransactionsModal(context, month, amount),
        onCategoryTap: (category, amount, count) =>
            _modalInvoker.showYearlyCategoryTransactionsModal(
          context,
          category,
          amount,
          count,
        ),
        currencyFormatter: _currencyFormatter,
      ),
    );
  }

  void _switchWeek(int offset) {
    if (isSameWeekOffset(currentOffset: _weekOffset, nextOffset: offset)) {
      return;
    }

    runAnalysisAnimatedTransition(
      controller: _animationController,
      setState: setState,
      canApply: () => mounted,
      applyState: () {
        _weekOffset = offset;
      },
    );
  }

  void _switchYear(int year) {
    if (isSameYearSelection(currentYear: _selectedYear, nextYear: year)) {
      return;
    }

    runAnalysisAnimatedTransition(
      controller: _animationController,
      setState: setState,
      canApply: () => mounted,
      applyState: () {
        _selectedYear = year;
        _selectedYearlyMonth = null;
      },
    );
  }
}
