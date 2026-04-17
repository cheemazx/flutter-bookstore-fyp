import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/models/order_model.dart';
import '../../auth/data/auth_repository.dart';
import '../../buyer/data/order_repository.dart';

final sellerOrdersProvider =
    StreamProvider.family<List<OrderModel>, String>((ref, sellerId) {
  return ref.watch(orderRepositoryProvider).getSellerOrders(sellerId);
});

class SellerOrdersScreen extends ConsumerStatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  ConsumerState<SellerOrdersScreen> createState() =>
      _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends ConsumerState<SellerOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [
    'All',
    'New',
    'Confirmed',
    'Shipped',
    'Delivered',
    'Returns',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders, String tab) {
    switch (tab) {
      case 'New':
        return orders
            .where((o) => o.status == OrderModel.statusProcessing)
            .toList();
      case 'Confirmed':
        return orders
            .where((o) => o.status == OrderModel.statusConfirmed)
            .toList();
      case 'Shipped':
        return orders
            .where((o) => o.status == OrderModel.statusShipped)
            .toList();
      case 'Delivered':
        return orders
            .where((o) => o.status == OrderModel.statusDelivered)
            .toList();
      case 'Returns':
        return orders
            .where((o) =>
                o.status == OrderModel.statusReturnRequested ||
                o.status == OrderModel.statusReturned ||
                o.status == OrderModel.statusCancelled)
            .toList();
      default:
        return orders;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Processing':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      case 'Shipped':
        return Colors.indigo;
      case 'Delivered':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      case 'Return Requested':
        return Colors.amber.shade700;
      case 'Returned':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Processing':
        return Icons.hourglass_top;
      case 'Confirmed':
        return Icons.check_circle_outline;
      case 'Shipped':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.inventory_2;
      case 'Cancelled':
        return Icons.cancel_outlined;
      case 'Return Requested':
        return Icons.assignment_return;
      case 'Returned':
        return Icons.undo;
      default:
        return Icons.info_outline;
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      await ref.read(orderRepositoryProvider).updateOrderStatus(orderId, newStatus);
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        ref.invalidate(sellerOrdersProvider(user.id));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order updated to $newStatus'),
            backgroundColor: _statusColor(newStatus),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processReturn(String orderId, bool approved) async {
    try {
      await ref.read(orderRepositoryProvider).processReturn(orderId, approved);
      final user = ref.read(authRepositoryProvider).currentUser;
      if (user != null) {
        ref.invalidate(sellerOrdersProvider(user.id));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approved ? 'Return approved' : 'Return denied'),
            backgroundColor: approved ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportToCsv(
      BuildContext context, List<OrderModel> orders, String sellerId) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders to export')),
      );
      return;
    }

    try {
      List<List<dynamic>> rows = [];
      rows.add([
        'Order ID',
        'Invoice',
        'Date',
        'Status',
        'Book Title',
        'Quantity',
        'Unit Price',
        'Total Price',
        'Buyer ID'
      ]);

      for (final order in orders) {
        final sellerItems =
            order.items.where((item) => item.book.sellerId == sellerId).toList();
        for (final item in sellerItems) {
          rows.add([
            order.id,
            order.invoiceNumber ?? 'N/A',
            order.timestamp.toString(),
            order.status,
            item.title,
            item.quantity,
            item.price.toStringAsFixed(2),
            item.totalPrice.toStringAsFixed(2),
            order.userId,
          ]);
        }
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/seller_orders.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      if (context.mounted) {
        await Share.shareXFiles([XFile(path)], text: 'Here are your orders.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view orders')),
      );
    }

    final ordersAsync = ref.watch(sellerOrdersProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: () {
              final orders = ordersAsync.asData?.value ?? [];
              _exportToCsv(context, orders, user.id);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) {
            // Show count badges on tabs
            final orders = ordersAsync.asData?.value ?? [];
            final filtered = _filterOrders(orders, t);
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t),
                  if (filtered.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${filtered.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          return TabBarView(
            controller: _tabController,
            children: _tabs.map((tab) {
              final filtered = _filterOrders(orders, tab);
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No ${tab.toLowerCase()} orders',
                        style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: filtered.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final order = filtered[index];
                  return _buildOrderCard(order, user.id);
                },
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, String sellerId) {
    final sellerItems =
        order.items.where((item) => item.book.sellerId == sellerId).toList();
    final sellerTotal =
        sellerItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final statusColor = _statusColor(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: order.status == OrderModel.statusProcessing
              ? Colors.orange.withOpacity(0.5)
              : Colors.grey.withOpacity(0.2),
          width: order.status == OrderModel.statusProcessing ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Order header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (order.invoiceNumber != null)
                          Text(
                            order.invoiceNumber!,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(order.status),
                              size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            order.status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.timestamp.toString().split('.')[0],
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Text(
                      'Rs. ${sellerTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Items
          ExpansionTile(
            title: Text('${sellerItems.length} item(s)',
                style: const TextStyle(fontSize: 14)),
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sellerItems.length,
                itemBuilder: (context, itemIndex) {
                  final item = sellerItems[itemIndex];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: item.imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(item.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.book)),
                            )
                          : const Icon(Icons.book),
                    ),
                    title: Text(item.title),
                    subtitle: Text('Qty: ${item.quantity}'),
                    trailing:
                        Text('Rs. ${item.totalPrice.toStringAsFixed(2)}'),
                  );
                },
              ),
            ],
          ),

          // Cancellation reason
          if (order.cancellationReason != null &&
              order.cancellationReason!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.red.withOpacity(0.05),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${order.cancellationReason}',
                      style: const TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // Action buttons
          if (order.canAdvanceStatus ||
              order.status == OrderModel.statusReturnRequested)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                children: [
                  if (order.canAdvanceStatus && order.nextStatus != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _updateStatus(order.id, order.nextStatus!),
                        icon: Icon(_statusIcon(order.nextStatus!), size: 18),
                        label: Text('Mark as ${order.nextStatus}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _statusColor(order.nextStatus!),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  if (order.status == OrderModel.statusReturnRequested) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _processReturn(order.id, false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Deny'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _processReturn(order.id, true),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve Return'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
