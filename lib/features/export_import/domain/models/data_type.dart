/// Enum representing the types of data that can be exported selectively as CSV.
enum DataType {
  transactions,
  wallets,
  categories,
  budgets,
  recurringTransactions,
  goals,
  goalDeposits,
  budgetAlerts;

  /// Column used for date filtering per type.
  /// Transactions use 'date', all others use 'createdAt'.
  String get dateColumn => switch (this) {
    DataType.transactions => 'date',
    _ => 'createdAt',
  };
}
