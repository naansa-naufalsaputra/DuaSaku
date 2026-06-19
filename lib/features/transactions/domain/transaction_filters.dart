class TransactionFilters {
  final String? searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? type; // 'income', 'expense', 'transfer', null = all
  final String? walletId; // Changed from int to String (Drift uses TextColumn)
  final double? minAmount;
  final double? maxAmount;
  final List<String>? tagIds; // Filter by tag IDs

  const TransactionFilters({
    this.searchQuery,
    this.startDate,
    this.endDate,
    this.type,
    this.walletId,
    this.minAmount,
    this.maxAmount,
    this.tagIds,
  });

  bool get isEmpty =>
      searchQuery == null &&
      startDate == null &&
      endDate == null &&
      type == null &&
      walletId == null &&
      minAmount == null &&
      maxAmount == null &&
      (tagIds == null || tagIds!.isEmpty);

  TransactionFilters copyWith({
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? walletId,
    double? minAmount,
    double? maxAmount,
    List<String>? tagIds,
  }) {
    return TransactionFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type ?? this.type,
      walletId: walletId ?? this.walletId,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}
