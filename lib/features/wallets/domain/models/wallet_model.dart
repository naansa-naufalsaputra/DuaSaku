class WalletModel {
  final String id;
  final String userId;
  final String name;
  final String type; // 'Bank', 'E-Wallet', 'Cash'
  final double balance;
  final String currency; // ISO 4217 currency code (e.g., 'IDR', 'USD')
  final DateTime createdAt;

  WalletModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'IDR',
    required this.createdAt,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      balance: (json['balance'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'IDR',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'type': type,
      'balance': balance,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
    };
  }

  WalletModel copyWith({
    String? name,
    String? type,
    double? balance,
    String? currency,
  }) {
    return WalletModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      createdAt: createdAt,
    );
  }
}
