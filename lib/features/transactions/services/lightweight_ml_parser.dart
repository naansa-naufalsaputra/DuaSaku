import '../../../core/utils/amount_extractor.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../../../services/models/category_info.dart';
import '../../../services/models/parsed_transaction.dart';
import '../../../services/models/wallet_info.dart';
import '../domain/transaction_parser_service_interface.dart';
import 'lightweight_ml_weights.dart';

/// Pure Dart statistical classification parser (Level 2).
///
/// Uses term weighting to predict transaction intents and categories
/// entirely offline without external native dependencies.
class LightweightMlParser implements TransactionParserServiceInterface {
  const LightweightMlParser();

  @override
  Future<ParsedTransaction> parseTransaction({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) async {
    // 1. Extract amount using Regex extractor
    final amountResult = AmountExtractor.extractAmount(inputText);
    final double amount = amountResult.amount;
    final String cleanText = amountResult.textWithoutAmount;

    // 2. Tokenize and sanitize words
    final String sanitized = TextSanitizer.sanitize(cleanText);
    final List<String> tokens = sanitized
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // 3. Classify Intent (Income vs Expense)
    double intentScore = 0.0;
    for (final token in tokens) {
      if (LightweightMlWeights.intentWeights.containsKey(token)) {
        intentScore += LightweightMlWeights.intentWeights[token]!;
      }
    }
    // Positive score -> income, otherwise expense
    final String type = intentScore > 0.0 ? 'income' : 'expense';

    // 4. Classify Category
    String bestCategoryName = '';
    double maxCategoryScore = -999.0;
    final Map<String, double> scores = {};

    for (final category in categories) {
      final String catKey = category.name;
      double score = 0.0;

      // Add weights for matched tokens
      if (LightweightMlWeights.categoryWeights.containsKey(catKey)) {
        final Map<String, double> weights =
            LightweightMlWeights.categoryWeights[catKey]!;
        for (final token in tokens) {
          if (weights.containsKey(token)) {
            score += weights[token]!;
          }
        }
      }

      scores[catKey] = score;

      if (score > maxCategoryScore) {
        maxCategoryScore = score;
        bestCategoryName = catKey;
      }
    }

    // Fallback: If no category matches (max score is 0.0), choose standard defaults based on type
    if (maxCategoryScore <= 0.0) {
      // Find a category matching the type
      final matches = categories.where((c) => c.type.toLowerCase() == type);
      if (matches.isNotEmpty) {
        bestCategoryName = matches.first.name;
      } else if (categories.isNotEmpty) {
        bestCategoryName = categories.first.name;
      } else {
        bestCategoryName = type == 'income' ? 'Gaji' : 'Makanan';
      }
    }

    // 5. Match Wallet if present in input text
    String? matchedWalletId;
    for (final wallet in wallets) {
      final name = wallet.name.toLowerCase();
      if (inputText.toLowerCase().contains(name)) {
        matchedWalletId = wallet.id;
        break;
      }
    }

    // If no direct name match, fall back to type keywords
    if (matchedWalletId == null && wallets.isNotEmpty) {
      for (final wallet in wallets) {
        final wType = wallet.type.toLowerCase();
        if (wType == 'cash' &&
            (tokens.contains('cash') ||
                tokens.contains('tunai') ||
                tokens.contains('dompet'))) {
          matchedWalletId = wallet.id;
          break;
        } else if ((wType == 'e-wallet' || wType == 'ewallet') &&
            (tokens.contains('gopay') ||
                tokens.contains('ovo') ||
                tokens.contains('dana') ||
                tokens.contains('spay') ||
                tokens.contains('shopeepay'))) {
          matchedWalletId = wallet.id;
          break;
        } else if (wType == 'bank' &&
            (tokens.contains('bank') ||
                tokens.contains('rekening') ||
                tokens.contains('transfer') ||
                tokens.contains('mandiri') ||
                tokens.contains('bca') ||
                tokens.contains('bri') ||
                tokens.contains('bni'))) {
          matchedWalletId = wallet.id;
          break;
        }
      }
    }

    return ParsedTransaction(
      amount: amount,
      category: bestCategoryName,
      type: type,
      walletId: matchedWalletId,
      notes: TextSanitizer.prettifyNotes(
        cleanText.isNotEmpty ? cleanText : inputText,
      ),
    );
  }
}
