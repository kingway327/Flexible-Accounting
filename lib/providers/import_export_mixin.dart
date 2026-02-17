import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../data/analysis_helpers.dart';
import '../data/export_service.dart';
import '../data/parsers.dart';
import '../data/transaction_dao.dart';
import '../models/models.dart';

mixin ImportExportMixin on ChangeNotifier {
  TransactionDao get transactionDao;
  ExportService get exportService;

  Future<void> reloadData();
  void setLoadingState(bool value);
  void showImportResultSnack(int inserted, int duplicates);
  set snackBarMessage(String? message);

  List<TransactionRecord> get recordsForExport;
  int get exportSelectedYear;
  int get exportSelectedMonth;
  bool get exportFilterByYear;

  Future<void> importFile() async {
    setLoadingState(true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setLoadingState(false);
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes ?? Uint8List(0);
      final extension = file.extension?.toLowerCase();

      List<TransactionRecord> records;
      if (extension == 'xlsx' || extension == 'xls') {
        final rows = decodeExcelBytes(bytes);
        final source = FileTypeDetector.detectSourceFromRows(rows);
        records = source == 'WeChat'
            ? WechatParser.parseRows(rows)
            : AlipayParser.parseRows(rows);
      } else {
        final content = await decodeCsvBytes(bytes);
        final source = FileTypeDetector.detectSource(content);
        records = source == 'WeChat'
            ? WechatParser.parse(content)
            : AlipayParser.parse(content);
      }

      final inserted = await transactionDao.insertTransactions(records);
      final duplicates = records.length - inserted;
      await reloadData();
      setLoadingState(false);
      showImportResultSnack(inserted, duplicates);
    } catch (e, stackTrace) {
      setLoadingState(false);
      snackBarMessage = '导入失败，请检查文件格式后重试';
      debugPrint('导入文件失败: $e');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
    }
  }

  Future<void> clearAllData() async {
    setLoadingState(true);
    try {
      final deleted = await transactionDao.clearAllTransactions();
      AnalysisCache.instance.clear();
      await reloadData();
      setLoadingState(false);
      snackBarMessage = '已清空 $deleted 条记录';
      notifyListeners();
    } catch (e, stackTrace) {
      setLoadingState(false);
      snackBarMessage = '清空失败，请重试';
      debugPrint('清空数据失败: $e');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
    }
  }

  Future<void> exportCurrentData() async {
    setLoadingState(true);
    try {
      final dataToExport = recordsForExport;
      final success = await exportService.exportToCsv(
        dataToExport,
        year: exportSelectedYear,
        month: exportSelectedMonth,
        filterByYear: exportFilterByYear,
      );
      setLoadingState(false);
      snackBarMessage = success ? '已导出 ${dataToExport.length} 条记录' : '导出失败，请重试';
      notifyListeners();
    } catch (e, stackTrace) {
      setLoadingState(false);
      snackBarMessage = '导出失败，请重试';
      debugPrint('导出当前数据失败: $e');
      debugPrintStack(stackTrace: stackTrace);
      notifyListeners();
    }
  }
}
