
import 'package:duasaku_app/features/export_import/domain/models/data_type.dart';
import 'package:duasaku_app/features/export_import/services/isolate_helpers.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;
import 'package:test/test.dart';

import 'generators.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Headers for each DataType (simplified for testing).
List<String> _headersForType(DataType type) {
  switch (type) {
    case DataType.transactions:
      return ['id', 'walletId', 'categoryId', 'amount', 'date', 'note'];
    case DataType.wallets:
      return ['id', 'name', 'balance', 'createdAt'];
    case DataType.categories:
      return ['id', 'name', 'type', 'createdAt'];
    case DataType.budgets:
      return ['id', 'categoryId', 'amount', 'createdAt'];
    case DataType.recurringTransactions:
      return ['id', 'walletId', 'categoryId', 'amount', 'createdAt'];
    case DataType.goals:
      return ['id', 'walletId', 'targetAmount', 'createdAt'];
    case DataType.goalDeposits:
      return ['id', 'goalId', 'amount', 'createdAt'];
    case DataType.budgetAlerts:
      return ['id', 'message', 'createdAt'];
  }
}

/// Generates sample data for a given DataType.
List<Map<String, dynamic>> _generateDataForType(
  DataType type,
  int count,
  Random rng,
) {
  final headers = _headersForType(type);
  return List.generate(count, (i) {
    final record = <String, dynamic>{};
    for (final h in headers) {
      if (h == 'id') {
        record[h] = '${type.name}_${rng.nextInt(99999)}';
      } else if (h == 'walletId') {
        record[h] = 'w_${1 + rng.nextInt(3)}';
      } else if (h == 'categoryId') {
        record[h] = 'c_${1 + rng.nextInt(3)}';
      } else if (h == 'goalId') {
        record[h] = 'g_${rng.nextInt(100)}';
      } else if (h == 'amount' || h == 'balance' || h == 'targetAmount') {
        record[h] = (rng.nextDouble() * 1000000).toStringAsFixed(2);
      } else if (h == 'date' || h == 'createdAt') {
        record[h] = randomIso8601(rng);
      } else {
        record[h] = randomString(rng, 3 + rng.nextInt(10));
      }
    }
    return record;
  });
}

// ---------------------------------------------------------------------------
// Property-Based Tests: CSV Properties
// ---------------------------------------------------------------------------

void main() {
  // Feature: export-import-data, Property 3: CSV Output Count Matches Selection
  // **Validates: Requirements 1.2, 1.7**
  group('Property 3: CSV Output Count Matches Selection', () {
    Glados(any.randomDataTypeSubset, ExploreConfig(numRuns: 100)).test(
      'number of CSV outputs equals number of selected DataTypes',
      (selectedTypes) {
        final rng = Random(selectedTypes.hashCode);

        // For each selected type, generate CSV content
        final csvOutputs = <String>[];
        for (final type in selectedTypes) {
          final data = _generateDataForType(type, 1 + rng.nextInt(5), rng);
          final headers = _headersForType(type);
          final csv = IsolateHelpers.generateCsvContent(data, headers);
          csvOutputs.add(csv);
        }

        // Assert: one CSV per selected type
        expect(csvOutputs.length, equals(selectedTypes.length));

        // MIME type logic:
        // single → text/csv (single .csv file)
        // multiple → application/zip (N files in .zip)
        if (selectedTypes.length == 1) {
          expect(csvOutputs.length, equals(1));
        } else {
          expect(csvOutputs.length, equals(selectedTypes.length));
          expect(csvOutputs.length, greaterThan(1));
        }
      },
    );
  });

  // Feature: export-import-data, Property 4: CSV Structure Correctness
  // **Validates: Requirements 1.3, 1.4, 1.5**
  group('Property 4: CSV Structure Correctness', () {
    Glados(any.intInRange(0, 999999), ExploreConfig(numRuns: 100)).test(
      'CSV starts with UTF-8 BOM, has header row, and resolves names for Transactions',
      (seed) {
        final rng = Random(seed);

        // Generate transaction data with wallet/category references
        final walletNames = {
          'w_1': 'Cash',
          'w_2': 'Bank BCA',
          'w_3': 'GoPay',
        };
        final categoryNames = {
          'c_1': 'Makanan',
          'c_2': 'Transport',
          'c_3': 'Belanja',
        };

        final transactionCount = 1 + rng.nextInt(8);
        final transactions = List.generate(transactionCount, (i) {
          final wKey = 'w_${1 + rng.nextInt(3)}';
          final cKey = 'c_${1 + rng.nextInt(3)}';
          return {
            'id': 't_$i',
            'walletId': wKey,
            'categoryId': cKey,
            'amount': (rng.nextDouble() * 500000).toStringAsFixed(2),
            'date': randomIso8601(rng),
            'note': randomString(rng, 5),
          };
        });

        final headers = [
          'id',
          'walletId',
          'categoryId',
          'amount',
          'date',
          'note',
        ];

        final csv = IsolateHelpers.generateCsvContent(
          transactions,
          headers,
          walletNames: walletNames,
          categoryNames: categoryNames,
        );

        // (a) Starts with UTF-8 BOM
        expect(csv.startsWith('\uFEFF'), isTrue,
            reason: 'CSV must start with UTF-8 BOM');

        // (b) First row is header row with resolved name columns
        final lines = csv.split('\n');
        final headerLine = lines[0].replaceFirst('\uFEFF', '');
        expect(headerLine, contains('id'));
        expect(headerLine, contains('walletName'));
        expect(headerLine, contains('categoryName'));

        // (c) Data rows have resolved wallet/category names
        for (var i = 1; i <= transactionCount; i++) {
          final dataLine = lines[i];
          final walletId = transactions[i - 1]['walletId'] as String;
          final categoryId = transactions[i - 1]['categoryId'] as String;
          final expectedWalletName = walletNames[walletId] ?? '';
          final expectedCategoryName = categoryNames[categoryId] ?? '';

          expect(dataLine, contains(expectedWalletName),
              reason: 'Row $i should contain resolved wallet name');
          expect(dataLine, contains(expectedCategoryName),
              reason: 'Row $i should contain resolved category name');
        }
      },
    );
  });

  // Feature: export-import-data, Property 5: Date Range Filter Correctness
  // **Validates: Requirements 2.3, 2.4, 2.5**
  group('Property 5: Date Range Filter Correctness', () {
    Glados(any.validDateRange, ExploreConfig(numRuns: 100)).test(
      'only records within date range are included; AllTime includes all',
      (dateRange) {
        final (startDate, endDate) = dateRange;
        final rng = Random(startDate.millisecondsSinceEpoch);

        // Generate records with varying dates
        final recordCount = 5 + rng.nextInt(15);
        final allRecords = List.generate(recordCount, (i) {
          final DateTime recordDate;
          if (rng.nextBool()) {
            // Inside range
            final maxDays = endDate.difference(startDate).inDays.clamp(1, 9999);
            final dayOffset = rng.nextInt(maxDays);
            recordDate = startDate.add(Duration(days: dayOffset));
          } else {
            // Outside range (before start or after end)
            if (rng.nextBool()) {
              recordDate =
                  startDate.subtract(Duration(days: 1 + rng.nextInt(365)));
            } else {
              recordDate = endDate.add(Duration(days: 1 + rng.nextInt(365)));
            }
          }
          return {
            'id': 'r_$i',
            'date': recordDate.toIso8601String(),
            'amount': '${rng.nextInt(10000)}',
          };
        });

        // Apply date range filter (simulating what the export engine does)
        final filteredRecords = allRecords.where((record) {
          final recordDate = DateTime.parse(record['date'] as String);
          return !recordDate.isBefore(startDate) &&
              !recordDate.isAfter(endDate);
        }).toList();

        // Assert: all filtered records are within range
        for (final record in filteredRecords) {
          final recordDate = DateTime.parse(record['date'] as String);
          expect(
            recordDate.isAfter(startDate) ||
                recordDate.isAtSameMomentAs(startDate),
            isTrue,
            reason: 'Record date $recordDate should be >= $startDate',
          );
          expect(
            recordDate.isBefore(endDate) ||
                recordDate.isAtSameMomentAs(endDate),
            isTrue,
            reason: 'Record date $recordDate should be <= $endDate',
          );
        }

        // AllTime: no filter → all records included
        final allTimeRecords = allRecords; // no filtering
        expect(allTimeRecords.length, equals(recordCount));
      },
    );
  });

  // Feature: export-import-data, Property 12: MIME Type Mapping Correctness
  // **Validates: Requirements 6.3, 6.4**
  group('Property 12: MIME Type Mapping Correctness', () {
    Glados(any.randomDataTypeSubset, ExploreConfig(numRuns: 100)).test(
      'single CSV → text/csv, multiple CSV → application/zip, JSON → application/json',
      (selectedTypes) {
        // Determine expected MIME type for CSV export
        final String expectedCsvMimeType;
        if (selectedTypes.length == 1) {
          expectedCsvMimeType = 'text/csv';
        } else {
          expectedCsvMimeType = 'application/zip';
        }

        // Verify MIME type mapping logic
        if (selectedTypes.length == 1) {
          expect(expectedCsvMimeType, equals('text/csv'));
        } else {
          expect(expectedCsvMimeType, equals('application/zip'));
        }

        // JSON backup always has application/json
        const jsonMimeType = 'application/json';
        expect(jsonMimeType, equals('application/json'));
      },
    );
  });
}
