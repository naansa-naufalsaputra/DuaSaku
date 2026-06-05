import '../../../services/models/parsed_transaction.dart';
import '../../../services/models/wallet_info.dart';
import '../../../services/models/category_info.dart';
import '../../../core/utils/amount_extractor.dart';
import '../../../core/utils/fuzzy_matcher.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../domain/transaction_parser_service_interface.dart';

/// Offline-first transaction parsing service.
///
/// Parses transaction details locally using Regex for amounts,
/// keyword-based intent classification, and fuzzy Levenshtein distance
/// with a synonym dictionary for category matching.
class LocalTransactionParserService implements TransactionParserServiceInterface {
  /// Parses transaction text locally (asynchronous version).
  @override
  Future<ParsedTransaction> parseTransaction({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) async {
    return parseTransactionSync(
      inputText: inputText,
      wallets: wallets,
      categories: categories,
    );
  }

  /// Parses transaction text locally (synchronous version).
  ParsedTransaction parseTransactionSync({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) {
    // 1. Extract Amount
    final amountResult = AmountExtractor.extractAmount(inputText);
    final amount = amountResult.amount;
    final textWithoutAmount = amountResult.textWithoutAmount;

    // 2. Sanitize Text (removes stop-words and punctuation)
    final sanitizedText = TextSanitizer.sanitize(textWithoutAmount);

    // 3. Classify Intent (income vs expense)
    final type = TextSanitizer.determineIntent(sanitizedText);

    // 4. Match Wallet
    final walletId = _matchWallet(sanitizedText, wallets);

    // 5. Match Category
    final category = _matchCategory(sanitizedText, type, categories);

    // Populate notes with sanitized text without amount (or original if empty)
    final notes = textWithoutAmount.isNotEmpty ? textWithoutAmount : inputText;

    return ParsedTransaction(
      amount: amount,
      category: category,
      type: type,
      walletId: walletId,
      notes: TextSanitizer.prettifyNotes(notes),
    );
  }

  /// Matches a wallet from the provided list based on text content.
  String? _matchWallet(String sanitizedText, List<WalletInfo> wallets) {
    // Try direct name match first
    for (final wallet in wallets) {
      final wName = wallet.name.toLowerCase();
      if (sanitizedText.contains(wName)) {
        return wallet.id;
      }
    }

    // Fall back to type-based keyword matching
    for (final wallet in wallets) {
      final wType = wallet.type.toLowerCase();
      if (wType == 'cash' &&
          (sanitizedText.contains('cash') ||
              sanitizedText.contains('tunai') ||
              sanitizedText.contains('dompet'))) {
        return wallet.id;
      } else if ((wType == 'e-wallet' || wType == 'ewallet') &&
          (sanitizedText.contains('gopay') ||
              sanitizedText.contains('ovo') ||
              sanitizedText.contains('dana') ||
              sanitizedText.contains('linkaja') ||
              sanitizedText.contains('spay') ||
              sanitizedText.contains('shopeepay') ||
              sanitizedText.contains('e-wallet') ||
              sanitizedText.contains('ewallet'))) {
        return wallet.id;
      } else if (wType == 'bank' &&
          (sanitizedText.contains('bank') ||
              sanitizedText.contains('rekening') ||
              sanitizedText.contains('transfer') ||
              sanitizedText.contains('debit') ||
              sanitizedText.contains('atm') ||
              sanitizedText.contains('mandiri') ||
              sanitizedText.contains('bca') ||
              sanitizedText.contains('bri') ||
              sanitizedText.contains('bni') ||
              sanitizedText.contains('cimb'))) {
        return wallet.id;
      }
    }

    return null;
  }

  /// Matches a category from the provided list based on synonym mapping and fuzzy Levenshtein fallback.
  String _matchCategory(
    String sanitizedText,
    String type,
    List<CategoryInfo> categories,
  ) {
    // 1. Try CategorySynonymDictionary mapping
    final mappedCategoryName = TextSanitizer.mapToCategorySynonym(sanitizedText);
    if (mappedCategoryName != null) {
      final targetKey = mappedCategoryName.toLowerCase();
      final Set<String> equivalents = {targetKey};
      for (final entry in TextSanitizer.categoryEquivalents.entries) {
        final key = entry.key.toLowerCase();
        if (key == targetKey || entry.value.contains(targetKey)) {
          equivalents.addAll(entry.value.map((e) => e.toLowerCase()));
          equivalents.add(key);
        }
      }

      for (final cat in categories) {
        final catName = cat.name.toLowerCase();
        if (equivalents.contains(catName) || 
            equivalents.any((eq) => catName.contains(eq) || eq.contains(catName))) {
          return cat.name;
        }
      }
    }

    // 2. Fallback to Fuzzy matching using similarity score
    double bestScore = 0.0;
    CategoryInfo? bestCategory;

    for (final cat in categories) {
      final catName = cat.name.toLowerCase().trim();
      final score = FuzzyMatcher.similarity(sanitizedText, catName);
      if (score > bestScore) {
        bestScore = score;
        bestCategory = cat;
      }
    }

    // Threshold check (similarity >= 60%)
    if (bestScore >= 0.6 && bestCategory != null) {
      return bestCategory.name;
    }

    // 3. Fallback to category matching transaction type
    for (final cat in categories) {
      final catType = cat.type.toLowerCase().trim();
      if (catType == type) {
        return cat.name;
      }
    }

    if (categories.isNotEmpty) {
      return categories.first.name;
    }
    return 'Food';
  }
}
