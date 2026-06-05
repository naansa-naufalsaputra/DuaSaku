// Feature: recurring-transactions, Property 12: Dashboard Upcoming Query
// Feature: recurring-transactions, Property 5: Execution Creates Transaction and Log
// Feature: recurring-transactions, Property 6: Catch-Up Executes Missed Transactions
// Feature: recurring-transactions, Property 7: Paused Transactions Are Never Executed
// Feature: recurring-transactions, Property 9: No Duplicate Executions
// Feature: recurring-transactions, Property 11: Historical Transactions Immutability
// Feature: recurring-transactions, Property 14: Retry Logic

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/features/recurring_transactions/data/recurring_transaction_dao.dart';

/// Creates a fresh in-memory database with seeded wallet and category.
/// Returns the database and DAO. Caller is responsible for closing.
Future<(AppDatabase, RecurringTransactionDao)> _createTestDb() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final dao = db.recurringTransactionDao;

  // Seed required wallet and category for foreign key constraints
  await db
      .into(db.wallets)
      .insert(
        WalletsCompanion.insert(
          id: 'test-wallet',
          userId: 'test-user',
          name: 'Test Wallet',
          type: 'Cash',
          icon: 'wallet',
          color: '#000000',
          createdAt: DateTime(2023, 1, 1),
        ),
      );
  await db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: 'test-category',
          userId: 'test-user',
          name: 'Test Category',
          type: 'expense',
          createdAt: DateTime(2023, 1, 1),
        ),
      );

  return (db, dao);
}

/// Helper to insert a recurring transaction with a given nextExecutionDate.
Future<void> _insertRecurring(
  RecurringTransactionDao dao, {
  required String id,
  required DateTime nextExecutionDate,
  String status = 'active',
}) async {
  await dao.insertRecurring(
    RecurringTransactionsCompanion.insert(
      id: id,
      userId: 'test-user',
      walletId: 'test-wallet',
      categoryId: 'test-category',
      amount: 100.0,
      type: 'expense',
      frequency: 'monthly',
      startDate: DateTime(2023, 1, 1),
      nextExecutionDate: nextExecutionDate,
      status: Value(status),
    ),
  );
}

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // Property 12: Dashboard Upcoming Query
  // **Validates: Requirements 5.2**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 12: Dashboard Upcoming Query', () {
    // Property-based test: generate varying numbers of transactions with
    // different day offsets and verify the query constraints.
    Glados2(
      // Number of transactions to insert (1–15)
      any.intInRange(1, 15),
      // Seed for generating day offsets
      any.intInRange(0, 10000),
    ).test(
      'getUpcoming(days=7, limit=5) returns ≤5 results, all within 7 days, sorted ascending',
      (count, seed) async {
        final (db, dao) = await _createTestDb();
        try {
          // Use a reference time slightly in the past to avoid race conditions
          // between our captured "now" and the DAO's internal DateTime.now().
          final referenceNow = DateTime.now();
          // The DAO uses DateTime.now() internally, so results will have
          // nextExecutionDate >= DAO's now and <= DAO's now + 7 days.
          // We use a generous tolerance window for assertions.
          final toleranceBefore = referenceNow.subtract(
            const Duration(seconds: 5),
          );
          final toleranceAfter = referenceNow.add(
            const Duration(days: 7, seconds: 5),
          );

          // Generate day offsets: mix of within-range and out-of-range dates.
          // Use hour-level offsets to avoid boundary issues with seconds.
          for (var i = 0; i < count; i++) {
            // Generate offsets from -2 to +12 days relative to now (in hours)
            final hourOffset = ((seed + i * 37) % 336) - 48; // -48h to +288h
            final nextDate = referenceNow.add(Duration(hours: hourOffset));

            await _insertRecurring(
              dao,
              id: 'recurring-$i',
              nextExecutionDate: nextDate,
            );
          }

          final results = await dao.getUpcoming('test-user', 7, 5);

          // Property 1: At most 5 results
          expect(results.length, lessThanOrEqualTo(5));

          // Property 2: All results have nextExecutionDate within the valid window
          for (final r in results) {
            expect(
              r.nextExecutionDate.isBefore(toleranceAfter),
              isTrue,
              reason:
                  'nextExecutionDate ${r.nextExecutionDate} should be <= ~7 days from now',
            );
            // Must be >= approximately now (with tolerance for timing)
            expect(
              r.nextExecutionDate.isAfter(toleranceBefore),
              isTrue,
              reason:
                  'nextExecutionDate ${r.nextExecutionDate} should be >= ~now',
            );
          }

          // Property 3: Results are sorted in ascending order by nextExecutionDate
          for (var i = 1; i < results.length; i++) {
            expect(
              results[i].nextExecutionDate.isAfter(
                    results[i - 1].nextExecutionDate,
                  ) ||
                  results[i].nextExecutionDate.isAtSameMomentAs(
                    results[i - 1].nextExecutionDate,
                  ),
              isTrue,
              reason:
                  'Results should be sorted ascending: ${results[i - 1].nextExecutionDate} <= ${results[i].nextExecutionDate}',
            );
          }
        } finally {
          await db.close();
        }
      },
    );

    // Additional property test: only active transactions are returned
    Glados(any.intInRange(1, 10)).test(
      'getUpcoming only returns active transactions',
      (count) async {
        final (db, dao) = await _createTestDb();
        try {
          final now = DateTime.now();

          for (var i = 0; i < count; i++) {
            // Alternate between active and paused, all within 7 days
            final status = i.isEven ? 'active' : 'paused';
            final nextDate = now.add(Duration(days: (i % 6) + 1));

            await _insertRecurring(
              dao,
              id: 'recurring-$i',
              nextExecutionDate: nextDate,
              status: status,
            );
          }

          final results = await dao.getUpcoming('test-user', 7, 5);

          // All returned results must be active
          for (final r in results) {
            expect(r.status, equals('active'));
          }
        } finally {
          await db.close();
        }
      },
    );

    // Edge case: when more than 5 valid results exist, only 5 are returned
    test(
      'returns exactly 5 when more than 5 active transactions within range',
      () async {
        final (db, dao) = await _createTestDb();
        try {
          final now = DateTime.now();

          for (var i = 0; i < 10; i++) {
            await _insertRecurring(
              dao,
              id: 'recurring-$i',
              nextExecutionDate: now.add(Duration(hours: i + 1)),
            );
          }

          final results = await dao.getUpcoming('test-user', 7, 5);
          expect(results.length, equals(5));
        } finally {
          await db.close();
        }
      },
    );

    // Edge case: returns empty when no transactions within range
    test('returns empty when no transactions within 7 days', () async {
      final (db, dao) = await _createTestDb();
      try {
        final now = DateTime.now();

        await _insertRecurring(
          dao,
          id: 'recurring-far',
          nextExecutionDate: now.add(const Duration(days: 30)),
        );

        final results = await dao.getUpcoming('test-user', 7, 5);
        expect(results, isEmpty);
      } finally {
        await db.close();
      }
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 5: Execution Creates Transaction and Log (placeholder)
  // **Validates: Requirements 2.1, 5.1**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 5: Execution Creates Transaction and Log', () {
    // Placeholder for Property 5
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 6: Catch-Up Executes Missed Transactions Chronologically (placeholder)
  // **Validates: Requirements 2.2**
  // ──────────────────────────────────────────────────────────────────────────
  group(
    'Property 6: Catch-Up Executes Missed Transactions Chronologically',
    () {
      // Placeholder for Property 6
    },
  );

  // ──────────────────────────────────────────────────────────────────────────
  // Property 7: Paused Transactions Are Never Executed (placeholder)
  // **Validates: Requirements 2.3, 8.2**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 7: Paused Transactions Are Never Executed', () {
    // Placeholder for Property 7
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 9: No Duplicate Executions (placeholder)
  // **Validates: Requirements 8.1, 8.5**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 9: No Duplicate Executions', () {
    // Placeholder for Property 9
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 11: Historical Transactions Immutability (placeholder)
  // **Validates: Requirements 5.7, 8.3, 9.2**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 11: Historical Transactions Immutability', () {
    // Placeholder for Property 11
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Property 14: Retry Logic (placeholder)
  // **Validates: Requirements 2.7**
  // ──────────────────────────────────────────────────────────────────────────
  group('Property 14: Retry Logic', () {
    // Placeholder for Property 14
  });
}
