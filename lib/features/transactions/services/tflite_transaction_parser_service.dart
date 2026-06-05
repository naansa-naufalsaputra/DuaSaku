import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../core/utils/dart_tokenizer.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../../../services/models/category_info.dart';
import '../../../services/models/parsed_transaction.dart';
import '../../../services/models/wallet_info.dart';
import '../domain/models/transaction_model.dart';
import '../domain/transaction_parser_service_interface.dart';

/// Joint NLP model (Intent, Category, and NER) parser service using TensorFlow Lite.
///
/// Executes 100% locally and offline on-device.
class TfliteTransactionParserService
    implements TransactionParserServiceInterface {
  Interpreter? _interpreter;
  Map<String, dynamic>? _metadata;
  DartTokenizer? _tokenizer;

  TfliteTransactionParserService();

  /// Lazy initializations of the TFLite interpreter and model metadata.
  Future<void> initialize({String? modelPath, String? metadataPath}) async {
    if (_interpreter != null) return;

    try {
      // 1. Load metadata.json containing vocab, intent_map, category_map, ner_map, and max_len
      final String metadataString;
      if (metadataPath != null) {
        metadataString = await File(metadataPath).readAsString();
      } else {
        metadataString = await rootBundle.loadString('assets/ml/metadata.json');
      }
      _metadata = json.decode(metadataString) as Map<String, dynamic>;

      // 2. Initialize pure DartTokenizer with loaded metadata
      _tokenizer = DartTokenizer.fromJson(_metadata!);

      // 3. Load TFLite Model interpreter
      if (modelPath != null) {
        _interpreter = Interpreter.fromFile(File(modelPath));
      } else {
        _interpreter = await Interpreter.fromAsset('ml/duasaku_level3.tflite');
      }
      debugPrint(
        '[TfliteTransactionParserService] Successfully loaded model and metadata.',
      );
    } catch (e) {
      debugPrint(
        '[TfliteTransactionParserService] Failed to initialize TFLite: $e',
      );
      rethrow;
    }
  }

  /// Main interface entry point returning the standard [ParsedTransaction].
  @override
  Future<ParsedTransaction> parseTransaction({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) async {
    await initialize();

    if (_interpreter == null || _tokenizer == null || _metadata == null) {
      throw StateError(
        'TfliteTransactionParserService was not initialized correctly.',
      );
    }

    // 1. Preprocess & tokenize input text
    final inputIds = _tokenizer!.tokenize(inputText);
    final input = [inputIds]; // Shape: [1, max_len]

    // 2. Dynamic output shape and index discovery to support any TF Lite compiler output order
    final outputTensors = _interpreter!.getOutputTensors();
    final outputs = <int, Object>{};

    int? intentIdx;
    int? categoryIdx;
    int? nerIdx;

    for (int i = 0; i < outputTensors.length; i++) {
      final tensor = outputTensors[i];
      final shape = tensor.shape;

      if (shape.length == 2 && shape[1] == 1) {
        // Intent output tensor [1, 1]
        outputs[i] = List.generate(1, (_) => List.filled(1, 0.0));
        intentIdx = i;
      } else if (shape.length == 2 && shape[1] > 1) {
        // Category output tensor [1, num_categories]
        outputs[i] = List.generate(1, (_) => List.filled(shape[1], 0.0));
        categoryIdx = i;
      } else if (shape.length == 3) {
        // NER output tensor [1, max_len, num_ner_tags]
        outputs[i] = List.generate(
          1,
          (_) => List.generate(shape[1], (_) => List.filled(shape[2], 0.0)),
        );
        nerIdx = i;
      }
    }

    if (intentIdx == null || categoryIdx == null || nerIdx == null) {
      throw StateError(
        'The loaded TFLite model output shapes do not match expected shapes (Intent, Category, NER).',
      );
    }

    // 3. Run Inference
    _interpreter!.runForMultipleInputs([input], outputs);

    // 4. Decode Intent (Sigmoid: >0.5 -> income, <=0.5 -> expense)
    final intentProb = (outputs[intentIdx] as List<List<double>>)[0][0];
    final intentMap = _metadata!['intent_map'] as Map<String, dynamic>;
    final intentIdxStr = intentProb > 0.5 ? '1' : '0';
    final type =
        intentMap[intentIdxStr] as String? ??
        (intentProb > 0.5 ? 'income' : 'expense');

    // 5. Decode Category (Softmax Argmax)
    final categoryProbs = (outputs[categoryIdx] as List<List<double>>)[0];
    int bestCatIdx = 0;
    double maxCatProb = -1.0;
    for (int i = 0; i < categoryProbs.length; i++) {
      if (categoryProbs[i] > maxCatProb) {
        maxCatProb = categoryProbs[i];
        bestCatIdx = i;
      }
    }
    final categoryMap = _metadata!['category_map'] as Map<String, dynamic>;
    final parsedCategory =
        categoryMap[bestCatIdx.toString()] as String? ?? 'Food';

    // 6. Decode NER Slots
    // PENTING: Gunakan rawTokens untuk mempertahankan titik/koma pada angka
    final rawTokens = inputText
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    final nerOutput =
        (outputs[nerIdx]
            as List<List<List<double>>>)[0]; // max_len x num_ner_tags
    final nerMap = _metadata!['ner_map'] as Map<String, dynamic>;

    final amountTokens = <String>[];
    final noteTokens = <String>[];

    for (int i = 0; i < rawTokens.length; i++) {
      if (i >= _tokenizer!.maxLen) break;

      final tagProbs = nerOutput[i];
      int bestTagIdx = 0;
      double maxTagProb = -1.0;
      for (int j = 0; j < tagProbs.length; j++) {
        if (tagProbs[j] > maxTagProb) {
          maxTagProb = tagProbs[j];
          bestTagIdx = j;
        }
      }

      final tagName = nerMap[bestTagIdx.toString()] as String? ?? 'O';

      // Reconstruct strings using rawTokens to preserve decimals
      if (tagName == 'B-AMOUNT' || tagName == 'I-AMOUNT') {
        amountTokens.add(rawTokens[i]);
      } else if (tagName == 'B-NOTE' || tagName == 'I-NOTE') {
        noteTokens.add(rawTokens[i]);
      }
    }

    // 7. Parse Extracted Amount to Double
    double amount = 0.0;
    if (amountTokens.isNotEmpty) {
      amount = parseExtractedAmount(amountTokens.join(' '));
    }

    // 8. Reconstruct Notes (catatan)
    final notes = noteTokens.isNotEmpty ? noteTokens.join(' ') : inputText;

    // Optional: Match Wallet if mentioned in the text
    String? matchedWalletId;
    for (final wallet in wallets) {
      if (inputText.toLowerCase().contains(wallet.name.toLowerCase())) {
        matchedWalletId = wallet.id;
        break;
      }
    }

    return ParsedTransaction(
      amount: amount,
      category: parsedCategory,
      type: type,
      walletId: matchedWalletId,
      notes: TextSanitizer.prettifyNotes(notes),
    );
  }

  /// Parses raw extracted amount string containing Indonesian colloquial terms.
  double parseExtractedAmount(String str) {
    // Lowercase and remove spaces
    final String cleaned = str.replaceAll(' ', '').toLowerCase();

    // Find numbers and optional suffixes (k, rb, ribu, jt, juta)
    final match = RegExp(r'([\d\.,]+)(k|rb|ribu|jt|juta)?').firstMatch(cleaned);
    if (match == null) {
      // Fallback: strip any non-digit/non-decimal characters and parse
      final digitsOnly = cleaned.replaceAll(RegExp(r'[^\d]'), '');
      return double.tryParse(digitsOnly) ?? 0.0;
    }

    String numStr = match.group(1)!;
    final suffix = match.group(2);

    if (suffix != null) {
      // If there is a suffix, treat dot/comma as decimal separator (e.g., 1.5jt or 1,5jt)
      numStr = numStr.replaceAll(',', '.');
      double value = double.tryParse(numStr) ?? 0.0;
      if (suffix == 'k' || suffix == 'rb' || suffix == 'ribu') {
        value *= 1000;
      } else if (suffix == 'jt' || suffix == 'juta') {
        value *= 1000000;
      }
      return value;
    } else {
      // If no suffix, treat dot/comma as thousands separator (e.g., 25.000 or 25,000)
      numStr = numStr.replaceAll('.', '').replaceAll(',', '');
      return double.tryParse(numStr) ?? 0.0;
    }
  }

  /// Direct helper method returning an assembled [TransactionModel] as specified.
  Future<TransactionModel> parse({
    required String inputText,
    required String userId,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) async {
    final parsedTx = await parseTransaction(
      inputText: inputText,
      wallets: wallets,
      categories: categories,
    );
    return TransactionModel(
      userId: userId,
      amount: parsedTx.amount,
      category: parsedTx.category,
      type: parsedTx.type,
      notes: parsedTx.notes,
      walletId: parsedTx.walletId,
      createdAt: DateTime.now(),
    );
  }
}
