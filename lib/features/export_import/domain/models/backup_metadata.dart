/// Model representing metadata for a DuaSaku JSON backup file.
///
/// Contains version information, timestamp, and device identifier
/// to validate backup files during import.
class BackupMetadata {
  final String appVersion;
  final int schemaVersion;
  final String exportedAt; // ISO 8601
  final String deviceId;
  final String exportedBy; // Always "duasaku"

  const BackupMetadata({
    required this.appVersion,
    required this.schemaVersion,
    required this.exportedAt,
    required this.deviceId,
    this.exportedBy = 'duasaku',
  });

  /// Creates a [BackupMetadata] with the current UTC timestamp
  /// and `exportedBy` set to `'duasaku'`.
  ///
  /// Requires [appVersion], [schemaVersion], and [deviceId].
  factory BackupMetadata.now({
    required String appVersion,
    required int schemaVersion,
    required String deviceId,
  }) {
    return BackupMetadata(
      appVersion: appVersion,
      schemaVersion: schemaVersion,
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      deviceId: deviceId,
      exportedBy: 'duasaku',
    );
  }

  /// Deserializes a [BackupMetadata] from a JSON map.
  ///
  /// Throws [FormatException] if:
  /// - Any required field is missing
  /// - `exportedBy` is not `'duasaku'`
  /// - `exportedAt` is not a valid ISO 8601 string
  /// - `schemaVersion` is not a positive integer
  factory BackupMetadata.fromJson(Map<String, dynamic> json) {
    // Validate all required fields are present
    const requiredFields = [
      'appVersion',
      'schemaVersion',
      'exportedAt',
      'deviceId',
      'exportedBy',
    ];

    for (final field in requiredFields) {
      if (!json.containsKey(field) || json[field] == null) {
        throw FormatException('Missing required field: $field');
      }
    }

    // Validate exportedBy
    final exportedBy = json['exportedBy'];
    if (exportedBy is! String || exportedBy != 'duasaku') {
      throw const FormatException('Invalid exportedBy: must be "duasaku"');
    }

    // Validate exportedAt is valid ISO 8601
    final exportedAt = json['exportedAt'];
    if (exportedAt is! String) {
      throw const FormatException('Invalid exportedAt: must be a string');
    }
    final parsedDate = DateTime.tryParse(exportedAt);
    if (parsedDate == null) {
      throw FormatException(
        'Invalid exportedAt: "$exportedAt" is not a valid ISO 8601 format',
      );
    }

    // Validate schemaVersion is a positive integer
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion is! int || schemaVersion <= 0) {
      throw FormatException(
        'Invalid schemaVersion: must be a positive integer, got $schemaVersion',
      );
    }

    // Validate appVersion is a string
    final appVersion = json['appVersion'];
    if (appVersion is! String) {
      throw const FormatException('Invalid appVersion: must be a string');
    }

    // Validate deviceId is a string
    final deviceId = json['deviceId'];
    if (deviceId is! String) {
      throw const FormatException('Invalid deviceId: must be a string');
    }

    return BackupMetadata(
      appVersion: appVersion,
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      deviceId: deviceId,
      exportedBy: exportedBy,
    );
  }

  /// Serializes this [BackupMetadata] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'appVersion': appVersion,
      'schemaVersion': schemaVersion,
      'exportedAt': exportedAt,
      'deviceId': deviceId,
      'exportedBy': exportedBy,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BackupMetadata &&
        other.appVersion == appVersion &&
        other.schemaVersion == schemaVersion &&
        other.exportedAt == exportedAt &&
        other.deviceId == deviceId &&
        other.exportedBy == exportedBy;
  }

  @override
  int get hashCode {
    return Object.hash(
      appVersion,
      schemaVersion,
      exportedAt,
      deviceId,
      exportedBy,
    );
  }

  @override
  String toString() {
    return 'BackupMetadata('
        'appVersion: $appVersion, '
        'schemaVersion: $schemaVersion, '
        'exportedAt: $exportedAt, '
        'deviceId: $deviceId, '
        'exportedBy: $exportedBy)';
  }
}
