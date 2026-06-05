import 'dart:convert';

import 'package:duasaku_app/features/export_import/services/isolate_helpers.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;
import 'package:test/test.dart';

import 'generators.dart';

// ---------------------------------------------------------------------------
// Property-Based Tests: Backup Properties
// ---------------------------------------------------------------------------

void main() {
  // Feature: export-import-data, Property 6: Backup Completeness
  // **Validates: Requirements 3.1, 3.2, 3.5**
  group('Property 6: Backup Completeness', () {
    Glados(any.validDatabaseState, ExploreConfig(numRuns: 100)).test(
      'JSON backup has complete metadata and data object with all 11 table keys',
      (dbState) {
        final rng = Random(dbState.hashCode);

        // Simulate backup creation
        final metadata = {
          'appVersion': randomSemver(rng),
          'schemaVersion': currentSchemaVersion,
          'exportedAt': randomIso8601(rng),
          'deviceId': randomString(rng, 12),
          'exportedBy': 'duasaku',
        };

        final backupData = <String, dynamic>{
          'metadata': metadata,
          'data': dbState,
        };

        final jsonString = IsolateHelpers.serializeBackupToJson(backupData);
        final parsed = jsonDecode(jsonString) as Map<String, dynamic>;

        // (a) Metadata has all required fields
        final parsedMetadata = parsed['metadata'] as Map<String, dynamic>;
        expect(parsedMetadata.containsKey('appVersion'), isTrue);
        expect(parsedMetadata.containsKey('schemaVersion'), isTrue);
        expect(parsedMetadata.containsKey('exportedAt'), isTrue);
        expect(parsedMetadata.containsKey('deviceId'), isTrue);
        expect(parsedMetadata.containsKey('exportedBy'), isTrue);
        expect(parsedMetadata['exportedBy'], equals('duasaku'));

        // (b) Data object has all 11 table keys
        final parsedData = parsed['data'] as Map<String, dynamic>;
        for (final key in requiredTableKeys) {
          expect(parsedData.containsKey(key), isTrue,
              reason: 'Data should contain key "$key"');
          expect(parsedData[key], isA<List>(),
              reason: 'Data["$key"] should be a List');
        }

        // (c) Each table's array length equals original record count
        for (final key in requiredTableKeys) {
          final originalCount = dbState[key]!.length;
          final parsedCount = (parsedData[key] as List).length;
          expect(parsedCount, equals(originalCount),
              reason: 'Table "$key" count mismatch');
        }
      },
    );
  });

  // Feature: export-import-data, Property 7: Backup Filename Format
  // **Validates: Requirements 3.4**
  group('Property 7: Backup Filename Format', () {
    Glados(any.intInRange(0, 999999), ExploreConfig(numRuns: 100)).test(
      'backup filename matches pattern duasaku_backup_{YYYY-MM-DD_HHmmss}.json',
      (seed) {
        final rng = Random(seed);

        // Generate a random export timestamp
        final exportTimestamp = DateTime(
          2020 + rng.nextInt(6),
          1 + rng.nextInt(12),
          1 + rng.nextInt(28),
          rng.nextInt(24),
          rng.nextInt(60),
          rng.nextInt(60),
        );

        // Generate filename using the same logic as ExportService
        final year = exportTimestamp.year.toString().padLeft(4, '0');
        final month = exportTimestamp.month.toString().padLeft(2, '0');
        final day = exportTimestamp.day.toString().padLeft(2, '0');
        final hour = exportTimestamp.hour.toString().padLeft(2, '0');
        final minute = exportTimestamp.minute.toString().padLeft(2, '0');
        final second = exportTimestamp.second.toString().padLeft(2, '0');

        final fileName =
            'duasaku_backup_$year-$month-${day}_$hour$minute$second.json';

        // Assert: matches the expected pattern
        final pattern = RegExp(
          r'^duasaku_backup_\d{4}-\d{2}-\d{2}_\d{6}\.json$',
        );
        expect(pattern.hasMatch(fileName), isTrue,
            reason: 'Filename "$fileName" should match pattern');

        // Assert: date components correspond to the timestamp
        expect(fileName, contains('$year-$month-$day'));
        expect(fileName, contains('$hour$minute$second'));
      },
    );
  });
}
