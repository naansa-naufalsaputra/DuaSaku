class BudgetModel {
  final String? id;
  final String userId;
  final String category;
  final double amountLimit;
  final String month; // 'YYYY-MM'
  final DateTime createdAt;

  BudgetModel({
    this.id,
    required this.userId,
    required this.category,
    required this.amountLimit,
    required this.month,
    required this.createdAt,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      category: json['category'] as String,
      amountLimit: (json['amount_limit'] as num).toDouble(),
      month: json['month'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'category': category,
      'amount_limit': amountLimit,
      'month': month,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    return map;
  }
}
