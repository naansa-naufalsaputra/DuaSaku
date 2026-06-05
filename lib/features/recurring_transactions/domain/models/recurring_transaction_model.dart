import 'frequency.dart';
import 'recurring_status.dart';
import 'reminder_timing.dart';

/// Domain model representing a recurring transaction template.
///
/// This is a pure Dart class with no external dependencies.
/// It serves as the single source of truth for recurring transaction data
/// across the domain, data, and presentation layers.
class RecurringTransactionModel {
  final String id;
  final String userId;
  final String walletId;
  final String categoryId;
  final double amount;
  final String type; // 'income' or 'expense'
  final Frequency frequency;
  final int customInterval;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextExecutionDate;
  final RecurringStatus status;
  final String? notes;
  final int retryCount;
  final bool notifyBefore;
  final ReminderTiming reminderTiming;
  final DateTime createdAt;

  const RecurringTransactionModel({
    required this.id,
    required this.userId,
    required this.walletId,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.frequency,
    required this.customInterval,
    required this.startDate,
    this.endDate,
    required this.nextExecutionDate,
    required this.status,
    this.notes,
    this.retryCount = 0,
    this.notifyBefore = false,
    this.reminderTiming = ReminderTiming.sameDay,
    required this.createdAt,
  });

  /// Whether this recurring transaction is an income type.
  bool get isIncome => type == 'income';

  /// Whether this recurring transaction is an expense type.
  bool get isExpense => type == 'expense';

  /// Whether this recurring transaction is currently active and can be executed.
  bool get isActive => status == RecurringStatus.active;

  /// Whether this recurring transaction has an end date configured.
  bool get hasEndDate => endDate != null;

  /// Creates a copy with the specified fields replaced.
  RecurringTransactionModel copyWith({
    String? id,
    String? userId,
    String? walletId,
    String? categoryId,
    double? amount,
    String? type,
    Frequency? frequency,
    int? customInterval,
    DateTime? startDate,
    DateTime? Function()? endDate,
    DateTime? nextExecutionDate,
    RecurringStatus? status,
    String? Function()? notes,
    int? retryCount,
    bool? notifyBefore,
    ReminderTiming? reminderTiming,
    DateTime? createdAt,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      walletId: walletId ?? this.walletId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      customInterval: customInterval ?? this.customInterval,
      startDate: startDate ?? this.startDate,
      endDate: endDate != null ? endDate() : this.endDate,
      nextExecutionDate: nextExecutionDate ?? this.nextExecutionDate,
      status: status ?? this.status,
      notes: notes != null ? notes() : this.notes,
      retryCount: retryCount ?? this.retryCount,
      notifyBefore: notifyBefore ?? this.notifyBefore,
      reminderTiming: reminderTiming ?? this.reminderTiming,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          walletId == other.walletId &&
          categoryId == other.categoryId &&
          amount == other.amount &&
          type == other.type &&
          frequency == other.frequency &&
          customInterval == other.customInterval &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          nextExecutionDate == other.nextExecutionDate &&
          status == other.status &&
          notes == other.notes &&
          retryCount == other.retryCount &&
          notifyBefore == other.notifyBefore &&
          reminderTiming == other.reminderTiming &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        walletId,
        categoryId,
        amount,
        type,
        frequency,
        customInterval,
        startDate,
        endDate,
        nextExecutionDate,
        status,
        notes,
        retryCount,
        notifyBefore,
        reminderTiming,
        createdAt,
      );

  @override
  String toString() =>
      'RecurringTransactionModel(id: $id, amount: $amount, type: $type, '
      'frequency: ${frequency.name}, interval: $customInterval, '
      'status: ${status.name}, next: $nextExecutionDate)';
}
