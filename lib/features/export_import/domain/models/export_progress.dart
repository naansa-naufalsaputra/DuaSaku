/// Represents the progress state during an export operation.
class ExportProgress {
  /// Progress percentage from 0.0 to 1.0.
  final double percentage;

  /// Name of the table currently being processed.
  final String currentTable;

  /// Estimated time remaining for the export to complete.
  final Duration? estimatedRemaining;

  const ExportProgress({
    required this.percentage,
    required this.currentTable,
    this.estimatedRemaining,
  });
}
