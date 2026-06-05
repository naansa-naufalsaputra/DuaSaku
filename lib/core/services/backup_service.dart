import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../local_db/app_database.dart';
import '../local_db/app_database_provider.dart';
import '../../features/wallets/providers/wallet_provider.dart';
import '../../features/transactions/providers/category_provider.dart';
import '../../features/transactions/providers/transaction_provider.dart';
import '../../features/transactions/providers/budget_provider.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    db: ref.watch(appDatabaseProvider),
    ref: ref,
  );
});

class BackupService {
  final AppDatabase db;
  final Ref ref;

  BackupService({
    required this.db,
    required this.ref,
  });

  /// Exports all database tables (Wallets, Categories, Transactions, Budgets) 
  /// to a JSON file and opens the platform's native share sheet.
  Future<void> exportData() async {
    try {
      // 1. Fetch all records from the database
      final allWallets = await db.select(db.wallets).get();
      final allCategories = await db.select(db.categories).get();
      final allTransactions = await db.select(db.transactions).get();
      final allBudgets = await db.select(db.budgets).get();

      // 2. Serialize database objects to JSON maps
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

      final jsonString = jsonEncode(backupMap);

      // 3. Write JSON to a temporary file
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final tempFile = File(p.join(tempDir.path, 'duasaku_backup_$timestamp.json'));
      await tempFile.writeAsString(jsonString);

      // 4. Trigger Native Share sheet
      final xFile = XFile(tempFile.path);
      await SharePlus.instance.share(
        ShareParams(
          subject: 'DuaSaku Backup Data',
          files: [xFile],
        ),
      );
    } catch (e) {
      throw Exception('Failed to export backup: $e');
    }
  }

  /// Lets the user select a backup JSON file, validates its format/schema,
  /// restores records atomically inside a Drift transaction, and invalidates providers.
  Future<Map<String, int>?> importData() async {
    try {
      // 1. Pick backup file using FilePicker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

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

      // 2. Decode and validate structure
      final Map<String, dynamic> backupMap = jsonDecode(jsonString) as Map<String, dynamic>;
      
      final metadata = backupMap['metadata'];
      if (metadata == null || metadata is! Map<String, dynamic>) {
        throw const FormatException('Invalid backup format: missing metadata');
      }

      final backupSchemaVersion = metadata['schemaVersion'];
      if (backupSchemaVersion == null) {
        throw const FormatException('Invalid backup format: missing schema version');
      }

      if (backupSchemaVersion != db.schemaVersion) {
        throw FormatException(
          'Incompatible schema version: expected version ${db.schemaVersion}, got $backupSchemaVersion'
        );
      }

      // 3. Extract JSON lists
      final List<dynamic> walletsJson = backupMap['wallets'] as List<dynamic>? ?? [];
      final List<dynamic> categoriesJson = backupMap['categories'] as List<dynamic>? ?? [];
      final List<dynamic> transactionsJson = backupMap['transactions'] as List<dynamic>? ?? [];
      final List<dynamic> budgetsJson = backupMap['budgets'] as List<dynamic>? ?? [];

      // 4. Perform atomic restore inside Drift transaction
      await db.transaction(() async {
        // Wipe in dependency order to satisfy foreign key constraints:
        // Budgets (references Categories via cascade, but clean it explicitly first)
        // Transactions (references Wallets via restrict, Categories via setNull)
        // Categories
        // Wallets
        await db.delete(db.budgets).go();
        await db.delete(db.transactions).go();
        await db.delete(db.categories).go();
        await db.delete(db.wallets).go();

        // Insert in reverse dependency order (independent tables first):
        // 1. Wallets
        for (final item in walletsJson) {
          final wallet = Wallet.fromJson(item as Map<String, dynamic>);
          await db.into(db.wallets).insert(wallet, mode: InsertMode.insertOrReplace);
        }

        // 2. Categories
        for (final item in categoriesJson) {
          final category = Category.fromJson(item as Map<String, dynamic>);
          await db.into(db.categories).insert(category, mode: InsertMode.insertOrReplace);
        }

        // 3. Transactions
        for (final item in transactionsJson) {
          final transaction = Transaction.fromJson(item as Map<String, dynamic>);
          await db.into(db.transactions).insert(transaction, mode: InsertMode.insertOrReplace);
        }

        // 4. Budgets
        for (final item in budgetsJson) {
          final budget = Budget.fromJson(item as Map<String, dynamic>);
          await db.into(db.budgets).insert(budget, mode: InsertMode.insertOrReplace);
        }
      });

      // 5. Invalidate Riverpod states to refresh the UI immediately
      ref.invalidate(walletProvider);
      ref.invalidate(categoryNotifierProvider);
      ref.invalidate(transactionNotifierProvider);
      ref.invalidate(budgetNotifierProvider);

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
