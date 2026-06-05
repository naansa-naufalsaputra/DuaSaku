import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/transactions/domain/transaction_parser_service_interface.dart';
import '../features/transactions/domain/parser_mode.dart';
import '../features/transactions/providers/parser_mode_provider.dart';
import '../features/transactions/services/tflite_transaction_parser_service.dart';
import '../features/transactions/services/local_transaction_parser_service.dart';
import '../features/transactions/services/smart_parser_orchestrator.dart';
import '../features/transactions/services/lightweight_ml_parser.dart';
import 'smart_input_ml_service.dart';
import 'receipt_scanner_service.dart';

/// Provider for [SmartInputMlService] using the Google ML Kit implementation.
final smartInputMlServiceProvider = Provider<SmartInputMlService>((ref) {
  return SmartInputMlServiceImpl();
});

/// Provides a singleton [TransactionParserServiceInterface] with an orchestrated parsing strategy.
final transactionParserServiceProvider =
    Provider<TransactionParserServiceInterface>((ref) {
      final mode = ref.watch(parserModeProvider);
      final tfliteService = TfliteTransactionParserService();
      final localService = LocalTransactionParserService();
      final mlService = ref.watch(smartInputMlServiceProvider);

      switch (mode) {
        case ParserMode.tfliteOnly:
          return tfliteService;
        case ParserMode.regexOnly:
          return localService;
        case ParserMode.lightweightMlOnly:
          return const LightweightMlParser();
        case ParserMode.auto:
          return SmartParserOrchestrator(
            tfliteService: tfliteService,
            localService: localService,
            lightweightMlService: const LightweightMlParser(),
            mlService: mlService,
          );
      }
    });

/// Provides a singleton [ReceiptScannerService] configured with the active parser service.
final receiptScannerServiceProvider = Provider<ReceiptScannerService>((ref) {
  final parserService = ref.watch(transactionParserServiceProvider);
  return ReceiptScannerServiceImpl(parserService);
});
