import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/utils/amount_extractor.dart';

void main() {
  group('AmountExtractor Tests', () {
    test('extracts pure integer amount', () {
      final result = AmountExtractor.extractAmount('beli makan 25000');
      expect(result.amount, equals(25000.0));
      expect(result.textWithoutAmount, equals('beli makan'));
    });

    test('extracts amount with dot thousand separator', () {
      final result = AmountExtractor.extractAmount('belanja 50.000');
      expect(result.amount, equals(50000.0));
      expect(result.textWithoutAmount, equals('belanja'));
    });

    test('extracts amount with Rp prefix', () {
      final result = AmountExtractor.extractAmount('bayar Rp25000');
      expect(result.amount, equals(25000.0));
      expect(result.textWithoutAmount, equals('bayar'));
    });

    test('extracts amount with Rp. prefix and dot separator', () {
      final result = AmountExtractor.extractAmount('makan Rp. 25.000');
      expect(result.amount, equals(25000.0));
      expect(result.textWithoutAmount, equals('makan'));
    });

    test('extracts amount with IDR prefix and k suffix', () {
      final result = AmountExtractor.extractAmount('langganan IDR 25k');
      expect(result.amount, equals(25000.0));
      expect(result.textWithoutAmount, equals('langganan'));
    });

    test('extracts amount with rb suffix', () {
      final result = AmountExtractor.extractAmount('makan 15rb');
      expect(result.amount, equals(15000.0));
      expect(result.textWithoutAmount, equals('makan'));
    });

    test('extracts amount with decimal and jt suffix', () {
      final result = AmountExtractor.extractAmount('gaji 5.5jt');
      expect(result.amount, equals(5500000.0));
      expect(result.textWithoutAmount, equals('gaji'));
    });

    test('extracts amount with comma decimal and jt suffix', () {
      final result = AmountExtractor.extractAmount('gaji 5,5jt');
      expect(result.amount, equals(5500000.0));
      expect(result.textWithoutAmount, equals('gaji'));
    });

    test('extracts amount with juta suffix', () {
      final result = AmountExtractor.extractAmount('beli laptop 10 juta');
      expect(result.amount, equals(10000000.0));
      expect(result.textWithoutAmount, equals('beli laptop'));
    });

    test('prioritizes currency prefix over plain numbers', () {
      final result = AmountExtractor.extractAmount('beli 2 kopi Rp 50.000');
      expect(result.amount, equals(50000.0));
      expect(result.textWithoutAmount, equals('beli 2 kopi'));
    });

    test('prioritizes suffix over plain numbers', () {
      final result = AmountExtractor.extractAmount('beli 5 bakso 75k');
      expect(result.amount, equals(75000.0));
      expect(result.textWithoutAmount, equals('beli 5 bakso'));
    });

    test('prioritizes larger nominal when scores are tied', () {
      final result = AmountExtractor.extractAmount('beli 25000 dan 50000');
      expect(result.amount, equals(50000.0));
      expect(result.textWithoutAmount, equals('beli 25000 dan'));
    });

    test('returns 0.0 amount and original text if no number is found', () {
      final result = AmountExtractor.extractAmount('beli kopi manis');
      expect(result.amount, equals(0.0));
      expect(result.textWithoutAmount, equals('beli kopi manis'));
    });

    test('handles empty input gracefully', () {
      final result = AmountExtractor.extractAmount('   ');
      expect(result.amount, equals(0.0));
      expect(result.textWithoutAmount, equals(''));
    });
  });
}
