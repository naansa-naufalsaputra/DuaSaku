/// Domain model representing the status of a triggered alert threshold.
///
/// Tracks which thresholds have already been triggered for a given
/// category and budget period to prevent duplicate alerts.
class AlertThresholdStatusModel {
  final String id;
  final String userId;
  final String categoryId;
  final String budgetMonth; // format 'YYYY-MM'
  final int thresholdValue; // 50, 75, 90, or 100
  final DateTime triggeredAt;

  const AlertThresholdStatusModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.budgetMonth,
    required this.thresholdValue,
    required this.triggeredAt,
  });

  /// Serializes the model to a JSON map for database storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'budget_month': budgetMonth,
      'threshold_value': thresholdValue,
      'triggered_at': triggeredAt.toIso8601String(),
    };
  }

  /// Deserializes a model from a JSON map (database row).
  factory AlertThresholdStatusModel.fromJson(Map<String, dynamic> json) {
    return AlertThresholdStatusModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String,
      budgetMonth: json['budget_month'] as String,
      thresholdValue: json['threshold_value'] as int,
      triggeredAt: DateTime.parse(json['triggered_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertThresholdStatusModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          categoryId == other.categoryId &&
          budgetMonth == other.budgetMonth &&
          thresholdValue == other.thresholdValue &&
          triggeredAt == other.triggeredAt;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        categoryId,
        budgetMonth,
        thresholdValue,
        triggeredAt,
      );

  @override
  String toString() =>
      'AlertThresholdStatusModel(id: $id, categoryId: $categoryId, '
      'month: $budgetMonth, threshold: $thresholdValue, '
      'triggeredAt: $triggeredAt)';
}
