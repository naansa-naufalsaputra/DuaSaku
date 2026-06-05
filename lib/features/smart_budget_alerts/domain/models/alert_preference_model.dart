import 'dart:convert';

/// Domain model representing user preferences for budget alerts.
///
/// This is a pure Dart class with no external dependencies.
/// Quiet hours are stored as "HH:mm" strings to avoid Flutter dependency
/// (TimeOfDay is from package:flutter/material.dart).
class AlertPreferenceModel {
  final String id;
  final String userId;
  final String? categoryId; // null = global settings
  final bool isEnabled;
  final List<int> thresholds; // e.g., [50, 75, 90, 100]
  final bool predictionsEnabled;
  final String? quietHoursStart; // "HH:mm" format, null = no quiet hours
  final String? quietHoursEnd; // "HH:mm" format, null = no quiet hours

  const AlertPreferenceModel({
    required this.id,
    required this.userId,
    this.categoryId,
    this.isEnabled = true,
    this.thresholds = const [50, 75, 90, 100],
    this.predictionsEnabled = true,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  /// Creates default preferences for a new user.
  ///
  /// Defaults: all thresholds active (50, 75, 90, 100),
  /// predictions enabled, no quiet hours.
  factory AlertPreferenceModel.defaults(String userId) {
    return AlertPreferenceModel(
      id: 'pref_${userId}_global',
      userId: userId,
      categoryId: null,
      isEnabled: true,
      thresholds: const [50, 75, 90, 100],
      predictionsEnabled: true,
      quietHoursStart: null,
      quietHoursEnd: null,
    );
  }

  /// Whether quiet hours are configured.
  bool get hasQuietHours =>
      quietHoursStart != null && quietHoursEnd != null;

  /// Whether this is a global (non-category-specific) preference.
  bool get isGlobal => categoryId == null;

  /// Serializes the model to a JSON map for database storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'is_enabled': isEnabled,
      'thresholds': jsonEncode(thresholds),
      'predictions_enabled': predictionsEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
    };
  }

  /// Deserializes a model from a JSON map (database row).
  factory AlertPreferenceModel.fromJson(Map<String, dynamic> json) {
    return AlertPreferenceModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String?,
      isEnabled: json['is_enabled'] as bool,
      thresholds: (jsonDecode(json['thresholds'] as String) as List<dynamic>)
          .cast<int>(),
      predictionsEnabled: json['predictions_enabled'] as bool,
      quietHoursStart: json['quiet_hours_start'] as String?,
      quietHoursEnd: json['quiet_hours_end'] as String?,
    );
  }

  /// Creates a copy with the specified fields replaced.
  AlertPreferenceModel copyWith({
    String? id,
    String? userId,
    String? Function()? categoryId,
    bool? isEnabled,
    List<int>? thresholds,
    bool? predictionsEnabled,
    String? Function()? quietHoursStart,
    String? Function()? quietHoursEnd,
  }) {
    return AlertPreferenceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      isEnabled: isEnabled ?? this.isEnabled,
      thresholds: thresholds ?? this.thresholds,
      predictionsEnabled: predictionsEnabled ?? this.predictionsEnabled,
      quietHoursStart:
          quietHoursStart != null ? quietHoursStart() : this.quietHoursStart,
      quietHoursEnd:
          quietHoursEnd != null ? quietHoursEnd() : this.quietHoursEnd,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertPreferenceModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          categoryId == other.categoryId &&
          isEnabled == other.isEnabled &&
          _listEquals(thresholds, other.thresholds) &&
          predictionsEnabled == other.predictionsEnabled &&
          quietHoursStart == other.quietHoursStart &&
          quietHoursEnd == other.quietHoursEnd;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        categoryId,
        isEnabled,
        Object.hashAll(thresholds),
        predictionsEnabled,
        quietHoursStart,
        quietHoursEnd,
      );

  @override
  String toString() =>
      'AlertPreferenceModel(id: $id, userId: $userId, '
      'categoryId: $categoryId, isEnabled: $isEnabled, '
      'thresholds: $thresholds, predictions: $predictionsEnabled, '
      'quietHours: $quietHoursStart-$quietHoursEnd)';
}

/// Helper to compare two lists for equality.
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
