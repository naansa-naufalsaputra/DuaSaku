import '../../../services/models/category_info.dart';
import '../../../services/models/parsed_transaction.dart';
import '../../../services/models/wallet_info.dart';

/// Contract interface for transaction parsing services.
///
/// Both the Level 1 Regex/Fuzzy parser and the Level 3 TFLite parser
/// implement this interface to enable dynamic switching in providers.
abstract class TransactionParserServiceInterface {
  /// Parses raw text input into a structured [ParsedTransaction].
  Future<ParsedTransaction> parseTransaction({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  });
}
