import 'dart:convert';

import 'package:duasaku_app/features/export_import/services/isolate_helpers.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;
import 'package:test/test.dart';

import 'generators.dart';

// ---------------------------------------------------------------------------
// Property-Based Tests: Validation Properties
// ---------------------------------------------------------------------------

void main() {
  // Feature: export-import-data, Property 8: Metadata Validation Rejects Invalid Files
  // **Validates: Requirements 4.1, 4.2**
  group('Property 8: Metadata Validation Rejects Invalid Files', () {
    Glados(any.malformedBackupJson, ExploreConfig(numRuns: 100)).test(
      'file without metadata or with exportedBy != duasaku is rejected',
      (malformedJson) {
        expect(
          () => IsolateHelpers.parseAndValidateBackupJson(
            malformedJson,
            currentSchemaVersion,
          ),
          throwsA(isA<FormatException>()),
          reason: 'Malformed backup should be rejected with FormatException',
        );
      },
    );
  });

  // Feature: export-import-data, Property 9: Schema Version Strict Match
  // **Validates: Requirements 4.7**
  group('Property 9: Schema Version Strict Match', () {
    Glados(any.intInRange(0, 999999), ExploreConfig(numRuns: 100)).test(
      'different schemaVersion causes import rejection with appropriate message',
      (seed) {
        final rng = Random(seed);

        // Build a valid backup base
        final dbState = _buildMinimalValidState(rng);
        final metadata = {
          'appVersion': randomSemver(rng),
          'schemaVersion': currentSchemaVersion,
          'exportedAt': randomIso8601(rng),
          'deviceId': randomString(rng, 10),
          'exportedBy': 'duasaku',
        };

        // Generate a schema version that differs from current
        int differentSchema;
        if (rng.nextBool()) {
          // Higher than current (user needs to update app)
          differentSchema = currentSchemaVersion + 1 + rng.nextInt(10);
        } else {
          // Lower than current (backup too old)
          differentSchema = 1 + rng.nextInt(currentSchemaVersion - 1);
          if (differentSchema >= currentSchemaVersion) {
            differentSchema = currentSchemaVersion - 1;
          }
        }
        metadata['schemaVersion'] = differentSchema;

        final backup = {'metadata': metadata, 'data': dbState};
        final jsonString = jsonEncode(backup);

        expect(
          () => IsolateHelpers.parseAndValidateBackupJson(
            jsonString,
            currentSchemaVersion,
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              anyOf(
                contains('update'),
                contains('lebih lama'),
                contains('lebih baru'),
              ),
            ),
          ),
          reason:
              'Schema version $differentSchema != $currentSchemaVersion should be rejected',
        );
      },
    );
  });

  // Feature: export-import-data, Property 10: Foreign Key Consistency Validation
  // **Validates: Requirements 5.2**
  group('Property 10: Foreign Key Consistency Validation', () {
    Glados(any.brokenFkBackup, ExploreConfig(numRuns: 100)).test(
      'broken FK references cause import rejection with table/record report',
      (brokenBackup) {
        final jsonString = jsonEncode(brokenBackup);

        expect(
          () => IsolateHelpers.parseAndValidateBackupJson(
            jsonString,
            currentSchemaVersion,
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('tidak konsisten'),
                // Should mention the table or FK field
                anyOf(
                  contains('transactions'),
                  contains('goals'),
                  contains('goalDeposits'),
                  contains('budgets'),
                  contains('recurringTransactions'),
                  contains('recurringExecutionLogs'),
                ),
              ),
            ),
          ),
          reason: 'Broken FK references should be rejected',
        );
      },
    );
  });

  // Feature: export-import-data, Property 11: Required Fields Validation
  // **Validates: Requirements 5.6**
  group('Property 11: Required Fields Validation', () {
    Glados(any.intInRange(0, 999999), ExploreConfig(numRuns: 100)).test(
      'missing required fields cause import rejection with field report',
      (seed) {
        final rng = Random(seed);

        // Build a valid backup base
        final dbState = _buildMinimalValidState(rng);
        final metadata = {
          'appVersion': randomSemver(rng),
          'schemaVersion': currentSchemaVersion,
          'exportedAt': randomIso8601(rng),
          'deviceId': randomString(rng, 10),
          'exportedBy': 'duasaku',
        };

        // Pick a random table and add a record without 'id' field
        const tables = IsolateHelpers.requiredTableKeys;
        final targetTable = tables[rng.nextInt(tables.length)];

        // Add a record missing the required 'id' field
        final existingRecords = (dbState[targetTable] as List)
            .cast<Map<String, dynamic>>();
        dbState[targetTable] = <Map<String, dynamic>>[
          ...existingRecords,
          <String, dynamic>{
            'name': 'Record without id',
            'createdAt': randomIso8601(rng),
          },
        ];

        final backup = {'metadata': metadata, 'data': dbState};
        final jsonString = jsonEncode(backup);

        expect(
          () => IsolateHelpers.parseAndValidateBackupJson(
            jsonString,
            currentSchemaVersion,
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(contains('id'), contains(targetTable)),
            ),
          ),
          reason:
              'Record missing "id" in table "$targetTable" should be rejected',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Internal Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal valid database state for validation tests.
Map<String, dynamic> _buildMinimalValidState(Random rng) {
  final wallets = [
    {
      'id': 'w_${rng.nextInt(99999)}',
      'name': 'Wallet',
      'balance': '1000',
      'createdAt': randomIso8601(rng),
    },
  ];
  final categories = [
    {
      'id': 'c_${rng.nextInt(99999)}',
      'name': 'Category',
      'type': 'expense',
      'createdAt': randomIso8601(rng),
    },
  ];

  return {
    'wallets': wallets,
    'categories': categories,
    'transactions': <Map<String, dynamic>>[],
    'budgets': <Map<String, dynamic>>[],
    'recurringTransactions': <Map<String, dynamic>>[],
    'recurringExecutionLogs': <Map<String, dynamic>>[],
    'goals': <Map<String, dynamic>>[],
    'goalDeposits': <Map<String, dynamic>>[],
    'budgetAlerts': <Map<String, dynamic>>[],
    'budgetAlertPreferences': <Map<String, dynamic>>[],
    'budgetAlertThresholdStatus': <Map<String, dynamic>>[],
  };
}
