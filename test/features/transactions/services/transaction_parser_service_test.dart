// Feature: codebase-refactoring, Property 1: Amount Parsing Round-Trip
// **Validates: Requirements 13.4**
// Feature: codebase-refactoring, Property 2: Transaction Type Detection from Keywords
// **Validates: Requirements 13.1**

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    hide expect, group, test, setUp, setUpAll, tearDown, tearDownAll;

import 'package:duasaku_app/services/transaction_parser_service.dart';
import 'package:duasaku_app/services/models/wallet_info.dart';
import 'package:duasaku_app/services/models/category_info.dart';

void main() {
  final parserService = TransactionParserService();

  const wallets = [WalletInfo(id: 'w1', name: 'Cash', type: 'cash')];
  const categories = [CategoryInfo(name: 'Food', type: 'expense')];

  group('Property 1: Amount Parsing Round-Trip', () {
    Glados(any.intInRange(1, 100000)).test(
      'plain number format round-trips correctly',
      (baseAmount) {
        final formattedText = 'beli makan $baseAmount';
        final expectedAmount = baseAmount.toDouble();

        final result = parserService.parseLocally(
          text: formattedText,
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(expectedAmount));
      },
    );

    Glados(any.intInRange(1, 10000)).test(
      '"k" multiplier format round-trips correctly',
      (baseAmount) {
        final formattedText = 'beli makan ${baseAmount}k';
        final expectedAmount = baseAmount.toDouble() * 1000.0;

        final result = parserService.parseLocally(
          text: formattedText,
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(expectedAmount));
      },
    );

    Glados(any.intInRange(1, 10000)).test(
      '"rb" multiplier format round-trips correctly',
      (baseAmount) {
        final formattedText = 'beli makan ${baseAmount}rb';
        final expectedAmount = baseAmount.toDouble() * 1000.0;

        final result = parserService.parseLocally(
          text: formattedText,
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(expectedAmount));
      },
    );

    Glados(any.intInRange(1, 10000)).test(
      '"ribu" multiplier format round-trips correctly',
      (baseAmount) {
        final formattedText = 'beli makan ${baseAmount}ribu';
        final expectedAmount = baseAmount.toDouble() * 1000.0;

        final result = parserService.parseLocally(
          text: formattedText,
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(expectedAmount));
      },
    );

    Glados(any.intInRange(1, 1000)).test(
      '"jt" multiplier format round-trips correctly',
      (baseAmount) {
        final formattedText = 'beli makan ${baseAmount}jt';
        final expectedAmount = baseAmount.toDouble() * 1000000.0;

        final result = parserService.parseLocally(
          text: formattedText,
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(expectedAmount));
      },
    );

    Glados(any.intInRange(1, 1000)).test(
      '"juta" multiplier format round-trips correctly',
      (baseAmount) {
        final formattedText = 'beli makan ${baseAmount}juta';
        final expectedAmount = baseAmount.toDouble() * 1000000.0;

        final result = parserService.parseLocally(
          text: formattedText,
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(expectedAmount));
      },
    );
  });

  // --- Property 2: Transaction Type Detection from Keywords ---

  /// Income keywords as defined in TransactionParserService._parseType
  const incomeKeywords = [
    'gaji',
    'salary',
    'bonus',
    'pemasukan',
    'transfer masuk',
    'dapat uang',
    'income',
    'receh',
    'untung',
  ];

  /// Generator for a random base text that does NOT contain any income keywords.
  Generator<String> safeBaseText() {
    return any.lowercaseLetters.map((s) {
      var result = s;
      for (final kw in incomeKeywords) {
        if (result.contains(kw)) {
          result = result.replaceAll(kw, 'x' * kw.length);
        }
      }
      return result;
    });
  }

  /// Generator for text that contains at least one income keyword.
  final textWithIncomeKeyword = any.combine3(
    any.lowercaseLetters,
    any.choose(incomeKeywords),
    any.lowercaseLetters,
    (String prefix, String keyword, String suffix) {
      return '$prefix $keyword $suffix';
    },
  );

  /// Generator for text that does NOT contain any income keywords.
  final textWithoutIncomeKeyword = safeBaseText();

  group('Property 2: Transaction Type Detection from Keywords', () {
    Glados(textWithIncomeKeyword).test(
      'input containing an income keyword classifies as "income"',
      (text) {
        final result = parserService.parseLocally(
          text: text,
          wallets: wallets,
          categories: categories,
        );

        expect(result.type, equals('income'));
      },
    );

    Glados(textWithoutIncomeKeyword).test(
      'input without any income keyword classifies as "expense"',
      (text) {
        // Verify precondition: text should not contain any income keyword
        final containsIncomeKeyword = incomeKeywords.any(
          (kw) => text.toLowerCase().contains(kw),
        );
        // If by some chance the generated text contains a keyword, skip
        if (containsIncomeKeyword) return;

        final result = parserService.parseLocally(
          text: text,
          wallets: wallets,
          categories: categories,
        );

        expect(result.type, equals('expense'));
      },
    );
  });

  // =========================================================================
  // Example-Based Unit Tests (Task 10.2)
  // Validates: Requirements 13.1
  // =========================================================================

  group('Unit Tests: Amount Extraction', () {
    test('"50k" extracts as 50000', () {
      final result = parserService.parseLocally(
        text: 'beli makan 50k',
        wallets: wallets,
        categories: categories,
      );
      expect(result.amount, equals(50000.0));
    });

    test('"2jt" extracts as 2000000', () {
      final result = parserService.parseLocally(
        text: 'bayar cicilan 2jt',
        wallets: wallets,
        categories: categories,
      );
      expect(result.amount, equals(2000000.0));
    });

    test('"15rb" extracts as 15000', () {
      final result = parserService.parseLocally(
        text: 'beli kopi 15rb',
        wallets: wallets,
        categories: categories,
      );
      expect(result.amount, equals(15000.0));
    });

    test('"100000" extracts as 100000', () {
      final result = parserService.parseLocally(
        text: 'transfer 100000',
        wallets: wallets,
        categories: categories,
      );
      expect(result.amount, equals(100000.0));
    });

    test('"50.000" (thousand separator) extracts as 50000', () {
      final result = parserService.parseLocally(
        text: 'belanja 50.000',
        wallets: wallets,
        categories: categories,
      );
      expect(result.amount, equals(50000.0));
    });

    test('"3ribu" extracts as 3000', () {
      final result = parserService.parseLocally(
        text: 'parkir 3ribu',
        wallets: wallets,
        categories: categories,
      );
      expect(result.amount, equals(3000.0));
    });

    test('"1juta" extracts as 1000000', () {
      final result = parserService.parseLocally(
        text: 'gaji 1juta',
        wallets: wallets,
        categories: categories,
      );
      expect(result.amount, equals(1000000.0));
    });

    test('no amount defaults to 50000', () {
      final result = parserService.parseLocally(
        text: 'beli sesuatu',
        wallets: wallets,
        categories: categories,
      );
      expect(result.amount, equals(50000.0));
    });
  });

  group('Unit Tests: Type Detection', () {
    test('"gaji bulan ini" detects as income', () {
      final result = parserService.parseLocally(
        text: 'gaji bulan ini',
        wallets: wallets,
        categories: categories,
      );
      expect(result.type, equals('income'));
    });

    test('"beli kopi" detects as expense', () {
      final result = parserService.parseLocally(
        text: 'beli kopi 15rb',
        wallets: wallets,
        categories: categories,
      );
      expect(result.type, equals('expense'));
    });

    test('"bonus tahunan" detects as income', () {
      final result = parserService.parseLocally(
        text: 'bonus tahunan 5jt',
        wallets: wallets,
        categories: categories,
      );
      expect(result.type, equals('income'));
    });

    test('"salary" detects as income', () {
      final result = parserService.parseLocally(
        text: 'salary this month 10jt',
        wallets: wallets,
        categories: categories,
      );
      expect(result.type, equals('income'));
    });

    test('"makan siang" detects as expense', () {
      final result = parserService.parseLocally(
        text: 'makan siang 25rb',
        wallets: wallets,
        categories: categories,
      );
      expect(result.type, equals('expense'));
    });

    test('"pemasukan freelance" detects as income', () {
      final result = parserService.parseLocally(
        text: 'pemasukan freelance 2jt',
        wallets: wallets,
        categories: categories,
      );
      expect(result.type, equals('income'));
    });
  });

  group('Unit Tests: Wallet Matching', () {
    const testWallets = [
      WalletInfo(id: 'w-cash', name: 'Cash', type: 'cash'),
      WalletInfo(id: 'w-gopay', name: 'GoPay', type: 'e-wallet'),
      WalletInfo(id: 'w-bca', name: 'BCA', type: 'bank'),
    ];

    test('matches wallet by direct name ("gopay")', () {
      final result = parserService.parseLocally(
        text: 'bayar pakai gopay 50k',
        wallets: testWallets,
        categories: categories,
      );
      expect(result.walletId, equals('w-gopay'));
    });

    test('matches wallet by direct name ("bca")', () {
      final result = parserService.parseLocally(
        text: 'transfer bca 100k',
        wallets: testWallets,
        categories: categories,
      );
      expect(result.walletId, equals('w-bca'));
    });

    test('matches cash wallet by keyword "tunai"', () {
      final result = parserService.parseLocally(
        text: 'bayar tunai 20k',
        wallets: testWallets,
        categories: categories,
      );
      expect(result.walletId, equals('w-cash'));
    });

    test('matches e-wallet by keyword "ovo"', () {
      final result = parserService.parseLocally(
        text: 'bayar ovo 30k',
        wallets: testWallets,
        categories: categories,
      );
      expect(result.walletId, equals('w-gopay'));
    });

    test('matches bank wallet by keyword "rekening"', () {
      final result = parserService.parseLocally(
        text: 'transfer dari rekening 500k',
        wallets: testWallets,
        categories: categories,
      );
      expect(result.walletId, equals('w-bca'));
    });

    test('returns null when no wallet matches', () {
      final result = parserService.parseLocally(
        text: 'beli makan 25k',
        wallets: testWallets,
        categories: categories,
      );
      expect(result.walletId, isNull);
    });
  });

  group('Unit Tests: Category Matching', () {
    const testCategories = [
      CategoryInfo(name: 'Food', type: 'expense'),
      CategoryInfo(name: 'Transport', type: 'expense'),
      CategoryInfo(name: 'Bills', type: 'expense'),
      CategoryInfo(name: 'Shopping', type: 'expense'),
      CategoryInfo(name: 'Salary', type: 'income'),
      CategoryInfo(name: 'Entertainment', type: 'expense'),
    ];

    test('"beli bensin" matches Transport category', () {
      final result = parserService.parseLocally(
        text: 'beli bensin 50k',
        wallets: wallets,
        categories: testCategories,
      );
      expect(result.category, equals('Transport'));
    });

    test('"makan siang" matches Food category', () {
      final result = parserService.parseLocally(
        text: 'makan siang 25k',
        wallets: wallets,
        categories: testCategories,
      );
      expect(result.category, equals('Food'));
    });

    test('"bayar listrik" matches Bills category', () {
      final result = parserService.parseLocally(
        text: 'bayar listrik 200k',
        wallets: wallets,
        categories: testCategories,
      );
      expect(result.category, equals('Bills'));
    });

    test('"belanja baju" matches Shopping category', () {
      final result = parserService.parseLocally(
        text: 'belanja baju 150k',
        wallets: wallets,
        categories: testCategories,
      );
      expect(result.category, equals('Shopping'));
    });

    test('"gaji bulan ini" matches Salary category', () {
      final result = parserService.parseLocally(
        text: 'gaji bulan ini 10jt',
        wallets: wallets,
        categories: testCategories,
      );
      expect(result.category, equals('Salary'));
    });

    test('"nonton bioskop" matches Entertainment category', () {
      final result = parserService.parseLocally(
        text: 'nonton bioskop 50k',
        wallets: wallets,
        categories: testCategories,
      );
      expect(result.category, equals('Entertainment'));
    });

    test('"beli kopi starbucks" matches Food category', () {
      final result = parserService.parseLocally(
        text: 'beli kopi starbucks 45k',
        wallets: wallets,
        categories: testCategories,
      );
      expect(result.category, equals('Food'));
    });

    test('falls back to type-appropriate category when no keyword matches', () {
      final result = parserService.parseLocally(
        text: 'something random 10k',
        wallets: wallets,
        categories: testCategories,
      );
      // Should pick first expense category since type is expense
      expect(result.category, equals('Food'));
    });
  });
}
