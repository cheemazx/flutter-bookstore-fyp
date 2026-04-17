import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/wallet_model.dart';
import '../../features/buyer/data/wallet_repository.dart';

// ── Current user convenience ─────────────────────────────────────────────────

final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

// ── Wallet balance stream ─────────────────────────────────────────────────────

final walletProvider = StreamProvider<WalletModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.read(walletRepositoryProvider).watchWallet(userId);
});

// ── Transaction history stream ────────────────────────────────────────────────

final walletTransactionsProvider =
    StreamProvider<List<WalletTransaction>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return ref.read(walletRepositoryProvider).watchTransactions(userId);
});

// ── Per-user wallet (for seller viewing their own wallet) ─────────────────────

final userWalletProvider =
    StreamProvider.family<WalletModel?, String>((ref, userId) {
  return ref.read(walletRepositoryProvider).watchWallet(userId);
});

final userTransactionsProvider =
    StreamProvider.family<List<WalletTransaction>, String>((ref, userId) {
  return ref.read(walletRepositoryProvider).watchTransactions(userId);
});
