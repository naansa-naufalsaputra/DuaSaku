/// A structured representation of a parsed financial transaction.
///
/// Used as the output type for both AI-based and local parsing services.
class ParsedTransaction {
  final double amount;
  final String categoryId;
  final String type; // 'income', 'expense'
  final String? walletId;
  final String notes;
  final DateTime? date;
  final bool isReceiptScan;
  final bool scanConfidenceLow;

  const ParsedTransaction({
    required this.amount,
    required this.categoryId,
    required this.type,
    this.walletId,
    required this.notes,
    this.date,
    this.isReceiptScan = false,
    this.scanConfidenceLow = false,
  });
}
