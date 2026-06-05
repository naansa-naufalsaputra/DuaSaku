
import 'package:duasaku_app/features/export_import/domain/models/backup_metadata.dart';
import 'package:duasaku_app/features/export_import/services/isolate_helpers.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;
import 'package:test/test.dart';

import 'generators.dart';

// ---------------------------------------------------------------------------
// Property-Based Tests: Round-Trip Properties
// ---------------------------------------------------------------------------

void main() {
  // Feature: export-import-data, Property 1: Full Database Round-Trip
  // **Validates: Requirements 8.1, 3.3, 4.5, 8.3, 8.5**
  group('Property 1: Full Database Round-Trip', () {
    Glados(any.validDatabaseState, ExploreConfig(numRuns: 100)).test(
      'export to JSON then parse back produces equivalent database state',
      (dbState) {
        // Arrange: create backup with valid metadata
        final metadata = BackupMetadata(
          appVersion: '1.0.0',
          schemaVersion: currentSchemaVersion,
          exportedAt: DateTime.now().toUtc().toIso8601String(),
          deviceId: 'test-device',
          exportedBy: 'duasaku',
        );

        // Act: serialize to JSON (simulating export)
        final backupData = <String, dynamic>{
          'metadata': metadata.toJson(),
          'data': dbState,
        };
        final jsonString = IsolateHelpers.serializeBackupToJson(backupData);

        // Act: parse and validate (simulating import)
        final parsed = IsolateHelpers.parseAndValidateBackupJson(
          jsonString,
          currentSchemaVersion,
        );

        // Assert: data section matches original state
        final restoredData = parsed['data'] as Map<String, dynamic>;

        for (final tableKey in requiredTableKeys) {
          final originalRecords = dbState[tableKey]!;
          final restoredRecords = restoredData[tableKey] as List;

          expect(
            restoredRecords.length,
            equals(originalRecords.length),
            reason: 'Table "$tableKey" record count mismatch',
          );

          for (var i = 0; i < originalRecords.length; i++) {
            final originalRecord = originalRecords[i];
            final restoredRecord = restoredRecords[i] as Map<String, dynamic>;

            for (final key in originalRecord.keys) {
              // JSON round-trip may convert types, compare as strings
              expect(
                restoredRecord[key]?.toString(),
                equals(originalRecord[key]?.toString()),
                reason:
                    'Table "$tableKey", record #$i, field "$key" mismatch',
              );
            }
          }
        }
      },
    );
  });

  // Feature: export-import-data, Property 2: BackupMetadata Serialization Round-Trip
  // **Validates: Requirements 8.4**
  group('Property 2: BackupMetadata Serialization Round-Trip', () {
    Glados(any.validBackupMetadata, ExploreConfig(numRuns: 100)).test(
      'toJson() then fromJson() produces identical BackupMetadata object',
      (original) {
        // Act: serialize then deserialize
        final json = original.toJson();
        final restored = BackupMetadata.fromJson(json);

        // Assert: all fields match
        expect(restored.appVersion, equals(original.appVersion));
        expect(restored.schemaVersion, equals(original.schemaVersion));
        expect(restored.exportedAt, equals(original.exportedAt));
        expect(restored.deviceId, equals(original.deviceId));
        expect(restored.exportedBy, equals(original.exportedBy));

        // Full equality
        expect(restored, equals(original));
      },
    );
  });
}
