import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/features/transactions/services/smart_parser_orchestrator.dart';
import 'package:duasaku_app/features/transactions/services/tflite_transaction_parser_service.dart';
import 'package:duasaku_app/features/transactions/services/local_transaction_parser_service.dart';
import 'package:duasaku_app/services/models/parsed_transaction.dart';
import 'package:duasaku_app/services/models/wallet_info.dart';
import 'package:duasaku_app/services/models/category_info.dart';
import 'package:duasaku_app/services/smart_input_ml_service.dart';
import 'package:duasaku_app/features/transactions/services/lightweight_ml_parser.dart';

class MockTfliteParser extends TfliteTransactionParserService {
  final bool shouldThrow;
  final Duration? delay;
  final ParsedTransaction? mockResult;

  MockTfliteParser({this.shouldThrow = false, this.delay, this.mockResult});

  @override
  Future<ParsedTransaction> parseTransaction({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) async {
    if (delay != null) {
      await Future.delayed(delay!);
    }
    if (shouldThrow) {
      throw Exception('TFLite failure simulation');
    }
    return mockResult ??
        const ParsedTransaction(
          amount: 999.0,
          categoryId: 'Makanan',
          type: 'expense',
          notes: 'parsed_by_tflite',
        );
  }
}

class MockMlService implements SmartInputMlService {
  final DateTime? mockDate;

  MockMlService({this.mockDate});

  @override
  Future<void> initializeSilently() async {}

  @override
  Future<DateTime?> extractDateTime(
    String text, {
    DateTime? referenceDate,
  }) async {
    return mockDate;
  }

  @override
  Future<void> close() async {}
}

class MockLightweightMlParser extends LightweightMlParser {
  final bool shouldThrow;
  final ParsedTransaction? mockResult;

  const MockLightweightMlParser({this.shouldThrow = false, this.mockResult});

  @override
  Future<ParsedTransaction> parseTransaction({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) async {
    if (shouldThrow) {
      throw Exception('Lightweight ML failure simulation');
    }
    return mockResult ??
        const ParsedTransaction(
          amount: 888.0,
          categoryId: 'Makanan',
          type: 'expense',
          notes: 'parsed_by_lightweight_ml',
        );
  }
}

void main() {
  group('SmartParserOrchestrator Fallback Tests', () {
    final wallets = [
      const WalletInfo(id: 'w-cash', name: 'Cash', type: 'cash'),
    ];
    final categories = [const CategoryInfo(name: 'Makanan', type: 'expense')];

    test('should return TFLite result when TFLite succeeds', () async {
      final mockTflite = MockTfliteParser(
        mockResult: const ParsedTransaction(
          amount: 50000.0,
          categoryId: 'Makanan',
          type: 'expense',
          notes: 'nasi goreng',
        ),
      );
      final localService = LocalTransactionParserService();
      final mockMl = MockMlService();
      final orchestrator = SmartParserOrchestrator(
        tfliteService: mockTflite,
        localService: localService,
        mlService: mockMl,
      );

      final result = await orchestrator.parseTransaction(
        inputText: 'nasi goreng 50k',
        wallets: wallets,
        categories: categories,
      );

      expect(result.amount, equals(50000.0));
      expect(result.notes, equals('nasi goreng'));
    });

    test(
      'should fallback to Local Regex parser when TFLite throws exception',
      () async {
        final mockTflite = MockTfliteParser(shouldThrow: true);
        final localService = LocalTransactionParserService();
        final mockMl = MockMlService();
        final orchestrator = SmartParserOrchestrator(
          tfliteService: mockTflite,
          localService: localService,
          mlService: mockMl,
        );

        // We expect this not to throw, but to successfully fallback to local
        final result = await orchestrator.parseTransaction(
          inputText: 'nasi goreng 50k',
          wallets: wallets,
          categories: categories,
        );

        // Local parser should parse 50k as 50000.0
        expect(result.amount, equals(50000.0));
        expect(result.categoryId, equals('Makanan'));
      },
    );

    test('should fallback to Local Regex parser when TFLite times out', () async {
      // Delay is 1.5 seconds, but timeout threshold is 500ms
      final mockTflite = MockTfliteParser(
        delay: const Duration(milliseconds: 1500),
      );
      final localService = LocalTransactionParserService();
      final mockMl = MockMlService();
      final orchestrator = SmartParserOrchestrator(
        tfliteService: mockTflite,
        localService: localService,
        mlService: mockMl,
        timeout: const Duration(milliseconds: 500),
      );

      final result = await orchestrator.parseTransaction(
        inputText: 'nasi goreng 50k',
        wallets: wallets,
        categories: categories,
      );

      // TFLite timed out, so result must be parsed by local service (50k -> 50000.0)
      expect(result.amount, equals(50000.0));
      expect(result.categoryId, equals('Makanan'));
    });

    test(
      'should fallback to Lightweight ML parser when TFLite throws exception',
      () async {
        final mockTflite = MockTfliteParser(shouldThrow: true);
        const mockLwMl = MockLightweightMlParser(
          mockResult: ParsedTransaction(
            amount: 75000.0,
            categoryId: 'Makanan',
            type: 'expense',
            notes: 'parsed_by_lightweight_ml',
          ),
        );
        final localService = LocalTransactionParserService();
        final mockMl = MockMlService();
        final orchestrator = SmartParserOrchestrator(
          tfliteService: mockTflite,
          localService: localService,
          lightweightMlService: mockLwMl,
          mlService: mockMl,
        );

        final result = await orchestrator.parseTransaction(
          inputText: 'makan bakso 75k',
          wallets: wallets,
          categories: categories,
        );

        expect(result.amount, equals(75000.0));
        expect(result.categoryId, equals('Makanan'));
        expect(result.notes, equals('parsed_by_lightweight_ml'));
      },
    );

    test(
      'should fallback to Local Regex parser when both TFLite and Lightweight ML throw exceptions',
      () async {
        final mockTflite = MockTfliteParser(shouldThrow: true);
        const mockLwMl = MockLightweightMlParser(shouldThrow: true);
        final localService = LocalTransactionParserService();
        final mockMl = MockMlService();
        final orchestrator = SmartParserOrchestrator(
          tfliteService: mockTflite,
          localService: localService,
          lightweightMlService: mockLwMl,
          mlService: mockMl,
        );

        final result = await orchestrator.parseTransaction(
          inputText: 'makan bakso 75k',
          wallets: wallets,
          categories: categories,
        );

        // Both failed, so local parser should resolve it (75k -> 75000.0)
        expect(result.amount, equals(75000.0));
        expect(result.categoryId, equals('Makanan'));
      },
    );
  });
}
