import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/wallet_model.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../auth/data/auth_repository.dart';

class SellerWalletScreen extends ConsumerWidget {
  const SellerWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final walletAsync = ref.watch(userWalletProvider(user.id));
    final transactionsAsync = ref.watch(userTransactionsProvider(user.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Earnings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Earnings Card ─────────────────────────────────────
          walletAsync.when(
            data: (wallet) => _EarningsCard(balance: wallet?.balance ?? 0.0),
            loading: () => const _EarningsCard(balance: 0.0, loading: true),
            error: (e, _) => const _EarningsCard(balance: 0.0),
          ),

          // ── Transaction list ──────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Row(
              children: const [
                Text(
                  'Earnings History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              data: (txns) {
                // Only show release transactions for sellers
                final releases =
                    txns.where((t) => t.type == 'release').toList();
                if (releases.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'No earnings yet',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Funds are released when orders are delivered',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  itemCount: releases.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _EarningsTile(transaction: releases[i]),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Earnings Card ──────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  final double balance;
  final bool loading;

  const _EarningsCard({required this.balance, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.trending_up_rounded,
                  color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Total Earnings',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          loading
              ? const SizedBox(
                  height: 48,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ))
              : Text(
                  'Rs. ${balance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '💡 Released automatically on delivery',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Earnings Tile ──────────────────────────────────────────────────────────────

class _EarningsTile extends StatelessWidget {
  final WalletTransaction transaction;

  const _EarningsTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF10B981), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Earnings Released',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1F2937)),
                ),
                if (transaction.orderId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Order: ${transaction.orderId!.substring(0, 8).toUpperCase()}…',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, yyyy • h:mm a')
                      .format(transaction.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
          Text(
            '+\$${transaction.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }
}
