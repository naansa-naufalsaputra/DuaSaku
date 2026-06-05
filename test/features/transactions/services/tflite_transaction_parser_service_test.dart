import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/features/transactions/services/tflite_transaction_parser_service.dart';

void main() {
  group('TfliteTransactionParserService Amount Parsing Tests', () {
    late TfliteTransactionParserService parserService;

    setUp(() {
      parserService = TfliteTransactionParserService();
    });

    test('should parse standard integer amounts without suffix', () {
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('25000'), equals(25000.0));
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('123456'), equals(123456.0));
    });

    test('should parse amounts with dots as thousands separators', () {
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('25.000'), equals(25000.0));
      // ignore: invalid_use_of_protected_member
      expect(
        parserService.parseExtractedAmount('1.000.000'),
        equals(1000000.0),
      );
    });

    test('should parse amounts with commas as thousands separators', () {
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('25,000'), equals(25000.0));
      // ignore: invalid_use_of_protected_member
      expect(
        parserService.parseExtractedAmount('1,000,000'),
        equals(1000000.0),
      );
    });

    test('should parse decimal amounts with suffix', () {
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('1.5jt'), equals(1500000.0));
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('1,5jt'), equals(1500000.0));
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('2.5 jt'), equals(2500000.0));
    });

    test('should parse standard multipliers (k, rb, ribu, jt, juta)', () {
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('25k'), equals(25000.0));
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('50rb'), equals(50000.0));
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('10ribu'), equals(10000.0));
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('2juta'), equals(2000000.0));
    });

    test('should fallback to 0.0 on completely invalid amount input', () {
      // ignore: invalid_use_of_protected_member
      expect(parserService.parseExtractedAmount('abc'), equals(0.0));
    });
  });
}
