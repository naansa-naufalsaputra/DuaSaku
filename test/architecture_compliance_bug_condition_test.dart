import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import the actual source files to inspect types and structure
import 'package:duasaku_app/features/wallets/providers/wallet_provider.dart';

/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8**
///
/// Bug Condition Exploration Test - Architecture Violations Exist in Unfixed Code
///
/// This test is EXPECTED TO FAIL on unfixed code. Failure confirms the violations exist.
/// DO NOT attempt to fix the test or the code when it fails.
void main() {
  group('Bug Condition: Architecture Violations Exist in Unfixed Code', () {
    // Violation 1: walletProvider should be AsyncNotifierProvider
    // **Validates: Requirements 1.1**
    test(
      'Violation 1: walletProvider is an AsyncNotifierProvider (not StateNotifierProvider)',
      () {
        // On unfixed code, walletProvider is a StateNotifierProvider
        // This assertion should FAIL, confirming the violation exists
        expect(
          walletProvider,
          isA<AsyncNotifierProvider>(),
          reason:
              'walletProvider should be AsyncNotifierProvider but is StateNotifierProvider',
        );
      },
    );

    // Violation 2: parseSmartText return type should be ParsedTransaction
    // **Validates: Requirements 1.2**
    test(
      'Violation 2: TransactionNotifier.parseSmartText() return type is ParsedTransaction',
      () {
        // Read the source file and check that parseSmartText returns ParsedTransaction
        final sourceFile = File(
          'lib/features/transactions/providers/transaction_provider.dart',
        );
        final content = sourceFile.readAsStringSync();

        // On unfixed code, the method signature is:
        // Future<Map<String, dynamic>> parseSmartText(String text)
        // It should be: Future<ParsedTransaction> parseSmartText(String text)
        expect(
          content.contains('Future<ParsedTransaction> parseSmartText'),
          isTrue,
          reason:
              'parseSmartText should return ParsedTransaction but returns Map<String, dynamic>',
        );
        expect(
          content.contains('Future<Map<String, dynamic>> parseSmartText'),
          isFalse,
          reason: 'parseSmartText should NOT return Map<String, dynamic>',
        );
      },
    );

    // Violation 3: WalletRepository should use Result pattern for error handling
    // **Validates: Requirements 1.3**
    test(
      'Violation 3: WalletRepository.createWallet() returns Result.failure for errors (not rethrow)',
      () {
        final sourceFile = File(
          'lib/features/wallets/data/wallet_repository.dart',
        );
        final content = sourceFile.readAsStringSync();

        // On unfixed code, createWallet uses rethrow
        // It should use Result<void, AppError> return type
        expect(
          content.contains('Result<'),
          isTrue,
          reason:
              'WalletRepository should use Result<T, AppError> pattern but uses rethrow',
        );
        expect(
          content.contains('rethrow'),
          isFalse,
          reason:
              'WalletRepository should NOT use rethrow for expected failures',
        );
      },
    );

    // Violation 4: SecurityWrapper should use .tr() localization
    // **Validates: Requirements 1.4**
    test(
      'Violation 4: SecurityWrapper time-tamper strings use .tr() localization keys',
      () {
        final sourceFile = File('lib/main.dart');
        final content = sourceFile.readAsStringSync();

        // On unfixed code, hardcoded Indonesian strings are present
        // They should use .tr() localization keys instead
        expect(
          content.contains("'Deteksi Manipulasi Waktu!'"),
          isFalse,
          reason:
              'SecurityWrapper should NOT contain hardcoded string "Deteksi Manipulasi Waktu!"',
        );
        expect(
          content.contains("'Periksa Kembali'"),
          isFalse,
          reason:
              'SecurityWrapper should NOT contain hardcoded string "Periksa Kembali"',
        );
        expect(
          content.contains('.tr()'),
          isTrue,
          reason:
              'SecurityWrapper should use .tr() localization keys for user-facing strings',
        );
      },
    );

    // Violation 5: No source file should contain literal 'local_user' outside constants
    // **Validates: Requirements 1.5**
    test(
      'Violation 5: No source file contains literal local_user string outside constants file',
      () {
        final appDatabaseFile = File('lib/core/local_db/app_database.dart');
        final authRepoFile = File(
          'lib/features/auth/data/auth_repository.dart',
        );

        final dbContent = appDatabaseFile.readAsStringSync();
        final authContent = authRepoFile.readAsStringSync();

        // On unfixed code, 'local_user' is hardcoded in both files
        // It should only exist in a constants file (AppConstants.defaultUserId)
        // Count occurrences of 'local_user' as a string literal (not in a constant definition)
        final dbMatches = RegExp(r"'local_user'").allMatches(dbContent).length;
        final authMatches = RegExp(
          r"'local_user'",
        ).allMatches(authContent).length;

        expect(
          dbMatches,
          equals(0),
          reason:
              'app_database.dart should NOT contain hardcoded "local_user" literals (found $dbMatches)',
        );
        expect(
          authMatches,
          equals(0),
          reason:
              'auth_repository.dart should NOT contain hardcoded "local_user" literals (found $authMatches)',
        );
      },
    );

    // Violation 6: WalletRepository methods should have @override annotations
    // **Validates: Requirements 1.6**
    test('Violation 6: WalletRepository methods have @override annotations', () {
      final sourceFile = File(
        'lib/features/wallets/data/wallet_repository.dart',
      );
      final content = sourceFile.readAsStringSync();

      // On unfixed code, @override annotations are missing
      // Check that each interface method has @override
      final methods = [
        'getWallets',
        'watchWallets',
        'createWallet',
        'updateWallet',
        'deleteWallet',
      ];

      for (final method in methods) {
        // Look for @override immediately before the method declaration
        // Use a pattern that handles nested generics (e.g., Future<Result<List<T>, E>>)
        final pattern = RegExp(
          '@override\\s+(?:Future|Stream)<[^(]+>\\s+$method',
        );
        expect(
          pattern.hasMatch(content),
          isTrue,
          reason: 'WalletRepository.$method should have @override annotation',
        );
      }
    });

    // Violation 7: syncPendingTransactions should have @Deprecated annotation
    // **Validates: Requirements 1.7**
    test(
      'Violation 7: syncPendingTransactions() has @Deprecated annotation or doc comment',
      () {
        final interfaceFile = File(
          'lib/features/transactions/domain/transaction_repository_interface.dart',
        );
        final implFile = File(
          'lib/features/transactions/data/transaction_repository.dart',
        );

        final interfaceContent = interfaceFile.readAsStringSync();
        final implContent = implFile.readAsStringSync();

        // On unfixed code, syncPendingTransactions has no @Deprecated annotation
        // and no doc comment explaining the intentional no-op
        expect(
          interfaceContent.contains('@Deprecated'),
          isTrue,
          reason:
              'syncPendingTransactions in interface should have @Deprecated annotation',
        );

        // Check implementation also has documentation
        final hasDocComment =
            implContent.contains('/// ') &&
            implContent.contains('syncPendingTransactions');
        final hasDeprecated = implContent.contains('@Deprecated');

        expect(
          hasDocComment || hasDeprecated,
          isTrue,
          reason:
              'syncPendingTransactions implementation should have doc comment or @Deprecated',
        );
      },
    );

    // Violation 8: Features should have abstract interfaces in domain/
    // **Validates: Requirements 1.8**
    test(
      'Violation 8: Features auth, insights, gamification, geofencing, profile have domain interfaces',
      () {
        final features = [
          'auth',
          'insights',
          'gamification',
          'geofencing',
          'profile',
        ];

        for (final feature in features) {
          final domainDir = Directory('lib/features/$feature/domain');
          expect(
            domainDir.existsSync(),
            isTrue,
            reason: 'Feature "$feature" should have a domain/ directory',
          );

          if (domainDir.existsSync()) {
            // Check for at least one abstract interface file
            final dartFiles = domainDir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.endsWith('_interface.dart'))
                .toList();
            expect(
              dartFiles.isNotEmpty,
              isTrue,
              reason:
                  'Feature "$feature" should have at least one abstract interface in domain/',
            );
          }
        }
      },
    );
  });
}
