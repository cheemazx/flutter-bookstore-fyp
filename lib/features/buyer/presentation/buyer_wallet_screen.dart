import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/models/wallet_model.dart';
import '../../../core/models/topup_request_model.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../data/topup_request_repository.dart';

class BuyerWalletScreen extends ConsumerStatefulWidget {
  const BuyerWalletScreen({super.key});

  @override
  ConsumerState<BuyerWalletScreen> createState() => _BuyerWalletScreenState();
}

class _BuyerWalletScreenState extends ConsumerState<BuyerWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showTopUpSheet() {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpRequestSheet(userId: user.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.read(authRepositoryProvider).currentUser;
    final walletAsync = ref.watch(walletProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF4F46E5),
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Top-Up Requests'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Balance Card ───────────────────────────────────────
          walletAsync.when(
            data: (w) => _BalanceCard(
              balance: w?.balance ?? 0.0,
              onTopUp: _showTopUpSheet,
            ),
            loading: () => const _BalanceCard(balance: 0.0, loading: true),
            error: (e, _) => const _BalanceCard(balance: 0.0),
          ),

          // ── Tabs ───────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Transaction History
                _TransactionHistoryTab(),
                // Tab 2: Top-Up Requests
                user == null
                    ? const Center(child: Text('Not logged in'))
                    : _TopUpRequestsTab(userId: user.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Balance Card ───────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final double balance;
  final bool loading;
  final VoidCallback? onTopUp;

  const _BalanceCard({required this.balance, this.loading = false, this.onTopUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text('Available Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          loading
              ? const SizedBox(
                  height: 48,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  'Rs. ${balance.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTopUp,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Request Top-Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction History Tab ────────────────────────────────────────────────────

class _TransactionHistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(walletTransactionsProvider);
    return transactionsAsync.when(
      data: (txns) {
        if (txns.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No transactions yet',
                    style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }
        return ListView.separated(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          itemCount: txns.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _TransactionTile(transaction: txns[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ── Top-Up Requests Tab ────────────────────────────────────────────────────────

class _TopUpRequestsTab extends ConsumerWidget {
  final String userId;
  const _TopUpRequestsTab({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync =
        ref.watch(_myTopUpRequestsProvider(userId));
    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.upload_file_outlined,
                    size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('No top-up requests yet',
                    style: TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                const Text(
                  'Submit a request to add funds to your wallet',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _RequestTile(request: requests[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

final _myTopUpRequestsProvider =
    StreamProvider.family<List<TopUpRequest>, String>((ref, userId) {
  return ref.read(topUpRequestRepositoryProvider).watchMyRequests(userId);
});

// ── Request Tile ───────────────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final TopUpRequest request;
  const _RequestTile({required this.request});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    Color bgColor;

    switch (request.status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle_rounded;
        bgColor = const Color(0xFF10B981).withOpacity(0.08);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.cancel_rounded;
        bgColor = const Color(0xFFEF4444).withOpacity(0.08);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.pending_rounded;
        bgColor = const Color(0xFFF59E0B).withOpacity(0.08);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screenshot thumbnail
          GestureDetector(
            onTap: () => _viewScreenshot(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                request.screenshotUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(Icons.image_not_supported_outlined,
                      color: Color(0xFF9CA3AF)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Rs. ${request.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF1F2937)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            request.statusLabel,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy • h:mm a')
                      .format(request.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF)),
                ),
                if (request.adminNote != null &&
                    request.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined,
                            size: 14, color: Color(0xFF6B7280)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request.adminNote!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
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

  void _viewScreenshot(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(request.screenshotUrl),
        ),
      ),
    );
  }
}

// ── Transaction Tile ───────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final WalletTransaction transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final color =
        isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final bgColor = isCredit
        ? const Color(0xFF10B981).withOpacity(0.08)
        : const Color(0xFFEF4444).withOpacity(0.08);
    final icon = switch (transaction.type) {
      'topup' => Icons.add_circle_outline_rounded,
      'purchase' => Icons.shopping_bag_outlined,
      'release' => Icons.check_circle_outline_rounded,
      'refund' => Icons.undo_rounded,
      _ => Icons.swap_horiz_rounded,
    };

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
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.typeLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1F2937))),
                if (transaction.description != null) ...[
                  const SizedBox(height: 2),
                  Text(transaction.description!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
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
            '${isCredit ? '+' : '-'}Rs. ${transaction.amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Top-Up Request Bottom Sheet ────────────────────────────────────────────────

class _TopUpRequestSheet extends ConsumerStatefulWidget {
  final String userId;
  const _TopUpRequestSheet({required this.userId});

  @override
  ConsumerState<_TopUpRequestSheet> createState() =>
      _TopUpRequestSheetState();
}

class _TopUpRequestSheetState extends ConsumerState<_TopUpRequestSheet> {
  final _amountController = TextEditingController();
  double? _selectedPreset;
  File? _screenshot;
  String? _uploadedUrl;
  bool _isUploading = false;
  bool _isSubmitting = false;

  final List<double> _presets = [500, 1000, 2000, 5000];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _screenshot = File(picked.path);
      _isUploading = true;
      _uploadedUrl = null;
    });

    try {
      final url = await ref
          .read(topUpRequestRepositoryProvider)
          .uploadScreenshot(widget.userId, File(picked.path));
      if (mounted) {
        setState(() {
          _uploadedUrl = url;
          _isUploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    double? amount;
    if (_selectedPreset != null) {
      amount = _selectedPreset;
    } else {
      amount = double.tryParse(_amountController.text.trim());
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_uploadedUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload your payment screenshot')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(topUpRequestRepositoryProvider).submitRequest(
            userId: widget.userId,
            amount: amount!,
            screenshotUrl: _uploadedUrl!,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Top-up request submitted! Admin will review shortly.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Request Top-Up',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937))),
                      SizedBox(height: 2),
                      Text('Transfer money & upload screenshot',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Bank info hint
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF4F46E5).withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: Color(0xFF4F46E5), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Transfer to our JazzCash/EasyPaisa: 0300-1234567\nThen upload your payment screenshot below.',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF4338CA)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount presets
            const Text('Select Amount',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presets.map((amt) {
                final selected = _selectedPreset == amt;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedPreset = selected ? null : amt;
                    if (!selected) _amountController.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: selected
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      'Rs. ${amt.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF1F2937)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom amount
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              onChanged: (_) =>
                  setState(() => _selectedPreset = null),
              decoration: const InputDecoration(
                hintText: 'Or enter custom amount',
                prefixText: 'Rs. ',
                prefixStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                    fontSize: 15),
              ),
            ),
            const SizedBox(height: 20),

            // Screenshot upload
            const Text('Payment Screenshot',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1F2937))),
            const SizedBox(height: 10),

            GestureDetector(
              onTap: _isUploading ? null : _pickScreenshot,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _uploadedUrl != null
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE5E7EB),
                    width: _uploadedUrl != null ? 1.5 : 1,
                  ),
                ),
                child: _isUploading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                                color: Color(0xFF4F46E5)),
                            SizedBox(height: 8),
                            Text('Uploading…',
                                style: TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 13)),
                          ],
                        ),
                      )
                    : _screenshot != null && _uploadedUrl != null
                        ? Stack(fit: StackFit.expand, children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(_screenshot!,
                                  fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Tap to change',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 11)),
                              ),
                            ),
                          ])
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file_rounded,
                                  size: 36,
                                  color: Color(0xFF9CA3AF)),
                              SizedBox(height: 8),
                              Text('Tap to upload screenshot',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4F46E5))),
                              SizedBox(height: 4),
                              Text('JPG or PNG from gallery',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF))),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSubmitting || _isUploading) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Request',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
