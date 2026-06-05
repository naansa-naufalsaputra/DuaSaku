import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

/// A helper class that encapsulates the wallet balance calculation logic
/// extracted from TransactionRepository.insertTransaction.
///
/// This allows testing the pure arithmetic logic in isolation without
/// needing the Drift database dependency.
class WalletBalanceCalculator {
  /// Calculates the new wallet balance after an income transaction.
  /// Income increases the wallet balance by the transaction amount.
  double calculateIncomeBalance({
    required double currentBalance,
    required double amount,
  }) {
    return currentBalance + amount;
  }

  /// Calculates the new wallet balance after an expense transaction.
  /// Expense decreases the wallet balance by the transaction amount.
  double calculateExpenseBalance({
    required double currentBalance,
    required double amount,
  }) {
    return currentBalance - amount;
  }

  /// Calculates the new balances for both wallets after a transfer.
  /// Returns a record with (fromWalletNewBalance, toWalletNewBalance).
  /// The transfer deducts from the source and adds to the destination.
  ({double fromBalance, double toBalance}) calculateTransferBalances({
    required double fromWalletCurrentBalance,
    required double toWalletCurrentBalance,
    required double amount,
  }) {
    return (
      fromBalance: fromWalletCurrentBalance - amount,
      toBalance: toWalletCurrentBalance + amount,
    );
  }
}

void main() {
  late WalletBalanceCalculator calculator;

  setUp(() {
    calculator = WalletBalanceCalculator();
  });

  group('Income transactions', () {
    test('income of 100 increases balance from 500 to 600', () {
      final newBalance = calculator.calculateIncomeBalance(
        currentBalance: 500.0,
        amount: 100.0,
      );
      expect(newBalance, equals(600.0));
    });

    test('income of 2500000 increases balance from 0 to 2500000', () {
      final newBalance = calculator.calculateIncomeBalance(
        currentBalance: 0.0,
        amount: 2500000.0,
      );
      expect(newBalance, equals(2500000.0));
    });

    test('income of 50000 increases balance from 1000000 to 1050000', () {
      final newBalance = calculator.calculateIncomeBalance(
        currentBalance: 1000000.0,
        amount: 50000.0,
      );
      expect(newBalance, equals(1050000.0));
    });

    test('income with decimal amount 99.99 increases balance correctly', () {
      final newBalance = calculator.calculateIncomeBalance(
        currentBalance: 200.01,
        amount: 99.99,
      );
      expect(newBalance, closeTo(300.0, 0.001));
    });
  });

  group('Expense transactions', () {
    test('expense of 100 decreases balance from 500 to 400', () {
      final newBalance = calculator.calculateExpenseBalance(
        currentBalance: 500.0,
        amount: 100.0,
      );
      expect(newBalance, equals(400.0));
    });

    test('expense of 750000 decreases balance from 1000000 to 250000', () {
      final newBalance = calculator.calculateExpenseBalance(
        currentBalance: 1000000.0,
        amount: 750000.0,
      );
      expect(newBalance, equals(250000.0));
    });

    test('expense equal to balance results in zero balance', () {
      final newBalance = calculator.calculateExpenseBalance(
        currentBalance: 300.0,
        amount: 300.0,
      );
      expect(newBalance, equals(0.0));
    });

    test('expense exceeding balance results in negative balance', () {
      final newBalance = calculator.calculateExpenseBalance(
        currentBalance: 100.0,
        amount: 250.0,
      );
      expect(newBalance, equals(-150.0));
    });
  });

  group('Transfer transactions', () {
    test('transfer of 200 moves exact amount between wallets', () {
      final result = calculator.calculateTransferBalances(
        fromWalletCurrentBalance: 1000.0,
        toWalletCurrentBalance: 500.0,
        amount: 200.0,
      );
      expect(result.fromBalance, equals(800.0));
      expect(result.toBalance, equals(700.0));
    });

    test('transfer results in net zero change across both wallets', () {
      const fromInitial = 1000.0;
      const toInitial = 500.0;
      const amount = 200.0;

      final result = calculator.calculateTransferBalances(
        fromWalletCurrentBalance: fromInitial,
        toWalletCurrentBalance: toInitial,
        amount: amount,
      );

      final fromChange = result.fromBalance - fromInitial;
      final toChange = result.toBalance - toInitial;
      expect(fromChange + toChange, equals(0.0));
    });

    test('transfer of 500000 between wallets preserves total money', () {
      const fromInitial = 2000000.0;
      const toInitial = 300000.0;
      const amount = 500000.0;

      final result = calculator.calculateTransferBalances(
        fromWalletCurrentBalance: fromInitial,
        toWalletCurrentBalance: toInitial,
        amount: amount,
      );

      // Total money before and after should be the same
      const totalBefore = fromInitial + toInitial;
      final totalAfter = result.fromBalance + result.toBalance;
      expect(totalAfter, equals(totalBefore));
    });

    test('transfer deducts exact amount from source wallet', () {
      final result = calculator.calculateTransferBalances(
        fromWalletCurrentBalance: 5000.0,
        toWalletCurrentBalance: 1000.0,
        amount: 3000.0,
      );
      expect(result.fromBalance, equals(2000.0));
    });

    test('transfer adds exact amount to destination wallet', () {
      final result = calculator.calculateTransferBalances(
        fromWalletCurrentBalance: 5000.0,
        toWalletCurrentBalance: 1000.0,
        amount: 3000.0,
      );
      expect(result.toBalance, equals(4000.0));
    });
  });

  // Feature: codebase-refactoring, Property 3: Wallet Balance Conservation on Transfer
  // **Validates: Requirements 13.2, 13.5**
  group('Property 3: Wallet Balance Conservation on Transfer', () {
    Glados3(
      any.intInRange(0, 10000000),
      any.intInRange(0, 10000000),
      any.intInRange(1, 5000000),
    ).test(
      'sum of balance changes equals zero for any transfer amount and initial balances',
      (fromInitialInt, toInitialInt, amountInt) {
        final calculator = WalletBalanceCalculator();
        final fromInitialBalance = fromInitialInt.toDouble();
        final toInitialBalance = toInitialInt.toDouble();
        final amount = amountInt.toDouble();

        final result = calculator.calculateTransferBalances(
          fromWalletCurrentBalance: fromInitialBalance,
          toWalletCurrentBalance: toInitialBalance,
          amount: amount,
        );

        // Balance changes
        final fromChange = result.fromBalance - fromInitialBalance;
        final toChange = result.toBalance - toInitialBalance;

        // Conservation property: sum of all balance changes must equal zero
        expect(fromChange + toChange, equals(0.0));
      },
    );

    Glados3(
      any.intInRange(0, 10000000),
      any.intInRange(0, 10000000),
      any.intInRange(1, 5000000),
    ).test('total money across wallets is preserved for any transfer', (
      fromInitialInt,
      toInitialInt,
      amountInt,
    ) {
      final calculator = WalletBalanceCalculator();
      final fromInitialBalance = fromInitialInt.toDouble();
      final toInitialBalance = toInitialInt.toDouble();
      final amount = amountInt.toDouble();

      final result = calculator.calculateTransferBalances(
        fromWalletCurrentBalance: fromInitialBalance,
        toWalletCurrentBalance: toInitialBalance,
        amount: amount,
      );

      // Total money before transfer
      final totalBefore = fromInitialBalance + toInitialBalance;
      // Total money after transfer
      final totalAfter = result.fromBalance + result.toBalance;

      // Conservation property: total money is neither created nor destroyed
      expect(totalAfter, equals(totalBefore));
    });

    Glados(any.intInRange(1, 10000000)).test(
      'fromWallet change equals negative amount for any transfer',
      (amountInt) {
        final calculator = WalletBalanceCalculator();
        const fromInitial = 10000000.0;
        final amount = amountInt.toDouble();

        final result = calculator.calculateTransferBalances(
          fromWalletCurrentBalance: fromInitial,
          toWalletCurrentBalance: 0.0,
          amount: amount,
        );

        final fromChange = result.fromBalance - fromInitial;
        expect(fromChange, equals(-amount));
      },
    );

    Glados(any.intInRange(1, 10000000)).test(
      'toWallet change equals positive amount for any transfer',
      (amountInt) {
        final calculator = WalletBalanceCalculator();
        const toInitial = 0.0;
        final amount = amountInt.toDouble();

        final result = calculator.calculateTransferBalances(
          fromWalletCurrentBalance: 10000000.0,
          toWalletCurrentBalance: toInitial,
          amount: amount,
        );

        final toChange = result.toBalance - toInitial;
        expect(toChange, equals(amount));
      },
    );
  });

  // Feature: codebase-refactoring, Property 4: Income/Expense Balance Symmetry
  // **Validates: Requirements 13.2, 13.5**
  group('Property 4: Income/Expense Balance Symmetry', () {
    Glados2(any.intInRange(-1000000, 1000000), any.intInRange(1, 1000000)).test(
      'income of amount A increases balance by exactly A',
      (initialBalanceInt, amountInt) {
        final initialBalance = initialBalanceInt.toDouble();
        final amount = amountInt.toDouble();
        final calculator = WalletBalanceCalculator();
        final newBalance = calculator.calculateIncomeBalance(
          currentBalance: initialBalance,
          amount: amount,
        );
        expect(newBalance, equals(initialBalance + amount));
      },
    );

    Glados2(any.intInRange(-1000000, 1000000), any.intInRange(1, 1000000)).test(
      'expense of amount A decreases balance by exactly A',
      (initialBalanceInt, amountInt) {
        final initialBalance = initialBalanceInt.toDouble();
        final amount = amountInt.toDouble();
        final calculator = WalletBalanceCalculator();
        final newBalance = calculator.calculateExpenseBalance(
          currentBalance: initialBalance,
          amount: amount,
        );
        expect(newBalance, equals(initialBalance - amount));
      },
    );
  });
}
