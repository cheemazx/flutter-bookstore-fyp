import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/order_model.dart';
import 'notification_repository.dart';

class OrderRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationRepository _notificationRepo = NotificationRepository();

  /// Generate a human-readable invoice number
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'INV-$datePart-$timePart';
  }

  Future<void> createOrder(OrderModel order) async {
    // Check stock for all items
    for (final item in order.items) {
      final response = await _supabase
          .from('books')
          .select('quantity')
          .eq('id', item.id)
          .single();
      final currentQuantity = response['quantity'] as int;
      if (currentQuantity < item.quantity) {
        throw Exception(
            'Insufficient stock for "${item.title}". Only $currentQuantity left.');
      }
    }

    // Deduct stock
    for (final item in order.items) {
      final response = await _supabase
          .from('books')
          .select('quantity')
          .eq('id', item.id)
          .single();
      final currentQuantity = response['quantity'] as int;
      final newQuantity = currentQuantity - item.quantity;
      await _supabase
          .from('books')
          .update({'quantity': newQuantity}).eq('id', item.id);
    }

    // Generate invoice number and initial status history
    final invoiceNumber = _generateInvoiceNumber();
    final initialHistory = [
      {
        'status': OrderModel.statusProcessing,
        'timestamp': DateTime.now().toIso8601String(),
        'note': 'Order placed',
      }
    ];

    final enrichedOrder = order.copyWith(
      invoiceNumber: invoiceNumber,
      statusHistory: initialHistory,
    );

    await _supabase.from('orders').insert(enrichedOrder.toMap());

    // Notify sellers of the new order
    try {
      await _notificationRepo.notifyNewOrder(
        orderId: order.id,
        sellerIds: order.sellerIds,
        totalAmount: order.totalAmount,
        itemCount: order.items.length,
      );
    } catch (e) {
      // Don't fail the order if notification fails
      print('Failed to send new order notification: $e');
    }
  }

  /// Update the status of an order and append to status history
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final response =
        await _supabase.from('orders').select().eq('id', orderId).single();
    final order = OrderModel.fromMap(response, orderId);

    final updatedHistory = List<Map<String, dynamic>>.from(order.statusHistory);
    updatedHistory.add({
      'status': newStatus,
      'timestamp': DateTime.now().toIso8601String(),
      'note': 'Status updated to $newStatus',
    });

    await _supabase.from('orders').update({
      'status': newStatus,
      'statusHistory': updatedHistory,
    }).eq('id', orderId);

    // Notify the buyer
    try {
      await _notificationRepo.notifyStatusUpdate(
        buyerUserId: order.userId,
        orderId: orderId,
        newStatus: newStatus,
      );
    } catch (e) {
      print('Failed to send status update notification: $e');
    }
  }

  /// Cancel an order and restore stock
  Future<void> cancelOrder(String orderId, String reason) async {
    final response =
        await _supabase.from('orders').select().eq('id', orderId).single();
    final order = OrderModel.fromMap(response, orderId);

    if (!order.canCancel) {
      throw Exception(
          'Order cannot be cancelled in its current status: ${order.status}');
    }

    // Restore stock
    for (final item in order.items) {
      final bookResponse = await _supabase
          .from('books')
          .select('quantity')
          .eq('id', item.id)
          .single();
      final currentQuantity = bookResponse['quantity'] as int;
      await _supabase
          .from('books')
          .update({'quantity': currentQuantity + item.quantity}).eq(
              'id', item.id);
    }

    final updatedHistory = List<Map<String, dynamic>>.from(order.statusHistory);
    updatedHistory.add({
      'status': OrderModel.statusCancelled,
      'timestamp': DateTime.now().toIso8601String(),
      'note': 'Cancelled: $reason',
    });

    await _supabase.from('orders').update({
      'status': OrderModel.statusCancelled,
      'cancellationReason': reason,
      'statusHistory': updatedHistory,
    }).eq('id', orderId);

    // Notify sellers
    try {
      await _notificationRepo.notifyCancellation(
        orderId: orderId,
        sellerIds: order.sellerIds,
        reason: reason,
      );
    } catch (e) {
      print('Failed to send cancellation notification: $e');
    }
  }

  /// Request a return for a delivered order
  Future<void> requestReturn(String orderId, String reason) async {
    final response =
        await _supabase.from('orders').select().eq('id', orderId).single();
    final order = OrderModel.fromMap(response, orderId);

    if (!order.canRequestReturn) {
      throw Exception('Return can only be requested for delivered orders.');
    }

    final updatedHistory = List<Map<String, dynamic>>.from(order.statusHistory);
    updatedHistory.add({
      'status': OrderModel.statusReturnRequested,
      'timestamp': DateTime.now().toIso8601String(),
      'note': 'Return requested: $reason',
    });

    await _supabase.from('orders').update({
      'status': OrderModel.statusReturnRequested,
      'cancellationReason': reason,
      'statusHistory': updatedHistory,
    }).eq('id', orderId);

    // Notify sellers
    try {
      await _notificationRepo.notifyReturnRequest(
        orderId: orderId,
        sellerIds: order.sellerIds,
        reason: reason,
      );
    } catch (e) {
      print('Failed to send return request notification: $e');
    }
  }

  /// Process a return (approve or deny)
  Future<void> processReturn(String orderId, bool approved) async {
    final response =
        await _supabase.from('orders').select().eq('id', orderId).single();
    final order = OrderModel.fromMap(response, orderId);

    if (order.status != OrderModel.statusReturnRequested) {
      throw Exception('Order is not in Return Requested status.');
    }

    final newStatus =
        approved ? OrderModel.statusReturned : OrderModel.statusDelivered;

    // Restore stock if return is approved
    if (approved) {
      for (final item in order.items) {
        final bookResponse = await _supabase
            .from('books')
            .select('quantity')
            .eq('id', item.id)
            .single();
        final currentQuantity = bookResponse['quantity'] as int;
        await _supabase
            .from('books')
            .update({'quantity': currentQuantity + item.quantity}).eq(
                'id', item.id);
      }
    }

    final updatedHistory = List<Map<String, dynamic>>.from(order.statusHistory);
    updatedHistory.add({
      'status': newStatus,
      'timestamp': DateTime.now().toIso8601String(),
      'note': approved ? 'Return approved' : 'Return denied',
    });

    await _supabase.from('orders').update({
      'status': newStatus,
      'statusHistory': updatedHistory,
    }).eq('id', orderId);

    // Notify the buyer
    try {
      await _notificationRepo.notifyStatusUpdate(
        buyerUserId: order.userId,
        orderId: orderId,
        newStatus: approved ? OrderModel.statusReturned : 'Return Denied',
      );
    } catch (e) {
      print('Failed to send return process notification: $e');
    }
  }

  Stream<List<OrderModel>> getUserOrders(String userId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('userId', userId)
        .order('timestamp', ascending: false)
        .map((data) =>
            data.map((json) => OrderModel.fromMap(json, json['id'])).toList());
  }

  Stream<List<OrderModel>> getSellerOrders(String sellerId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id']).map((data) {
      final orders = data
          .where((json) {
            final ids = json['sellerIds'];
            if (ids is List) {
              return ids.contains(sellerId);
            }
            return false;
          })
          .map((json) => OrderModel.fromMap(json, json['id']))
          .toList();
      orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return orders;
    });
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository();
});
