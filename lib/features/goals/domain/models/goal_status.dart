/// Status of a financial goal.
enum GoalStatus {
  active,
  completed,
  archived;

  /// Convert a string value to [GoalStatus].
  static GoalStatus fromString(String value) {
    return GoalStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => GoalStatus.active,
    );
  }
}

/// Tracking mode for a financial goal.
enum TrackingMode {
  manual,
  wallet;

  /// Convert a string value to [TrackingMode].
  static TrackingMode fromString(String value) {
    return TrackingMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TrackingMode.manual,
    );
  }
}
