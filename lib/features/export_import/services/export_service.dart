import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

// ignore_for_file: prefer_initializing_formals

import 'package:archive/archive.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/export_import/domain/export_import_repository_interface.dart';
import 'package:duasaku_app/features/export_import/domain/export_service_interface.dart';
import 'package:duasaku_app/features/export_import/domain/models/backup_metadata.dart';
import 'package:duasaku_app/features/export_import/domain/models/data_type.dart';
import 'package:duasaku_app/features/export_import/domain/models/export_config.dart';
import 'package:duasaku_app/features/export_import/domain/models/export_result.dart';
import 'package:duasaku_app/features/export_import/services/isolate_helpers.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Concrete implementation of [ExportServiceInterface].
///
/// Handles CSV export (single file or ZIP archive), JSON full backup,
/// file sharing via native share sheet, and temp file cleanup.
class ExportService implements ExportServiceInterface {
  final ExportImportRepositoryInterface _repository;
  final String _userId;

  /// Schema version of the current database (Drift).
  static const int _currentSchemaVersion = 7;

  /// App version string.
  static const String _appVersion = '1.0.0';

  ExportService(this._repository, {required String userId}) : _userId = userId;
  // ---------------------------------------------------------------------------
  // CSV Export
  // ---------------------------------------------------------------------------

  @override
  Future<Result<ExportResult, AppError>> exportCsv(ExportConfig config) async {
    try {
      final timestamp = _formatTimestamp(DateTime.now());
      final tempDir = await getTemporaryDirectory();

      // Get wallet and category name maps for resolving FKs in CSV
      final walletNamesResult = await _repository.getWalletNameMap(_userId);
      final categoryNamesResult = await _repository.getCategoryNameMap(_userId);

      final Map<String, String> walletNames;
      final Map<String, String> categoryNames;

      switch (walletNamesResult) {
        case Success(:final value):
          walletNames = value;
        case Failure(:final error):
          return Failure(error);
      }

      switch (categoryNamesResult) {
        case Success(:final value):
          categoryNames = value;
        case Failure(:final error):
          return Failure(error);
      }

      final selectedTypes = config.selectedTypes.toList();
      int totalRecordCount = 0;

      if (selectedTypes.length == 1) {
        // Single type → produce a single CSV file
        final dataType = selectedTypes.first;
        final dataResult = await _fetchDataForType(
          dataType,
          startDate: config.dateRange.startDate,
          endDate: config.dateRange.endDate,
        );

        switch (dataResult) {
          case Success(:final value):
            final data = value;
            totalRecordCount = data.length;

            final headers = _getHeadersForType(dataType, data);
            final csvContent = await Isolate.run(
              () => IsolateHelpers.generateCsvContent(
                data,
                headers,
                walletNames: dataType == DataType.transactions
                    ? walletNames
                    : null,
                categoryNames: dataType == DataType.transactions
                    ? categoryNames
                    : null,
              ),
            );

            final fileName = 'duasaku_${dataType.name}_$timestamp.csv';
            final filePath = p.join(tempDir.path, fileName);
            await File(filePath).writeAsString(csvContent);

            return Success(
              ExportResult(
                filePath: filePath,
                mimeType: 'text/csv',
                fileName: fileName,
                recordCount: totalRecordCount,
              ),
            );

          case Failure(:final error):
            return Failure(error);
        }
      } else {
        // Multiple types → produce a ZIP archive
        final archive = Archive();

        for (final dataType in selectedTypes) {
          final dataResult = await _fetchDataForType(
            dataType,
            startDate: config.dateRange.startDate,
            endDate: config.dateRange.endDate,
          );

          switch (dataResult) {
            case Success(:final value):
              final data = value;
              totalRecordCount += data.length;

              final headers = _getHeadersForType(dataType, data);
              final csvContent = await Isolate.run(
                () => IsolateHelpers.generateCsvContent(
                  data,
                  headers,
                  walletNames: dataType == DataType.transactions
                      ? walletNames
                      : null,
                  categoryNames: dataType == DataType.transactions
                      ? categoryNames
                      : null,
                ),
              );

              final csvFileName = 'duasaku_${dataType.name}_$timestamp.csv';
              final csvBytes = Uint8List.fromList(utf8.encode(csvContent));
              archive.addFile(
                ArchiveFile(csvFileName, csvBytes.length, csvBytes),
              );

            case Failure(:final error):
              return Failure(error);
          }
        }

        // Encode the archive as ZIP
        final zipBytes = ZipEncoder().encode(archive);

        if (zipBytes == null) {
          return Failure(AppError.unknown('Failed to encode ZIP archive'));
        }

        final zipFileName = 'duasaku_export_$timestamp.zip';
        final zipFilePath = p.join(tempDir.path, zipFileName);
        await File(zipFilePath).writeAsBytes(zipBytes);

        return Success(
          ExportResult(
            filePath: zipFilePath,
            mimeType: 'application/zip',
            fileName: zipFileName,
            recordCount: totalRecordCount,
          ),
        );
      }
    } catch (e, stack) {
      return Failure(
        AppError.unknown(
          'CSV export failed: ${e.toString()}',
          stackTrace: stack,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Excel Export
  // ---------------------------------------------------------------------------

  @override
  Future<Result<ExportResult, AppError>> exportExcel(
    ExportConfig config,
  ) async {
    try {
      final timestamp = _formatTimestamp(DateTime.now());
      final tempDir = await getTemporaryDirectory();

      // Get wallet and category name maps for resolving FKs
      final walletNamesResult = await _repository.getWalletNameMap(_userId);
      final categoryNamesResult = await _repository.getCategoryNameMap(_userId);

      final Map<String, String> walletNames;
      final Map<String, String> categoryNames;

      switch (walletNamesResult) {
        case Success(:final value):
          walletNames = value;
        case Failure(:final error):
          return Failure(error);
      }

      switch (categoryNamesResult) {
        case Success(:final value):
          categoryNames = value;
        case Failure(:final error):
          return Failure(error);
      }

      // Create Excel workbook
      final excel = Excel.createExcel();

      // Remove default sheet
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      int totalRecordCount = 0;

      // Add sheet per selected data type
      for (final dataType in config.selectedTypes) {
        final dataResult = await _fetchDataForType(
          dataType,
          startDate: config.dateRange.startDate,
          endDate: config.dateRange.endDate,
        );

        switch (dataResult) {
          case Success(:final value):
            final data = value;
            totalRecordCount += data.length;

            if (data.isEmpty) continue;

            final headers = _getHeadersForType(dataType, data);
            final sheetName = dataType.name;

            excel.copy('Sheet1', sheetName);
            final sheet = excel[sheetName];

            // Write headers
            for (var i = 0; i < headers.length; i++) {
              sheet
                  .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
                  .value = TextCellValue(
                headers[i],
              );
            }

            // Write data rows
            for (var rowIdx = 0; rowIdx < data.length; rowIdx++) {
              final row = data[rowIdx];
              for (var colIdx = 0; colIdx < headers.length; colIdx++) {
                final header = headers[colIdx];
                var cellValue = row[header];

                // Resolve FK references
                if (dataType == DataType.transactions) {
                  if (header == 'wallet_id' && cellValue != null) {
                    cellValue = walletNames[cellValue] ?? cellValue;
                  } else if (header == 'from_wallet_id' && cellValue != null) {
                    cellValue = walletNames[cellValue] ?? cellValue;
                  } else if (header == 'to_wallet_id' && cellValue != null) {
                    cellValue = walletNames[cellValue] ?? cellValue;
                  } else if (header == 'category_id' && cellValue != null) {
                    cellValue = categoryNames[cellValue] ?? cellValue;
                  }
                }

                final cell = sheet.cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: colIdx,
                    rowIndex: rowIdx + 1,
                  ),
                );

                if (cellValue == null) {
                  cell.value = TextCellValue('');
                } else if (cellValue is num) {
                  cell.value = DoubleCellValue(cellValue.toDouble());
                } else if (cellValue is bool) {
                  cell.value = BoolCellValue(cellValue);
                } else {
                  cell.value = TextCellValue(cellValue.toString());
                }
              }
            }

          case Failure(:final error):
            return Failure(error);
        }
      }

      // Save Excel file
      final fileName = 'duasaku_export_$timestamp.xlsx';
      final filePath = p.join(tempDir.path, fileName);
      final excelBytes = excel.encode();

      if (excelBytes == null) {
        return Failure(AppError.unknown('Failed to encode Excel file'));
      }

      await File(filePath).writeAsBytes(excelBytes);

      return Success(
        ExportResult(
          filePath: filePath,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          fileName: fileName,
          recordCount: totalRecordCount,
        ),
      );
    } catch (e, stack) {
      return Failure(
        AppError.unknown(
          'Excel export failed: ${e.toString()}',
          stackTrace: stack,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // JSON Backup Export
  // ---------------------------------------------------------------------------

  @override
  Future<Result<ExportResult, AppError>> exportJsonBackup() async {
    try {
      final timestamp = _formatTimestamp(DateTime.now());
      final tempDir = await getTemporaryDirectory();

      // Fetch all 11 tables
      final walletsResult = await _repository.getWalletsRaw(_userId);
      final categoriesResult = await _repository.getCategoriesRaw(_userId);
      final transactionsResult = await _repository.getTransactionsRaw(_userId);
      final budgetsResult = await _repository.getBudgetsRaw(_userId);
      final recurringTransactionsResult = await _repository
          .getRecurringTransactionsRaw(_userId);
      final recurringExecutionLogsResult = await _repository
          .getRecurringExecutionLogsRaw(_userId);
      final goalsResult = await _repository.getGoalsRaw(_userId);
      final goalDepositsResult = await _repository.getGoalDepositsRaw(_userId);
      final budgetAlertsResult = await _repository.getBudgetAlertsRaw(_userId);
      final budgetAlertPreferencesResult = await _repository
          .getBudgetAlertPreferencesRaw(_userId);
      final budgetAlertThresholdStatusResult = await _repository
          .getBudgetAlertThresholdStatusRaw(_userId);

      // Unwrap all results
      final wallets = _unwrapResult(walletsResult);
      final categories = _unwrapResult(categoriesResult);
      final transactions = _unwrapResult(transactionsResult);
      final budgets = _unwrapResult(budgetsResult);
      final recurringTransactions = _unwrapResult(recurringTransactionsResult);
      final recurringExecutionLogs = _unwrapResult(
        recurringExecutionLogsResult,
      );
      final goals = _unwrapResult(goalsResult);
      final goalDeposits = _unwrapResult(goalDepositsResult);
      final budgetAlerts = _unwrapResult(budgetAlertsResult);
      final budgetAlertPreferences = _unwrapResult(
        budgetAlertPreferencesResult,
      );
      final budgetAlertThresholdStatus = _unwrapResult(
        budgetAlertThresholdStatusResult,
      );

      // Check for any failures
      if (wallets == null ||
          categories == null ||
          transactions == null ||
          budgets == null ||
          recurringTransactions == null ||
          recurringExecutionLogs == null ||
          goals == null ||
          goalDeposits == null ||
          budgetAlerts == null ||
          budgetAlertPreferences == null ||
          budgetAlertThresholdStatus == null) {
        return Failure(
          AppError.unknown('Failed to fetch data from one or more tables'),
        );
      }

      // Build backup structure
      final metadata = BackupMetadata.now(
        appVersion: _appVersion,
        schemaVersion: _currentSchemaVersion,
        deviceId: _getDeviceId(),
      );

      final backupData = <String, dynamic>{
        'metadata': metadata.toJson(),
        'data': {
          'wallets': wallets,
          'categories': categories,
          'transactions': transactions,
          'budgets': budgets,
          'recurringTransactions': recurringTransactions,
          'recurringExecutionLogs': recurringExecutionLogs,
          'goals': goals,
          'goalDeposits': goalDeposits,
          'budgetAlerts': budgetAlerts,
          'budgetAlertPreferences': budgetAlertPreferences,
          'budgetAlertThresholdStatus': budgetAlertThresholdStatus,
        },
      };

      // Serialize in isolate
      final jsonString = await Isolate.run(
        () => IsolateHelpers.serializeBackupToJson(backupData),
      );

      // Write to temp file
      final fileName = 'duasaku_backup_$timestamp.json';
      final filePath = p.join(tempDir.path, fileName);
      await File(filePath).writeAsString(jsonString);

      final totalRecords =
          wallets.length +
          categories.length +
          transactions.length +
          budgets.length +
          recurringTransactions.length +
          recurringExecutionLogs.length +
          goals.length +
          goalDeposits.length +
          budgetAlerts.length +
          budgetAlertPreferences.length +
          budgetAlertThresholdStatus.length;

      return Success(
        ExportResult(
          filePath: filePath,
          mimeType: 'application/json',
          fileName: fileName,
          recordCount: totalRecords,
        ),
      );
    } catch (e, stack) {
      return Failure(
        AppError.unknown(
          'JSON backup export failed: ${e.toString()}',
          stackTrace: stack,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Share File
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void, AppError>> shareFile(
    String filePath,
    String mimeType,
  ) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(filePath, mimeType: mimeType)]),
      );
      return const Success(null);
    } catch (e, stack) {
      return Failure(
        AppError.unknown(
          'Failed to share file: ${e.toString()}',
          stackTrace: stack,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup Temp Files
  // ---------------------------------------------------------------------------

  @override
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);
      final now = DateTime.now();
      const maxAge = Duration(hours: 24);

      await for (final entity in dir.list()) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (fileName.startsWith('duasaku_')) {
            final stat = await entity.stat();
            final age = now.difference(stat.modified);
            if (age > maxAge) {
              await entity.delete();
            }
          }
        }
      }
    } catch (_) {
      // Cleanup is best-effort; silently ignore errors
    }
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  /// Formats a DateTime to the file naming pattern: YYYY-MM-DD_HHmmss
  String _formatTimestamp(DateTime dateTime) {
    final formatter = DateFormat('yyyy-MM-dd_HHmmss');
    return formatter.format(dateTime);
  }

  /// Returns a simple device identifier.
  String _getDeviceId() {
    // Use platform info as a simple device identifier
    return '${Platform.operatingSystem}_${Platform.localHostname}';
  }

  /// Fetches raw data for a given [DataType] from the repository.
  Future<Result<List<Map<String, dynamic>>, AppError>> _fetchDataForType(
    DataType dataType, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    switch (dataType) {
      case DataType.transactions:
        return _repository.getTransactionsRaw(
          _userId,
          startDate: startDate,
          endDate: endDate,
        );
      case DataType.wallets:
        return _repository.getWalletsRaw(_userId);
      case DataType.categories:
        return _repository.getCategoriesRaw(_userId);
      case DataType.budgets:
        return _repository.getBudgetsRaw(
          _userId,
          startDate: startDate,
          endDate: endDate,
        );
      case DataType.recurringTransactions:
        return _repository.getRecurringTransactionsRaw(
          _userId,
          startDate: startDate,
          endDate: endDate,
        );
      case DataType.goals:
        return _repository.getGoalsRaw(
          _userId,
          startDate: startDate,
          endDate: endDate,
        );
      case DataType.goalDeposits:
        return _repository.getGoalDepositsRaw(
          _userId,
          startDate: startDate,
          endDate: endDate,
        );
      case DataType.budgetAlerts:
        return _repository.getBudgetAlertsRaw(
          _userId,
          startDate: startDate,
          endDate: endDate,
        );
    }
  }

  /// Extracts headers from the first record of data, or returns an empty list.
  List<String> _getHeadersForType(
    DataType dataType,
    List<Map<String, dynamic>> data,
  ) {
    if (data.isEmpty) return [];
    return data.first.keys.toList();
  }

  /// Unwraps a Result, returning the value on success or null on failure.
  List<Map<String, dynamic>>? _unwrapResult(
    Result<List<Map<String, dynamic>>, AppError> result,
  ) {
    switch (result) {
      case Success(:final value):
        return value;
      case Failure():
        return null;
    }
  }
}
