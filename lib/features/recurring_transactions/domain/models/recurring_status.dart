/// Status of a recurring transaction.
enum RecurringStatus {
  active,
  paused,
  completed;

  /// Parse a status from its string name.
  static RecurringStatus fromString(String value) =>
      RecurringStatus.values.firstWhere((s) => s.name == value);
}
