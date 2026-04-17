import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/topup_request_model.dart';
import '../data/admin_repository.dart';

class AdminTopUpScreen extends ConsumerStatefulWidget {
  const AdminTopUpScreen({super.key});

  @override
  ConsumerState<AdminTopUpScreen> createState() => _AdminTopUpScreenState();
}

class _AdminTopUpScreenState extends ConsumerState<AdminTopUpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TopUpRequest>? _pending;
  List<TopUpRequest>? _approved;
  List<TopUpRequest>? _rejected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final repo = ref.read(adminRepositoryProvider);
    final results = await Future.wait([
      repo.getRequestsByStatus('pending'),
      repo.getRequestsByStatus('approved'),
      repo.getRequestsByStatus('rejected'),
    ]);
    if (mounted) {
      setState(() {
        _pending = results[0];
        _approved = results[1];
        _rejected = results[2];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Top-Up Requests'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4F46E5),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF4F46E5),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  if (_pending != null && _pending!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_pending!.length}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Approved'),
            const Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _RequestList(
                  requests: _pending ?? [],
                  emptyMsg: 'No pending requests',
                  emptyIcon: Icons.check_circle_outline_rounded,
                  showActions: true,
                  onAction: (id, approved, note) async {
                    final repo = ref.read(adminRepositoryProvider);
                    if (approved) {
                      await repo.approveRequest(id, note: note);
                    } else {
                      await repo.rejectRequest(id, note: note ?? 'No reason given');
                    }
                    await _loadAll();
                  },
                ),
                _RequestList(
                  requests: _approved ?? [],
                  emptyMsg: 'No approved requests',
                  emptyIcon: Icons.verified_outlined,
                ),
                _RequestList(
                  requests: _rejected ?? [],
                  emptyMsg: 'No rejected requests',
                  emptyIcon: Icons.cancel_outlined,
                ),
              ],
            ),
    );
  }
}

// ── Request List ───────────────────────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  final List<TopUpRequest> requests;
  final String emptyMsg;
  final IconData emptyIcon;
  final bool showActions;
  final Future<void> Function(String id, bool approved, String? note)?
      onAction;

  const _RequestList({
    required this.requests,
    required this.emptyMsg,
    required this.emptyIcon,
    this.showActions = false,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(emptyIcon, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(emptyMsg,
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return ListView.separated(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _AdminRequestCard(
        request: requests[i],
        showActions: showActions,
        onAction: onAction,
      ),
    );
  }
}

// ── Admin Request Card ─────────────────────────────────────────────────────────

class _AdminRequestCard extends StatefulWidget {
  final TopUpRequest request;
  final bool showActions;
  final Future<void> Function(String id, bool approved, String? note)?
      onAction;

  const _AdminRequestCard({
    required this.request,
    this.showActions = false,
    this.onAction,
  });

  @override
  State<_AdminRequestCard> createState() => _AdminRequestCardState();
}

class _AdminRequestCardState extends State<_AdminRequestCard> {
  bool _actioning = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    Color statusColor;
    switch (r.status) {
      case 'approved':
        statusColor = const Color(0xFF10B981);
        break;
      case 'rejected':
        statusColor = const Color(0xFFEF4444);
        break;
      default:
        statusColor = const Color(0xFFF59E0B);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.userName ?? 'Unknown User',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        r.userEmail ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r.statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
          ),

          // Amount + date
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Text(
                  'Rs. ${r.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937)),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy\nh:mm a').format(r.createdAt),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF)),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),

          // Screenshot
          GestureDetector(
            onTap: () => _viewScreenshot(context, r.screenshotUrl),
            child: Container(
              height: 180,
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF3F4F6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      r.screenshotUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Color(0xFF9CA3AF), size: 48),
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
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in_rounded,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Tap to expand',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (r.adminNote != null && r.adminNote!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
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
                      child: Text(r.adminNote!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280))),
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons (only for pending)
          if (widget.showActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _actioning
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _handleAction(context, false),
                            icon: const Icon(Icons.close_rounded,
                                size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(
                                  color: Color(0xFFEF4444)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _handleAction(context, true),
                            icon: const Icon(Icons.check_rounded,
                                size: 16),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, bool approve) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(approve ? '✅ Approve Request' : '❌ Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(approve
                ? 'Rs. ${widget.request.amount.toStringAsFixed(0)} will be credited to the buyer\'s wallet.'
                : 'The buyer will be notified of the rejection.'),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: approve
                    ? 'Admin note (optional)'
                    : 'Reason for rejection (required)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: approve
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
            child: Text(approve ? 'Confirm Approve' : 'Confirm Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _actioning = true);
      try {
        await widget.onAction?.call(
          widget.request.id,
          approve,
          noteController.text.trim().isEmpty
              ? null
              : noteController.text.trim(),
        );
      } finally {
        if (mounted) setState(() => _actioning = false);
      }
    }
  }

  void _viewScreenshot(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }
}
