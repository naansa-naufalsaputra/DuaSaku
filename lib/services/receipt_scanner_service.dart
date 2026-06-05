import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/utils/text_sanitizer.dart';
import '../features/transactions/domain/transaction_parser_service_interface.dart';
import 'models/parsed_transaction.dart';

/// Abstract service interface for scanning physical receipts offline.
abstract class ReceiptScannerService {
  /// Processes a receipt image offline, extracting the total amount, date,
  /// merchant name, and predicting the transaction category.
  Future<ParsedTransaction> scanReceipt(String imagePath);
}

/// Concrete implementation of [ReceiptScannerService] utilizing Google ML Kit OCR.
class ReceiptScannerServiceImpl implements ReceiptScannerService {
  final TransactionParserServiceInterface tfliteService;

  ReceiptScannerServiceImpl(this.tfliteService);

  @override
  Future<ParsedTransaction> scanReceipt(String imagePath) async {
    final File imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw ArgumentError('Receipt image file does not exist at path: $imagePath');
    }

    final TextRecognizer recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await recognizer.processImage(inputImage);

      // 1. Reconstruct lines from OCR blocks
      final List<String> rawLines = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          if (line.text.trim().isNotEmpty) {
            rawLines.add(line.text.trim());
          }
        }
      }

      if (rawLines.isEmpty) {
        debugPrint('[ReceiptScannerService] OCR returned empty text.');
        return const ParsedTransaction(
          amount: 0.0,
          category: 'Food', // default category
          type: 'expense',
          notes: 'Struk Belanja',
          isReceiptScan: true,
          scanConfidenceLow: true,
        );
      }

      // 2. Extract Merchant Name (from the top headers)
      final String rawMerchant = extractMerchantName(rawLines);
      final String merchantName = TextSanitizer.prettifyNotes(rawMerchant);

      // 3. Extract Date
      final DateTime date = extractDate(rawLines);

      // 4. Extract Total Amount and check confidence
      final (double amount, bool scanConfidenceLow) = extractTotalAmount(rawLines);

      // 5. Predict category using existing TFLite transaction parser
      String category = 'Food';
      String intentType = 'expense';
      try {
        final parsedResult = await tfliteService.parseTransaction(
          inputText: merchantName,
          wallets: [],
          categories: [],
        );
        category = parsedResult.category;
        intentType = parsedResult.type;
      } catch (e) {
        debugPrint('[ReceiptScannerService] Failed to predict category via TFLite: $e');
        // Fallback: match via local text sanitizer keywords if TFLite fails
        final sanitized = TextSanitizer.sanitize(merchantName);
        category = TextSanitizer.mapToCategorySynonym(sanitized) ?? 'Food';
        intentType = TextSanitizer.determineIntent(sanitized);
      }

      return ParsedTransaction(
        amount: amount,
        category: category,
        type: intentType,
        notes: merchantName,
        date: date,
        isReceiptScan: true,
        scanConfidenceLow: scanConfidenceLow,
      );
    } catch (e) {
      debugPrint('[ReceiptScannerService] Error parsing receipt image: $e');
      rethrow;
    } finally {
      await recognizer.close();
    }
  }

  /// Extracts the merchant name from the top non-empty lines of the receipt.
  /// Ignores lines containing address keywords, phones, websites, dates, or ids.
  @visibleForTesting
  String extractMerchantName(List<String> lines) {
    final addressRegex = RegExp(
      r'\b(sleman|jakarta|bandung|surabaya|yogyakarta|kec\.|kab\.|rt\.|rw\.|depok|tangerang|bekasi)\b|jl\.\s|no\.\s*\d',
      caseSensitive: false,
    );
    final phoneRegex = RegExp(r'\b\+?\d[\d\-\s]{7,}\d\b');
    final webRegex = RegExp(
      r'\b(www\.|http:|https:|\.com\b|@)',
      caseSensitive: false,
    );
    final idOrDateRegex = RegExp(
      r'(no\.|id\b|invoice|nota|transaksi|struk|tgl|date|time|\d{2}:\d{2}|telp|phone)',
      caseSensitive: false,
    );

    // Scan the first 5 lines for a merchant candidate
    final int limit = lines.length < 5 ? lines.length : 5;
    for (int i = 0; i < limit; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Skip address, phone, web, or date/id lines
      if (addressRegex.hasMatch(line) ||
          phoneRegex.hasMatch(line) ||
          webRegex.hasMatch(line) ||
          idOrDateRegex.hasMatch(line)) {
        continue;
      }

      // Check if it has letters (we don't want a purely numeric line like an invoice number)
      if (RegExp(r'[a-zA-Z]').hasMatch(line)) {
        // Strip out trailing punctuation typical of headings
        return line.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$'), '').trim();
      }
    }

    return 'Struk Belanja';
  }

  /// Extracts date from the receipt lines. Falls back to DateTime.now().
  @visibleForTesting
  DateTime extractDate(List<String> lines) {
    // Regex 1: DD/MM/YYYY or DD-MM-YYYY (supporting 2 or 4 digit years)
    final dateNumericRegex = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b');

    // Regex 2: DD Month YYYY (e.g. 12 Jan 2026, 12 Januari 2026)
    final dateWordRegex = RegExp(
      r'\b(\d{1,2})\s+(jan|feb|mar|apr|mei|jun|jul|agu|sep|okt|nov|des)[a-z]*\s+(\d{2,4})\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      // 1. Try word dates
      var match = dateWordRegex.firstMatch(line);
      if (match != null) {
        final int? day = int.tryParse(match.group(1) ?? '');
        final String monthStr = (match.group(2) ?? '').toLowerCase();
        final String yearStr = match.group(3) ?? '';
        int year = int.tryParse(yearStr) ?? DateTime.now().year;
        if (year < 100) year += 2000;

        final int month = _mapMonthWordToNumber(monthStr);
        if (day != null && month > 0) {
          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }

      // 2. Try numeric dates
      match = dateNumericRegex.firstMatch(line);
      if (match != null) {
        final int? day = int.tryParse(match.group(1) ?? '');
        final int? month = int.tryParse(match.group(2) ?? '');
        final String yearStr = match.group(3) ?? '';
        int year = int.tryParse(yearStr) ?? DateTime.now().year;
        if (year < 100) year += 2000;

        if (day != null && month != null && month >= 1 && month <= 12) {
          try {
            return DateTime(year, month, day);
          } catch (_) {}
        }
      }
    }

    return DateTime.now();
  }

  int _mapMonthWordToNumber(String monthStr) {
    switch (monthStr) {
      case 'jan': return 1;
      case 'feb': return 2;
      case 'mar': return 3;
      case 'apr': return 4;
      case 'mei': return 5;
      case 'jun': return 6;
      case 'jul': return 7;
      case 'agu': return 8;
      case 'sep': return 9;
      case 'okt': return 10;
      case 'nov': return 11;
      case 'des': return 12;
      default: return 0;
    }
  }

  /// Extracts Total Amount from receipt lines.
  /// Returns a tuple of (Amount, scanConfidenceLow).
  @visibleForTesting
  (double, bool) extractTotalAmount(List<String> lines) {
    // Total keywords matching list - split into primary totals vs secondary payments
    final primaryKeywordRegex = RegExp(
      r'\b(total|grand|netto|jumlah|tagihan|payment)\b',
      caseSensitive: false,
    );
    final secondaryKeywordRegex = RegExp(
      r'\b(bayar|cash|tunai|belanja|harga)\b',
      caseSensitive: false,
    );

    double? primaryKeywordAmount;
    double? secondaryKeywordAmount;
    final List<double> allNumbersFound = [];

    for (int i = 0; i < lines.length; i++) {
      final String line = lines[i];

      // Extract all numbers from each line for the document-wide candidates
      final numbersInLine = _extractPricesFromLine(line);
      allNumbersFound.addAll(numbersInLine);

      // Check primary keywords
      if (primaryKeywordRegex.hasMatch(line)) {
        if (numbersInLine.isNotEmpty) {
          final candidate = numbersInLine.last;
          if (primaryKeywordAmount == null || candidate > primaryKeywordAmount) {
            primaryKeywordAmount = candidate;
          }
        } else if (i + 1 < lines.length) {
          final nextLineNumbers = _extractPricesFromLine(lines[i + 1]);
          if (nextLineNumbers.isNotEmpty) {
            final candidate = nextLineNumbers.first;
            if (primaryKeywordAmount == null || candidate > primaryKeywordAmount) {
              primaryKeywordAmount = candidate;
            }
          }
        }
      }

      // Check secondary keywords
      if (secondaryKeywordRegex.hasMatch(line)) {
        if (numbersInLine.isNotEmpty) {
          final candidate = numbersInLine.last;
          if (secondaryKeywordAmount == null || candidate > secondaryKeywordAmount) {
            secondaryKeywordAmount = candidate;
          }
        } else if (i + 1 < lines.length) {
          final nextLineNumbers = _extractPricesFromLine(lines[i + 1]);
          if (nextLineNumbers.isNotEmpty) {
            final candidate = nextLineNumbers.first;
            if (secondaryKeywordAmount == null || candidate > secondaryKeywordAmount) {
              secondaryKeywordAmount = candidate;
            }
          }
        }
      }
    }

    // Sort numbers to find the largest valid candidate
    // A valid transaction candidate should filter out years (e.g. 2026) or telephone/invoice IDs.
    final validCandidates = allNumbersFound.where((val) {
      // Exclude values that match common years
      if (val == 2023.0 || val == 2024.0 || val == 2025.0 || val == 2026.0) return false;
      // Exclude numbers that are extremely large (e.g. barcode IDs, serial numbers > 10,000,000)
      if (val > 10000000.0) return false;
      // Exclude numbers that are too small
      if (val < 100.0) return false;
      return true;
    }).toList();

    validCandidates.sort();

    // 1. If we matched a primary total keyword, take it (highest priority)
    if (primaryKeywordAmount != null && primaryKeywordAmount > 0) {
      return (primaryKeywordAmount, false);
    }

    // 2. If we matched a secondary keyword (and no primary total was found), take it
    if (secondaryKeywordAmount != null && secondaryKeywordAmount > 0) {
      return (secondaryKeywordAmount, false);
    }

    // 3. Fallback to the largest valid candidate in the entire document
    if (validCandidates.isNotEmpty) {
      final largestCandidate = validCandidates.last;
      return (largestCandidate, true); // Low confidence: took largest number but no keyword match
    }

    return (0.0, true); // Failed to find any amount
  }

  /// Parses all price-like numeric tokens from a line.
  /// Replaces 'O' or 'o' inside digit sequences with '0'.
  List<double> _extractPricesFromLine(String line) {
    final List<double> prices = [];

    // Preprocess: Replace O/o with 0 only if surrounded by digits, dots, commas, or currency symbols.
    // e.g., "1O.OOO" -> "10.000", "5O,00" -> "50,00", "Rp. 2O.ooo" -> "Rp. 20.000"
    String sanitizedLine = line;
    sanitizedLine = sanitizedLine.replaceAllMapped(
      RegExp(r'(?<=\d|rp|idr|Rp|IDR|[.,\-\s])[Oo0](?=\d|[.,\-\s]|$)'),
      (match) => '0',
    );
    // Colloquial OCR ooo -> 000
    sanitizedLine = sanitizedLine.replaceAll(RegExp(r'\b[oO]{3}\b'), '000');

    // Regex to match prices (e.g. 50.000, 12,500, Rp 150000, 25000)
    // Matches digits optionally followed by dot/comma decimal separators.
    final priceRegex = RegExp(r'\b(rp|idr)?\s*([\d\.,]+)\b', caseSensitive: false);

    for (final match in priceRegex.allMatches(sanitizedLine)) {
      final String numString = match.group(2) ?? '';
      if (numString.isEmpty) continue;

      // Clean the numeric string
      // If the string contains both dot and comma (e.g. 1,250.00 or 1.250,00),
      // we detect which is the decimal separator.
      // In Indonesia, dot is thousands, comma is decimal. In English, it is reversed.
      String cleaned = numString;
      if (cleaned.contains('.') && cleaned.contains(',')) {
        final dotIndex = cleaned.indexOf('.');
        final commaIndex = cleaned.indexOf(',');
        if (dotIndex > commaIndex) {
          // English-style: 1,250.00 -> remove commas, parse
          cleaned = cleaned.replaceAll(',', '');
        } else {
          // Indonesian-style: 1.250,00 -> remove dots, replace comma with dot
          cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
        }
      } else if (cleaned.contains('.')) {
        // If it only has dot, check if it looks like thousands (e.g. 50.000) or decimal (e.g. 50.00)
        // Receipts usually don't have decimals for Rupiah unless they represent cents/fractions.
        // A simple rule: if it ends with exactly 3 digits after the dot (e.g. 50.000), it's thousands.
        // Otherwise, if it has 2 digits after the dot (e.g. 50.00), it's a decimal.
        final parts = cleaned.split('.');
        if (parts.length == 2 && parts[1].length == 3) {
          cleaned = cleaned.replaceAll('.', '');
        } else if (parts.length > 2) {
          // Multi-dot: 1.250.000 -> thousands separators
          cleaned = cleaned.replaceAll('.', '');
        }
      } else if (cleaned.contains(',')) {
        // If it only has comma:
        // If it has 3 digits after the comma (e.g., 50,000), it's thousands.
        // If it has 2 digits (e.g. 50,00), it's decimal.
        final parts = cleaned.split(',');
        if (parts.length == 2 && parts[1].length == 3) {
          cleaned = cleaned.replaceAll(',', '');
        } else if (parts.length > 2) {
          cleaned = cleaned.replaceAll(',', '');
        } else {
          // E.g. 50,00 -> decimal
          cleaned = cleaned.replaceAll(',', '.');
        }
      }

      final parsed = double.tryParse(cleaned);
      if (parsed != null && parsed > 0) {
        prices.add(parsed);
      }
    }

    return prices;
  }
}
