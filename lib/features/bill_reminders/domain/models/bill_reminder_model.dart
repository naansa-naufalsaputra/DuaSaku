class BillReminderModel {
  final String id;
  final String userId;
  final String title;
  final double amount;
  final String currency;
  final DateTime dueDate;
  final int reminderDaysBefore;
  final String status; // 'pending', 'reminded', 'snoozed', 'paid', 'dismissed'
  final String? notes;
  final String? recurringTransactionId;
  final DateTime? lastReminderSentAt;
  final DateTime createdAt;

  BillReminderModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.amount,
    this.currency = 'IDR',
    required this.dueDate,
    this.reminderDaysBefore = 3,
    required this.status,
    this.notes,
    this.recurringTransactionId,
    this.lastReminderSentAt,
    required this.createdAt,
  });

  /// Check if reminder should be sent now
  bool shouldSendReminder() {
    if (status != 'pending') return false;

    final now = DateTime.now();
    final reminderDate = dueDate.subtract(Duration(days: reminderDaysBefore));

    // Send if we've reached reminder date and haven't sent yet
    if (now.isAfter(reminderDate) && lastReminderSentAt == null) {
      return true;
    }

    return false;
  }

  /// Check if overdue
  bool get isOverdue {
    return DateTime.now().isAfter(dueDate) && status == 'pending';
  }

  factory BillReminderModel.fromJson(Map<String, dynamic> json) {
    return BillReminderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'IDR',
      dueDate: DateTime.parse(json['due_date'] as String),
      reminderDaysBefore: json['reminder_days_before'] as int? ?? 3,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      recurringTransactionId: json['recurring_transaction_id'] as String?,
      lastReminderSentAt: json['last_reminder_sent_at'] != null
          ? DateTime.parse(json['last_reminder_sent_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'amount': amount,
      'currency': currency,
      'due_date': dueDate.toIso8601String(),
      'reminder_days_before': reminderDaysBefore,
      'status': status,
      if (notes != null) 'notes': notes,
      if (recurringTransactionId != null)
        'recurring_transaction_id': recurringTransactionId,
      if (lastReminderSentAt != null)
        'last_reminder_sent_at': lastReminderSentAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  BillReminderModel copyWith({
    String? title,
    double? amount,
    String? currency,
    DateTime? dueDate,
    int? reminderDaysBefore,
    String? status,
    String? notes,
    DateTime? lastReminderSentAt,
  }) {
    return BillReminderModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      dueDate: dueDate ?? this.dueDate,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      recurringTransactionId: recurringTransactionId,
      lastReminderSentAt: lastReminderSentAt ?? this.lastReminderSentAt,
      createdAt: createdAt,
    );
  }
}
