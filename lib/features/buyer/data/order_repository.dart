import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/order_model.dart';
import 'notification_repository.dart';
import 'wallet_repository.dart';

class OrderRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationRepository _notificationRepo = NotificationRepository();
  final WalletRepository _walletRepo = WalletRepository();

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
    // 1. Check wallet balance BEFORE doing anything else
    final hasFunds = await _walletRepo.hasSufficientBalance(
        order.userId, order.totalAmount);
    if (!hasFunds) {
      final balance = await _walletRepo.getBalance(order.userId);
      throw Exception(
          'Insufficient wallet balance. You have Rs. ${balance.toStringAsFixed(0)} but need Rs. ${order.totalAmount.toStringAsFixed(0)}. Please top up your wallet.');
    }

    // 2. Check stock for all items
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

    // 3. Deduct wallet — funds held in escrow
    await _walletRepo.deductForOrder(
        order.userId, order.id, order.totalAmount);

    // 4. Deduct stock
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

    // 5. Generate invoice number and initial status history
    final invoiceNumber = _generateInvoiceNumber();
    final initialHistory = [
      {
        'status': OrderModel.statusProcessing,
        'timestamp': DateTime.now().toIso8601String(),
        'note': 'Order placed — payment held in escrow',
      }
    ];

    final enrichedOrder = order.copyWith(
      invoiceNumber: invoiceNumber,
      statusHistory: initialHistory,
    );

    await _supabase.from('orders').insert(enrichedOrder.toMap());

    // 6. Notify sellers of the new order
    try {
      await _notificationRepo.notifyNewOrder(
        orderId: order.id,
        sellerIds: order.sellerIds,
        totalAmount: order.totalAmount,
        itemCount: order.items.length,
      );
    } catch (e) {
      print('Failed to send new order notification: $e');
    }
  }

  /// Update the status of an order and append to status history.
  /// When status becomes 'Delivered', escrow funds are released to seller(s).
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final response =
        await _supabase.from('orders').select().eq('id', orderId).single();
    final order = OrderModel.fromMap(response, orderId);

    final updatedHistory = List<Map<String, dynamic>>.from(order.statusHistory);
    updatedHistory.add({
      'status': newStatus,
      'timestamp': DateTime.now().toIso8601String(),
      'note': newStatus == OrderModel.statusDelivered
          ? 'Order delivered — funds released to seller(s)'
          : 'Status updated to $newStatus',
    });

    await _supabase.from('orders').update({
      'status': newStatus,
      'statusHistory': updatedHistory,
    }).eq('id', orderId);

    // Release escrow funds to seller(s) on delivery
    if (newStatus == OrderModel.statusDelivered) {
      try {
        await _releaseEscrowToSellers(order);
      } catch (e) {
        print('Wallet release failed (non-critical): $e');
      }
    }

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

  /// Splits the order total proportionally and releases each seller's share.
  Future<void> _releaseEscrowToSellers(OrderModel order) async {
    if (order.sellerIds.isEmpty) return;

    // Calculate each seller's share based on their items
    final Map<String, double> sellerTotals = {};
    for (final item in order.items) {
      final sellerId = item.book.sellerId;
      if (sellerId.isEmpty) continue;
      sellerTotals[sellerId] =
          (sellerTotals[sellerId] ?? 0.0) + (item.price * item.quantity);
    }

    // If we couldn't map items to sellers, split equally
    if (sellerTotals.isEmpty) {
      final split = order.totalAmount / order.sellerIds.length;
      for (final sellerId in order.sellerIds) {
        await _walletRepo.releaseToSeller(sellerId, order.id, split);
      }
    } else {
      for (final entry in sellerTotals.entries) {
        await _walletRepo.releaseToSeller(entry.key, order.id, entry.value);
      }
    }
  }

  /// Cancel an order, restore stock, and refund buyer's wallet.
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
      'note': 'Cancelled: $reason — refund issued to wallet',
    });

    await _supabase.from('orders').update({
      'status': OrderModel.statusCancelled,
      'cancellationReason': reason,
      'statusHistory': updatedHistory,
    }).eq('id', orderId);

    // Refund buyer wallet
    try {
      await _walletRepo.refundToBuyer(
          order.userId, orderId, order.totalAmount);
    } catch (e) {
      print('Wallet refund failed (non-critical): $e');
    }

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
      'note': approved
          ? 'Return approved — refund issued to buyer wallet'
          : 'Return denied',
    });

    await _supabase.from('orders').update({
      'status': newStatus,
      'statusHistory': updatedHistory,
    }).eq('id', orderId);

    // Refund buyer if return approved
    // Note: seller's wallet is NOT clawed back in this demo — funds stay with seller
    if (approved) {
      try {
        await _walletRepo.refundToBuyer(
            order.userId, orderId, order.totalAmount);
      } catch (e) {
        print('Wallet refund on return failed (non-critical): $e');
      }
    }

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
