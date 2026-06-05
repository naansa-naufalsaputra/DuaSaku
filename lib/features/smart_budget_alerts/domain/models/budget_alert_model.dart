import 'alert_type.dart';

/// Domain model representing a budget alert record.
///
/// This is a pure Dart class with no external dependencies.
/// It stores alert data including type, threshold, spending percentage,
/// and computed fields for display purposes.
class BudgetAlertModel {
  final String id;
  final String userId;
  final String categoryId;
  final AlertType alertType;
  final int? thresholdValue; // e.g., 50, 75, 90, 100 (null for prediction)
  final double actualPercentage; // current spending percentage
  final String message; // localized alert message
  final bool isRead;
  final DateTime createdAt;

  // Computed fields (not stored in DB)
  final String? categoryName; // joined from Categories table
  final double? remainingBudget; // budget limit - current spending
  final double? overAmount; // amount over budget (for overBudget type)
  final DateTime? projectedOverspendDate; // for prediction type

  const BudgetAlertModel({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.alertType,
    this.thresholdValue,
    required this.actualPercentage,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.categoryName,
    this.remainingBudget,
    this.overAmount,
    this.projectedOverspendDate,
  });

  /// Serializes the model to a JSON map for database storage.
  /// Computed fields are excluded as they are derived at query time.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'alert_type': alertType.toJson(),
      'threshold_value': thresholdValue,
      'actual_percentage': actualPercentage,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      if (categoryName != null) 'category_name': categoryName,
      if (remainingBudget != null) 'remaining_budget': remainingBudget,
      if (overAmount != null) 'over_amount': overAmount,
      if (projectedOverspendDate != null)
        'projected_overspend_date':
            projectedOverspendDate!.toIso8601String(),
    };
  }

  /// Deserializes a model from a JSON map (database row).
  factory BudgetAlertModel.fromJson(Map<String, dynamic> json) {
    return BudgetAlertModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String,
      alertType: AlertType.fromJson(json['alert_type'] as String),
      thresholdValue: json['threshold_value'] as int?,
      actualPercentage: (json['actual_percentage'] as num).toDouble(),
      message: json['message'] as String,
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      categoryName: json['category_name'] as String?,
      remainingBudget: json['remaining_budget'] != null
          ? (json['remaining_budget'] as num).toDouble()
          : null,
      overAmount: json['over_amount'] != null
          ? (json['over_amount'] as num).toDouble()
          : null,
      projectedOverspendDate: json['projected_overspend_date'] != null
          ? DateTime.parse(json['projected_overspend_date'] as String)
          : null,
    );
  }

  /// Creates a copy with the specified fields replaced.
  BudgetAlertModel copyWith({
    String? id,
    String? userId,
    String? categoryId,
    AlertType? alertType,
    int? Function()? thresholdValue,
    double? actualPercentage,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    String? Function()? categoryName,
    double? Function()? remainingBudget,
    double? Function()? overAmount,
    DateTime? Function()? projectedOverspendDate,
  }) {
    return BudgetAlertModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      alertType: alertType ?? this.alertType,
      thresholdValue:
          thresholdValue != null ? thresholdValue() : this.thresholdValue,
      actualPercentage: actualPercentage ?? this.actualPercentage,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      categoryName:
          categoryName != null ? categoryName() : this.categoryName,
      remainingBudget:
          remainingBudget != null ? remainingBudget() : this.remainingBudget,
      overAmount: overAmount != null ? overAmount() : this.overAmount,
      projectedOverspendDate: projectedOverspendDate != null
          ? projectedOverspendDate()
          : this.projectedOverspendDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetAlertModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          categoryId == other.categoryId &&
          alertType == other.alertType &&
          thresholdValue == other.thresholdValue &&
          actualPercentage == other.actualPercentage &&
          message == other.message &&
          isRead == other.isRead &&
          createdAt == other.createdAt &&
          categoryName == other.categoryName &&
          remainingBudget == other.remainingBudget &&
          overAmount == other.overAmount &&
          projectedOverspendDate == other.projectedOverspendDate;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        categoryId,
        alertType,
        thresholdValue,
        actualPercentage,
        message,
        isRead,
        createdAt,
        categoryName,
        remainingBudget,
        overAmount,
        projectedOverspendDate,
      );

  @override
  String toString() =>
      'BudgetAlertModel(id: $id, type: ${alertType.name}, '
      'threshold: $thresholdValue, percentage: $actualPercentage, '
      'isRead: $isRead, createdAt: $createdAt)';
}
