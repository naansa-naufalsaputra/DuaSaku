/// Enum representing the type of budget alert.
enum AlertType {
  /// Alert triggered when spending reaches a configured threshold percentage.
  threshold,

  /// Alert triggered when spending is predicted to exceed budget.
  prediction,

  /// Alert triggered when spending has exceeded the budget limit (100%+).
  overBudget;

  /// Serializes the alert type to a string for database storage.
  String toJson() => switch (this) {
    AlertType.threshold => 'threshold',
    AlertType.prediction => 'prediction',
    AlertType.overBudget => 'over_budget',
  };

  /// Deserializes an alert type from a database string value.
  static AlertType fromJson(String value) => switch (value) {
    'threshold' => AlertType.threshold,
    'prediction' => AlertType.prediction,
    'over_budget' => AlertType.overBudget,
    _ => throw ArgumentError('Unknown AlertType value: $value'),
  };
}
