import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/features/transactions/data/transaction_repository.dart';
import 'package:duasaku_app/features/transactions/domain/transaction_filters.dart';

void main() {
  late AppDatabase database;
  late TransactionRepository repository;
  const testUserId = 'test_user_001';

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepository(database);

    // Seed test data
    await _seedTestData(database, testUserId);
  });

  tearDown(() async {
    await database.close();
  });

  group('fetchTransactionsFiltered - Search Query', () {
    test('filters transactions by searchQuery in notes', () async {
      const filters = TransactionFilters(searchQuery: 'makan');

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(transactions.length, greaterThan(0));
      expect(
        transactions.every((t) => t.notes.toLowerCase().contains('makan')),
        isTrue,
      );
    });

    test('filters transactions by searchQuery in category', () async {
      const filters = TransactionFilters(searchQuery: 'food');

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(transactions.length, greaterThan(0));
      expect(
        transactions.every((t) => t.categoryId == 'category-1' || t.notes.toLowerCase().contains('food')),
        isTrue,
      );
    });
  });

  group('fetchTransactionsFiltered - Date Range', () {
    test('filters by startDate only', () async {
      final startDate = DateTime(2026, 6, 10);
      final filters = TransactionFilters(startDate: startDate);

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(
        transactions.every(
          (t) =>
              t.createdAt.isAfter(startDate) ||
              t.createdAt.isAtSameMomentAs(startDate),
        ),
        isTrue,
      );
    });

    test('filters by endDate only', () async {
      final endDate = DateTime(2026, 6, 15);
      final filters = TransactionFilters(endDate: endDate);

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(
        transactions.every(
          (t) =>
              t.createdAt.isBefore(endDate) ||
              t.createdAt.isAtSameMomentAs(endDate),
        ),
        isTrue,
      );
    });

    test('filters by date range (both startDate and endDate)', () async {
      final startDate = DateTime(2026, 6, 10);
      final endDate = DateTime(2026, 6, 15);
      final filters = TransactionFilters(
        startDate: startDate,
        endDate: endDate,
      );

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(
        transactions.every(
          (t) =>
              (t.createdAt.isAfter(startDate) ||
                  t.createdAt.isAtSameMomentAs(startDate)) &&
              (t.createdAt.isBefore(endDate) ||
                  t.createdAt.isAtSameMomentAs(endDate)),
        ),
        isTrue,
      );
    });
  });

  group('fetchTransactionsFiltered - Type Filter', () {
    test('filters by type: income', () async {
      const filters = TransactionFilters(type: 'income');

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(transactions.length, greaterThan(0));
      expect(transactions.every((t) => t.type == 'income'), isTrue);
    });

    test('filters by type: expense', () async {
      const filters = TransactionFilters(type: 'expense');

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(transactions.length, greaterThan(0));
      expect(transactions.every((t) => t.type == 'expense'), isTrue);
    });
  });

  group('fetchTransactionsFiltered - Amount Range', () {
    test('filters by minAmount', () async {
      const filters = TransactionFilters(minAmount: 50000);

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(transactions.every((t) => t.amount >= 50000), isTrue);
    });

    test('filters by maxAmount', () async {
      const filters = TransactionFilters(maxAmount: 100000);

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(transactions.every((t) => t.amount <= 100000), isTrue);
    });

    test('filters by amount range (both min and max)', () async {
      const filters = TransactionFilters(minAmount: 50000, maxAmount: 100000);

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      expect(
        transactions.every((t) => t.amount >= 50000 && t.amount <= 100000),
        isTrue,
      );
    });
  });

  group('fetchTransactionsFiltered - Combined Filters', () {
    test('applies multiple filters together (AND logic)', () async {
      const filters = TransactionFilters(
        searchQuery: 'makan',
        type: 'expense',
        minAmount: 20000,
        maxAmount: 100000,
      );

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      for (final t in transactions) {
        expect(t.notes.toLowerCase().contains('makan'), isTrue);
        expect(t.type, 'expense');
        expect(t.amount, greaterThanOrEqualTo(20000));
        expect(t.amount, lessThanOrEqualTo(100000));
      }
    });
  });

  group('fetchTransactionsFiltered - Empty Filters', () {
    test('returns all transactions when filters are empty', () async {
      const filters = TransactionFilters();

      final stream = repository.fetchTransactionsFiltered(
        testUserId,
        filters,
        100,
      );
      final transactions = await stream.first;

      // Should return all seeded transactions
      expect(transactions.length, greaterThanOrEqualTo(10));
    });
  });
}

Future<void> _seedTestData(AppDatabase db, String userId) async {
  // Create test user wallet
  const walletId = 'wallet-1';
  await db
      .into(db.wallets)
      .insert(
        WalletsCompanion.insert(
          id: walletId,
          userId: userId,
          name: 'Test Wallet',
          type: 'Cash',
          balance: const Value(1000000.0),
          currency: const Value('IDR'),
          icon: 'wallet',
          color: '#000000',
          createdAt: DateTime.now(),
        ),
      );

  // Create test category
  const categoryId = 'category-1';
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: categoryId,
          userId: userId,
          name: 'Food',
          type: 'expense',
          createdAt: DateTime.now(),
        ),
      );

  // Seed diverse transactions
  final testTransactions = [
    // Income
    {
      'notes': 'Salary June',
      'amount': 5000000.0,
      'type': 'income',
      'date': DateTime(2026, 6, 1),
    },
    {
      'notes': 'Freelance payment',
      'amount': 1500000.0,
      'type': 'income',
      'date': DateTime(2026, 6, 5),
    },

    // Expenses - Food related
    {
      'notes': 'Makan siang di resto',
      'amount': 75000.0,
      'type': 'expense',
      'date': DateTime(2026, 6, 10),
    },
    {
      'notes': 'Makan malam keluarga',
      'amount': 150000.0,
      'type': 'expense',
      'date': DateTime(2026, 6, 12),
    },
    {
      'notes': 'Grocery shopping',
      'amount': 350000.0,
      'type': 'expense',
      'date': DateTime(2026, 6, 14),
    },

    // Expenses - Other
    {
      'notes': 'Transport',
      'amount': 50000.0,
      'type': 'expense',
      'date': DateTime(2026, 6, 11),
    },
    {
      'notes': 'Electricity bill',
      'amount': 200000.0,
      'type': 'expense',
      'date': DateTime(2026, 6, 13),
    },
    {
      'notes': 'Internet subscription',
      'amount': 350000.0,
      'type': 'expense',
      'date': DateTime(2026, 6, 15),
    },

    // Varied amounts for range testing
    {
      'notes': 'Small expense',
      'amount': 15000.0,
      'type': 'expense',
      'date': DateTime(2026, 6, 16),
    },
    {
      'notes': 'Large expense',
      'amount': 500000.0,
      'type': 'expense',
      'date': DateTime(2026, 6, 17),
    },
  ];

  for (final tx in testTransactions) {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            userId: userId,
            amount: tx['amount'] as double,
            type: tx['type'] as String,
            notes: Value(tx['notes'] as String),
            date: tx['date'] as DateTime,
            walletId: const Value(walletId),
            categoryId: const Value(categoryId),
          ),
        );
  }
}
