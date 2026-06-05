import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/services/receipt_scanner_service.dart';
import 'package:duasaku_app/features/transactions/domain/transaction_parser_service_interface.dart';
import 'package:mockito/mockito.dart';

class MockTransactionParserService extends Mock
    implements TransactionParserServiceInterface {}

void main() {
  late ReceiptScannerServiceImpl scanner;

  setUp(() {
    scanner = ReceiptScannerServiceImpl(MockTransactionParserService());
  });

  group('ReceiptScannerServiceImpl - Merchant Name Extraction', () {
    test('Extracts merchant name and ignores addresses and phone numbers', () {
      final lines = [
        'ALFAMART JALAN RAYA',
        'Jl. Kaliurang KM 5 Sleman',
        'Telp: +62 812-3456-7890',
        'Nota: 12345',
        'Total: 50000',
      ];
      final merchant = scanner.extractMerchantName(lines);
      expect(merchant, 'ALFAMART JALAN RAYA');
    });

    test('Strips leading/trailing non-alphanumeric noise symbols', () {
      final lines = [
        '=== WARKOP CAHYO ===',
        'Sleman, Yogyakarta',
        'Total: 15000',
      ];
      final merchant = scanner.extractMerchantName(lines);
      expect(merchant, 'WARKOP CAHYO');
    });

    test('Falls back to default if all top lines are noise', () {
      final lines = ['Jl. Kaliurang KM 5', 'Telp: 081234', 'www.alfamart.com'];
      final merchant = scanner.extractMerchantName(lines);
      expect(merchant, 'Struk Belanja');
    });
  });

  group('ReceiptScannerServiceImpl - Date Extraction', () {
    test('Parses numeric dates (DD/MM/YYYY)', () {
      final lines = ['TGL: 15/06/2026 12:30', 'TOTAL: 50000'];
      final date = scanner.extractDate(lines);
      expect(date.year, 2026);
      expect(date.month, 6);
      expect(date.day, 15);
    });

    test('Parses numeric dates with hyphens (DD-MM-YY)', () {
      final lines = ['Date: 05-12-26', 'Total: 25000'];
      final date = scanner.extractDate(lines);
      expect(date.year, 2026);
      expect(date.month, 12);
      expect(date.day, 5);
    });

    test('Parses Indonesian word-based dates (DD Month YYYY)', () {
      final lines = ['Yogyakarta, 25 Mei 2026', 'Total: 75000'];
      final date = scanner.extractDate(lines);
      expect(date.year, 2026);
      expect(date.month, 5);
      expect(date.day, 25);
    });

    test('Falls back to DateTime.now() if no date is found', () {
      final lines = ['No date here', 'Total: 75000'];
      final beforeTest = DateTime.now();
      final date = scanner.extractDate(lines);
      final afterTest = DateTime.now();
      expect(
        date.isAfter(beforeTest.subtract(const Duration(seconds: 1))),
        true,
      );
      expect(date.isBefore(afterTest.add(const Duration(seconds: 1))), true);
    });
  });

  group('ReceiptScannerServiceImpl - Total Amount Extraction', () {
    test(
      'Extracts correct total adjacent to total keyword with high confidence',
      () {
        final lines = [
          'Kopi Kenangan',
          'Espresso: 25.000',
          'Croissant: 30.000',
          'TOTAL: 55.000',
          'CASH: 100.000',
        ];
        final (amount, lowConfidence) = scanner.extractTotalAmount(lines);
        expect(amount, 55000.0);
        expect(lowConfidence, false);
      },
    );

    test(
      'Sanitizes OCR errors replacing O/o with 0 inside digit structures',
      () {
        final lines = [
          'Starbucks Coffee',
          'Grand Total: Rp 7O.OOO', // O instead of 0
          'Bayar: 1OO.ooo', // o instead of 0
        ];
        final (amount, lowConfidence) = scanner.extractTotalAmount(lines);
        expect(amount, 70000.0);
        expect(lowConfidence, false);
      },
    );

    test('Correctly handles colloquial ooo representing 000', () {
      final lines = ['TOTAL: 15.ooo'];
      final (amount, _) = scanner.extractTotalAmount(lines);
      expect(amount, 15000.0);
    });

    test('Parses English decimal thousands and ignores cents', () {
      final lines = ['TOTAL: 125,500.00'];
      final (amount, _) = scanner.extractTotalAmount(lines);
      expect(amount, 125500.0);
    });

    test('Parses Indonesian thousand dots and decimal commas', () {
      final lines = ['TOTAL: Rp 125.500,00'];
      final (amount, _) = scanner.extractTotalAmount(lines);
      expect(amount, 125500.0);
    });

    test(
      'Falls back to the largest valid number if no keyword matches, set lowConfidence to true',
      () {
        final lines = [
          'Item A: 12.000',
          'Item B: 85.000', // Largest number, no total keyword
          'No Label here',
        ];
        final (amount, lowConfidence) = scanner.extractTotalAmount(lines);
        expect(amount, 85000.0);
        expect(lowConfidence, true);
      },
    );

    test('Excludes years and barcode ids from fallbacks', () {
      final lines = [
        'Tahun 2026',
        'Item A: 15.000',
        'Serial: 9988776655', // Too large
        'Qty: 1', // Too small
      ];
      final (amount, lowConfidence) = scanner.extractTotalAmount(lines);
      expect(amount, 15000.0);
      expect(lowConfidence, true);
    });

    test('Returns 0.0 with low confidence if no numbers found', () {
      final lines = ['Starbucks Coffee', 'No prices listed'];
      final (amount, lowConfidence) = scanner.extractTotalAmount(lines);
      expect(amount, 0.0);
      expect(lowConfidence, true);
    });
  });
}
