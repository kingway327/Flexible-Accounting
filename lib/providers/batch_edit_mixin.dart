import 'package:flutter/foundation.dart';

import '../data/transaction_dao.dart';

mixin BatchEditMixin on ChangeNotifier {
  bool _isBatchEditing = false;
  Set<String> _selectedIds = {};

  TransactionDao get transactionDao;
  Future<void> reloadData();
  void setLoadingState(bool value);
  set snackBarMessage(String? message);
  Set<String> get recordIdsInCurrentView;

  bool get isBatchEditing => _isBatchEditing;
  Set<String> get selectedIds => _selectedIds;
  int get selectedCount => _selectedIds.length;

  void toggleBatchEdit() {
    _isBatchEditing = !_isBatchEditing;
    if (!_isBatchEditing) {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  void exitBatchEdit() {
    _isBatchEditing = false;
    _selectedIds.clear();
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedIds = recordIdsInCurrentView;
    notifyListeners();
  }

  void clearSelection() {
    _selectedIds.clear();
    notifyListeners();
  }

  Future<void> updateBatchCategory(String category) async {
    if (_selectedIds.isEmpty) {
      return;
    }
    setLoadingState(true);
    try {
      final count = await transactionDao.batchUpdateCategory(
          _selectedIds.toList(), category);
      await reloadData();
      _isBatchEditing = false;
      _selectedIds.clear();
      snackBarMessage = '已更新 $count 条记录的分类';
      notifyListeners();
    } finally {
      setLoadingState(false);
    }
  }

  Future<void> updateBatchNote(String note) async {
    if (_selectedIds.isEmpty) {
      return;
    }
    setLoadingState(true);
    try {
      final count =
          await transactionDao.batchUpdateNote(_selectedIds.toList(), note);
      await reloadData();
      _isBatchEditing = false;
      _selectedIds.clear();
      snackBarMessage = '已更新 $count 条记录的备注';
      notifyListeners();
    } finally {
      setLoadingState(false);
    }
  }
}
