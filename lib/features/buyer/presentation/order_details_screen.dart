
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/order_model.dart';
import '../../../core/providers/cart_provider.dart';
import '../data/order_repository.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _isLoading = false;

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

  Future<void> _cancelOrder() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this order?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final reason = reasonController.text.trim().isEmpty
          ? 'No reason provided'
          : reasonController.text.trim();
      setState(() => _isLoading = true);
      try {
        await ref.read(orderRepositoryProvider).cancelOrder(widget.order.id, reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _requestReturn() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Return'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why would you like to return this order?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for return',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            child: const Text('Submit Return', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final reason = reasonController.text.trim().isEmpty
          ? 'No reason provided'
          : reasonController.text.trim();
      setState(() => _isLoading = true);
      try {
        await ref.read(orderRepositoryProvider).requestReturn(widget.order.id, reason);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Return request submitted'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _reorderItems() async {
    setState(() => _isLoading = true);
    for (final item in widget.order.items) {
      for (int i = 0; i < item.quantity; i++) {
        await ref.read(cartProvider.notifier).addToCart(item.book);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Items added to cart'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      context.go('/buyer-home'); // Taking them back to home where cart is accessible
    }
  }

  Future<void> _downloadInvoice() async {
    final order = widget.order;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('INVOICE', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Order ID: ${order.id.substring(0, 8).toUpperCase()}'),
                      pw.Text('Date: ${DateFormat('MMM dd, yyyy').format(order.timestamp)}'),
                      if (order.invoiceNumber != null) pw.Text('Invoice #: ${order.invoiceNumber}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Flutter Bookstore', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Thank you for your purchase!'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Table.fromTextArray(
                headers: ['Item', 'Qty', 'Unit Price', 'Total'],
                data: order.items.map((item) => [
                  item.title,
                  item.quantity.toString(),
                  'Rs. ${item.price.toStringAsFixed(2)}',
                  'Rs. ${item.totalPrice.toStringAsFixed(2)}',
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'Total: \$${order.totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'invoice_${order.id.substring(0, 8)}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final statusColor = _statusColor(order.status);
    final isCancelledOrReturned = order.status == OrderModel.statusCancelled ||
        order.status == OrderModel.statusReturned;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Download Invoice',
            onPressed: () => _downloadInvoice(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Status & ID Card
                  Card(
                    elevation: 0,
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (order.invoiceNumber != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        order.invoiceNumber!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
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
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 6),
                              Text(
                                dateFormat.format(order.timestamp),
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status Timeline
                  if (!isCancelledOrReturned) ...[
                    Text(
                      'Order Progress',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusTimeline(order),
                    const SizedBox(height: 24),
                  ],

                  // Cancellation / Return Info
                  if (order.cancellationReason != null &&
                      order.cancellationReason!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: Colors.red, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                order.status == OrderModel.statusCancelled
                                    ? 'Cancellation Reason'
                                    : 'Return Reason',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            order.cancellationReason!,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Status History
                  if (order.statusHistory.isNotEmpty) ...[
                    Text(
                      'Status History',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...order.statusHistory.reversed.map((entry) {
                      final status = entry['status'] ?? '';
                      final ts = entry['timestamp'] != null
                          ? DateFormat('MMM dd, yyyy • hh:mm a')
                              .format(DateTime.parse(entry['timestamp']))
                          : '';
                      final note = entry['note'] ?? '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_statusIcon(status),
                                  size: 16, color: _statusColor(status)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(note,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  Text(ts,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500])),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // Items Ordered
                  Text(
                    'Items Ordered (${order.items.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = order.items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 50,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: item.imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(item.imageUrl,
                                      fit: BoxFit.cover),
                                )
                              : const Icon(Icons.book),
                        ),
                        title: Text(item.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Qty: ${item.quantity}'),
                        trailing: Text(
                          'Rs. ${(item.price * item.quantity).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),

                  const Divider(height: 32),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount',
                          style: TextStyle(fontSize: 18, color: Colors.grey)),
                      Text(
                        'Rs. ${order.totalAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Reorder Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _reorderItems,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Reorder Items'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  if (order.canCancel)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelOrder,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Order'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  if (order.canRequestReturn)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _requestReturn,
                        icon: const Icon(Icons.assignment_return),
                        label: const Text('Request Return'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber.shade700,
                          side: BorderSide(color: Colors.amber.shade700),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  if (order.status == OrderModel.statusReturnRequested)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_top,
                              color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your return request is being reviewed by the seller.',
                              style: TextStyle(color: Colors.amber),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusTimeline(OrderModel order) {
    final statuses = OrderModel.progressionStatuses;
    final currentIndex = statuses.indexOf(order.status);

    return Row(
      children: List.generate(statuses.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < currentIndex;
          return Expanded(
            child: Container(
              height: 3,
              color: isCompleted
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300],
            ),
          );
        }

        // Step circle
        final stepIndex = index ~/ 2;
        final status = statuses[stepIndex];
        final isCompleted = stepIndex <= currentIndex;
        final isCurrent = stepIndex == currentIndex;
        final color = isCompleted
            ? _statusColor(status)
            : Colors.grey[400]!;

        return Column(
          children: [
            Container(
              width: isCurrent ? 36 : 28,
              height: isCurrent ? 36 : 28,
              decoration: BoxDecoration(
                color: isCompleted ? color.withOpacity(0.15) : Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: isCurrent ? 2.5 : 1.5,
                ),
              ),
              child: Icon(
                isCompleted ? Icons.check : _statusIcon(status),
                size: isCurrent ? 18 : 14,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCompleted ? color : Colors.grey[500],
              ),
            ),
          ],
        );
      }),
    );
  }
}
