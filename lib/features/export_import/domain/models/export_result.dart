/// Result of a completed export operation.
class ExportResult {
  /// Path to the generated export file.
  final String filePath;

  /// MIME type of the export file (text/csv, application/zip, application/json).
  final String mimeType;

  /// Display name of the export file.
  final String fileName;

  /// Total number of records exported.
  final int recordCount;

  const ExportResult({
    required this.filePath,
    required this.mimeType,
    required this.fileName,
    required this.recordCount,
  });
}
