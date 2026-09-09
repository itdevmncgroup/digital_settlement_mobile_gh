import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/approval_pending_item.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../utils/format.dart';
import '../../widgets/error_view.dart';
import '../../widgets/status_badge.dart';
import '../expenses/expense_detail_screen.dart';
import '../settlements/settlement_approval_detail_screen.dart';

class ApprovalsListScreen extends StatefulWidget {
  const ApprovalsListScreen({super.key});

  @override
  State<ApprovalsListScreen> createState() => _ApprovalsListScreenState();
}

class _ApprovalsListScreenState extends State<ApprovalsListScreen> {
  late Future<List<ApprovalPendingItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ApprovalPendingItem>> _load() async {
    final api = context.read<ApiClient>();
    final data = await api.get('/approvals/pending') as List;
    return data
        .map((e) => ApprovalPendingItem.fromJson(e as Map<String, dynamic>))
        .whereType<ApprovalPendingItem>()
        .toList();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Surfaced by FutureBuilder's error branch.
    }
  }

  Future<void> _open(ApprovalPendingItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => item.type == ApprovalItemType.settlement
            ? SettlementApprovalDetailScreen(settlementId: item.settlementId!)
            : ExpenseDetailScreen(expenseId: item.expenseId!),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    // A read-scope viewer (HEAD_POD/Management via approval.read.all/owndept,
    // same as BOD) can land here with nothing actionable for THEM specifically,
    // so "on your approval" would be misleading - it's a monitoring view, not
    // necessarily their queue.
    final user = context.watch<AuthService>().user;
    final isViewerOnly = user?.positionCode == 'BOD' || (user?.hasAnyPermission(['approval.read.all', 'approval.read.owndept']) ?? false);
    return Scaffold(
      appBar: AppBar(title: const Text('Approvals')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ApprovalPendingItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(message: '${snapshot.error}', onRetry: _refresh);
            }
            final rows = snapshot.data ?? [];
            if (rows.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  const Icon(Icons.fact_check_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      isViewerOnly ? 'No pending approvals' : 'Nothing waiting on your approval',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ApprovalCard(item: rows[i], onTap: () => _open(rows[i])),
            );
          },
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final ApprovalPendingItem item;
  final VoidCallback onTap;
  const _ApprovalCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: item.isMyTurn ? 1 : 0.6,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: item.type == ApprovalItemType.settlement ? _buildSettlement(context) : _buildExpense(context),
          ),
        ),
      ),
    );
  }

  Widget _buildTurnBadge(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!item.isMyTurn) ...[
          const Icon(Icons.visibility_outlined, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text('Waiting', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
          const SizedBox(width: 8),
        ],
        StatusBadge(status: item.status),
      ],
    );
  }

  Widget _buildExpense(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(item.expenseNo ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            _buildTurnBadge(context),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${item.advertiserName} / ${item.brandName}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(item.purpose ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDate(item.expenseDate ?? ''), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            Text(formatCurrency(item.amount), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('by ${item.salesName}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            if (item.departmentName != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.groups_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(item.departmentName!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSettlement(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.receipt_long, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(item.settlementNo ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            _buildTurnBadge(context),
          ],
        ),
        const SizedBox(height: 6),
        Text('Settlement · ${item.expenseCount ?? 0} expense(s)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('by ${item.createdByName ?? '-'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            Text(formatCurrency(item.amount), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        if (item.departmentName != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(item.departmentName!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
            ],
          ),
        ],
      ],
    );
  }
}
