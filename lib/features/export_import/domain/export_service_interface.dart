import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/export_import/domain/models/export_config.dart';
import 'package:duasaku_app/features/export_import/domain/models/export_result.dart';

/// Abstract interface for export operations.
///
/// Handles CSV export, Excel export, JSON backup export, file sharing via native share sheet,
/// and cleanup of temporary export files.
abstract class ExportServiceInterface {
  /// Exports selected data types as CSV files.
  ///
  /// Returns path to the generated file (single CSV or ZIP archive
  /// when multiple types are selected).
  Future<Result<ExportResult, AppError>> exportCsv(ExportConfig config);

  /// Exports selected data types as Excel (.xlsx) file.
  ///
  /// Returns path to the generated Excel file with sheets per data type.
  Future<Result<ExportResult, AppError>> exportExcel(ExportConfig config);

  /// Exports full database backup as JSON.
  ///
  /// Returns path to the generated JSON backup file containing all
  /// 11 tables and metadata.
  Future<Result<ExportResult, AppError>> exportJsonBackup();

  /// Opens native share sheet with the exported file.
  ///
  /// [filePath] is the path to the file to share.
  /// [mimeType] is the MIME type (text/csv, application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/zip, application/json).
  Future<Result<void, AppError>> shareFile(String filePath, String mimeType);

  /// Cleans up temporary export files older than 24 hours.
  Future<void> cleanupTempFiles();
}
