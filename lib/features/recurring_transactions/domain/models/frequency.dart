/// Frequency enum representing the interval type for recurring transactions.
enum Frequency {
  daily,
  weekly,
  monthly,
  yearly;

  /// Maximum allowed custom interval for this frequency.
  int get maxInterval => switch (this) {
    Frequency.daily => 365,
    Frequency.weekly => 52,
    Frequency.monthly => 12,
    Frequency.yearly => 10,
  };

  /// Human-readable label for display purposes.
  String get label => switch (this) {
    Frequency.daily => 'Daily',
    Frequency.weekly => 'Weekly',
    Frequency.monthly => 'Monthly',
    Frequency.yearly => 'Yearly',
  };

  /// Parse a frequency from its string name.
  static Frequency fromString(String value) =>
      Frequency.values.firstWhere((f) => f.name == value);
}
