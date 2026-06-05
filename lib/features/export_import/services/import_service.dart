import 'dart:io';
import 'dart:isolate';

import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/export_import/domain/export_import_repository_interface.dart';
import 'package:duasaku_app/features/export_import/domain/import_service_interface.dart';
import 'package:duasaku_app/features/export_import/domain/models/backup_metadata.dart';
import 'package:duasaku_app/features/export_import/domain/models/import_preview.dart';
import 'package:duasaku_app/features/export_import/domain/models/import_progress.dart';
import 'package:duasaku_app/features/export_import/services/isolate_helpers.dart';

/// Concrete implementation of [ImportServiceInterface].
///
/// Handles backup file validation, preview generation, and full
/// destructive restore from a JSON backup file.
class ImportService implements ImportServiceInterface {
  final ExportImportRepositoryInterface _repository;
  final int currentSchemaVersion;

  ImportService(this._repository, {required this.currentSchemaVersion});

  /// Maximum allowed file size in bytes (50 MB).
  static const int _maxFileSizeBytes = 50 * 1024 * 1024;

  /// Table names in FK-respecting insertion order.
  static const List<String> _tableInsertionOrder = [
    'wallets',
    'categories',
    'transactions',
    'budgets',
    'recurringTransactions',
    'recurringExecutionLogs',
    'goals',
    'goalDeposits',
    'budgetAlerts',
    'budgetAlertPreferences',
    'budgetAlertThresholdStatus',
  ];

  @override
  Future<Result<ImportPreview, AppError>> previewBackup(String filePath) async {
    // 1. Check file extension
    if (!filePath.toLowerCase().endsWith('.json')) {
      return Failure(AppError.validation('export_import.error.not_json_file'));
    }

    // 2. Read file and check size
    final file = File(filePath);
    final fileSizeBytes = await file.length();

    if (fileSizeBytes > _maxFileSizeBytes) {
      return Failure(AppError.validation('export_import.error.file_too_large'));
    }

    final content = await file.readAsString();

    // 3. Parse and validate in isolate
    try {
      final schemaVersion = currentSchemaVersion;
      final parsed = await Isolate.run(
        () => IsolateHelpers.parseAndValidateBackupJson(content, schemaVersion),
      );

      // 4. Build ImportPreview from parsed data
      final metadata = BackupMetadata.fromJson(
        parsed['metadata'] as Map<String, dynamic>,
      );
      final data = parsed['data'] as Map<String, dynamic>;

      return Success(
        ImportPreview(
          metadata: metadata,
          walletCount: (data['wallets'] as List).length,
          categoryCount: (data['categories'] as List).length,
          transactionCount: (data['transactions'] as List).length,
          budgetCount: (data['budgets'] as List).length,
          goalCount: (data['goals'] as List).length,
          recurringTransactionCount:
              (data['recurringTransactions'] as List).length,
          budgetAlertCount: (data['budgetAlerts'] as List).length,
          fileSizeBytes: fileSizeBytes,
        ),
      );
    } on FormatException catch (e) {
      return Failure(_mapFormatExceptionToAppError(e));
    }
  }

  @override
  Future<Result<void, AppError>> restoreBackup(
    String filePath, {
    required void Function(ImportProgress) onProgress,
  }) async {
    // 1. Read and parse file (re-validate)
    final file = File(filePath);
    final content = await file.readAsString();

    final Map<String, dynamic> parsed;
    try {
      final schemaVersion = currentSchemaVersion;
      parsed = await Isolate.run(
        () => IsolateHelpers.parseAndValidateBackupJson(content, schemaVersion),
      );
    } on FormatException catch (e) {
      return Failure(_mapFormatExceptionToAppError(e));
    }

    // 2. Extract data map
    final data = parsed['data'] as Map<String, dynamic>;

    // 3. Report progress per table
    final totalTables = _tableInsertionOrder.length;
    for (var i = 0; i < totalTables; i++) {
      final tableName = _tableInsertionOrder[i];
      onProgress(
        ImportProgress(
          percentage: (i + 1) / totalTables,
          currentTable: tableName,
        ),
      );
    }

    // 4. Build typed data map for repository
    final typedData = <String, List<Map<String, dynamic>>>{};
    for (final key in _tableInsertionOrder) {
      final tableData = data[key] as List;
      typedData[key] = tableData.cast<Map<String, dynamic>>();
    }

    // 5. Call repository to restore
    final result = await _repository.restoreFullBackup(typedData);

    return result;
  }

  /// Maps a [FormatException] from the isolate validation to an [AppError].
  AppError _mapFormatExceptionToAppError(FormatException e) {
    final message = e.message.toLowerCase();

    if (message.contains('rusak') || message.contains('malformed')) {
      return AppError.validation('export_import.error.malformed_json');
    }

    if (message.contains('bukan backup') || message.contains('exportedby')) {
      return AppError.validation('export_import.error.not_duasaku_backup');
    }

    if (message.contains('update')) {
      return AppError.validation('export_import.error.update_app_required');
    }

    if (message.contains('lebih lama')) {
      return AppError.validation('export_import.error.backup_too_old');
    }

    if (message.contains('tidak konsisten')) {
      return AppError.validation('export_import.error.data_inconsistent');
    }

    if (message.contains('tidak memiliki field') ||
        message.contains('missing')) {
      return AppError.validation('export_import.error.missing_fields');
    }

    // Fallback for unmapped FormatException messages
    return AppError.validation(e.message);
  }
}
