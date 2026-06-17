import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:duasaku_app/core/constants/app_constants.dart';
import 'package:duasaku_app/features/goals/data/goal_dao.dart';
import 'package:duasaku_app/features/recurring_transactions/data/recurring_transaction_dao.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

// File ini akan di-generate oleh build_runner
part 'app_database.g.dart';

@TableIndex(name: 'idx_wallets_user_id', columns: {#userId})
class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'Bank', 'E-Wallet', 'Cash'
  RealColumn get balance => real().withDefault(const Constant(0.0))();
  TextColumn get icon => text()();
  TextColumn get color => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_categories_user_id', columns: {#userId})
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get type => text()(); // 'income' atau 'expense'
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_transactions_user_date', columns: {#userId, #date})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();

  // walletId references Wallets (nullable, e.g. for transfers)
  TextColumn get walletId => text().nullable().references(
    Wallets,
    #id,
    onDelete: KeyAction.restrict,
  )();

  // fromWalletId and toWalletId for transfer type
  TextColumn get fromWalletId => text().nullable().references(
    Wallets,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get toWalletId => text().nullable().references(
    Wallets,
    #id,
    onDelete: KeyAction.restrict,
  )();

  // categoryId references Categories (nullable)
  TextColumn get categoryId => text().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();

  RealColumn get amount => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get date => dateTime()();
  TextColumn get type => text()(); // 'income', 'expense', atau 'transfer'
  TextColumn get badge => text().nullable()(); // 'recurring' or null

  // Location coordinates
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
}

@TableIndex(name: 'idx_budgets_user_id', columns: {#userId})
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get userId =>
      text().withDefault(const Constant(AppConstants.defaultUserId))();
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  TextColumn get month => text()(); // format 'YYYY-MM'
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_recurring_user_id', columns: {#userId})
@TableIndex(name: 'idx_recurring_next_execution', columns: {#nextExecutionDate})
class RecurringTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get walletId =>
      text().references(Wallets, #id, onDelete: KeyAction.restrict)();
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.setNull)();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // 'income' or 'expense'
  TextColumn get frequency =>
      text()(); // 'daily', 'weekly', 'monthly', 'yearly'
  IntColumn get customInterval => integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get nextExecutionDate => dateTime()();
  TextColumn get status => text().withDefault(
    const Constant('active'),
  )(); // 'active', 'paused', 'completed'
  TextColumn get notes => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  BoolColumn get notifyBefore => boolean().withDefault(const Constant(false))();
  TextColumn get reminderTiming => text().withDefault(
    const Constant('same_day'),
  )(); // 'day_before', 'same_day'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_exec_log_recurring_id',
  columns: {#recurringTransactionId},
)
class RecurringExecutionLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recurringTransactionId => text().references(
    RecurringTransactions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  DateTimeColumn get executedAt => dateTime()();
  TextColumn get status => text()(); // 'success', 'failed'
  IntColumn get transactionId => integer().nullable().references(
    Transactions,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get errorMessage => text().nullable()();
}

@TableIndex(name: 'idx_goals_user_id', columns: {#userId})
@TableIndex(name: 'idx_goals_status', columns: {#status})
@TableIndex(name: 'idx_goals_linked_wallet', columns: {#linkedWalletId})
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get targetAmount => real()();
  RealColumn get currentAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get icon => text()();
  TextColumn get color => text()();
  TextColumn get linkedWalletId =>
      text().nullable().references(Wallets, #id, onDelete: KeyAction.setNull)();
  TextColumn get trackingMode => text()(); // 'manual' or 'wallet'
  TextColumn get status => text().withDefault(
    const Constant('active'),
  )(); // 'active', 'completed', 'archived'
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get notifiedMilestones =>
      text().withDefault(const Constant(''))(); // comma-separated: "25,50,75"
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_goal_deposits_goal_id', columns: {#goalId})
class GoalDeposits extends Table {
  TextColumn get id => text()();
  TextColumn get goalId =>
      text().references(Goals, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_budget_alerts_user_created',
  columns: {#userId, #createdAt},
)
class BudgetAlerts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get alertType =>
      text()(); // 'threshold', 'prediction', 'over_budget'
  IntColumn get thresholdValue => integer().nullable()();
  RealColumn get actualPercentage => real()();
  TextColumn get message => text()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_alert_prefs_user', columns: {#userId})
class BudgetAlertPreferences extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get thresholds => text()(); // JSON encoded: "[50,75,90,100]"
  BoolColumn get predictionsEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get quietHoursStart => text().nullable()(); // "HH:mm" format
  TextColumn get quietHoursEnd => text().nullable()(); // "HH:mm" format

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_threshold_status_user_cat_month',
  columns: {#userId, #categoryId, #budgetMonth},
)
class BudgetAlertThresholdStatus extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text()();
  TextColumn get budgetMonth => text()(); // 'YYYY-MM'
  IntColumn get thresholdValue => integer()();
  DateTimeColumn get triggeredAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Wallets,
    Categories,
    Transactions,
    Budgets,
    RecurringTransactions,
    RecurringExecutionLogs,
    Goals,
    GoalDeposits,
    BudgetAlerts,
    BudgetAlertPreferences,
    BudgetAlertThresholdStatus,
  ],
  daos: [RecurringTransactionDao, GoalDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor for testing — accepts a custom [QueryExecutor] (e.g. NativeDatabase.memory()).
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // Seed default categories
      final defaultCategories = [
        CategoriesCompanion.insert(
          id: 'food',
          userId: AppConstants.defaultUserId,
          name: 'Food',
          icon: const Value('restaurant'),
          color: const Value('#FF9800'),
          type: 'expense',
          createdAt: DateTime.now(),
        ),
        CategoriesCompanion.insert(
          id: 'transport',
          userId: AppConstants.defaultUserId,
          name: 'Transport',
          icon: const Value('directions_car'),
          color: const Value('#2196F3'),
          type: 'expense',
          createdAt: DateTime.now(),
        ),
        CategoriesCompanion.insert(
          id: 'salary',
          userId: AppConstants.defaultUserId,
          name: 'Salary',
          icon: const Value('attach_money'),
          color: const Value('#4CAF50'),
          type: 'income',
          createdAt: DateTime.now(),
        ),
        CategoriesCompanion.insert(
          id: 'bills',
          userId: AppConstants.defaultUserId,
          name: 'Bills',
          icon: const Value('receipt'),
          color: const Value('#F44336'),
          type: 'expense',
          createdAt: DateTime.now(),
        ),
        CategoriesCompanion.insert(
          id: 'shopping',
          userId: AppConstants.defaultUserId,
          name: 'Shopping',
          icon: const Value('shopping_bag'),
          color: const Value('#E91E63'),
          type: 'expense',
          createdAt: DateTime.now(),
        ),
      ];

      for (final category in defaultCategories) {
        await into(categories).insert(category);
      }
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(budgets);
      }
      if (from < 3) {
        // Add userId column to budgets table
        await m.addColumn(budgets, budgets.userId);
        // Create indexes using Drift's type-safe API
        await m.createIndex(idxWalletsUserId);
        await m.createIndex(idxCategoriesUserId);
        await m.createIndex(idxTransactionsUserDate);
        await m.createIndex(idxBudgetsUserId);
      }
      if (from < 4) {
        // Schema v4: No structural changes — regenerated .g.dart to fix
        // stale column alias references in JOIN queries.
        // Force re-create indexes to ensure consistency.
        await m.createIndex(idxWalletsUserId);
        await m.createIndex(idxCategoriesUserId);
        await m.createIndex(idxTransactionsUserDate);
        await m.createIndex(idxBudgetsUserId);
      }
      if (from < 5) {
        // Schema v5: Add recurring transactions feature
        await m.addColumn(transactions, transactions.badge);
        await m.createTable(recurringTransactions);
        await m.createTable(recurringExecutionLogs);
        await m.createIndex(idxRecurringUserId);
        await m.createIndex(idxRecurringNextExecution);
        await m.createIndex(idxExecLogRecurringId);
      }
      if (from < 6) {
        // Schema v6: Add financial goals feature
        await m.createTable(goals);
        await m.createTable(goalDeposits);
        await m.createIndex(idxGoalsUserId);
        await m.createIndex(idxGoalsStatus);
        await m.createIndex(idxGoalsLinkedWallet);
        await m.createIndex(idxGoalDepositsGoalId);
      }
      if (from < 7) {
        // Schema v7: Add smart budget alerts feature
        await m.createTable(budgetAlerts);
        await m.createTable(budgetAlertPreferences);
        await m.createTable(budgetAlertThresholdStatus);
        await m.createIndex(idxBudgetAlertsUserCreated);
        await m.createIndex(idxAlertPrefsUser);
        await m.createIndex(idxThresholdStatusUserCatMonth);
      }
      if (from < 8) {
        // Schema v8: One-time balance recalculation to fix drift from
        // background recurring executor not adjusting wallet balances.
        await customStatement('''
              UPDATE wallets SET balance = (
                SELECT COALESCE(
                  (SELECT SUM(amount) FROM transactions
                   WHERE type = 'income' AND wallet_id = wallets.id), 0)
                  -
                  COALESCE(
                  (SELECT SUM(amount) FROM transactions
                   WHERE type = 'expense' AND wallet_id = wallets.id), 0)
                  +
                  COALESCE(
                  (SELECT SUM(amount) FROM transactions
                   WHERE type = 'transfer' AND to_wallet_id = wallets.id), 0)
                  -
                  COALESCE(
                  (SELECT SUM(amount) FROM transactions
                   WHERE type = 'transfer' AND from_wallet_id = wallets.id), 0)
              )
            ''');
      }
      if (from < 9) {
        // Schema v9: Add coordinates (latitude and longitude) to transactions
        await m.addColumn(transactions, transactions.latitude);
        await m.addColumn(transactions, transactions.longitude);
      }
    },
  );
}

bool _isValidUuid(String? uuid) {
  if (uuid == null) return false;
  final uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$'
  );
  return uuidRegex.hasMatch(uuid);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'duasaku_offline.sqlite'));

    // Secure storage setup
    const secureStorage = FlutterSecureStorage();
    String? dbKey = await secureStorage.read(key: 'db_key');
    
    if (dbKey != null && !_isValidUuid(dbKey)) {
      throw ArgumentError('Invalid database key format');
    }

    if (await file.exists()) {
      if (dbKey == null) {
        // Deteksi apakah database eksisting adalah plaintext
        bool isPlaintext = false;
        sqlite.Database? rawDb;
        try {
          rawDb = sqlite.sqlite3.open(file.path);
          // Jalankan user_version untuk memverifikasi plaintext
          rawDb.select('PRAGMA user_version;');
          isPlaintext = true;
        } catch (_) {
          isPlaintext = false;
        } finally {
          rawDb?.close();
        }

        if (isPlaintext) {
          // Migrasi plaintext ke SQLCipher
          dbKey = const Uuid().v4();
          
          // Validate key format before SQL execution (prevent SQL injection)
          if (!_isValidUuid(dbKey)) {
            throw ArgumentError('Generated database key has invalid format');
          }
          
          final tempFile = File('${file.path}.tmp_encrypted');
          if (await tempFile.exists()) {
            await tempFile.delete();
          }

          final dbToEncrypt = sqlite.sqlite3.open(file.path);
          try {
            dbToEncrypt.execute("ATTACH DATABASE '${tempFile.path}' AS encrypted KEY '$dbKey';");
            dbToEncrypt.execute("SELECT sqlcipher_export('encrypted');");
            dbToEncrypt.execute("DETACH DATABASE encrypted;");
          } finally {
            dbToEncrypt.close();
          }

          // Gantikan file lama dengan file terenkripsi
          await file.delete();
          await tempFile.rename(file.path);

          // Simpan key baru ke SecureStorage
          await secureStorage.write(key: 'db_key', value: dbKey);
        } else {
          // Database file exist, tapi bukan plaintext, dan key tidak ada di SecureStorage.
          // Ini adalah kegagalan pemulihan key. Tapi untuk mengizinkan pembuatan baru, kita buat key baru.
          dbKey = const Uuid().v4();
          await secureStorage.write(key: 'db_key', value: dbKey);
        }
      }
    } else {
      // Database baru (belum ada file)
      if (dbKey == null) {
        dbKey = const Uuid().v4();
        await secureStorage.write(key: 'db_key', value: dbKey);
      }
    }

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Atur kunci enkripsi untuk SQLCipher
        db.execute("PRAGMA key = '$dbKey';");
        db.execute('PRAGMA foreign_keys = ON;');
        db.execute('PRAGMA journal_mode = WAL;');
      },
    );
  });
}
