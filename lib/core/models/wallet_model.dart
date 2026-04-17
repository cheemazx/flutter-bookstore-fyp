class WalletModel {
  final String userId;
  final double balance;
  final DateTime updatedAt;

  const WalletModel({
    required this.userId,
    required this.balance,
    required this.updatedAt,
  });

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      userId: map['user_id'] ?? '',
      balance: (map['balance'] ?? 0.0).toDouble(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'].toString())
          : DateTime.now(),
    );
  }

  WalletModel copyWith({double? balance, DateTime? updatedAt}) {
    return WalletModel(
      userId: userId,
      balance: balance ?? this.balance,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WalletTransaction {
  final String id;
  final String userId;
  final String type; // topup | purchase | release | refund
  final double amount;
  final String? description;
  final String? orderId;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.description,
    this.orderId,
    required this.createdAt,
  });

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      type: map['type'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      description: map['description'],
      orderId: map['order_id'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'amount': amount,
      'description': description,
      'order_id': orderId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// True for credits (topup / release / refund)
  bool get isCredit => type == 'topup' || type == 'release' || type == 'refund';

  String get typeLabel {
    switch (type) {
      case 'topup':
        return 'Top-Up';
      case 'purchase':
        return 'Purchase';
      case 'release':
        return 'Earnings';
      case 'refund':
        return 'Refund';
      default:
        return type;
    }
  }
}
