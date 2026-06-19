class TransactionModel {
  final int? id;
  final String userId;
  final double amount;
  final String currency; // ISO 4217 currency code
  final String categoryId; // References Categories.id (foreign key)
  final String type; // 'income', 'expense', or 'transfer'
  final String notes;
  final DateTime createdAt;
  final String? walletId;
  final String? fromWalletId;
  final String? toWalletId;
  final double? latitude;
  final double? longitude;
  final String? photoPath;

  TransactionModel({
    this.id,
    required this.userId,
    required this.amount,
    this.currency = 'IDR',
    required this.categoryId,
    required this.type,
    required this.notes,
    required this.createdAt,
    this.walletId,
    this.fromWalletId,
    this.toWalletId,
    this.latitude,
    this.longitude,
    this.photoPath,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int?,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'IDR',
      categoryId: json['category_id'] as String,
      type: json['type'] as String,
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      walletId: json['wallet_id'] as String?,
      fromWalletId: json['from_wallet_id'] as String?,
      toWalletId: json['to_wallet_id'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      photoPath: json['photo_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'category_id': categoryId,
      'type': type,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      if (walletId != null) 'wallet_id': walletId,
      if (fromWalletId != null) 'from_wallet_id': fromWalletId,
      if (toWalletId != null) 'to_wallet_id': toWalletId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (photoPath != null) 'photo_path': photoPath,
    };
  }

  TransactionModel copyWith({
    int? id,
    String? userId,
    double? amount,
    String? currency,
    String? categoryId,
    String? type,
    String? notes,
    DateTime? createdAt,
    String? walletId,
    String? fromWalletId,
    String? toWalletId,
    double? latitude,
    double? longitude,
    String? photoPath,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      walletId: walletId ?? this.walletId,
      fromWalletId: fromWalletId ?? this.fromWalletId,
      toWalletId: toWalletId ?? this.toWalletId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}
