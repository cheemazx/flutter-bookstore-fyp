import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:my_app/core/providers/cart_provider.dart';
import 'package:my_app/core/providers/wallet_provider.dart';
import 'package:my_app/core/models/order_model.dart';
import 'package:my_app/features/buyer/data/order_repository.dart';
import 'package:my_app/features/auth/data/auth_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final totalAmount = ref.watch(cartTotalProvider);
    final cartItemsAsync = ref.watch(cartProvider);
    final walletAsync = ref.watch(walletProvider);

    final walletBalance = walletAsync.maybeWhen(
      data: (w) => w?.balance ?? 0.0,
      orElse: () => null,
    );
    final hasBalance = walletBalance != null && walletBalance >= totalAmount;
    final walletLoading = walletAsync is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ── Order Total ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total to Pay'),
                  Text(
                    'Rs. ${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Wallet Balance ───────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: walletBalance == null
                    ? Colors.grey.withOpacity(0.05)
                    : hasBalance
                        ? const Color(0xFF10B981).withOpacity(0.07)
                        : const Color(0xFFEF4444).withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: walletBalance == null
                      ? Colors.grey.withOpacity(0.2)
                      : hasBalance
                          ? const Color(0xFF10B981).withOpacity(0.4)
                          : const Color(0xFFEF4444).withOpacity(0.4),
                ),
              ),
              child: walletLoading
                  ? const Row(
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Loading wallet…',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_rounded,
                              size: 18,
                              color: hasBalance
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Wallet Balance',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: hasBalance
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Rs. ${(walletBalance ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: hasBalance
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
            ),

            // ── Insufficient balance warning + top-up shortcut ───
            if (walletBalance != null && !hasBalance) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFFCA5A5).withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFEF4444), size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Insufficient Balance',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF991B1B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You need \$${(totalAmount - (walletBalance)).toStringAsFixed(2)} more.',
                      style: const TextStyle(
                          color: Color(0xFF7F1D1D), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/buyer-wallet'),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Top Up Wallet'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            ElevatedButton(
              onPressed: (_isLoading || walletLoading || !hasBalance)
                  ? null
                  : () async {
                      final user =
                          ref.read(authRepositoryProvider).currentUser;
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Please login to checkout')));
                        return;
                      }

                      final cartItems = cartItemsAsync.value ?? [];
                      if (cartItems.isEmpty) return;

                      setState(() => _isLoading = true);

                      try {
                        final sellerIds = cartItems
                            .map((item) => item.book.sellerId)
                            .where((id) => id.isNotEmpty)
                            .toSet()
                            .toList();

                        final orderId = const Uuid().v4();
                        final order = OrderModel(
                          id: orderId,
                          userId: user.id,
                          items: cartItems,
                          totalAmount: totalAmount,
                          status: OrderModel.statusProcessing,
                          timestamp: DateTime.now(),
                          sellerIds: sellerIds,
                        );

                        await ref
                            .read(orderRepositoryProvider)
                            .createOrder(order);
                        await ref
                            .read(cartProvider.notifier)
                            .clearCart();

                        if (mounted) {
                          setState(() => _isLoading = false);
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => AlertDialog(
                              title: Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green[600], size: 28),
                                  const SizedBox(width: 8),
                                  const Text('Order Placed!'),
                                ],
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                      'Your order has been placed and payment is held securely.'),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFF10B981)
                                              .withOpacity(0.3)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet_rounded,
                                          size: 18,
                                          color: Color(0xFF10B981),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Funds released to seller\nafter you receive the book.',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF065F46)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => context.go('/buyer-home'),
                                  child: const Text('Continue Shopping'),
                                ),
                                ElevatedButton(
                                  onPressed: () =>
                                      context.go('/order-history'),
                                  child: const Text('View Orders'),
                                ),
                              ],
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          final msg = e
                              .toString()
                              .replaceAll('Exception: ', '');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Pay with Wallet & Place Order'),
            ),
          ],
        ),
      ),
    );
  }
}
