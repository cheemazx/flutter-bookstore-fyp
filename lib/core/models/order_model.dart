
import 'cart_item.dart';

class OrderModel {
  final String id;
  final String userId;
  final List<CartItem> items;
  final double totalAmount;
  final String status;
  final DateTime timestamp;
  final List<String> sellerIds;
  final String? cancellationReason;
  final List<Map<String, dynamic>> statusHistory;
  final String? invoiceNumber;

  /// Valid order statuses
  static const String statusProcessing = 'Processing';
  static const String statusConfirmed = 'Confirmed';
  static const String statusShipped = 'Shipped';
  static const String statusDelivered = 'Delivered';
  static const String statusCancelled = 'Cancelled';
  static const String statusReturnRequested = 'Return Requested';
  static const String statusReturned = 'Returned';

  static const List<String> allStatuses = [
    statusProcessing,
    statusConfirmed,
    statusShipped,
    statusDelivered,
    statusCancelled,
    statusReturnRequested,
    statusReturned,
  ];

  /// The normal forward progression of an order
  static const List<String> progressionStatuses = [
    statusProcessing,
    statusConfirmed,
    statusShipped,
    statusDelivered,
  ];

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.timestamp,
    required this.sellerIds,
    this.cancellationReason,
    this.statusHistory = const [],
    this.invoiceNumber,
  });

  OrderModel copyWith({
    String? id,
    String? userId,
    List<CartItem>? items,
    double? totalAmount,
    String? status,
    DateTime? timestamp,
    List<String>? sellerIds,
    String? cancellationReason,
    List<Map<String, dynamic>>? statusHistory,
    String? invoiceNumber,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      sellerIds: sellerIds ?? this.sellerIds,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      statusHistory: statusHistory ?? this.statusHistory,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
    );
  }

  /// Whether the order can be cancelled by the buyer
  bool get canCancel =>
      status == statusProcessing || status == statusConfirmed;

  /// Whether a return can be requested
  bool get canRequestReturn => status == statusDelivered;

  /// Whether the seller can advance the order status
  bool get canAdvanceStatus =>
      status == statusProcessing ||
      status == statusConfirmed ||
      status == statusShipped;

  /// Get the next status in the progression
  String? get nextStatus {
    final idx = progressionStatuses.indexOf(status);
    if (idx >= 0 && idx < progressionStatuses.length - 1) {
      return progressionStatuses[idx + 1];
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'sellerIds': sellerIds,
      'cancellationReason': cancellationReason,
      'statusHistory': statusHistory,
      'invoiceNumber': invoiceNumber,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String docId) {
    return OrderModel(
      id: docId,
      userId: map['userId'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => CartItem.fromMap(item))
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'Processing',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'].toString())
          : DateTime.now(),
      sellerIds: List<String>.from(map['sellerIds'] ?? []),
      cancellationReason: map['cancellationReason'],
      statusHistory: (map['statusHistory'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      invoiceNumber: map['invoiceNumber'],
    );
  }
}
