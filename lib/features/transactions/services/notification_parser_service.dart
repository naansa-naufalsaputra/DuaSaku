import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';

import '../providers/transaction_provider.dart';
import '../../auth/providers/auth_provider.dart';

final notificationParserProvider = Provider<NotificationParserService>((ref) {
  final service = NotificationParserService(ref);
  service.init();
  return service;
});

class NotificationParserService {
  final Ref _ref;
  static const EventChannel _channel = EventChannel(
    'com.duasaku.app/bank_notifications',
  );
  final Set<String> _processedSignatures = {};

  NotificationParserService(this._ref);

  void init() {
    _channel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final packageName = event['packageName'] as String? ?? '';
          final title = event['title'] as String? ?? '';
          final text = event['text'] as String? ?? '';
          _processNotification(packageName, title, text);
        }
      },
      onError: (dynamic error) {
        debugPrint('[NotificationParserService] Stream error: $error');
      },
    );
  }

  void _processNotification(String packageName, String title, String text) {
    debugPrint(
      '[NotificationParserService] Received: $packageName | $title | $text',
    );

    final parsed = _parseText(packageName, title, text);
    if (parsed == null) return;

    final amount = parsed['amount'] as double;
    final type = parsed['type'] as String; // 'income' or 'expense'
    final bankName = parsed['bank'] as String;

    // Create a 60-second minute-based timestamp for debounce
    final now = DateTime.now();
    // Round to minute to handle duplicates arriving within the same minute easily
    final timestampMinute =
        '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';

    // Hash signature
    final rawString = '$amount-$type-$bankName-$timestampMinute';
    final signature = sha256.convert(utf8.encode(rawString)).toString();

    if (_processedSignatures.contains(signature)) {
      debugPrint(
        '[NotificationParserService] Duplicate detected, ignoring. ($signature)',
      );
      return;
    }

    // Register signature
    _processedSignatures.add(signature);

    // Cleanup old signatures (keep max 50 to avoid memory leak)
    if (_processedSignatures.length > 50) {
      _processedSignatures.remove(_processedSignatures.first);
    }

    _insertTransaction(amount, type, bankName, title, text);
  }

  Map<String, dynamic>? _parseText(
    String packageName,
    String title,
    String text,
  ) {
    final lowerTitle = title.toLowerCase();
    final lowerText = text.toLowerCase();
    final combined = '$lowerTitle $lowerText';

    String bank = 'Unknown';
    if (packageName.contains('com.bca') || lowerTitle.contains('bca')) {
      bank = 'BCA';
    } else if (packageName.contains('mandiri') ||
        lowerTitle.contains('mandiri') ||
        lowerTitle.contains('livin')) {
      bank = 'Mandiri';
    } else if (packageName.contains('bri') || lowerTitle.contains('brimo')) {
      bank = 'BRI';
    } else if (packageName.contains('jago')) {
      bank = 'Jago';
    } else if (packageName.contains('gojek') ||
        packageName.contains('gopay') ||
        lowerTitle.contains('gopay')) {
      bank = 'GoPay';
    } else if (packageName.contains('ovo')) {
      bank = 'OVO';
    } else {
      // If we don't recognize the package or bank, return null
      return null;
    }

    // Check income vs expense
    String type = 'expense'; // default to expense
    if (combined.contains('dana masuk') ||
        combined.contains('uang masuk') ||
        combined.contains('berhasil top up') ||
        combined.contains('cash masuk') ||
        combined.contains('menerima transfer') ||
        combined.contains('terima dana')) {
      type = 'income';
    } else if (combined.contains('uang keluar') ||
        combined.contains('berhasil transfer') ||
        combined.contains('pembayaran') ||
        combined.contains('tarik tunai')) {
      type = 'expense';
    } else {
      // Must contain success keywords to be a valid transaction notification
      if (!combined.contains('berhasil') &&
          !combined.contains('sukses') &&
          !combined.contains('masuk')) {
        return null;
      }
    }

    // Extract amount
    final amountPattern = RegExp(
      r'rp\s?(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)',
      caseSensitive: false,
    );
    final match = amountPattern.firstMatch(combined);

    if (match != null && match.groupCount >= 1) {
      final amountString = match.group(1)!;
      // Clean up string (e.g. 50.000,00 -> 50000.00)
      final cleanString = amountString.replaceAll('.', '').replaceAll(',', '.');
      final amount = double.tryParse(cleanString);

      if (amount != null && amount > 0) {
        return {'amount': amount, 'type': type, 'bank': bank};
      }
    }

    return null;
  }

  Future<void> _insertTransaction(
    double amount,
    String type,
    String bankName,
    String title,
    String text,
  ) async {
    final user = _ref.read(userProvider);
    if (user == null) {
      debugPrint(
        '[NotificationParserService] User not logged in, cannot insert.',
      );
      return;
    }

    final notes = 'Auto-recorded via $bankName notification.';

    try {
      await _ref
          .read(transactionNotifierProvider.notifier)
          .createTransaction(
            amount: amount,
            category: 'Notification ($bankName)',
            type: type,
            notes: notes,
          );
      debugPrint(
        '[NotificationParserService] Recorded transaction of Rp $amount as $type',
      );
    } catch (e) {
      debugPrint('[NotificationParserService] Error inserting transaction: $e');
    }
  }
}
