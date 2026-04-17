import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/topup_request_model.dart';
import '../../../core/models/wallet_model.dart';

class TopUpRequestRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Screenshot Upload ─────────────────────────────────────────────────────

  /// Uploads the payment screenshot to Supabase Storage and returns the public URL.
  Future<String> uploadScreenshot(String userId, File imageFile) async {
    final ext = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = 'screenshots/$fileName';

    await _supabase.storage
        .from('payment-screenshots')
        .upload(storagePath, imageFile,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));

    final publicUrl = _supabase.storage
        .from('payment-screenshots')
        .getPublicUrl(storagePath);

    return publicUrl;
  }

  // ── Submit Request (Buyer) ────────────────────────────────────────────────

  /// Buyer submits a top-up request with a payment screenshot URL.
  Future<void> submitRequest({
    required String userId,
    required double amount,
    required String screenshotUrl,
  }) async {
    final request = TopUpRequest(
      id: const Uuid().v4(),
      userId: userId,
      amount: amount,
      screenshotUrl: screenshotUrl,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    await _supabase.from('topup_requests').insert(request.toMap());
  }

  // ── Buyer: Watch own requests ─────────────────────────────────────────────

  Stream<List<TopUpRequest>> watchMyRequests(String userId) {
    return _supabase
        .from('topup_requests')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((r) => TopUpRequest.fromMap(r)).toList());
  }

  // ── Admin: Fetch all requests (with user info) ────────────────────────────

  /// Returns all requests joined with basic user info, filtered by status.
  Future<List<TopUpRequest>> fetchRequestsByStatus(String status) async {
    final rows = await _supabase
        .from('topup_requests')
        .select(
          'id, user_id, amount, screenshot_url, status, admin_note, created_at, reviewed_at, users!inner(name, email)',
        )
        .eq('status', status)
        .order('created_at', ascending: false);

    return rows.map<TopUpRequest>((r) {
      final userInfo = r['users'] as Map<String, dynamic>? ?? {};
      return TopUpRequest(
        id: r['id'] ?? '',
        userId: r['user_id'] ?? '',
        amount: (r['amount'] ?? 0.0).toDouble(),
        screenshotUrl: r['screenshot_url'] ?? '',
        status: r['status'] ?? 'pending',
        adminNote: r['admin_note'],
        createdAt: r['created_at'] != null
            ? DateTime.parse(r['created_at'].toString())
            : DateTime.now(),
        reviewedAt: r['reviewed_at'] != null
            ? DateTime.parse(r['reviewed_at'].toString())
            : null,
        userName: userInfo['name'],
        userEmail: userInfo['email'],
      );
    }).toList();
  }

  /// Returns count of pending requests (for admin badge).
  Future<int> getPendingCount() async {
    final rows = await _supabase
        .from('topup_requests')
        .select('id')
        .eq('status', 'pending');
    return rows.length;
  }

  // ── Admin: Approve ────────────────────────────────────────────────────────

  Future<void> approveRequest(String requestId, {String? adminNote}) async {
    // Fetch request details
    final row = await _supabase
        .from('topup_requests')
        .select()
        .eq('id', requestId)
        .single();

    final userId = row['user_id'] as String;
    final amount = (row['amount'] as num).toDouble();

    // Credit buyer wallet
    await _creditWallet(userId, amount, requestId);

    // Mark approved
    await _supabase.from('topup_requests').update({
      'status': 'approved',
      'admin_note': adminNote,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  // ── Admin: Reject ─────────────────────────────────────────────────────────

  Future<void> rejectRequest(String requestId, {required String adminNote}) async {
    await _supabase.from('topup_requests').update({
      'status': 'rejected',
      'admin_note': adminNote,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  // ── Internal: Credit wallet ───────────────────────────────────────────────

  Future<void> _creditWallet(
      String userId, double amount, String requestId) async {
    // Ensure wallet row exists
    await _supabase.from('wallets').upsert(
      {'user_id': userId, 'balance': 0.00},
      onConflict: 'user_id',
      ignoreDuplicates: true,
    );

    // Fetch current balance
    final row = await _supabase
        .from('wallets')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();
    final current = row != null ? (row['balance'] ?? 0.0).toDouble() : 0.0;

    // Update balance
    await _supabase.from('wallets').upsert({
      'user_id': userId,
      'balance': current + amount,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');

    // Log transaction
    await _supabase.from('wallet_transactions').insert({
      'id': const Uuid().v4(),
      'user_id': userId,
      'type': 'topup',
      'amount': amount,
      'description': 'Top-up approved — Rs. ${amount.toStringAsFixed(0)}',
      'order_id': requestId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Admin: All users overview ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchUsersWithBalances() async {
    final users = await _supabase
        .from('users')
        .select('id, name, email, role')
        .inFilter('role', ['buyer', 'seller'])
        .order('role');

    final results = <Map<String, dynamic>>[];
    for (final user in users) {
      final walletRow = await _supabase
          .from('wallets')
          .select('balance')
          .eq('user_id', user['id'])
          .maybeSingle();
      results.add({
        ...user,
        'balance': walletRow != null
            ? (walletRow['balance'] ?? 0.0).toDouble()
            : 0.0,
      });
    }
    return results;
  }
}

final topUpRequestRepositoryProvider =
    Provider<TopUpRequestRepository>((ref) => TopUpRequestRepository());
