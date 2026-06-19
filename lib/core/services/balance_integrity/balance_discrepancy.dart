/// Represents a detected mismatch between stored wallet balance
/// and computed transaction totals.
class BalanceDiscrepancy {
  final String walletId;
  final String walletName;
  final double storedBalance;
  final double computedBalance;
  final double difference;
  final DateTime detectedAt;

  BalanceDiscrepancy({
    required this.walletId,
    required this.walletName,
    required this.storedBalance,
    required this.computedBalance,
    required this.difference,
    required this.detectedAt,
  });

  /// Returns true if discrepancy exceeds the tolerance threshold (0.01 IDR)
  bool get isSignificant => difference.abs() > 0.01;

  /// Returns discrepancy details as map for logging/analysis
  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'walletName': walletName,
      'storedBalance': storedBalance,
      'computedBalance': computedBalance,
      'difference': difference,
      'detectedAt': detectedAt.toIso8601String(),
      'isSignificant': isSignificant,
    };
  }
}
