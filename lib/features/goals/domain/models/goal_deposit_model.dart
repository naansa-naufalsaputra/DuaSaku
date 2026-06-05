class GoalDepositModel {
  final String id;
  final String goalId;
  final double amount;
  final String? note;
  final DateTime createdAt;

  GoalDepositModel({
    required this.id,
    required this.goalId,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  factory GoalDepositModel.fromJson(Map<String, dynamic> json) {
    return GoalDepositModel(
      id: json['id'] as String,
      goalId: json['goal_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goal_id': goalId,
      'amount': amount,
      if (note != null) 'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  GoalDepositModel copyWith({
    String? id,
    String? goalId,
    double? amount,
    String? note,
    bool clearNote = false,
    DateTime? createdAt,
  }) {
    return GoalDepositModel(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amount: amount ?? this.amount,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
