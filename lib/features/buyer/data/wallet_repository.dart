import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/wallet_model.dart';

class WalletRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Read ──────────────────────────────────────────────────

  /// Real-time stream of a user's wallet balance.
  Stream<WalletModel?> watchWallet(String userId) {
    return _supabase
        .from('wallets')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) => rows.isNotEmpty ? WalletModel.fromMap(rows.first) : null);
  }

  /// Real-time stream of a user's transaction history (newest first).
  Stream<List<WalletTransaction>> watchTransactions(String userId) {
    return _supabase
        .from('wallet_transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) =>
            rows.map((r) => WalletTransaction.fromMap(r)).toList());
  }

  /// Fetch current balance once (for pre-checkout check).
  Future<double> getBalance(String userId) async {
    final row = await _supabase
        .from('wallets')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return 0.0;
    return (row['balance'] ?? 0.0).toDouble();
  }

  /// Returns true if the user has enough balance.
  Future<bool> hasSufficientBalance(String userId, double amount) async {
    final balance = await getBalance(userId);
    return balance >= amount;
  }

  // ── Ensure wallet row ────────────────────────────────────

  /// Creates a wallet row if one doesn't already exist.
  Future<void> ensureWalletExists(String userId) async {
    await _supabase.from('wallets').upsert(
      {'user_id': userId, 'balance': 0.00},
      onConflict: 'user_id',
      ignoreDuplicates: true,
    );
  }

  // ── Write helpers ────────────────────────────────────────

  Future<void> _logTransaction({
    required String userId,
    required String type,
    required double amount,
    String? description,
    String? orderId,
  }) async {
    await _supabase.from('wallet_transactions').insert({
      'id': const Uuid().v4(),
      'user_id': userId,
      'type': type,
      'amount': amount,
      'description': description,
      'order_id': orderId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _adjustBalance(String userId, double delta) async {
    // Fetch current balance then update
    final row = await _supabase
        .from('wallets')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();

    final current = row != null ? (row['balance'] ?? 0.0).toDouble() : 0.0;
    final newBalance = current + delta;

    await _supabase.from('wallets').upsert({
      'user_id': userId,
      'balance': newBalance,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
  }

  // ── Public operations ────────────────────────────────────

  /// Buyer tops up their wallet.
  Future<void> topUp(String userId, double amount) async {
    if (amount <= 0) throw Exception('Top-up amount must be greater than zero.');
    await ensureWalletExists(userId);
    await _adjustBalance(userId, amount);
    await _logTransaction(
      userId: userId,
      type: 'topup',
      amount: amount,
      description: 'Wallet top-up of Rs. ${amount.toStringAsFixed(0)}',
    );
  }

  /// Deduct buyer's wallet when placing an order.
  /// Throws if insufficient balance.
  Future<void> deductForOrder(String userId, String orderId, double amount) async {
    final balance = await getBalance(userId);
    if (balance < amount) {
      throw Exception(
          'Insufficient wallet balance. You have Rs. ${balance.toStringAsFixed(0)} but need Rs. ${amount.toStringAsFixed(0)}.');
    }
    await _adjustBalance(userId, -amount);
    await _logTransaction(
      userId: userId,
      type: 'purchase',
      amount: amount,
      description: 'Payment for order #$orderId',
      orderId: orderId,
    );
  }

  /// Release funds to a seller after order delivery.
  Future<void> releaseToSeller(
      String sellerId, String orderId, double amount) async {
    await ensureWalletExists(sellerId);
    await _adjustBalance(sellerId, amount);
    await _logTransaction(
      userId: sellerId,
      type: 'release',
      amount: amount,
      description: 'Earnings released for order #$orderId',
      orderId: orderId,
    );
  }

  /// Refund buyer when order is cancelled or returned.
  Future<void> refundToBuyer(
      String userId, String orderId, double amount) async {
    await _adjustBalance(userId, amount);
    await _logTransaction(
      userId: userId,
      type: 'refund',
      amount: amount,
      description: 'Refund for cancelled/returned order #$orderId',
      orderId: orderId,
    );
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository();
});
