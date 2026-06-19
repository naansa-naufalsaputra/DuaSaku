import '../features/transactions/services/local_transaction_parser_service.dart';
import 'models/parsed_transaction.dart';
import 'models/wallet_info.dart';
import 'models/category_info.dart';

/// Legacy compatible wrapper for the new offline [LocalTransactionParserService].
///
/// Extends the offline parser to allow drop-in replacement without breaking
/// type signatures or existing tests that invoke `parseLocally`.
class TransactionParserService extends LocalTransactionParserService {
  // Ignore the GeminiService parameter to make the parser 100% offline
  TransactionParserService([dynamic geminiService]);

  /// Fallback parsing method retained for backward compatibility in existing tests.
  ParsedTransaction parseLocally({
    required String text,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) {
    final result = parseTransactionSync(
      inputText: text,
      wallets: wallets,
      categories: categories,
    );

    // Legacy behavior required that if no amount was found, it defaulted to 50000.0
    if (result.amount == 0.0) {
      return ParsedTransaction(
        amount: 50000.0,
        categoryId: result.categoryId,
        type: result.type,
        walletId: result.walletId,
        notes: result.notes,
      );
    }
    return result;
  }
}
