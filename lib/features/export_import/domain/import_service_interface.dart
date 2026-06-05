import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/export_import/domain/models/import_preview.dart';
import 'package:duasaku_app/features/export_import/domain/models/import_progress.dart';

/// Abstract interface for import/restore operations.
///
/// Handles backup file validation, preview, and full destructive restore
/// from a JSON backup file.
abstract class ImportServiceInterface {
  /// Validates and previews a backup file without importing.
  ///
  /// Returns a summary of data counts for user confirmation before
  /// proceeding with the destructive restore operation.
  Future<Result<ImportPreview, AppError>> previewBackup(String filePath);

  /// Executes full restore from a validated backup file.
  ///
  /// This is a destructive operation that replaces all existing data
  /// in the database with the backup contents.
  ///
  /// [filePath] is the path to the validated JSON backup file.
  /// [onProgress] callback reports progress per table being restored.
  Future<Result<void, AppError>> restoreBackup(
    String filePath, {
    required void Function(ImportProgress) onProgress,
  });
}
