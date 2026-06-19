class DebtModel {
  final String id;
  final String userId;
  final String type; // 'debt' (I owe) or 'loan' (they owe me)
  final String personName; // Debtor/creditor name
  final double amount;
  final String currency;
  final double paidAmount;
  final String status; // 'unpaid', 'partial', 'paid'
  final String? notes;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? settledAt;

  DebtModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.personName,
    required this.amount,
    this.currency = 'IDR',
    this.paidAmount = 0.0,
    required this.status,
    this.notes,
    this.dueDate,
    required this.createdAt,
    this.settledAt,
  });

  /// Remaining amount to be paid
  double get remainingAmount => amount - paidAmount;

  /// Is debt/loan fully settled
  bool get isSettled => status == 'paid';

  /// Is overdue (past due date and not settled)
  bool get isOverdue {
    if (dueDate == null || isSettled) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    return DebtModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      personName: json['person_name'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'IDR',
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'person_name': personName,
      'amount': amount,
      'currency': currency,
      'paid_amount': paidAmount,
      'status': status,
      if (notes != null) 'notes': notes,
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (settledAt != null) 'settled_at': settledAt!.toIso8601String(),
    };
  }

  DebtModel copyWith({
    String? personName,
    double? amount,
    String? currency,
    double? paidAmount,
    String? status,
    String? notes,
    DateTime? dueDate,
    DateTime? settledAt,
  }) {
    return DebtModel(
      id: id,
      userId: userId,
      type: type,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      settledAt: settledAt ?? this.settledAt,
    );
  }
}

class DebtPaymentModel {
  final String id;
  final String debtId;
  final double amount;
  final String? notes;
  final DateTime paidAt;

  DebtPaymentModel({
    required this.id,
    required this.debtId,
    required this.amount,
    this.notes,
    required this.paidAt,
  });

  factory DebtPaymentModel.fromJson(Map<String, dynamic> json) {
    return DebtPaymentModel(
      id: json['id'] as String,
      debtId: json['debt_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      notes: json['notes'] as String?,
      paidAt: DateTime.parse(json['paid_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'debt_id': debtId,
      'amount': amount,
      if (notes != null) 'notes': notes,
      'paid_at': paidAt.toIso8601String(),
    };
  }
}
