import 'dart:convert';

/// Pure Dart helper functions for export/import serialization.
///
/// All functions are static and free of Flutter, Drift, or Riverpod imports
/// so they can safely run inside `Isolate.run`.
class IsolateHelpers {
  IsolateHelpers._();

  /// Required table keys in a valid DuaSaku backup.
  static const List<String> requiredTableKeys = [
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

  /// Required metadata fields.
  static const List<String> requiredMetadataFields = [
    'appVersion',
    'schemaVersion',
    'exportedAt',
    'deviceId',
    'exportedBy',
  ];

  // ---------------------------------------------------------------------------
  // CSV Generation
  // ---------------------------------------------------------------------------

  /// Generates CSV content from [data] using the given [headers] for column order.
  ///
  /// The returned string starts with a UTF-8 BOM character (`\uFEFF`), followed
  /// by a header row and data rows. Values are quoted per RFC 4180 when they
  /// contain commas, double-quotes, or newlines.
  ///
  /// For Transaction data, if [walletNames] is provided a "walletName" column is
  /// appended (resolved from each record's "walletId"). Similarly for
  /// [categoryNames] → "categoryName" resolved from "categoryId".
  static String generateCsvContent(
    List<Map<String, dynamic>> data,
    List<String> headers, {
    Map<String, String>? walletNames,
    Map<String, String>? categoryNames,
  }) {
    final buffer = StringBuffer();

    // UTF-8 BOM prefix
    buffer.write('\uFEFF');

    // Build effective headers list (original + resolved name columns)
    final effectiveHeaders = List<String>.from(headers);
    if (walletNames != null) {
      effectiveHeaders.add('walletName');
    }
    if (categoryNames != null) {
      effectiveHeaders.add('categoryName');
    }

    // Header row
    buffer.writeln(effectiveHeaders.map(_escapeCsvValue).join(','));

    // Data rows
    for (final row in data) {
      final values = <String>[];
      for (final header in headers) {
        final value = row[header];
        values.add(_escapeCsvValue(value?.toString() ?? ''));
      }

      // Append resolved wallet name
      if (walletNames != null) {
        final walletId = row['walletId']?.toString() ?? '';
        values.add(_escapeCsvValue(walletNames[walletId] ?? ''));
      }

      // Append resolved category name
      if (categoryNames != null) {
        final categoryId = row['categoryId']?.toString() ?? '';
        values.add(_escapeCsvValue(categoryNames[categoryId] ?? ''));
      }

      buffer.writeln(values.join(','));
    }

    return buffer.toString();
  }

  /// Escapes a CSV value per RFC 4180.
  ///
  /// If the value contains a comma, double-quote, or newline, it is wrapped
  /// in double-quotes with internal double-quotes escaped by doubling them.
  static String _escapeCsvValue(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      final escaped = value.replaceAll('"', '""');
      return '"$escaped"';
    }
    return value;
  }

  // ---------------------------------------------------------------------------
  // JSON Serialization
  // ---------------------------------------------------------------------------

  /// Serializes [backupData] to a pretty-printed JSON string.
  ///
  /// Uses two-space indentation for readability.
  static String serializeBackupToJson(Map<String, dynamic> backupData) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(backupData);
  }

  // ---------------------------------------------------------------------------
  // JSON Parsing & Validation
  // ---------------------------------------------------------------------------

  /// Parses and validates a DuaSaku backup JSON string.
  ///
  /// Throws [FormatException] with a descriptive message when:
  /// - The JSON is malformed
  /// - The `metadata` field is missing or incomplete
  /// - `exportedBy` is not `'duasaku'`
  /// - `schemaVersion` does not match [currentSchemaVersion]
  /// - The `data` field is missing required table keys
  /// - Foreign key references are broken
  /// - Required fields (at minimum `id`) are missing from records
  ///
  /// Returns the parsed `Map<String, dynamic>` on success.
  static Map<String, dynamic> parseAndValidateBackupJson(
    String jsonString,
    int currentSchemaVersion,
  ) {
    // 1. Parse JSON
    final dynamic parsed;
    try {
      parsed = jsonDecode(jsonString);
    } on FormatException {
      throw const FormatException(
        'File backup rusak atau tidak valid. Pastikan file tidak dimodifikasi secara manual.',
      );
    }

    if (parsed is! Map<String, dynamic>) {
      throw const FormatException(
        'File backup rusak atau tidak valid. Pastikan file tidak dimodifikasi secara manual.',
      );
    }

    // 2. Validate metadata exists
    if (!parsed.containsKey('metadata') ||
        parsed['metadata'] is! Map<String, dynamic>) {
      throw const FormatException(
        'File backup tidak memiliki metadata. Hanya file backup DuaSaku yang didukung.',
      );
    }

    final metadata = parsed['metadata'] as Map<String, dynamic>;

    // 3. Validate required metadata fields
    for (final field in requiredMetadataFields) {
      if (!metadata.containsKey(field) || metadata[field] == null) {
        throw FormatException(
          'Metadata tidak lengkap: field "$field" tidak ditemukan.',
        );
      }
    }

    // 4. Validate exportedBy
    if (metadata['exportedBy'] != 'duasaku') {
      throw const FormatException(
        'File ini bukan backup DuaSaku. Hanya file backup DuaSaku yang didukung.',
      );
    }

    // 5. Validate schemaVersion
    final backupSchema = metadata['schemaVersion'];
    if (backupSchema is! int) {
      throw const FormatException(
        'Schema version tidak valid dalam metadata backup.',
      );
    }

    if (backupSchema > currentSchemaVersion) {
      throw const FormatException(
        'File backup dibuat dengan versi DuaSaku yang lebih baru. '
        'Silakan update aplikasi DuaSaku Anda terlebih dahulu.',
      );
    }

    if (backupSchema < currentSchemaVersion) {
      throw const FormatException(
        'File backup ini dibuat dengan versi DuaSaku yang lebih lama '
        'dan tidak kompatibel dengan versi saat ini.',
      );
    }

    // 6. Validate data field exists with all required table keys
    if (!parsed.containsKey('data') ||
        parsed['data'] is! Map<String, dynamic>) {
      throw const FormatException('File backup tidak memiliki field "data".');
    }

    final data = parsed['data'] as Map<String, dynamic>;

    for (final key in requiredTableKeys) {
      if (!data.containsKey(key)) {
        throw FormatException(
          'Data backup tidak lengkap: tabel "$key" tidak ditemukan.',
        );
      }
      if (data[key] is! List) {
        throw FormatException(
          'Data backup tidak valid: tabel "$key" harus berupa array.',
        );
      }
    }

    // 7. Validate required fields (at minimum: id must exist in every record)
    _validateRequiredFields(data);

    // 8. Validate FK consistency
    _validateForeignKeys(data);

    return parsed;
  }

  /// Validates that every record in each table has at least an `id` field.
  static void _validateRequiredFields(Map<String, dynamic> data) {
    for (final tableName in requiredTableKeys) {
      final records = data[tableName] as List;
      for (var i = 0; i < records.length; i++) {
        final record = records[i];
        if (record is! Map<String, dynamic>) {
          throw FormatException(
            'Record #${i + 1} di tabel "$tableName" bukan objek yang valid.',
          );
        }
        if (!record.containsKey('id') || record['id'] == null) {
          throw FormatException(
            'Record #${i + 1} di tabel "$tableName" tidak memiliki field "id".',
          );
        }
      }
    }
  }

  /// Validates foreign key consistency across tables.
  ///
  /// Rules:
  /// - transactions: walletId → wallets, categoryId → categories
  /// - budgets: categoryId → categories
  /// - recurringTransactions: walletId → wallets, categoryId → categories
  /// - recurringExecutionLogs: recurringTransactionId → recurringTransactions
  /// - goals: walletId → wallets
  /// - goalDeposits: goalId → goals
  static void _validateForeignKeys(Map<String, dynamic> data) {
    // Build ID sets for parent tables
    final walletIds = _extractIds(data['wallets'] as List);
    final categoryIds = _extractIds(data['categories'] as List);
    final recurringTransactionIds = _extractIds(
      data['recurringTransactions'] as List,
    );
    final goalIds = _extractIds(data['goals'] as List);

    // Validate transactions → wallets, categories
    _validateFkReferences(
      records: data['transactions'] as List,
      tableName: 'transactions',
      fkField: 'walletId',
      parentIds: walletIds,
      parentTable: 'wallets',
    );
    _validateFkReferences(
      records: data['transactions'] as List,
      tableName: 'transactions',
      fkField: 'categoryId',
      parentIds: categoryIds,
      parentTable: 'categories',
    );

    // Validate budgets → categories
    _validateFkReferences(
      records: data['budgets'] as List,
      tableName: 'budgets',
      fkField: 'categoryId',
      parentIds: categoryIds,
      parentTable: 'categories',
    );

    // Validate recurringTransactions → wallets, categories
    _validateFkReferences(
      records: data['recurringTransactions'] as List,
      tableName: 'recurringTransactions',
      fkField: 'walletId',
      parentIds: walletIds,
      parentTable: 'wallets',
    );
    _validateFkReferences(
      records: data['recurringTransactions'] as List,
      tableName: 'recurringTransactions',
      fkField: 'categoryId',
      parentIds: categoryIds,
      parentTable: 'categories',
    );

    // Validate recurringExecutionLogs → recurringTransactions
    _validateFkReferences(
      records: data['recurringExecutionLogs'] as List,
      tableName: 'recurringExecutionLogs',
      fkField: 'recurringTransactionId',
      parentIds: recurringTransactionIds,
      parentTable: 'recurringTransactions',
    );

    // Validate goals → wallets
    _validateFkReferences(
      records: data['goals'] as List,
      tableName: 'goals',
      fkField: 'walletId',
      parentIds: walletIds,
      parentTable: 'wallets',
    );

    // Validate goalDeposits → goals
    _validateFkReferences(
      records: data['goalDeposits'] as List,
      tableName: 'goalDeposits',
      fkField: 'goalId',
      parentIds: goalIds,
      parentTable: 'goals',
    );
  }

  /// Extracts a set of ID values (as strings) from a list of records.
  static Set<String> _extractIds(List records) {
    final ids = <String>{};
    for (final record in records) {
      if (record is Map<String, dynamic> && record.containsKey('id')) {
        ids.add(record['id'].toString());
      }
    }
    return ids;
  }

  /// Validates that all [fkField] values in [records] exist in [parentIds].
  ///
  /// Throws [FormatException] if a broken reference is found.
  static void _validateFkReferences({
    required List records,
    required String tableName,
    required String fkField,
    required Set<String> parentIds,
    required String parentTable,
  }) {
    for (var i = 0; i < records.length; i++) {
      final record = records[i];
      if (record is! Map<String, dynamic>) continue;

      // Skip if FK field is not present (nullable FK)
      if (!record.containsKey(fkField) || record[fkField] == null) continue;

      final fkValue = record[fkField].toString();
      if (!parentIds.contains(fkValue)) {
        throw FormatException(
          'Data tidak konsisten: record #${i + 1} di tabel "$tableName" '
          'mereferensi $fkField "$fkValue" yang tidak ada di tabel "$parentTable".',
        );
      }
    }
  }
}
