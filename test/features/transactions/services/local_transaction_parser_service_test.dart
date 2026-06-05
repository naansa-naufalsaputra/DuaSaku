import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/features/transactions/services/local_transaction_parser_service.dart';
import 'package:duasaku_app/services/models/wallet_info.dart';
import 'package:duasaku_app/services/models/category_info.dart';

void main() {
  group('LocalTransactionParserService Tests', () {
    final parserService = LocalTransactionParserService();

    final wallets = [
      const WalletInfo(id: 'w-cash', name: 'Cash Wallet', type: 'cash'),
      const WalletInfo(id: 'w-bca', name: 'BCA Rekening', type: 'bank'),
    ];

    final categories = [
      const CategoryInfo(name: 'Makanan', type: 'expense'),
      const CategoryInfo(name: 'Transportasi', type: 'expense'),
      const CategoryInfo(name: 'Tagihan', type: 'expense'),
      const CategoryInfo(name: 'Gaji', type: 'income'),
    ];

    test(
      'parses basic transaction with amount, intent, wallet, and synonym category',
      () async {
        final result = await parserService.parseTransaction(
          inputText: 'beli pertalite Rp 25.000 cash',
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(25000.0));
        expect(result.type, equals('expense'));
        expect(result.walletId, equals('w-cash'));
        // "pertalite" maps to "Transportasi" via CategorySynonymDictionary
        expect(result.category, equals('Transportasi'));
        // Notes should have amount and wallet prefix stripped but keep contextual words
        expect(result.notes, equals('Beli pertalite cash'));
      },
    );

    test('parses income transaction and maps correct category', () async {
      final result = await parserService.parseTransaction(
        inputText: 'dapat bonus gaji bca 5jt',
        wallets: wallets,
        categories: categories,
      );

      expect(result.amount, equals(5000000.0));
      expect(result.type, equals('income'));
      expect(result.walletId, equals('w-bca'));
      // "gaji" maps to "Gaji" or falls back logically
      expect(result.category, equals('Gaji'));
      expect(result.notes, equals('Dapat bonus gaji bca'));
    });

    test(
      'falls back to fuzzy category matching when synonyms do not match',
      () async {
        // "makan" is not in synonym map but has high Levenshtein similarity to "Makanan"
        final result = await parserService.parseTransaction(
          inputText: 'makan siang 15k',
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(15000.0));
        expect(result.category, equals('Makanan'));
        expect(result.notes, equals('Makan siang'));
      },
    );

    test(
      'falls back to default type category if similarity is below threshold',
      () async {
        final result = await parserService.parseTransaction(
          inputText: 'sesuatu yang aneh 20000',
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(20000.0));
        // "sesuatu yang aneh" has low similarity to Makanan/Transportasi/Tagihan.
        // Falls back to the first category that matches type 'expense' (Makanan).
        expect(result.category, equals('Makanan'));
        expect(result.notes, equals('Sesuatu yang aneh'));
      },
    );
  });
}
