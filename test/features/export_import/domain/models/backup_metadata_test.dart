import 'package:duasaku_app/features/export_import/domain/models/backup_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupMetadata', () {
    const validJson = {
      'appVersion': '1.0.0',
      'schemaVersion': 7,
      'exportedAt': '2024-01-15T10:30:00.000Z',
      'deviceId': 'abc123',
      'exportedBy': 'duasaku',
    };

    group('constructor', () {
      test('creates instance with all required fields', () {
        const metadata = BackupMetadata(
          appVersion: '1.0.0',
          schemaVersion: 7,
          exportedAt: '2024-01-15T10:30:00.000Z',
          deviceId: 'abc123',
        );

        expect(metadata.appVersion, '1.0.0');
        expect(metadata.schemaVersion, 7);
        expect(metadata.exportedAt, '2024-01-15T10:30:00.000Z');
        expect(metadata.deviceId, 'abc123');
        expect(metadata.exportedBy, 'duasaku');
      });

      test('exportedBy defaults to "duasaku"', () {
        const metadata = BackupMetadata(
          appVersion: '2.0.0',
          schemaVersion: 1,
          exportedAt: '2024-06-01T00:00:00.000Z',
          deviceId: 'device1',
        );

        expect(metadata.exportedBy, 'duasaku');
      });
    });

    group('BackupMetadata.now()', () {
      test('auto-fills exportedAt with current UTC timestamp', () {
        final before = DateTime.now().toUtc();
        final metadata = BackupMetadata.now(
          appVersion: '1.0.0',
          schemaVersion: 7,
          deviceId: 'device123',
        );
        final after = DateTime.now().toUtc();

        final exportedAt = DateTime.parse(metadata.exportedAt);
        expect(exportedAt.isUtc, isTrue);
        expect(
          exportedAt.isAfter(before) || exportedAt.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          exportedAt.isBefore(after) || exportedAt.isAtSameMomentAs(after),
          isTrue,
        );
      });

      test('sets exportedBy to "duasaku"', () {
        final metadata = BackupMetadata.now(
          appVersion: '1.0.0',
          schemaVersion: 7,
          deviceId: 'device123',
        );

        expect(metadata.exportedBy, 'duasaku');
      });

      test('passes appVersion, schemaVersion, and deviceId correctly', () {
        final metadata = BackupMetadata.now(
          appVersion: '2.5.1',
          schemaVersion: 12,
          deviceId: 'my-device-id',
        );

        expect(metadata.appVersion, '2.5.1');
        expect(metadata.schemaVersion, 12);
        expect(metadata.deviceId, 'my-device-id');
      });
    });

    group('toJson()', () {
      test('serializes all fields correctly', () {
        const metadata = BackupMetadata(
          appVersion: '1.0.0',
          schemaVersion: 7,
          exportedAt: '2024-01-15T10:30:00.000Z',
          deviceId: 'abc123',
          exportedBy: 'duasaku',
        );

        final json = metadata.toJson();

        expect(json, validJson);
      });
    });

    group('fromJson()', () {
      test('deserializes valid JSON correctly', () {
        final metadata = BackupMetadata.fromJson(validJson);

        expect(metadata.appVersion, '1.0.0');
        expect(metadata.schemaVersion, 7);
        expect(metadata.exportedAt, '2024-01-15T10:30:00.000Z');
        expect(metadata.deviceId, 'abc123');
        expect(metadata.exportedBy, 'duasaku');
      });

      test('throws FormatException when appVersion is missing', () {
        final json = Map<String, dynamic>.from(validJson)..remove('appVersion');

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('appVersion'),
            ),
          ),
        );
      });

      test('throws FormatException when schemaVersion is missing', () {
        final json = Map<String, dynamic>.from(validJson)
          ..remove('schemaVersion');

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('schemaVersion'),
            ),
          ),
        );
      });

      test('throws FormatException when exportedAt is missing', () {
        final json = Map<String, dynamic>.from(validJson)..remove('exportedAt');

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('exportedAt'),
            ),
          ),
        );
      });

      test('throws FormatException when deviceId is missing', () {
        final json = Map<String, dynamic>.from(validJson)..remove('deviceId');

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('deviceId'),
            ),
          ),
        );
      });

      test('throws FormatException when exportedBy is missing', () {
        final json = Map<String, dynamic>.from(validJson)..remove('exportedBy');

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('exportedBy'),
            ),
          ),
        );
      });

      test('throws FormatException when exportedBy is not "duasaku"', () {
        final json = Map<String, dynamic>.from(validJson)
          ..['exportedBy'] = 'other_app';

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('duasaku'),
            ),
          ),
        );
      });

      test('throws FormatException when exportedAt is not valid ISO 8601', () {
        final json = Map<String, dynamic>.from(validJson)
          ..['exportedAt'] = 'not-a-date';

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('ISO 8601'),
            ),
          ),
        );
      });

      test('throws FormatException when schemaVersion is zero', () {
        final json = Map<String, dynamic>.from(validJson)
          ..['schemaVersion'] = 0;

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('positive integer'),
            ),
          ),
        );
      });

      test('throws FormatException when schemaVersion is negative', () {
        final json = Map<String, dynamic>.from(validJson)
          ..['schemaVersion'] = -1;

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('positive integer'),
            ),
          ),
        );
      });

      test('throws FormatException when schemaVersion is not an int', () {
        final json = Map<String, dynamic>.from(validJson)
          ..['schemaVersion'] = 'seven';

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('positive integer'),
            ),
          ),
        );
      });

      test('throws FormatException when a field is null', () {
        final json = Map<String, dynamic>.from(validJson)..['deviceId'] = null;

        expect(
          () => BackupMetadata.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('round-trip (toJson → fromJson)', () {
      test('produces equivalent object', () {
        const original = BackupMetadata(
          appVersion: '1.0.0',
          schemaVersion: 7,
          exportedAt: '2024-01-15T10:30:00.000Z',
          deviceId: 'abc123',
          exportedBy: 'duasaku',
        );

        final roundTripped = BackupMetadata.fromJson(original.toJson());

        expect(roundTripped, equals(original));
      });
    });

    group('equality', () {
      test('two instances with same values are equal', () {
        const a = BackupMetadata(
          appVersion: '1.0.0',
          schemaVersion: 7,
          exportedAt: '2024-01-15T10:30:00.000Z',
          deviceId: 'abc123',
        );
        const b = BackupMetadata(
          appVersion: '1.0.0',
          schemaVersion: 7,
          exportedAt: '2024-01-15T10:30:00.000Z',
          deviceId: 'abc123',
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('two instances with different values are not equal', () {
        const a = BackupMetadata(
          appVersion: '1.0.0',
          schemaVersion: 7,
          exportedAt: '2024-01-15T10:30:00.000Z',
          deviceId: 'abc123',
        );
        const b = BackupMetadata(
          appVersion: '2.0.0',
          schemaVersion: 7,
          exportedAt: '2024-01-15T10:30:00.000Z',
          deviceId: 'abc123',
        );

        expect(a, isNot(equals(b)));
      });
    });
  });
}
