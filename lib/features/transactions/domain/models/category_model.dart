class CategoryModel {
  final String? id;
  final String userId;
  final String name;
  final String type; // 'income' or 'expense'
  final String? icon;
  final String? color;
  final DateTime createdAt;

  CategoryModel({
    this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    required this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'type': type,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) map['id'] = id;
    if (icon != null) map['icon'] = icon;
    if (color != null) map['color'] = color;
    return map;
  }
}
