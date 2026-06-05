// Feature: system-audit-fixes, Property 7: Repository failures produce AsyncError state without throwing
// **Validates: Requirements 10.1, 10.2, 10.3**

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

import 'package:duasaku_app/core/utils/app_error.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/transactions/domain/models/transaction_model.dart';
import 'package:duasaku_app/features/transactions/domain/transaction_repository_interface.dart';
import 'package:duasaku_app/features/transactions/providers/transaction_provider.dart';
import 'package:duasaku_app/features/auth/providers/auth_provider.dart';
import 'package:duasaku_app/features/auth/data/auth_repository.dart';
import 'package:duasaku_app/services/service_providers.dart';
import 'package:duasaku_app/services/transaction_parser_service.dart';

// ---------------------------------------------------------------------------
// Fake repository that returns configurable Failure results.
// ---------------------------------------------------------------------------

class FakeFailingTransactionRepository implements TransactionRepositoryInterface {
  final AppError errorToReturn;

  FakeFailingTransactionRepository(this.errorToReturn);

  @override
  Stream<List<TransactionModel>> fetchTransactions(String userId) {
    return Stream.value([]);
  }

  @override
  Future<Result<void, AppError>> insertTransaction(TransactionModel transaction) async {
    return Failure(errorToReturn);
  }

  @override
  Future<Result<void, AppError>> deleteTransaction(int id) async {
    return Failure(errorToReturn);
  }

  @override
  @Deprecated('Deprecated in interface')
  Future<void> syncPendingTransactions() async {}
}

// ---------------------------------------------------------------------------
// Helper: create an AppError from an integer index (0-3) and a seed
// ---------------------------------------------------------------------------

AppError _createAppError(int typeIndex, int messageSeed) {
  final messages = [
    'Error_$messageSeed',
    'Resource not found: item_$messageSeed',
    'DB constraint violation #$messageSeed',
    'Validation failed for field_$messageSeed',
    'Unknown failure code=$messageSeed',
    'Network timeout after ${messageSeed}ms',
    'Permission denied for user_$messageSeed',
    'Conflict on record_$messageSeed',
  ];
  final message = messages[messageSeed % messages.length];

  switch (typeIndex % 4) {
    case 0:
      return AppError.notFound(message);
    case 1:
      return AppError.database(message);
    case 2:
      return AppError.validation(message);
    case 3:
      return AppError.unknown(message);
    default:
      return AppError.unknown(message);
  }
}

// ---------------------------------------------------------------------------
// Helper: create a ProviderContainer with all necessary overrides
// ---------------------------------------------------------------------------

ProviderContainer _createTestContainer(AppError errorToReturn) {
  final fakeRepo = FakeFailingTransactionRepository(errorToReturn);
  final dummyParser = TransactionParserService();

  return ProviderContainer(
    overrides: [
      transactionRepositoryProvider.overrideWithValue(fakeRepo),
      userProvider.overrideWithValue(
        User(id: 'test-user', email: 'test@example.com'),
      ),
      transactionParserServiceProvider.overrideWithValue(dummyParser),
    ],
  );
}

// ---------------------------------------------------------------------------
// Helper: wait for the notifier to finish building (initial stream emission)
// ---------------------------------------------------------------------------

Future<void> _waitForInitialization(ProviderContainer container) async {
  await container.read(transactionNotifierProvider.future);
}

// ---------------------------------------------------------------------------
// Helper: create a TransactionModel from seed values
// ---------------------------------------------------------------------------

TransactionModel _createTransaction(int seed) {
  final types = ['income', 'expense', 'transfer'];
  final type = types[seed.abs() % 3];
  final amount = (seed.abs() % 9999 + 1).toDouble() + (seed.abs() % 100) / 100.0;

  return TransactionModel(
    id: seed.abs() + 1,
    userId: 'test-user',
    amount: amount,
    category: 'Category_${seed.abs() % 10}',
    type: type,
    notes: 'Note_$seed',
    createdAt: DateTime(2024, 1, (seed.abs() % 28) + 1),
    walletId: 'wallet-${seed.abs() % 5}',
    fromWalletId: type == 'transfer' ? 'wallet-${seed.abs() % 5}' : null,
    toWalletId: type == 'transfer' ? 'wallet-${(seed.abs() + 1) % 5}' : null,
  );
}

// ---------------------------------------------------------------------------
// Property-based tests
// ---------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group(
    'Feature: system-audit-fixes, '
    'Property 7: Repository failures produce AsyncError state without throwing',
    () {
      // Property 7a: addTransaction sets AsyncError state without throwing
      // for any AppError type
      Glados2(
        any.intInRange(0, 3), // error type index: notFound, database, validation, unknown
        any.intInRange(0, 99), // message seed for variety
        ExploreConfig(numRuns: 100),
      ).test(
        'addTransaction sets AsyncError state and does NOT throw for any AppError',
        (errorTypeIndex, messageSeed) async {
          final appError = _createAppError(errorTypeIndex, messageSeed);
          final container = _createTestContainer(appError);

          try {
            // Wait for the notifier to fully initialize
            await _waitForInitialization(container);

            final notifier = container.read(transactionNotifierProvider.notifier);

            // Verify initial state is loaded (AsyncData)
            final initialState = container.read(transactionNotifierProvider);
            expect(initialState.hasValue, isTrue,
                reason: 'Initial state should be AsyncData');

            // Create a test transaction
            final transaction = _createTransaction(messageSeed);

            // Call addTransaction — should NOT throw
            Object? caughtError;
            try {
              await notifier.addTransaction(transaction);
            } catch (e) {
              caughtError = e;
            }

            // Verify: no exception was thrown
            expect(caughtError, isNull,
                reason: 'addTransaction should not throw on Failure');

            // Verify: state is AsyncError
            final resultState = container.read(transactionNotifierProvider);
            expect(resultState, isA<AsyncError<List<TransactionModel>>>(),
                reason: 'State should be AsyncError after Failure');

            // Verify: the error in state matches the generated AppError
            expect(resultState.error, same(appError),
                reason: 'Error in state should be the same AppError instance');
          } finally {
            container.dispose();
          }
        },
      );

      // Property 7b: deleteTransaction sets AsyncError state without throwing
      // for any AppError type
      Glados2(
        any.intInRange(0, 3), // error type index
        any.intInRange(1, 999), // transaction ID to delete
        ExploreConfig(numRuns: 100),
      ).test(
        'deleteTransaction sets AsyncError state and does NOT throw for any AppError',
        (errorTypeIndex, transactionId) async {
          final appError = _createAppError(errorTypeIndex, transactionId);
          final container = _createTestContainer(appError);

          try {
            // Wait for the notifier to fully initialize
            await _waitForInitialization(container);

            final notifier = container.read(transactionNotifierProvider.notifier);

            // Verify initial state is loaded
            final initialState = container.read(transactionNotifierProvider);
            expect(initialState.hasValue, isTrue,
                reason: 'Initial state should be AsyncData');

            // Call deleteTransaction — should NOT throw
            Object? caughtError;
            try {
              await notifier.deleteTransaction(transactionId);
            } catch (e) {
              caughtError = e;
            }

            // Verify: no exception was thrown
            expect(caughtError, isNull,
                reason: 'deleteTransaction should not throw on Failure');

            // Verify: state is AsyncError
            final resultState = container.read(transactionNotifierProvider);
            expect(resultState, isA<AsyncError<List<TransactionModel>>>(),
                reason: 'State should be AsyncError after Failure');

            // Verify: the error in state matches the generated AppError
            expect(resultState.error, same(appError),
                reason: 'Error in state should be the same AppError instance');
          } finally {
            container.dispose();
          }
        },
      );

      // Property 7c: Both addTransaction and deleteTransaction produce
      // AsyncError for all AppError subtypes with varied transaction data
      Glados2(
        any.intInRange(0, 3), // error type index
        any.intInRange(0, 199), // seed for transaction data variety
        ExploreConfig(numRuns: 100),
      ).test(
        'both add and delete produce AsyncError for any AppError and transaction combination',
        (errorTypeIndex, seed) async {
          final rng = Random(seed);
          final messageSeed = rng.nextInt(100);
          final appError = _createAppError(errorTypeIndex, messageSeed);
          final transaction = _createTransaction(seed);

          // Test addTransaction
          final addContainer = _createTestContainer(appError);
          try {
            await _waitForInitialization(addContainer);

            final addNotifier =
                addContainer.read(transactionNotifierProvider.notifier);

            Object? addError;
            try {
              await addNotifier.addTransaction(transaction);
            } catch (e) {
              addError = e;
            }

            expect(addError, isNull,
                reason: 'addTransaction must not throw');
            final addState = addContainer.read(transactionNotifierProvider);
            expect(addState, isA<AsyncError<List<TransactionModel>>>(),
                reason: 'addTransaction state should be AsyncError');
            expect(addState.error, same(appError),
                reason: 'addTransaction error should match');
          } finally {
            addContainer.dispose();
          }

          // Test deleteTransaction
          final delContainer = _createTestContainer(appError);
          try {
            await _waitForInitialization(delContainer);

            final delNotifier =
                delContainer.read(transactionNotifierProvider.notifier);

            Object? delError;
            try {
              await delNotifier.deleteTransaction(transaction.id ?? 1);
            } catch (e) {
              delError = e;
            }

            expect(delError, isNull,
                reason: 'deleteTransaction must not throw');
            final delState = delContainer.read(transactionNotifierProvider);
            expect(delState, isA<AsyncError<List<TransactionModel>>>(),
                reason: 'deleteTransaction state should be AsyncError');
            expect(delState.error, same(appError),
                reason: 'deleteTransaction error should match');
          } finally {
            delContainer.dispose();
          }
        },
      );
    },
  );
}
