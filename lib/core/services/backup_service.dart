import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart' as crypt;

import '../local_db/app_database.dart';
import '../local_db/app_database_provider.dart';
import '../../features/wallets/providers/wallet_provider.dart';
import '../../features/transactions/providers/category_provider.dart';
import '../../features/transactions/providers/transaction_provider.dart';
import '../../features/transactions/providers/budget_provider.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(db: ref.watch(appDatabaseProvider), ref: ref);
});

class BackupService {
  final AppDatabase db;
  final Ref ref;

  BackupService({required this.db, required this.ref});

  Uint8List deriveKey(String password) {
    final bytes = utf8.encode(password);
    final digest = crypt.sha256.convert(bytes);
    return Uint8List.fromList(digest.bytes);
  }

  String encryptBackup(String plaintext, String password) {
    final key = enc.Key(deriveKey(password));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    final wrapper = {
      'duasaku_encrypted_backup': true,
      'iv': iv.base64,
      'ciphertext': encrypted.base64,
    };
    return jsonEncode(wrapper);
  }

  String decryptBackup(String ciphertextJson, String password) {
    final Map<String, dynamic> wrapper = jsonDecode(ciphertextJson) as Map<String, dynamic>;
    if (wrapper['duasaku_encrypted_backup'] != true) {
      throw const FormatException('File backup tidak terenkripsi atau format tidak dikenali');
    }

    final String ivBase64 = wrapper['iv'] as String;
    final String ciphertextBase64 = wrapper['ciphertext'] as String;

    final key = enc.Key(deriveKey(password));
    final iv = enc.IV.fromBase64(ivBase64);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    try {
      final decrypted = encrypter.decrypt(enc.Encrypted.fromBase64(ciphertextBase64), iv: iv);
      return decrypted;
    } catch (e) {
      throw const FormatException('Kata sandi salah atau data file backup rusak');
    }
  }

  /// Generates the raw JSON string containing all table records.
  Future<String> generateBackupPlaintext() async {
    final allWallets = await db.select(db.wallets).get();
    final allCategories = await db.select(db.categories).get();
    final allTransactions = await db.select(db.transactions).get();
    final allBudgets = await db.select(db.budgets).get();

    final backupMap = {
      'metadata': {
        'schemaVersion': db.schemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'device': Platform.operatingSystem,
      },
      'wallets': allWallets.map((w) => w.toJson()).toList(),
      'categories': allCategories.map((c) => c.toJson()).toList(),
      'transactions': allTransactions.map((t) => t.toJson()).toList(),
      'budgets': allBudgets.map((b) => b.toJson()).toList(),
    };

    return jsonEncode(backupMap);
  }

  /// Restores records atomically from a raw JSON string of all tables.
  Future<void> restoreFromPlaintext(String plaintext) async {
    final Map<String, dynamic> backupMap =
        jsonDecode(plaintext) as Map<String, dynamic>;

    final metadata = backupMap['metadata'];
    if (metadata == null || metadata is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format: missing metadata');
    }

    final backupSchemaVersion = metadata['schemaVersion'];
    if (backupSchemaVersion == null) {
      throw const FormatException(
        'Invalid backup format: missing schema version',
      );
    }

    if (backupSchemaVersion != db.schemaVersion) {
      throw FormatException(
        'Incompatible schema version: expected version ${db.schemaVersion}, got $backupSchemaVersion',
      );
    }

    final List<dynamic> walletsJson =
        backupMap['wallets'] as List<dynamic>? ?? [];
    final List<dynamic> categoriesJson =
        backupMap['categories'] as List<dynamic>? ?? [];
    final List<dynamic> transactionsJson =
        backupMap['transactions'] as List<dynamic>? ?? [];
    final List<dynamic> budgetsJson =
        backupMap['budgets'] as List<dynamic>? ?? [];

    await db.transaction(() async {
      // Wipe in dependency order to satisfy foreign key constraints:
      await db.delete(db.budgets).go();
      await db.delete(db.transactions).go();
      await db.delete(db.categories).go();
      await db.delete(db.wallets).go();

      // Insert in reverse dependency order (independent tables first):
      for (final item in walletsJson) {
        final wallet = Wallet.fromJson(item as Map<String, dynamic>);
        await db
            .into(db.wallets)
            .insert(wallet, mode: InsertMode.insertOrReplace);
      }

      for (final item in categoriesJson) {
        final category = Category.fromJson(item as Map<String, dynamic>);
        await db
            .into(db.categories)
            .insert(category, mode: InsertMode.insertOrReplace);
      }

      for (final item in transactionsJson) {
        final transaction = Transaction.fromJson(
          item as Map<String, dynamic>,
        );
        await db
            .into(db.transactions)
            .insert(transaction, mode: InsertMode.insertOrReplace);
      }

      for (final item in budgetsJson) {
        final budget = Budget.fromJson(item as Map<String, dynamic>);
        await db
            .into(db.budgets)
            .insert(budget, mode: InsertMode.insertOrReplace);
      }
    });

    // Invalidate Riverpod states to refresh the UI immediately
    ref.invalidate(walletProvider);
    ref.invalidate(categoryNotifierProvider);
    ref.invalidate(transactionNotifierProvider);
    ref.invalidate(budgetNotifierProvider);
  }

  /// Exports all database tables (Wallets, Categories, Transactions, Budgets)
  /// to a JSON file and opens the platform's native share sheet.
  Future<void> exportData(String password) async {
    try {
      final jsonString = await generateBackupPlaintext();
      final encryptedJsonString = encryptBackup(jsonString, password);

      // 3. Write encrypted JSON to a temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final tempFile = File(
        p.join(tempDir.path, 'duasaku_backup_$timestamp.json'),
      );
      await tempFile.writeAsString(encryptedJsonString);

      // 4. Trigger Native Share sheet
      final xFile = XFile(tempFile.path);
      await SharePlus.instance.share(
        ShareParams(subject: 'DuaSaku Backup Data', files: [xFile]),
      );
    } catch (e) {
      throw Exception('Failed to export backup: $e');
    }
  }

  /// Lets the user select a backup JSON file, validates its format/schema,
  /// restores records atomically inside a Drift transaction, and invalidates providers.
  Future<Map<String, int>?> importData(String password) async {
    try {
      // 1. Pick backup file using FilePicker
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result == null || result.files.isEmpty) {
        // User canceled file selection
        return null;
      }

      final fileBytes = result.files.first.bytes;
      final filePath = result.files.first.path;
      String jsonString;

      if (filePath != null) {
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File does not exist at selected path');
        }
        jsonString = await file.readAsString();
      } else if (fileBytes != null) {
        jsonString = utf8.decode(fileBytes);
      } else {
        throw Exception('Unable to read selected file contents');
      }

      // 2. Decrypt the ciphertext
      final decryptedJsonString = decryptBackup(jsonString, password);

      // 3. Decode list lengths for output
      final Map<String, dynamic> backupMap =
          jsonDecode(decryptedJsonString) as Map<String, dynamic>;
      final List<dynamic> walletsJson =
          backupMap['wallets'] as List<dynamic>? ?? [];
      final List<dynamic> categoriesJson =
          backupMap['categories'] as List<dynamic>? ?? [];
      final List<dynamic> transactionsJson =
          backupMap['transactions'] as List<dynamic>? ?? [];
      final List<dynamic> budgetsJson =
          backupMap['budgets'] as List<dynamic>? ?? [];

      // 4. Restore using the helper method
      await restoreFromPlaintext(decryptedJsonString);

      return {
        'wallets': walletsJson.length,
        'categories': categoriesJson.length,
        'transactions': transactionsJson.length,
        'budgets': budgetsJson.length,
      };
    } on FormatException catch (fe) {
      throw Exception('Format Error: ${fe.message}');
    } catch (e) {
      throw Exception('Import Failed: $e');
    }
  }
}
