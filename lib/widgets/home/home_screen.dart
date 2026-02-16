import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/analysis_helpers.dart';
import '../../data/database_helper.dart';
import '../../pages/analysis_page.dart';
import '../../pages/category_manage_page.dart';
import '../../pages/transaction_detail_page.dart';
import '../../providers/finance_provider.dart';
import 'home_modals.dart';
import 'home_display_widgets.dart';
import 'home_guides.dart';
import '../month_picker.dart';

/// 首页主界面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _kNormalToolbarHeight = 84;

  final _db = DatabaseHelper.instance;
  final _listScrollController = ScrollController();
  Timer? _guideCycleTimer;
  Timer? _guideHideTimer;
  bool _floatingGuideFeatureEnabled = false;
  bool _floatingGuideVisible = false;
  bool _markGuideShownPending = false;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_handleListScroll);
    _applyHomeIconGuidePolicy();
  }

  void _handleListScroll() {
    if (!_listScrollController.hasClients) {
      return;
    }
    final shouldShow = _listScrollController.offset > 320;
    if (shouldShow == _showScrollToTop) {
      return;
    }
    setState(() => _showScrollToTop = shouldShow);
  }

  void _scrollToTop() {
    if (!_listScrollController.hasClients) {
      return;
    }
    _listScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _applyHomeIconGuidePolicy() async {
    final guideEnabled = await _db.getHomeIconGuideEnabled();
    final shownOnce = await _db.hasShownHomeIconGuide();
    final shouldEnable = guideEnabled || !shownOnce;

    if (!mounted) {
      return;
    }

    _guideCycleTimer?.cancel();
    _guideHideTimer?.cancel();

    if (!shouldEnable) {
      setState(() {
        _floatingGuideFeatureEnabled = false;
        _floatingGuideVisible = false;
      });
      return;
    }

    _markGuideShownPending = !shownOnce;

    setState(() {
      _floatingGuideFeatureEnabled = true;
    });

    _showGuideWindow();
    if (guideEnabled) {
      _guideCycleTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        if (!mounted) return;
        _showGuideWindow();
      });
    }
  }

  void _showGuideWindow() {
    _guideHideTimer?.cancel();
    setState(() => _floatingGuideVisible = true);
    if (_markGuideShownPending) {
      _markGuideShownPending = false;
      _db.markHomeIconGuideShown();
    }
    _guideHideTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _floatingGuideVisible = false);
    });
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _guideCycleTimer?.cancel();
    _guideHideTimer?.cancel();
    super.dispose();
  }

  Widget _buildScrollToTopFab() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: _showScrollToTop
          ? FloatingActionButton.small(
              key: const ValueKey('scroll_to_top_fab'),
              heroTag: 'scroll_to_top_fab',
              tooltip: '回到顶部',
              onPressed: _scrollToTop,
              child: const Icon(Icons.keyboard_arrow_up),
            )
          : const SizedBox(
              key: ValueKey('scroll_to_top_placeholder'),
              width: 0,
              height: 0,
            ),
    );
  }

  Widget _buildBottomActionOverlay(
      BuildContext context, FinanceProvider provider) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 16;

    if (_floatingGuideFeatureEnabled) {
      return Positioned(
        right: 0,
        bottom: bottomInset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingGuideAction(
              label: '批量编辑',
              heroTag: 'edit_fab',
              icon: Icons.edit_outlined,
              compact: true,
              emphasized: _floatingGuideVisible,
              onTap: provider.loading ? null : provider.toggleBatchEdit,
            ),
            const SizedBox(height: 12),
            FloatingGuideAction(
              label: '导入账单',
              heroTag: 'import_fab',
              icon: Icons.upload_file,
              compact: false,
              emphasized: _floatingGuideVisible,
              onTap: provider.loading ? null : provider.importFile,
              onLongPress: provider.loading
                  ? null
                  : () => _showClearDataDialog(context, provider),
            ),
          ],
        ),
      );
    }

    return Positioned(
      right: 16,
      bottom: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'edit_fab',
            onPressed: provider.loading ? null : provider.toggleBatchEdit,
            child: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onLongPress: provider.loading
                ? null
                : () => _showClearDataDialog(context, provider),
            child: FloatingActionButton(
              heroTag: 'import_fab',
              onPressed: provider.loading ? null : provider.importFile,
              child: const Icon(Icons.upload_file),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, _) {
        final snack = provider.consumeSnackMessage();
        if (snack != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(snack)),
            );
          });
        }

        final scaffoldAppBar = provider.isBatchEditing
            ? _buildBatchEditAppBar(context, provider)
            : null;

        if (provider.initializing) {
          return Scaffold(
            appBar: provider.isBatchEditing
                ? _buildBatchEditAppBar(context, provider)
                : _buildNormalAppBar(context, provider),
            body: const HomeStartupSkeleton(),
          );
        }

        final records = provider.records;
        final scrollToTopInset = provider.isBatchEditing
            ? 12.0
            : MediaQuery.of(context).padding.top + _kNormalToolbarHeight + 12;

        return Scaffold(
          appBar: scaffoldAppBar,
          bottomNavigationBar: provider.isBatchEditing
              ? BatchEditBottomBar(
                  hasSelection: provider.selectedCount > 0,
                  onEditCategory: () =>
                      showBatchCategoryModal(context, provider),
                  onEditNote: () => showBatchNoteModal(context, provider),
                )
              : null,
          body: Stack(
            children: [
              CustomScrollView(
                controller: _listScrollController,
                slivers: [
                  if (!provider.isBatchEditing)
                    _buildNormalSliverAppBar(context, provider),
                  SliverPersistentHeader(
                    pinned: !provider.isBatchEditing,
                    delegate: _HomeFilterHeaderDelegate(
                      hasActiveFilters: provider.hasActiveFilters,
                      onFilterTap: () => showAdvancedFilterModal(
                        context,
                        initialTypeFilter: provider.typeFilter,
                        initialCategories: provider.selectedCategories,
                        filterTypes: provider.filterTypes,
                        categoryGroups: provider.categoryGroups,
                        onConfirm: (typeFilter, categories) {
                          provider.updateAdvancedFilters(
                            typeFilter: typeFilter,
                            categories: categories,
                          );
                        },
                      ),
                      onSearchChanged: provider.updateSearchQuery,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: MonthSummaryRow(
                        year: provider.selectedYear,
                        month: provider.selectedMonth,
                        summary: provider.summary,
                        filterByYear: provider.filterByYear,
                        onMonthTap: () {
                          if (provider.filterByYear) {
                            showYearPicker(context, provider);
                          } else {
                            showMonthYearPicker(
                              context,
                              initialYear: provider.selectedYear,
                              initialMonth: provider.selectedMonth,
                              onConfirm: provider.updateMonthYear,
                              hasDataForYearMonth: (year, month) =>
                                  hasDataForMonthAny(
                                records: provider.allRecords,
                                year: year,
                                month: month,
                              ),
                              noDataWarning: '该月份暂无数据',
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: SourceFilterWidget(
                        current: provider.currentFilter,
                        onChanged: provider.updateFilter,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      provider.isBatchEditing ? 80 : 16,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final record = records[index];
                          return TransactionTile(
                            key: ValueKey(record.id),
                            record: record,
                            isEditing: provider.isBatchEditing,
                            isSelected:
                                provider.selectedIds.contains(record.id),
                            onTap: provider.isBatchEditing
                                ? () => provider.toggleSelection(record.id)
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TransactionDetailPage(
                                          record: record,
                                        ),
                                      ),
                                    );
                                  },
                          );
                        },
                        childCount: records.length,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: scrollToTopInset,
                right: 12,
                child: _buildScrollToTopFab(),
              ),
              if (!provider.isBatchEditing)
                _buildBottomActionOverlay(context, provider),
              if (provider.loading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x55000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  SliverAppBar _buildNormalSliverAppBar(
    BuildContext context,
    FinanceProvider provider,
  ) {
    return SliverAppBar(
      toolbarHeight: _kNormalToolbarHeight,
      floating: true,
      snap: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('记账'),
          const SizedBox(width: 12),
          DateRangeRadio(
            filterByYear: provider.filterByYear,
            onChanged: provider.updateFilterByYear,
          ),
        ],
      ),
      actions: [
        TopActionGuideButton(
          icon: Icons.file_download_outlined,
          tooltip: '导出账单',
          guideLabel: '导出账单',
          guideVisible: _floatingGuideFeatureEnabled,
          onPressed: provider.loading ? null : provider.exportCurrentData,
        ),
        TopActionGuideButton(
          icon: Icons.analytics_outlined,
          tooltip: '收支分析',
          guideLabel: '收支分析',
          guideVisible: _floatingGuideFeatureEnabled,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalysisPage()),
            );
          },
        ),
        TopActionGuideButton(
          icon: Icons.settings_outlined,
          tooltip: '系统设置',
          guideLabel: '系统设置',
          guideVisible: _floatingGuideFeatureEnabled,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryManagePage()),
            );
            if (!context.mounted) return;
            await _applyHomeIconGuidePolicy();
          },
        ),
      ],
    );
  }

  AppBar _buildNormalAppBar(BuildContext context, FinanceProvider provider) {
    return AppBar(
      toolbarHeight: _kNormalToolbarHeight,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('记账'),
          const SizedBox(width: 12),
          DateRangeRadio(
            filterByYear: provider.filterByYear,
            onChanged: provider.updateFilterByYear,
          ),
        ],
      ),
      actions: [
        TopActionGuideButton(
          icon: Icons.file_download_outlined,
          tooltip: '导出账单',
          guideLabel: '导出账单',
          guideVisible: _floatingGuideFeatureEnabled,
          onPressed: provider.loading ? null : provider.exportCurrentData,
        ),
        TopActionGuideButton(
          icon: Icons.analytics_outlined,
          tooltip: '收支分析',
          guideLabel: '收支分析',
          guideVisible: _floatingGuideFeatureEnabled,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalysisPage()),
            );
          },
        ),
        TopActionGuideButton(
          icon: Icons.settings_outlined,
          tooltip: '系统设置',
          guideLabel: '系统设置',
          guideVisible: _floatingGuideFeatureEnabled,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryManagePage()),
            );
            if (!context.mounted) return;
            await _applyHomeIconGuidePolicy();
          },
        ),
      ],
    );
  }

  AppBar _buildBatchEditAppBar(BuildContext context, FinanceProvider provider) {
    final allSelected = provider.selectedCount == provider.records.length &&
        provider.records.isNotEmpty;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: provider.exitBatchEdit,
      ),
      title: Text('已选择 ${provider.selectedCount} 项'),
      actions: [
        TextButton(
          onPressed: allSelected ? provider.clearSelection : provider.selectAll,
          child: Text(allSelected ? '取消全选' : '全选'),
        ),
      ],
    );
  }
}

// ==================== 弹窗函数 ====================

/// 显示清空数据对话框
void _showClearDataDialog(BuildContext context, FinanceProvider provider) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('清空数据'),
      content: const Text('确定要清空所有交易记录吗？\n\n清空后需要重新导入账单文件。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            provider.clearAllData();
          },
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('清空'),
        ),
      ],
    ),
  );
}

class _HomeFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HomeFilterHeaderDelegate({
    required this.hasActiveFilters,
    required this.onFilterTap,
    required this.onSearchChanged,
  });

  static const double _extent = 62;

  final bool hasActiveFilters;
  final VoidCallback onFilterTap;
  final ValueChanged<String> onSearchChanged;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: overlapsContent ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            FilterButton(
              hasActiveFilters: hasActiveFilters,
              onTap: onFilterTap,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SearchBarWidget(onChanged: onSearchChanged),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeFilterHeaderDelegate oldDelegate) {
    return hasActiveFilters != oldDelegate.hasActiveFilters;
  }
}
