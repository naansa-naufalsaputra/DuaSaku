import 'dart:convert';

import 'package:duasaku_app/features/export_import/services/isolate_helpers.dart';
import 'package:test/test.dart';

void main() {
  group('IsolateHelpers.generateCsvContent', () {
    test('starts with UTF-8 BOM character', () {
      final result = IsolateHelpers.generateCsvContent(
        [
          {'id': '1', 'name': 'Test'},
        ],
        ['id', 'name'],
      );

      expect(result.startsWith('\uFEFF'), isTrue);
    });

    test('includes header row after BOM', () {
      final result = IsolateHelpers.generateCsvContent(
        [
          {'id': '1', 'name': 'Test'},
        ],
        ['id', 'name'],
      );

      final lines = result.split('\n');
      // First line after BOM removal should be headers
      expect(lines[0], equals('\uFEFFid,name'));
    });

    test('includes data rows in correct column order', () {
      final result = IsolateHelpers.generateCsvContent(
        [
          {'id': '1', 'name': 'Wallet A', 'balance': '1000'},
          {'id': '2', 'name': 'Wallet B', 'balance': '2000'},
        ],
        ['id', 'name', 'balance'],
      );

      final lines = result.trim().split('\n');
      expect(lines.length, equals(3)); // header + 2 data rows
      expect(lines[1], equals('1,Wallet A,1000'));
      expect(lines[2], equals('2,Wallet B,2000'));
    });

    test('quotes values containing commas', () {
      final result = IsolateHelpers.generateCsvContent(
        [
          {'id': '1', 'desc': 'Food, Drink'},
        ],
        ['id', 'desc'],
      );

      final lines = result.trim().split('\n');
      expect(lines[1], equals('1,"Food, Drink"'));
    });

    test('quotes values containing double-quotes and escapes them', () {
      final result = IsolateHelpers.generateCsvContent(
        [
          {'id': '1', 'desc': 'He said "hello"'},
        ],
        ['id', 'desc'],
      );

      final lines = result.trim().split('\n');
      expect(lines[1], equals('1,"He said ""hello"""'));
    });

    test('quotes values containing newlines', () {
      final result = IsolateHelpers.generateCsvContent(
        [
          {'id': '1', 'desc': 'Line1\nLine2'},
        ],
        ['id', 'desc'],
      );

      // The value should be quoted
      expect(result.contains('"Line1\nLine2"'), isTrue);
    });

    test('resolves walletName from walletId when walletNames provided', () {
      final result = IsolateHelpers.generateCsvContent(
        [
          {'id': '1', 'walletId': 'w1', 'amount': '100'},
          {'id': '2', 'walletId': 'w2', 'amount': '200'},
        ],
        ['id', 'walletId', 'amount'],
        walletNames: {'w1': 'Cash', 'w2': 'Bank BCA'},
      );

      final lines = result.trim().split('\n');
      // Header should include walletName
      expect(lines[0], contains('walletName'));
      // Data should have resolved names
      expect(lines[1], contains('Cash'));
      expect(lines[2], contains('Bank BCA'));
    });

    test(
      'resolves categoryName from categoryId when categoryNames provided',
      () {
        final result = IsolateHelpers.generateCsvContent(
          [
            {'id': '1', 'categoryId': 'c1', 'amount': '50'},
          ],
          ['id', 'categoryId', 'amount'],
          categoryNames: {'c1': 'Makanan'},
        );

        final lines = result.trim().split('\n');
        expect(lines[0], contains('categoryName'));
        expect(lines[1], contains('Makanan'));
      },
    );

    test('handles missing FK references gracefully (empty string)', () {
      final result = IsolateHelpers.generateCsvContent(
        [
          {'id': '1', 'walletId': 'unknown_id', 'amount': '100'},
        ],
        ['id', 'walletId', 'amount'],
        walletNames: {'w1': 'Cash'},
      );

      final lines = result.trim().split('\n');
      // walletName should be empty for unresolved ID
      expect(lines[1], equals('1,unknown_id,100,'));
    });

    test('handles empty data list', () {
      final result = IsolateHelpers.generateCsvContent([], ['id', 'name']);

      // Remove trailing newline for line count check
      final content = result.trimRight();
      final lines = content.split('\n');
      expect(lines.length, equals(1)); // Only header
      // BOM is at the start
      expect(lines[0], equals('\uFEFFid,name'));
    });
  });

  group('IsolateHelpers.serializeBackupToJson', () {
    test('returns pretty-printed JSON with 2-space indent', () {
      final data = {
        'metadata': {'appVersion': '1.0.0', 'schemaVersion': 7},
        'data': {'wallets': []},
      };

      final result = IsolateHelpers.serializeBackupToJson(data);

      // Should be indented
      expect(result, contains('  "metadata"'));
      // Should be valid JSON
      expect(() => jsonDecode(result), returnsNormally);
    });

    test('preserves all data fields', () {
      final data = {
        'metadata': {
          'appVersion': '1.0.0',
          'schemaVersion': 7,
          'exportedAt': '2024-01-15T10:30:00.000Z',
          'deviceId': 'abc123',
          'exportedBy': 'duasaku',
        },
        'data': {
          'wallets': [
            {'id': '1', 'name': 'Cash', 'balance': 1000.50},
          ],
        },
      };

      final result = IsolateHelpers.serializeBackupToJson(data);
      final decoded = jsonDecode(result) as Map<String, dynamic>;

      expect(decoded['metadata']['appVersion'], equals('1.0.0'));
      expect(decoded['data']['wallets'][0]['balance'], equals(1000.50));
    });
  });

  group('IsolateHelpers.parseAndValidateBackupJson', () {
    Map<String, dynamic> validBackup() => {
      'metadata': {
        'appVersion': '1.0.0',
        'schemaVersion': 7,
        'exportedAt': '2024-01-15T10:30:00.000Z',
        'deviceId': 'abc123',
        'exportedBy': 'duasaku',
      },
      'data': {
        'wallets': [
          {'id': 'w1', 'name': 'Cash'},
        ],
        'categories': [
          {'id': 'c1', 'name': 'Food'},
        ],
        'transactions': [
          {'id': 't1', 'walletId': 'w1', 'categoryId': 'c1'},
        ],
        'budgets': [
          {'id': 'b1', 'categoryId': 'c1'},
        ],
        'recurringTransactions': [
          {'id': 'rt1', 'walletId': 'w1', 'categoryId': 'c1'},
        ],
        'recurringExecutionLogs': [
          {'id': 'rel1', 'recurringTransactionId': 'rt1'},
        ],
        'goals': [
          {'id': 'g1', 'walletId': 'w1'},
        ],
        'goalDeposits': [
          {'id': 'gd1', 'goalId': 'g1'},
        ],
        'budgetAlerts': [
          {'id': 'ba1'},
        ],
        'budgetAlertPreferences': [
          {'id': 'bap1'},
        ],
        'budgetAlertThresholdStatus': [
          {'id': 'bats1'},
        ],
      },
    };

    test('returns parsed map for valid backup', () {
      final json = jsonEncode(validBackup());
      final result = IsolateHelpers.parseAndValidateBackupJson(json, 7);

      expect(result, isA<Map<String, dynamic>>());
      expect(result['metadata']['exportedBy'], equals('duasaku'));
    });

    test('throws FormatException for malformed JSON', () {
      expect(
        () => IsolateHelpers.parseAndValidateBackupJson('{invalid json', 7),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when metadata is missing', () {
      final json = jsonEncode({'data': {}});
      expect(
        () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('metadata'),
          ),
        ),
      );
    });

    test('throws FormatException when exportedBy is not duasaku', () {
      final backup = validBackup();
      backup['metadata']['exportedBy'] = 'other_app';
      final json = jsonEncode(backup);

      expect(
        () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('bukan backup DuaSaku'),
          ),
        ),
      );
    });

    test(
      'throws FormatException when backup schema > current (update app)',
      () {
        final backup = validBackup();
        backup['metadata']['schemaVersion'] = 10;
        final json = jsonEncode(backup);

        expect(
          () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('update'),
            ),
          ),
        );
      },
    );

    test(
      'throws FormatException when backup schema < current (older version)',
      () {
        final backup = validBackup();
        backup['metadata']['schemaVersion'] = 5;
        final json = jsonEncode(backup);

        expect(
          () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('lebih lama'),
            ),
          ),
        );
      },
    );

    test('throws FormatException when required table key is missing', () {
      final backup = validBackup();
      (backup['data'] as Map).remove('wallets');
      final json = jsonEncode(backup);

      expect(
        () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('wallets'),
          ),
        ),
      );
    });

    test('throws FormatException when record is missing id field', () {
      final backup = validBackup();
      (backup['data']['wallets'] as List).add({'name': 'No ID Wallet'});
      final json = jsonEncode(backup);

      expect(
        () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('id'),
          ),
        ),
      );
    });

    test('throws FormatException for broken FK: transaction → wallet', () {
      final backup = validBackup();
      (backup['data']['transactions'] as List).add({
        'id': 't2',
        'walletId': 'nonexistent',
        'categoryId': 'c1',
      });
      final json = jsonEncode(backup);

      expect(
        () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('transactions'), contains('walletId')),
          ),
        ),
      );
    });

    test('throws FormatException for broken FK: transaction → category', () {
      final backup = validBackup();
      (backup['data']['transactions'] as List).add({
        'id': 't2',
        'walletId': 'w1',
        'categoryId': 'nonexistent',
      });
      final json = jsonEncode(backup);

      expect(
        () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('transactions'), contains('categoryId')),
          ),
        ),
      );
    });

    test('throws FormatException for broken FK: goalDeposits → goals', () {
      final backup = validBackup();
      (backup['data']['goalDeposits'] as List).add({
        'id': 'gd2',
        'goalId': 'nonexistent',
      });
      final json = jsonEncode(backup);

      expect(
        () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('goalDeposits'), contains('goalId')),
          ),
        ),
      );
    });

    test(
      'throws FormatException for broken FK: recurringExecutionLogs → recurringTransactions',
      () {
        final backup = validBackup();
        (backup['data']['recurringExecutionLogs'] as List).add({
          'id': 'rel2',
          'recurringTransactionId': 'nonexistent',
        });
        final json = jsonEncode(backup);

        expect(
          () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('recurringExecutionLogs'),
                contains('recurringTransactionId'),
              ),
            ),
          ),
        );
      },
    );

    test('allows records with null FK fields (nullable references)', () {
      final backup = validBackup();
      // Transaction without categoryId (null) should be valid
      (backup['data']['transactions'] as List).add({
        'id': 't2',
        'walletId': 'w1',
        // categoryId is null/missing — should be allowed
      });
      final json = jsonEncode(backup);

      expect(
        () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
        returnsNormally,
      );
    });

    test('throws FormatException when metadata field is missing', () {
      final backup = validBackup();
      (backup['metadata'] as Map).remove('deviceId');
      final json = jsonEncode(backup);

      expect(
        () => IsolateHelpers.parseAndValidateBackupJson(json, 7),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('deviceId'),
          ),
        ),
      );
    });
  });
}
