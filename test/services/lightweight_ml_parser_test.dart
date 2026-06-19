import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/features/transactions/services/lightweight_ml_parser.dart';
import 'package:duasaku_app/services/models/category_info.dart';
import 'package:duasaku_app/services/models/wallet_info.dart';

void main() {
  group('LightweightMlParser Test Suite', () {
    late LightweightMlParser parser;
    late List<WalletInfo> mockWallets;
    late List<CategoryInfo> mockCategories;

    setUp(() {
      parser = const LightweightMlParser();

      mockWallets = [
        const WalletInfo(id: 'w1', name: 'Cash', type: 'cash'),
        const WalletInfo(id: 'w2', name: 'BCA', type: 'bank'),
        const WalletInfo(id: 'w3', name: 'GoPay', type: 'e-wallet'),
      ];

      mockCategories = [
        const CategoryInfo(name: 'Makanan', type: 'expense'),
        const CategoryInfo(name: 'Gaji', type: 'income'),
        const CategoryInfo(name: 'Transportasi', type: 'expense'),
        const CategoryInfo(name: 'Belanja', type: 'expense'),
        const CategoryInfo(name: 'Tagihan', type: 'expense'),
        const CategoryInfo(name: 'Hiburan', type: 'expense'),
      ];
    });

    test(
      'should parse simple expense transaction (Makanan) and extract amount',
      () async {
        final result = await parser.parseTransaction(
          inputText: 'makan bakso kemarin habis 35.000 rupiah pakai Cash',
          wallets: mockWallets,
          categories: mockCategories,
        );

        expect(result.amount, equals(35000.0));
        expect(result.type, equals('expense'));
        expect(result.categoryId, equals('Makanan'));
        expect(result.walletId, equals('w1')); // Match Cash wallet
      },
    );

    test(
      'should parse simple income transaction (Gaji) with transfer details',
      () async {
        final result = await parser.parseTransaction(
          inputText: 'dapet transferan uang gajian masuk 5.500.000 ke bca',
          wallets: mockWallets,
          categories: mockCategories,
        );

        expect(result.amount, equals(5500000.0));
        expect(result.type, equals('income'));
        expect(result.categoryId, equals('Gaji'));
        expect(result.walletId, equals('w2')); // Match BCA wallet
      },
    );

    test(
      'should parse shopping transaction (Belanja) with suffix amount',
      () async {
        final result = await parser.parseTransaction(
          inputText: 'checkout baju baru di shopee abis 120k',
          wallets: mockWallets,
          categories: mockCategories,
        );

        expect(result.amount, equals(120000.0));
        expect(result.type, equals('expense'));
        expect(result.categoryId, equals('Belanja'));
      },
    );

    test('should fallback to default category if no weights match', () async {
      final result = await parser.parseTransaction(
        inputText: 'sesuatu yang aneh habis 50000',
        wallets: mockWallets,
        categories: mockCategories,
      );

      expect(result.amount, equals(50000.0));
      expect(result.type, equals('expense'));
      // Fallback expense category should be Makanan
      expect(result.categoryId, equals('Makanan'));
    });
  });
}
