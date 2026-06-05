import 'package:duasaku_app/features/export_import/domain/models/backup_metadata.dart';

/// Summary preview of a backup file before the user confirms restore.
class ImportPreview {
  /// Metadata from the backup file header.
  final BackupMetadata metadata;

  /// Number of wallet records in the backup.
  final int walletCount;

  /// Number of category records in the backup.
  final int categoryCount;

  /// Number of transaction records in the backup.
  final int transactionCount;

  /// Number of budget records in the backup.
  final int budgetCount;

  /// Number of goal records in the backup.
  final int goalCount;

  /// Number of recurring transaction records in the backup.
  final int recurringTransactionCount;

  /// Number of budget alert records in the backup.
  final int budgetAlertCount;

  /// Size of the backup file in bytes.
  final int fileSizeBytes;

  const ImportPreview({
    required this.metadata,
    required this.walletCount,
    required this.categoryCount,
    required this.transactionCount,
    required this.budgetCount,
    required this.goalCount,
    required this.recurringTransactionCount,
    required this.budgetAlertCount,
    required this.fileSizeBytes,
  });
}
