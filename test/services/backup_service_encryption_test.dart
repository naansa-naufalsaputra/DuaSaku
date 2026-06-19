import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duasaku_app/core/services/backup_service.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';

class FakeRef extends Fake implements Ref {
  @override
  void invalidate(ProviderOrFamily provider) {
    // No-op
  }
}

void main() {
  group('BackupService Encryption & Decryption Tests', () {
    late AppDatabase db;
    late BackupService backupService;
    late Ref fakeRef;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      fakeRef = FakeRef();
      backupService = BackupService(db: db, ref: fakeRef);
    });

    tearDown(() async {
      await db.close();
    });

    test('deriveKey produces a 32-byte key using SHA-256', () {
      final key1 = backupService.deriveKey('super_secret_password');
      final key2 = backupService.deriveKey('super_secret_password');
      final key3 = backupService.deriveKey('different_password');

      expect(key1.length, equals(32));
      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
    });

    test('encryptBackup returns wrapped encrypted JSON structure', () {
      const plaintext = '{"hello": "world"}';
      const password = 'my_password_123';

      final encryptedJson = backupService.encryptBackup(plaintext, password);
      final decoded = jsonDecode(encryptedJson) as Map<String, dynamic>;

      expect(decoded['duasaku_encrypted_backup'], isTrue);
      expect(decoded.containsKey('iv'), isTrue);
      expect(decoded.containsKey('ciphertext'), isTrue);
      expect(decoded['ciphertext'], isNot(equals(plaintext)));
    });

    test('decryptBackup restores plaintext successfully with correct password', () {
      const plaintext = '{"userId": "123", "balance": 50000.0}';
      const password = 'secure_backup_password';

      final encryptedJson = backupService.encryptBackup(plaintext, password);
      final decrypted = backupService.decryptBackup(encryptedJson, password);

      expect(decrypted, equals(plaintext));
    });

    test('decryptBackup throws FormatException when incorrect password is used', () {
      const plaintext = '{"userId": "123", "balance": 50000.0}';
      const password = 'correct_password';
      const wrongPassword = 'wrong_password';

      final encryptedJson = backupService.encryptBackup(plaintext, password);

      expect(
        () => backupService.decryptBackup(encryptedJson, wrongPassword),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('Kata sandi salah'),
        )),
      );
    });

    test('decryptBackup throws FormatException when backup signature is missing', () {
      const invalidJson = '{"iv": "abc", "ciphertext": "xyz"}';
      const password = 'password';

      expect(
        () => backupService.decryptBackup(invalidJson, password),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('tidak terenkripsi atau format tidak dikenali'),
        )),
      );
    });
  });
}
