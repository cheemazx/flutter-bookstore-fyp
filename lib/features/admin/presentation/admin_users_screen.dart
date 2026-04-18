import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/admin_repository.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  List<Map<String, dynamic>>? _users;
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users =
          await ref.read(adminRepositoryProvider).getUsersWithBalances();
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  void _applyFilter() {
    if (_users == null) return;
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = _users!.where((u) {
        final matchRole =
            _roleFilter == 'all' || u['role'] == _roleFilter;
        final matchSearch = q.isEmpty ||
            (u['name'] as String? ?? '').toLowerCase().contains(q) ||
            (u['email'] as String? ?? '').toLowerCase().contains(q);
        return matchRole && matchSearch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('All Users'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search + Filter ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or email…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                    label: 'All',
                    selected: _roleFilter == 'all',
                    onTap: () {
                      setState(() => _roleFilter = 'all');
                      _applyFilter();
                    }),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Buyers',
                    selected: _roleFilter == 'buyer',
                    onTap: () {
                      setState(() => _roleFilter = 'buyer');
                      _applyFilter();
                    }),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Sellers',
                    selected: _roleFilter == 'seller',
                    onTap: () {
                      setState(() => _roleFilter = 'seller');
                      _applyFilter();
                    }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── User Count ─────────────────────────────────────────
          if (!_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_filtered.length} user${_filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ),
            ),
          const SizedBox(height: 8),

          // ── List ───────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_outlined,
                                size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No users found',
                                style:
                                    TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _UserTile(user: _filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4F46E5)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFF4F46E5)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ── User Tile ──────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String? ?? 'buyer';
    final balance = (user['balance'] ?? 0.0) as double;
    final isBuyer = role == 'buyer';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isBuyer
                  ? const Color(0xFF4F46E5).withOpacity(0.1)
                  : const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isBuyer
                  ? Icons.person_outline_rounded
                  : Icons.storefront_outlined,
              color: isBuyer
                  ? const Color(0xFF4F46E5)
                  : const Color(0xFF10B981),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] as String? ?? 'No name',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1F2937)),
                ),
                const SizedBox(height: 2),
                Text(
                  user['email'] as String? ?? '',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isBuyer
                        ? const Color(0xFF4F46E5).withOpacity(0.08)
                        : const Color(0xFF10B981).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    role[0].toUpperCase() + role.substring(1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isBuyer
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${balance.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: balance > 0
                      ? const Color(0xFF1F2937)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 2),
              const Text('balance',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }
}
