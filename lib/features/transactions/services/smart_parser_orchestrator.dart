import 'package:flutter/foundation.dart';
import '../../../core/utils/amount_extractor.dart';
import '../../../services/models/category_info.dart';
import '../../../services/models/parsed_transaction.dart';
import '../../../services/models/wallet_info.dart';
import '../../../services/smart_input_ml_service.dart';
import '../domain/transaction_parser_service_interface.dart';
import 'tflite_transaction_parser_service.dart';
import 'local_transaction_parser_service.dart';
import 'lightweight_ml_parser.dart';

/// An orchestrator that attempts Level 3 TF Lite parsing and gracefully
/// falls back to Level 2 Lightweight ML parsing, then to Level 1 Regex/Fuzzy
/// parsing, and finally integrates Level 4 ML Kit date/time extraction.
class SmartParserOrchestrator implements TransactionParserServiceInterface {
  final TfliteTransactionParserService tfliteService;
  final LocalTransactionParserService localService;
  final LightweightMlParser lightweightMlService;
  final SmartInputMlService mlService;
  final Duration timeout;

  SmartParserOrchestrator({
    required this.tfliteService,
    required this.localService,
    this.lightweightMlService = const LightweightMlParser(),
    required this.mlService,
    this.timeout = const Duration(seconds: 3),
  });

  @override
  Future<ParsedTransaction> parseTransaction({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) async {
    ParsedTransaction baseResult;

    // 1. Run Level 3 TFLite parser FIRST
    try {
      baseResult = await tfliteService
          .parseTransaction(
            inputText: inputText,
            wallets: wallets,
            categories: categories,
          )
          .timeout(timeout);
    } catch (e, stackTrace) {
      debugPrint(
        '[SmartParserOrchestrator] TFLite parsing failed, falling back to Level 2 Lightweight ML: $e',
      );
      if (kDebugMode) {
        debugPrint('[SmartParserOrchestrator] Stacktrace: $stackTrace');
      }

      // 2. Try Level 2 Lightweight ML parser fallback
      try {
        baseResult = await lightweightMlService.parseTransaction(
          inputText: inputText,
          wallets: wallets,
          categories: categories,
        );
      } catch (e2) {
        debugPrint(
          '[SmartParserOrchestrator] Level 2 Lightweight ML failed, falling back to Level 1 Regex/Fuzzy: $e2',
        );
        // 3. Fallback to Level 1 Local Regex/Fuzzy parser
        baseResult = localService.parseTransactionSync(
          inputText: inputText,
          wallets: wallets,
          categories: categories,
        );
      }
    }

    // 4. Extract remaining text without amount/slang tokens
    final extraction = AmountExtractor.extractAmount(inputText);
    final textWithoutAmount = extraction.textWithoutAmount;

    // 5. Translate and extract the DateTime using ML Kit
    DateTime? extractedDate;
    try {
      extractedDate = await mlService
          .extractDateTime(textWithoutAmount)
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint(
        '[SmartParserOrchestrator] ML Kit date extraction failed or timed out: $e',
      );
    }

    // 6. Fallback to DateTime.now() if no date is extracted or if models aren't ready
    final finalDate = extractedDate ?? DateTime.now();

    return ParsedTransaction(
      amount: baseResult.amount,
      categoryId: baseResult.categoryId,
      type: baseResult.type,
      walletId: baseResult.walletId,
      notes: baseResult.notes,
      date: finalDate,
    );
  }
}
