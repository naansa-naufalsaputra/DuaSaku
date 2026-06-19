class TransactionSplitModel {
  final String id;
  final int transactionId;
  final String categoryId;
  final double amount;
  final String? notes;

  TransactionSplitModel({
    required this.id,
    required this.transactionId,
    required this.categoryId,
    required this.amount,
    this.notes,
  });

  factory TransactionSplitModel.fromJson(Map<String, dynamic> json) {
    return TransactionSplitModel(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as int,
      categoryId: json['category_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'category_id': categoryId,
      'amount': amount,
      if (notes != null) 'notes': notes,
    };
  }

  TransactionSplitModel copyWith({
    String? categoryId,
    double? amount,
    String? notes,
  }) {
    return TransactionSplitModel(
      id: id,
      transactionId: transactionId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
    );
  }
}
