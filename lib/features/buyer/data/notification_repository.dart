import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new notification
  Future<void> createNotification(NotificationModel notification) async {
    await _supabase.from('notifications').insert(notification.toMap());
  }

  /// Get all notifications for a user as a stream
  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('userId', userId)
        .order('createdAt', ascending: false)
        .map((data) =>
            data.map((json) => NotificationModel.fromMap(json)).toList());
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'isRead': true}).eq('id', notificationId);
  }

  /// Mark all notifications for a user as read
  Future<void> markAllAsRead(String userId) async {
    await _supabase
        .from('notifications')
        .update({'isRead': true}).eq('userId', userId);
  }

  /// Notify all sellers of a new order
  Future<void> notifyNewOrder(
      {required String orderId,
      required List<String> sellerIds,
      required double totalAmount,
      required int itemCount}) async {
    for (final sellerId in sellerIds) {
      final notification = NotificationModel(
        id: const Uuid().v4(),
        userId: sellerId,
        title: '🛒 New Order Received!',
        message:
            'You have a new order with $itemCount item(s) worth \$${totalAmount.toStringAsFixed(2)}.',
        orderId: orderId,
        type: 'new_order',
        createdAt: DateTime.now(),
      );
      await createNotification(notification);
    }
  }

  /// Notify the buyer of an order status update
  Future<void> notifyStatusUpdate({
    required String buyerUserId,
    required String orderId,
    required String newStatus,
  }) async {
    String title;
    String message;

    switch (newStatus) {
      case 'Confirmed':
        title = '✅ Order Confirmed';
        message = 'Your order has been confirmed and is being prepared.';
        break;
      case 'Shipped':
        title = '🚚 Order Shipped';
        message = 'Your order is on its way!';
        break;
      case 'Delivered':
        title = '📦 Order Delivered';
        message = 'Your order has been delivered. Enjoy your books!';
        break;
      case 'Cancelled':
        title = '❌ Order Cancelled';
        message = 'Your order has been cancelled.';
        break;
      case 'Return Requested':
        title = '🔄 Return Requested';
        message = 'Your return request has been submitted.';
        break;
      case 'Returned':
        title = '✅ Return Approved';
        message = 'Your return has been approved and processed.';
        break;
      default:
        title = '📋 Order Update';
        message = 'Your order status has been updated to $newStatus.';
    }

    final notification = NotificationModel(
      id: const Uuid().v4(),
      userId: buyerUserId,
      title: title,
      message: message,
      orderId: orderId,
      type: newStatus == 'Cancelled'
          ? 'cancellation'
          : newStatus.contains('Return')
              ? 'return_request'
              : 'status_update',
      createdAt: DateTime.now(),
    );
    await createNotification(notification);
  }

  /// Notify sellers about a cancellation
  Future<void> notifyCancellation({
    required String orderId,
    required List<String> sellerIds,
    required String reason,
  }) async {
    for (final sellerId in sellerIds) {
      final notification = NotificationModel(
        id: const Uuid().v4(),
        userId: sellerId,
        title: '❌ Order Cancelled',
        message: 'An order has been cancelled. Reason: $reason',
        orderId: orderId,
        type: 'cancellation',
        createdAt: DateTime.now(),
      );
      await createNotification(notification);
    }
  }

  /// Notify sellers about a return request
  Future<void> notifyReturnRequest({
    required String orderId,
    required List<String> sellerIds,
    required String reason,
  }) async {
    for (final sellerId in sellerIds) {
      final notification = NotificationModel(
        id: const Uuid().v4(),
        userId: sellerId,
        title: '🔄 Return Requested',
        message: 'A buyer has requested a return. Reason: $reason',
        orderId: orderId,
        type: 'return_request',
        createdAt: DateTime.now(),
      );
      await createNotification(notification);
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});
