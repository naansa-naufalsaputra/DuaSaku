/// Represents the progress state during an import/restore operation.
class ImportProgress {
  /// Progress percentage from 0.0 to 1.0.
  final double percentage;

  /// Name of the table currently being processed.
  final String currentTable;

  /// Estimated time remaining for the import to complete.
  final Duration? estimatedRemaining;

  const ImportProgress({
    required this.percentage,
    required this.currentTable,
    this.estimatedRemaining,
  });
}
