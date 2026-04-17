import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/topup_request_model.dart';
import '../../buyer/data/topup_request_repository.dart';

class AdminRepository {
  final _repo = TopUpRequestRepository();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Pending top-up requests (for badge count)
  Future<int> getPendingCount() => _repo.getPendingCount();

  /// Fetch requests by status: 'pending' | 'approved' | 'rejected'
  Future<List<TopUpRequest>> getRequestsByStatus(String status) =>
      _repo.fetchRequestsByStatus(status);

  /// Approve a top-up request
  Future<void> approveRequest(String requestId, {String? note}) =>
      _repo.approveRequest(requestId, adminNote: note);

  /// Reject a top-up request
  Future<void> rejectRequest(String requestId, {required String note}) =>
      _repo.rejectRequest(requestId, adminNote: note);

  /// Get all buyers and sellers with wallet balances
  Future<List<Map<String, dynamic>>> getUsersWithBalances() =>
      _repo.fetchUsersWithBalances();

  /// Get aggregate stats for dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final pending = await getPendingCount();

    final usersRows = await _supabase
        .from('users')
        .select('id, role')
        .inFilter('role', ['buyer', 'seller']);

    final buyerCount =
        usersRows.where((u) => u['role'] == 'buyer').length;
    final sellerCount =
        usersRows.where((u) => u['role'] == 'seller').length;

    final walletRows =
        await _supabase.from('wallets').select('balance');
    final totalVolume = walletRows.fold<double>(
        0.0, (sum, r) => sum + ((r['balance'] ?? 0.0) as num).toDouble());

    final txnRows = await _supabase
        .from('wallet_transactions')
        .select('id')
        .eq('type', 'topup');
    final totalTopUps = txnRows.length;

    return {
      'pendingRequests': pending,
      'buyerCount': buyerCount,
      'sellerCount': sellerCount,
      'totalVolume': totalVolume,
      'totalTopUps': totalTopUps,
    };
  }
}

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository());
