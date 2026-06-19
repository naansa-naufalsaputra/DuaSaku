class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarPath;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarPath,
    required this.createdAt,
    required this.lastActiveAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarPath: json['avatar_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastActiveAt: DateTime.parse(json['last_active_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (avatarPath != null) 'avatar_path': avatarPath,
      'created_at': createdAt.toIso8601String(),
      'last_active_at': lastActiveAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? avatarPath,
    DateTime? lastActiveAt,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}
