/// Domain model representing a single execution log entry for a recurring transaction.
///
/// Each time a recurring transaction is executed (successfully or not),
/// an execution log entry is created to track the history.
class ExecutionLogModel {
  final int? id;
  final String recurringTransactionId;
  final DateTime executedAt;
  final String status; // 'success' or 'failed'
  final int? transactionId;
  final String? errorMessage;

  const ExecutionLogModel({
    this.id,
    required this.recurringTransactionId,
    required this.executedAt,
    required this.status,
    this.transactionId,
    this.errorMessage,
  });

  /// Whether this execution was successful.
  bool get isSuccess => status == 'success';

  /// Whether this execution failed.
  bool get isFailed => status == 'failed';

  /// Creates a copy with the specified fields replaced.
  ExecutionLogModel copyWith({
    int? Function()? id,
    String? recurringTransactionId,
    DateTime? executedAt,
    String? status,
    int? Function()? transactionId,
    String? Function()? errorMessage,
  }) {
    return ExecutionLogModel(
      id: id != null ? id() : this.id,
      recurringTransactionId:
          recurringTransactionId ?? this.recurringTransactionId,
      executedAt: executedAt ?? this.executedAt,
      status: status ?? this.status,
      transactionId: transactionId != null
          ? transactionId()
          : this.transactionId,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExecutionLogModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          recurringTransactionId == other.recurringTransactionId &&
          executedAt == other.executedAt &&
          status == other.status &&
          transactionId == other.transactionId &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    id,
    recurringTransactionId,
    executedAt,
    status,
    transactionId,
    errorMessage,
  );

  @override
  String toString() =>
      'ExecutionLogModel(id: $id, recurringId: $recurringTransactionId, '
      'status: $status, executedAt: $executedAt)';
}
