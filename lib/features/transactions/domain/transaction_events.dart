import 'models/transaction_model.dart';

/// Sealed class representing all transaction domain events.
///
/// Events are emitted by the repository after successful database operations
/// and consumed by event handlers to trigger side-effects (balance updates,
/// alert evaluation, geofence sync).
sealed class TransactionEvent {
  final TransactionModel transaction;
  final DateTime timestamp;

  const TransactionEvent(this.transaction, this.timestamp);
}

/// Event emitted when a new transaction is successfully created.
final class TransactionCreated extends TransactionEvent {
  const TransactionCreated(super.transaction, super.timestamp);

  factory TransactionCreated.now(TransactionModel transaction) {
    return TransactionCreated(transaction, DateTime.now());
  }
}

/// Event emitted when an existing transaction is successfully updated.
final class TransactionUpdated extends TransactionEvent {
  final TransactionModel oldTransaction;

  const TransactionUpdated(
    super.transaction,
    this.oldTransaction,
    super.timestamp,
  );

  factory TransactionUpdated.now(
    TransactionModel transaction,
    TransactionModel oldTransaction,
  ) {
    return TransactionUpdated(transaction, oldTransaction, DateTime.now());
  }
}

/// Event emitted when a transaction is successfully deleted.
final class TransactionDeleted extends TransactionEvent {
  const TransactionDeleted(super.transaction, super.timestamp);

  factory TransactionDeleted.now(TransactionModel transaction) {
    return TransactionDeleted(transaction, DateTime.now());
  }
}
