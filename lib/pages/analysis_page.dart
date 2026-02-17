import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/analysis_view_models.dart';
import '../data/app_settings_dao.dart';
import '../data/transaction_dao.dart';
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
  final _txDao = TransactionDao.instance;
  final _settingsDao = AppSettingsDao.instance;
  final _currencyFormatter =
      NumberFormat.currency(symbol: '¥', decimalDigits: 2);

  List<TransactionRecord> _allRecords = [];
  bool _loading = true;
  late int _selectedMonthlyYear;
  late int _selectedMonthlyMonth;
  late int _selectedYearlyYear;
  late int _selectedYearlyMonth;
  bool _isExpense = true; // true=支出, false=收入

  // Tab 控制
  late TabController _tabController;
  int _lastPersistedTabIndex = 1;

  // 周度状态
  int _weekOffset = 0; // 0=本周, -1=上周, 1=下周

  // 动画控制
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthlyYear = now.year;
    _selectedMonthlyMonth = now.month;
    _selectedYearlyYear = now.year;
    _selectedYearlyMonth = now.month;

    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(_onTabChanged);
    _lastPersistedTabIndex = _tabController.index;

    // 恢复持久化的分析页面状态
    _restoreAnalysisState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  Future<void> _restoreAnalysisState() async {
    final savedState = await _settingsDao.getAnalysisLastViewState();

    if (!mounted) {
      return;
    }

    var shouldRebuild = false;
    var shouldPersistDateDefaults = false;

    final savedSelectedMonthlyYear = savedState['selectedYear'];
    if (savedSelectedMonthlyYear is int && savedSelectedMonthlyYear > 0) {
      _selectedMonthlyYear = savedSelectedMonthlyYear;
      shouldRebuild = true;
    } else {
      shouldPersistDateDefaults = true;
    }

    final savedSelectedMonthlyMonth = savedState['selectedMonth'];
    if (savedSelectedMonthlyMonth is int &&
        savedSelectedMonthlyMonth >= 1 &&
        savedSelectedMonthlyMonth <= 12) {
      _selectedMonthlyMonth = savedSelectedMonthlyMonth;
      shouldRebuild = true;
    } else {
      shouldPersistDateDefaults = true;
    }

    final savedSelectedYearlyYear = savedState['selectedYearlyYear'];
    if (savedSelectedYearlyYear is int && savedSelectedYearlyYear > 0) {
      _selectedYearlyYear = savedSelectedYearlyYear;
      shouldRebuild = true;
    } else {
      _selectedYearlyYear = _selectedMonthlyYear;
      shouldPersistDateDefaults = true;
    }

    final savedTabIndex = savedState['tabIndex'];
    if (savedTabIndex is int && savedTabIndex >= 0 && savedTabIndex < 3) {
      if (savedTabIndex != _tabController.index) {
        _tabController.removeListener(_onTabChanged);
        _tabController.dispose();
        _tabController = TabController(
          length: 3,
          vsync: this,
          initialIndex: savedTabIndex,
        );
        _tabController.addListener(_onTabChanged);
        _lastPersistedTabIndex = savedTabIndex;
        shouldRebuild = true;
      }
    }

    if (savedState['weekOffset'] != null && savedState['weekOffset'] is int) {
      _weekOffset = savedState['weekOffset'] as int;
      shouldRebuild = true;
    }

    if (savedState['isExpense'] is bool) {
      _isExpense = savedState['isExpense'] as bool;
      shouldRebuild = true;
    }

    if (savedState['selectedYearlyMonth'] != null &&
        savedState['selectedYearlyMonth'] is int &&
        savedState['selectedYearlyMonth'] >= 1 &&
        savedState['selectedYearlyMonth'] <= 12) {
      _selectedYearlyMonth = savedState['selectedYearlyMonth'] as int;
      shouldRebuild = true;
    } else {
      _selectedYearlyMonth = _selectedMonthlyMonth;
      shouldPersistDateDefaults = true;
    }

    if (shouldPersistDateDefaults) {
      _settingsDao.setAnalysisLastViewState(
        selectedYear: _selectedMonthlyYear,
        selectedMonth: _selectedMonthlyMonth,
        selectedYearlyYear: _selectedYearlyYear,
        selectedYearlyMonth: _selectedYearlyMonth,
      );
    }

    if (shouldRebuild && mounted) {
      setState(() {});
    }
  }

  void _onTabChanged() {
    final tabIndex = _tabController.index;
    if (_lastPersistedTabIndex == tabIndex) {
      return;
    }
    _lastPersistedTabIndex = tabIndex;
    _settingsDao.setAnalysisLastViewState(tabIndex: tabIndex);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _allRecords = await _txDao.fetchTransactions();
    setState(() => _loading = false);
    _animationController.forward(from: 0.0);
  }

  /// 轻量级刷新数据，不重置UI状态和动画
  /// 用于从详情页返回时刷新数据
  Future<void> _refreshData() async {
    final newRecords = await _txDao.fetchTransactions();
    if (mounted) {
      setState(() {
        _allRecords = newRecords;
      });
    }
  }

  AnalysisModalInvoker get _weeklyModalInvoker => AnalysisModalInvoker(
        records: _allRecords,
        selectedYear: _selectedMonthlyYear,
        selectedMonth: _selectedMonthlyMonth,
        isExpense: _isExpense,
        weekOffset: _weekOffset,
        currencyFormatter: _currencyFormatter,
        onRefresh: _refreshData,
      );

  AnalysisPickerInvoker get _weeklyPickerInvoker => AnalysisPickerInvoker(
        allRecords: _allRecords,
        selectedYear: _selectedMonthlyYear,
        selectedMonth: _selectedMonthlyMonth,
        isExpense: _isExpense,
        weekOffset: _weekOffset,
        selectedColor: kDarkBlue,
      );

  AnalysisModalInvoker get _monthlyModalInvoker => AnalysisModalInvoker(
        records: _allRecords,
        selectedYear: _selectedMonthlyYear,
        selectedMonth: _selectedMonthlyMonth,
        isExpense: _isExpense,
        weekOffset: _weekOffset,
        currencyFormatter: _currencyFormatter,
        onRefresh: _refreshData,
      );

  AnalysisPickerInvoker get _monthlyPickerInvoker => AnalysisPickerInvoker(
        allRecords: _allRecords,
        selectedYear: _selectedMonthlyYear,
        selectedMonth: _selectedMonthlyMonth,
        isExpense: _isExpense,
        weekOffset: _weekOffset,
        selectedColor: kDarkBlue,
      );

  AnalysisModalInvoker get _yearlyModalInvoker => AnalysisModalInvoker(
        records: _allRecords,
        selectedYear: _selectedYearlyYear,
        selectedMonth: _selectedYearlyMonth,
        isExpense: _isExpense,
        weekOffset: _weekOffset,
        currencyFormatter: _currencyFormatter,
        onRefresh: _refreshData,
      );

  AnalysisPickerInvoker get _yearlyPickerInvoker => AnalysisPickerInvoker(
        allRecords: _allRecords,
        selectedYear: _selectedYearlyYear,
        selectedMonth: _selectedYearlyMonth,
        isExpense: _isExpense,
        weekOffset: _weekOffset,
        selectedColor: kDarkBlue,
      );

  /// 切换月份时触发动画
  void _switchMonth(int year, int month) {
    if (isSameMonthSelection(
      currentYear: _selectedMonthlyYear,
      currentMonth: _selectedMonthlyMonth,
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
        _selectedMonthlyYear = year;
        _selectedMonthlyMonth = month;
        _settingsDao.setAnalysisLastViewState(
          selectedYear: year,
          selectedMonth: month,
        );
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
        _settingsDao.setAnalysisLastViewState(isExpense: isExpense);
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
            _weeklyPickerInvoker.showWeekPicker(context, _switchWeek),
        onTypeChanged: (isExpense) => _switchExpenseType(isExpense),
        onDayTap: (day) =>
            _weeklyModalInvoker.showWeekDayTransactionsModal(context, day),
        onCategoryTap: (category, amount, count) =>
            _weeklyModalInvoker.showWeeklyCategoryTransactionsModal(
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
      selectedYear: _selectedMonthlyYear,
      selectedMonth: _selectedMonthlyMonth,
      isExpense: _isExpense,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: MonthlyReportView(
        selectedYear: _selectedMonthlyYear,
        selectedMonth: _selectedMonthlyMonth,
        isExpense: _isExpense,
        totalAmount: data.totalAmount,
        dailyTotals: data.dailyTotals,
        categoryTotals: data.categoryTotals,
        monthlyTotals: data.monthlyTotals,
        onMonthPickerTap: () =>
            _monthlyPickerInvoker.showMonthYearPicker(context, _switchMonth),
        onTypeChanged: (isExpense) => _switchExpenseType(isExpense),
        onMonthSwitched: (year, month) => _switchMonth(year, month),
        onDayTap: (day, amount) =>
            _monthlyModalInvoker.showDayTransactionsModal(
          context,
          day,
          amount,
        ),
        onCategoryTap: (category, amount, count) =>
            _monthlyModalInvoker.showCategoryTransactionsModal(
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
      selectedYear: _selectedYearlyYear,
      isExpense: _isExpense,
      selectedYearlyMonth: _selectedYearlyMonth,
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: YearlyReportView(
        selectedYear: _selectedYearlyYear,
        isExpense: _isExpense,
        totalAmount: data.yearlyTotal,
        selectedYearlyMonth: _selectedYearlyMonth,
        averageAmount: data.yearlyAverage,
        yearlyMonthlyTotals: data.yearlyMonthlyTotals,
        categoryTotals: data.yearlyCategoryTotals,
        onYearPickerTap: () =>
            _yearlyPickerInvoker.showYearPicker(context, _switchYear),
        onTypeChanged: (isExpense) => _switchExpenseType(isExpense),
        onMonthChanged: (month) {
          if (_selectedYearlyMonth == month) {
            return;
          }
          setState(() {
            _selectedYearlyMonth = month;
            _settingsDao.setAnalysisLastViewState(
              selectedYearlyMonth: month,
            );
            // No need to reset _touchedPieIndex (handled in widget state)
          });
        },
        onMonthTap: (month, amount) => _yearlyModalInvoker
            .showYearlyMonthTransactionsModal(context, month, amount),
        onCategoryTap: (category, amount, count) =>
            _yearlyModalInvoker.showYearlyCategoryTransactionsModal(
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
        _settingsDao.setAnalysisLastViewState(weekOffset: offset);
      },
    );
  }

  void _switchYear(int year) {
    if (isSameYearSelection(currentYear: _selectedYearlyYear, nextYear: year)) {
      return;
    }

    runAnalysisAnimatedTransition(
      controller: _animationController,
      setState: setState,
      canApply: () => mounted,
      applyState: () {
        _selectedYearlyYear = year;
        _settingsDao.setAnalysisLastViewState(
          selectedYearlyYear: year,
        );
      },
    );
  }
}
