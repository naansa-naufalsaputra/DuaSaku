import 'goal_status.dart';

class GoalModel {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final String icon;
  final String color;
  final String? linkedWalletId;
  final TrackingMode trackingMode;
  final GoalStatus status;
  final DateTime? completedAt;
  final Set<int> notifiedMilestones;
  final DateTime createdAt;

  GoalModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.deadline,
    required this.icon,
    required this.color,
    this.linkedWalletId,
    required this.trackingMode,
    this.status = GoalStatus.active,
    this.completedAt,
    this.notifiedMilestones = const {},
    required this.createdAt,
  });

  // Computed properties

  /// Progress as a value between 0.0 and 1.0.
  double get progressPercentage =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  /// Number of days remaining until the deadline, or null if no deadline.
  int? get remainingDays => deadline?.difference(DateTime.now()).inDays;

  /// Whether this goal has been completed.
  bool get isCompleted => status == GoalStatus.completed;

  /// The current milestone bracket (0, 25, 50, 75, or 100).
  int get currentMilestone {
    final pct = (progressPercentage * 100).floor();
    if (pct >= 100) return 100;
    if (pct >= 75) return 75;
    if (pct >= 50) return 50;
    if (pct >= 25) return 25;
    return 0;
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0.0,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      icon: json['icon'] as String,
      color: json['color'] as String,
      linkedWalletId: json['linked_wallet_id'] as String?,
      trackingMode: TrackingMode.fromString(json['tracking_mode'] as String),
      status: GoalStatus.fromString(json['status'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      notifiedMilestones: _parseMilestones(json['notified_milestones']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      if (deadline != null) 'deadline': deadline!.toIso8601String(),
      'icon': icon,
      'color': color,
      if (linkedWalletId != null) 'linked_wallet_id': linkedWalletId,
      'tracking_mode': trackingMode.name,
      'status': status.name,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      'notified_milestones': notifiedMilestones.join(','),
      'created_at': createdAt.toIso8601String(),
    };
  }

  GoalModel copyWith({
    String? id,
    String? userId,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    bool clearDeadline = false,
    String? icon,
    String? color,
    String? linkedWalletId,
    bool clearLinkedWalletId = false,
    TrackingMode? trackingMode,
    GoalStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    Set<int>? notifiedMilestones,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      icon: icon ?? this.icon,
      color: color ?? this.color,
      linkedWalletId: clearLinkedWalletId
          ? null
          : (linkedWalletId ?? this.linkedWalletId),
      trackingMode: trackingMode ?? this.trackingMode,
      status: status ?? this.status,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
      notifiedMilestones: notifiedMilestones ?? this.notifiedMilestones,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static Set<int> _parseMilestones(dynamic value) {
    if (value == null || value == '') return {};
    if (value is String) {
      return value
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => int.parse(s.trim()))
          .toSet();
    }
    if (value is List) {
      return value.map((e) => e as int).toSet();
    }
    return {};
  }
}
