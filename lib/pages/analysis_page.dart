import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/analysis_helpers.dart';
import '../data/database_helper.dart';
import '../models/models.dart';
import '../widgets/month_picker.dart';
import 'transaction_detail_page.dart';

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

  int? _touchedPieIndex;
  
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
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _touchedPieIndex = null;
        });
      }
    });
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
        _touchedPieIndex = null;
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
        _touchedPieIndex = null;
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        _buildWeeklyHeaderSection(theme, weeklyTotal, weekRangeStr),
        const SizedBox(height: 24),
        // 一周小结（双柱对比图）
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildWeeklyBarChartSection(theme, weeklyDailyTotals, lastWeekDailyTotals),
        ),
        const SizedBox(height: 24),
        // 周日历（7天横向）
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildWeeklyCalendarSection(theme, weeklyDailyTotals),
        ),
        const SizedBox(height: 24),
        // 分类饼图
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildPieChartSection(theme, weeklyCategoryTotals, weeklyTotal),
        ),
        const SizedBox(height: 16),
        // 分类排行榜
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildCategoryRankingSectionForWeek(theme, weeklyCategoryTotals, weeklyTotal),
        ),
      ],
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderSection(theme, totalAmount),
        const SizedBox(height: 24),
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildMonthlyBarChartSection(theme, monthlyTotals),
        ),
        const SizedBox(height: 24),
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildCalendarSection(theme, dailyTotals),
        ),
        const SizedBox(height: 24),
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildPieChartSection(theme, categoryTotals, totalAmount),
        ),
        const SizedBox(height: 16),
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildCategoryRankingSection(theme, categoryTotals, totalAmount),
        ),
      ],
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        _buildYearlyHeaderSection(theme, yearlyTotal),
        const SizedBox(height: 24),
        // 月度对比图
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildYearlyBarChartSection(theme, yearlyMonthlyTotals, yearlyAverage),
        ),
        const SizedBox(height: 24),
        // 分类饼图
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildPieChartSection(theme, yearlyCategoryTotals, yearlyTotal),
        ),
        const SizedBox(height: 16),
        // 分类排行榜
        FadeTransition(
          opacity: _fadeAnimation,
          child: _buildCategoryRankingSectionForYear(theme, yearlyCategoryTotals, yearlyTotal),
        ),
      ],
    );
  }

  /// 周度 Header
  Widget _buildWeeklyHeaderSection(ThemeData theme, int totalAmount, String weekRangeStr) {
    final isThisWeek = _weekOffset == 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _showWeekPicker(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isThisWeek ? '本周' : weekRangeStr,
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
              selected: {_isExpense},
              onSelectionChanged: (value) {
                if (value.isNotEmpty) {
                  _switchExpenseType(value.first);
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
                _currencyFormatter.format(value),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isExpense ? Colors.red.shade700 : Colors.green.shade700,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 年度 Header
  Widget _buildYearlyHeaderSection(ThemeData theme, int totalAmount) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _showYearPicker(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_selectedYear年',
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
              selected: {_isExpense},
              onSelectionChanged: (value) {
                if (value.isNotEmpty) {
                  _switchExpenseType(value.first);
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
                _currencyFormatter.format(value),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isExpense ? Colors.red.shade700 : Colors.green.shade700,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 一周小结：双柱对比图（上周 vs 当周）
  Widget _buildWeeklyBarChartSection(
    ThemeData theme,
    List<WeeklyDailyTotal> currentWeek,
    List<WeeklyDailyTotal> lastWeek,
  ) {
    if (currentWeek.isEmpty) return const SizedBox.shrink();

    final allAmounts = [...currentWeek.map((e) => e.amount), ...lastWeek.map((e) => e.amount)];
    final maxAmount = allAmounts.fold<int>(0, (max, e) => e > max ? e : max);
    final maxY = maxAmount > 0 ? (maxAmount / 100).ceilToDouble() * 1.3 : 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '一周小结',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            // 图例
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: kLightBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text('上周', style: theme.textTheme.bodySmall),
                const SizedBox(width: 12),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: kDarkBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text('当周', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < currentWeek.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            currentWeek[index].dayLabel,
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (index) {
                final lastWeekAmount = index < lastWeek.length ? lastWeek[index].amount / 100 : 0.0;
                final currentWeekAmount = index < currentWeek.length ? currentWeek[index].amount / 100 : 0.0;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: lastWeekAmount,
                      color: kLightBlue,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: currentWeekAmount,
                      color: kDarkBlue,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => kDarkBlue,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final label = rodIndex == 0 ? '上周' : '当周';
                    return BarTooltipItem(
                      '$label: ¥${rod.toY.toStringAsFixed(2)}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          ),
        ),
      ],
    );
  }

  /// 周日历：7天横向排列
  Widget _buildWeeklyCalendarSection(ThemeData theme, List<WeeklyDailyTotal> weeklyDailyTotals) {
    return Row(
      children: weeklyDailyTotals.map((day) {
        final hasAmount = day.amount > 0;
        return Expanded(
          child: GestureDetector(
            onTap: hasAmount ? () => _showWeekDayTransactionsModal(context, day) : null,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: day.isToday ? kTodayBg : null,
                borderRadius: BorderRadius.circular(8),
                border: day.isToday
                    ? Border.all(color: kDarkBlue, width: 1)
                    : Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.dateLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: day.isToday ? FontWeight.bold : FontWeight.w500,
                      color: day.isToday ? kDarkBlue : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAmount ? (day.amount / 100).toStringAsFixed(0) : '-',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hasAmount ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                      fontWeight: hasAmount ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 年度月度对比图
  Widget _buildYearlyBarChartSection(
    ThemeData theme,
    List<YearlyMonthTotal> monthlyTotals,
    int averageAmount,
  ) {
    if (monthlyTotals.isEmpty) return const SizedBox.shrink();

    final maxAmount = monthlyTotals.fold<int>(0, (max, e) => e.amount > max ? e.amount : max);
    final avgY = averageAmount / 100;
    final maxY = (maxAmount > averageAmount ? maxAmount : averageAmount) / 100 * 1.3;
    final selectedMonth = _selectedYearlyMonth ?? DateTime.now().month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '月度对比',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            // 图例
            Row(
              children: [
                Container(width: 16, height: 2, color: Colors.orange),
                const SizedBox(width: 4),
                Text('月支出均值', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 计算每个柱子的位置，用于放置可点击的 tooltip
              final chartWidth = constraints.maxWidth;
              final barWidth = chartWidth / 12;
              
              return Stack(
                children: [
                  // 柱状图
                  BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY > 0 ? maxY : 100,
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < 12) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    '${index + 1}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: avgY,
                            color: Colors.orange,
                            strokeWidth: 1,
                            dashArray: [5, 5],
                            label: HorizontalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              labelResolver: (line) => avgY.toStringAsFixed(0),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      barGroups: monthlyTotals.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        final isSelected = data.month == selectedMonth;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: data.amount / 100,
                              color: isSelected ? kDarkBlue : kLightBlue,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                          // 不显示内置 tooltip，使用自定义的
                          showingTooltipIndicators: [],
                        );
                      }).toList(),
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchCallback: (event, response) {
                          if (event.isInterestedForInteractions && response?.spot != null) {
                            final index = response!.spot!.touchedBarGroupIndex;
                            if (index >= 0 && index < 12) {
                              setState(() {
                                _selectedYearlyMonth = index + 1;
                                _touchedPieIndex = null;
                              });
                            }
                          }
                        },
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.transparent,
                          tooltipPadding: EdgeInsets.zero,
                          tooltipMargin: 0,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) => null,
                        ),
                      ),
                    ),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                  ),
                  // 选中月份的可点击 tooltip
                  if (monthlyTotals.isNotEmpty)
                    ...monthlyTotals.asMap().entries.map((entry) {
                      final index = entry.key;
                      final data = entry.value;
                      final isSelected = data.month == selectedMonth;
                      if (!isSelected || data.amount <= 0) return const SizedBox.shrink();
                      
                      // 计算 tooltip 位置
                      final barCenterX = barWidth * index + barWidth / 2;
                      final barHeight = maxY > 0 ? (data.amount / 100) / maxY : 0;
                      // 图表高度减去底部标题空间(30)，tooltip 在柱子上方
                      final chartHeight = 250.0 - 30;
                      final tooltipY = chartHeight * (1 - barHeight) - 45; // 45 是 tooltip 高度 + margin
                      
                      // tooltip 宽度约 90，计算水平位置并确保不超出边界
                      const tooltipWidth = 90.0;
                      var tooltipX = barCenterX - tooltipWidth / 2;
                      // 左边界限制
                      if (tooltipX < 0) {
                        tooltipX = 0;
                      }
                      // 右边界限制
                      if (tooltipX + tooltipWidth > chartWidth) {
                        tooltipX = chartWidth - tooltipWidth;
                      }
                      
                      return Positioned(
                        left: tooltipX,
                        top: tooltipY > 0 ? tooltipY : 0,
                        child: GestureDetector(
                          onTap: () => _showYearlyMonthTransactionsModal(context, data.month, data.amount),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: kDarkBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_selectedYear年${data.month}月\n¥${(data.amount / 100).toStringAsFixed(2)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ],
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
        _touchedPieIndex = null;
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
        _touchedPieIndex = null;
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

  /// 周度分类排行榜（复用样式，但数据来源不同）
  Widget _buildCategoryRankingSectionForWeek(
    ThemeData theme,
    List<CategoryTotal> categoryTotals,
    int totalAmount,
  ) {
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
          final percentage = totalAmount > 0 ? (data.amount / totalAmount * 100) : 0.0;

          return _buildCategoryItem(
            theme: theme,
            rank: index + 1,
            category: data.category,
            percentage: percentage,
            amount: data.amount,
            count: data.count,
            onTap: () => _showWeeklyCategoryTransactionsModal(
              context,
              data.category,
              data.amount,
              data.count,
            ),
          );
        }),
      ],
    );
  }

  /// 年度分类排行榜
  Widget _buildCategoryRankingSectionForYear(
    ThemeData theme,
    List<CategoryTotal> categoryTotals,
    int totalAmount,
  ) {
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
          final percentage = totalAmount > 0 ? (data.amount / totalAmount * 100) : 0.0;

          return _buildCategoryItem(
            theme: theme,
            rank: index + 1,
            category: data.category,
            percentage: percentage,
            amount: data.amount,
            count: data.count,
            onTap: () => _showYearlyCategoryTransactionsModal(
              context,
              data.category,
              data.amount,
              data.count,
            ),
          );
        }),
      ],
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
  Widget _buildHeaderSection(ThemeData theme, int totalAmount) {
    return Column(
      children: [
        // 日期选择 + 收支切换
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 日期选择
            GestureDetector(
              onTap: () => _showMonthYearPicker(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_selectedYear年$_selectedMonth月',
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
            // 收支切换 (胶囊形式 SegmentedButton)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('支出')),
                ButtonSegment(value: false, label: Text('收入')),
              ],
              selected: {_isExpense},
              onSelectionChanged: (value) {
                if (value.isNotEmpty) {
                  _switchExpenseType(value.first);
                }
              },
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 总金额（大字显示，带动画）
        Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: totalAmount / 100),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Text(
                _currencyFormatter.format(value),
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _isExpense ? Colors.red.shade700 : Colors.green.shade700,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 月度小结：近5个月柱状图（金额显示在柱子顶部）
  Widget _buildMonthlyBarChartSection(ThemeData theme, List<MonthlyTotal> monthlyTotals) {
    if (monthlyTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxAmount = monthlyTotals.fold<int>(0, (max, e) => e.amount > max ? e.amount : max);
    // 为金额标签预留空间，增加顶部边距
    final maxY = maxAmount > 0 ? (maxAmount / 100).ceilToDouble() * 1.5 : 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月度小结',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < monthlyTotals.length) {
                        final data = monthlyTotals[index];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            data.label,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    interval: maxY / 3,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 3,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: monthlyTotals.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final isSelectedMonth = data.year == _selectedYear && data.month == _selectedMonth;
                final barColor = isSelectedMonth
                    ? const Color(0xFF1976D2)
                    : const Color(0xFF90CAF9);
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: data.amount / 100,
                      color: barColor,
                      width: 40,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      // 在柱子顶部显示金额标签
                      rodStackItems: [],
                    ),
                  ],
                  // 显示柱子顶部的金额标签
                  showingTooltipIndicators: data.amount > 0 ? [0] : [],
                );
              }).toList(),
              barTouchData: BarTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (event.isInterestedForInteractions &&
                      response?.spot != null) {
                    final index = response!.spot!.touchedBarGroupIndex;
                    if (index >= 0 && index < monthlyTotals.length) {
                      final tappedMonth = monthlyTotals[index];
                      
                      // 边界月份自动推进逻辑
                      int newYear = tappedMonth.year;
                      int newMonth = tappedMonth.month;
                      
                      if (index == 0) {
                        // 点击最左边的柱子，检查是否有更早的数据
                        int prevMonth = tappedMonth.month - 1;
                        int prevYear = tappedMonth.year;
                        if (prevMonth <= 0) {
                          prevMonth = 12;
                          prevYear -= 1;
                        }
                        // 如果有更早月份的数据，则使用点击的月份（显示范围会自动往前推）
                        if (hasDataForMonth(
                          records: _allRecords,
                          year: prevYear,
                          month: prevMonth,
                          isExpense: _isExpense,
                        )) {
                          // 有更早数据，正常跳转到点击的月份
                          newYear = tappedMonth.year;
                          newMonth = tappedMonth.month;
                        }
                      } else if (index == monthlyTotals.length - 1) {
                        // 点击最右边的柱子，检查是否有更晚的数据
                        int nextMonth = tappedMonth.month + 1;
                        int nextYear = tappedMonth.year;
                        if (nextMonth > 12) {
                          nextMonth = 1;
                          nextYear += 1;
                        }
                        // 如果有更晚月份的数据，则跳转到下一个月（显示范围会往后推）
                        if (hasDataForMonth(
                          records: _allRecords,
                          year: nextYear,
                          month: nextMonth,
                          isExpense: _isExpense,
                        )) {
                          // 有更晚数据，跳转到下一个月
                          newYear = nextYear;
                          newMonth = nextMonth;
                        }
                      }
                      
                      // 跳转到目标月份（带动画）
                      _switchMonth(newYear, newMonth);
                    }
                  }
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  tooltipMargin: 0,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final data = monthlyTotals[groupIndex];
                    final isSelectedMonth = data.year == _selectedYear && data.month == _selectedMonth;
                    return BarTooltipItem(
                      _formatAmountShort(data.amount),
                      TextStyle(
                        color: isSelectedMonth
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: isSelectedMonth ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 11,
                      ),
                    );
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          ),
        ),
      ],
    );
  }

  /// 日历视图
  Widget _buildCalendarSection(ThemeData theme, List<DailyTotal> dailyTotals) {
    // 构建每日金额映射
    final dailyMap = <int, int>{};
    for (final dt in dailyTotals) {
      dailyMap[dt.day] = dt.amount;
    }

    // 获取当月第一天是星期几 (0=周日, 1=周一, ..., 6=周六)
    final firstDayOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 转换为周日=0
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;

    // 今天的日期
    final today = DateTime.now();
    final isCurrentMonth = today.year == _selectedYear && today.month == _selectedMonth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 星期标题行
        Row(
          children: ['日', '一', '二', '三', '四', '五', '六']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // 日历网格
        _buildCalendarGrid(
          theme: theme,
          firstWeekday: firstWeekday,
          daysInMonth: daysInMonth,
          dailyMap: dailyMap,
          isCurrentMonth: isCurrentMonth,
          today: today.day,
        ),
      ],
    );
  }

  /// 构建日历网格
  Widget _buildCalendarGrid({
    required ThemeData theme,
    required int firstWeekday,
    required int daysInMonth,
    required Map<int, int> dailyMap,
    required bool isCurrentMonth,
    required int today,
  }) {
    final rows = <Widget>[];
    var currentDay = 1;

    // 计算需要多少行
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    for (var row = 0; row < rowCount; row++) {
      final cells = <Widget>[];
      for (var col = 0; col < 7; col++) {
        final cellIndex = row * 7 + col;
        if (cellIndex < firstWeekday || currentDay > daysInMonth) {
          // 空白格子
          cells.add(const Expanded(child: SizedBox(height: 60)));
        } else {
          final day = currentDay;
          final amount = dailyMap[day] ?? 0;
          final isToday = isCurrentMonth && day == today;
          cells.add(
            Expanded(
              child: _buildDayCell(
                theme: theme,
                day: day,
                amount: amount,
                isToday: isToday,
              ),
            ),
          );
          currentDay++;
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: cells),
        ),
      );
    }

    return Column(children: rows);
  }

  /// 构建单个日期格子（可点击）
  Widget _buildDayCell({
    required ThemeData theme,
    required int day,
    required int amount,
    required bool isToday,
  }) {
    final hasAmount = amount > 0;
    final amountStr = hasAmount ? (amount / 100).toStringAsFixed(2) : '';

    return GestureDetector(
      onTap: hasAmount ? () => _showDayTransactionsModal(context, day, amount) : null,
      child: Container(
        height: 60,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday
              ? theme.colorScheme.primaryContainer
              : hasAmount
                  ? theme.colorScheme.surfaceContainerHighest
                  : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isToday ? '今天' : '$day',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ),
            if (hasAmount)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  amountStr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

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
  Widget _buildPieChartSection(
    ThemeData theme,
    List<CategoryTotal> categoryTotals,
    int totalAmount,
  ) {
    if (categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    // 只取前5名，其余合并为"其他"
    const maxDisplayCount = 5;
    List<CategoryTotal> displayCategories;
    if (categoryTotals.length > maxDisplayCount) {
      displayCategories = categoryTotals.take(maxDisplayCount).toList();
      // 计算"其他"的总金额和笔数
      int otherAmount = 0;
      int otherCount = 0;
      for (var i = maxDisplayCount; i < categoryTotals.length; i++) {
        otherAmount += categoryTotals[i].amount;
        otherCount += categoryTotals[i].count;
      }
      if (otherAmount > 0) {
        displayCategories.add(CategoryTotal(
          category: '其他(总和)',
          amount: otherAmount,
          count: otherCount,
        ));
      }
    } else {
      displayCategories = categoryTotals;
    }

    // 确定当前选中的分类索引（默认第一个即最大占比）
    final selectedIndex = (_touchedPieIndex != null &&
            _touchedPieIndex! >= 0 &&
            _touchedPieIndex! < displayCategories.length)
        ? _touchedPieIndex!
        : 0;

    final selectedCategory = displayCategories[selectedIndex];
    final displayPercentage = totalAmount > 0
        ? (selectedCategory.amount / totalAmount * 100)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isExpense ? '支出分类' : '收入分类',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event.isInterestedForInteractions &&
                          response?.touchedSection != null) {
                        final index = response!.touchedSection!.touchedSectionIndex;
                        if (index >= 0 && index < displayCategories.length) {
                          setState(() {
                            _touchedPieIndex = index;
                          });
                        }
                      }
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: displayCategories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    final isSelected = index == selectedIndex;
                    final percentage = totalAmount > 0
                        ? (data.amount / totalAmount * 100)
                        : 0.0;
                    final color = kCategoryColors[index % kCategoryColors.length];
                    
                    // 是否有用户主动选中（非默认状态）
                    final hasUserSelection = _touchedPieIndex != null;
                    
                    // 标签显示逻辑：
                    // - 有选中时：只显示选中的那个标签
                    // - 无选中时（默认）：显示占比 >= 5% 的标签
                    final shouldShowBadge = hasUserSelection
                        ? isSelected
                        : percentage >= 5;

                    return PieChartSectionData(
                      color: color,
                      value: data.amount.toDouble(),
                      title: '',
                      radius: isSelected ? 40 : 32,
                      // 外部标签：带颜色边框的方框
                      badgeWidget: shouldShowBadge
                          ? _buildCategoryBadge(
                              theme: theme,
                              category: data.category,
                              percentage: percentage,
                              color: color,
                              isSelected: isSelected,
                            )
                          : null,
                      badgePositionPercentageOffset: 1.15,
                    );
                  }).toList(),
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              // 中间显示选中分类信息
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Column(
                  key: ValueKey('${selectedCategory.category}-${selectedCategory.amount}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      selectedCategory.category,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${displayPercentage.toStringAsFixed(1)}%',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      _formatAmountShort(selectedCategory.amount),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 图例
        const SizedBox(height: 12),
        _buildPieLegend(theme, displayCategories, totalAmount, selectedIndex),
      ],
    );
  }

  /// 构建分类标签（带颜色边框的方框）
  Widget _buildCategoryBadge({
    required ThemeData theme,
    required String category,
    required double percentage,
    required Color color,
    required bool isSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        '$category ${percentage.toStringAsFixed(0)}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 10,
        ),
      ),
    );
  }

  /// 构建饼图图例
  Widget _buildPieLegend(
    ThemeData theme,
    List<CategoryTotal> categories,
    int totalAmount,
    int selectedIndex,
  ) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: categories.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        final color = kCategoryColors[index % kCategoryColors.length];
        final percentage = totalAmount > 0
            ? (data.amount / totalAmount * 100)
            : 0.0;
        final isSelected = index == selectedIndex;

        return GestureDetector(
          onTap: () {
            setState(() {
              _touchedPieIndex = index;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${data.category} ${percentage.toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// 支出分类排行榜（支付宝风格）
  Widget _buildCategoryRankingSection(
    ThemeData theme,
    List<CategoryTotal> categoryTotals,
    int totalAmount,
  ) {
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
          final percentage = totalAmount > 0 ? (data.amount / totalAmount * 100) : 0.0;

          return _buildCategoryItem(
            theme: theme,
            rank: index + 1,
            category: data.category,
            percentage: percentage,
            amount: data.amount,
            count: data.count,
            onTap: () => _showCategoryTransactionsModal(
              context,
              data.category,
              data.amount,
              data.count,
            ),
          );
        }),
      ],
    );
  }

  /// 构建单个分类项（支付宝风格：序号.名称 百分比 | 金额(笔数)）
  Widget _buildCategoryItem({
    required ThemeData theme,
    required int rank,
    required String category,
    required double percentage,
    required int amount,
    required int count,
    required VoidCallback onTap,
  }) {
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
                      text: '$category ',
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
              '${_currencyFormatter.format(amount / 100)}($count笔)',
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
