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
  bool _selectMode = false;
  final Set<String> _selectedExpenseIds = {};
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Only an expense row that's actually this user's turn can be bulk
  // approved/rejected - settlement rows go through submitSettlementTier
  // (member-by-member review) instead of the single approve/reject endpoint.
  bool _selectable(ApprovalPendingItem item) => item.type == ApprovalItemType.expense && item.isMyTurn;

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedExpenseIds.clear();
    });
  }

  void _toggleSelected(ApprovalPendingItem item) {
    if (!_selectable(item)) return;
    setState(() {
      if (_selectedExpenseIds.contains(item.expenseId)) {
        _selectedExpenseIds.remove(item.expenseId);
      } else {
        _selectedExpenseIds.add(item.expenseId!);
      }
    });
  }

  void _toggleSelectAll(List<ApprovalPendingItem> rows) {
    final selectableIds = rows.where(_selectable).map((e) => e.expenseId!).toSet();
    setState(() {
      if (_selectedExpenseIds.length == selectableIds.length) {
        _selectedExpenseIds.clear();
      } else {
        _selectedExpenseIds
          ..clear()
          ..addAll(selectableIds);
      }
    });
  }

  Future<void> _bulkApprove() async {
    await _runBulk((api, id) => api.post('/approvals/expense/$id/approve'));
  }

  Future<void> _bulkReject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reject ${_selectedExpenseIds.length} expense(s)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason', hintText: 'Why is this being rejected?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length < 3) return;
              Navigator.of(dialogContext).pop(text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) return;
    await _runBulk((api, id) => api.post('/approvals/expense/$id/reject', {'reason': reason}));
  }

  // Backend has no batch approve/reject endpoint (see approvals.controller.ts)
  // so each selected expense fires its own call. Runs one at a time so one
  // failure doesn't fire a burst of retries; failures are collected and
  // reported together instead of aborting the whole batch.
  Future<void> _runBulk(Future<void> Function(ApiClient api, String id) call) async {
    final api = context.read<ApiClient>();
    final ids = _selectedExpenseIds.toList();
    setState(() => _bulkBusy = true);
    var success = 0;
    final failures = <String>[];
    for (final id in ids) {
      try {
        await call(api, id);
        success++;
      } on ApiException catch (e) {
        failures.add(e.message);
      }
    }
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selectMode = false;
      _selectedExpenseIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures.isEmpty
              ? '$success expense(s) processed'
              : '$success succeeded, ${failures.length} failed: ${failures.first}',
        ),
      ),
    );
    _refresh();
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
    if (_selectMode) {
      _toggleSelected(item);
      return;
    }
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
      appBar: AppBar(
        title: Text(_selectMode ? '${_selectedExpenseIds.length} selected' : 'Approvals'),
        leading: _selectMode ? IconButton(icon: const Icon(Icons.close), onPressed: _bulkBusy ? null : _toggleSelectMode) : null,
        actions: [
          if (!_selectMode)
            IconButton(icon: const Icon(Icons.checklist), tooltip: 'Select', onPressed: _toggleSelectMode),
        ],
      ),
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
            final selectableCount = rows.where(_selectable).length;
            return Column(
              children: [
                if (_selectMode && selectableCount > 0)
                  CheckboxListTile(
                    value: _selectedExpenseIds.length == selectableCount,
                    onChanged: _bulkBusy ? null : (_) => _toggleSelectAll(rows),
                    title: Text('Select all ($selectableCount)'),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ApprovalCard(
                      item: rows[i],
                      onTap: () => _open(rows[i]),
                      selectMode: _selectMode,
                      selectable: _selectable(rows[i]),
                      selected: _selectedExpenseIds.contains(rows[i].expenseId),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _selectMode && _selectedExpenseIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _bulkBusy ? null : _bulkReject,
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _bulkBusy ? null : _bulkApprove,
                        icon: _bulkBusy
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final ApprovalPendingItem item;
  final VoidCallback onTap;
  final bool selectMode;
  final bool selectable;
  final bool selected;
  const _ApprovalCard({
    required this.item,
    required this.onTap,
    this.selectMode = false,
    this.selectable = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selectMode && !selectable ? null : onTap,
        child: Opacity(
          opacity: !item.isMyTurn || (selectMode && !selectable) ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectMode) ...[
                  Checkbox(value: selected, onChanged: selectable ? (_) => onTap() : null),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: item.type == ApprovalItemType.settlement ? _buildSettlement(context) : _buildExpense(context),
                ),
              ],
            ),
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
