import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/settlement_detail.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../utils/format.dart';
import '../../widgets/error_view.dart';
import '../../widgets/status_badge.dart';
import '../expenses/expense_detail_screen.dart';

/// Approval -> Settlement -> its Expense list. The tier's approver works through
/// the member Expenses (checklist bulk Approve/Reject, or the row's own detail
/// page), then presses the single Submit to close the tier and move the batch to
/// the next one - SLS_MAR_DIR -> VP_ACC_BIL_TAX_3TV -> CO_CFO_3TV, with the last
/// Submit marking everything COMPLETE and pushing it to the external system.
///
/// Approving marks an Expense reviewed at this tier; rejecting drops it out of
/// the batch entirely. Submit stays disabled until every remaining Expense has
/// been reviewed (the backend enforces the same rule).
class SettlementApprovalDetailScreen extends StatefulWidget {
  final String settlementId;
  const SettlementApprovalDetailScreen({super.key, required this.settlementId});

  @override
  State<SettlementApprovalDetailScreen> createState() => _SettlementApprovalDetailScreenState();
}

class _SettlementApprovalDetailScreenState extends State<SettlementApprovalDetailScreen> {
  late Future<SettlementDetail> _future;
  final Set<String> _checked = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SettlementDetail> _load() async {
    final api = context.read<ApiClient>();
    final data = await api.get('/settlements/${widget.settlementId}') as Map<String, dynamic>;
    return SettlementDetail.fromJson(data);
  }

  void _refresh() => setState(() {
        _checked.clear();
        _future = _load();
      });

  Future<String?> _askReason(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
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
  }

  Future<void> _bulkAct({required bool approve}) async {
    String? reason;
    if (!approve) {
      reason = await _askReason('Reject ${_checked.length} expense(s)');
      if (reason == null || !mounted) return;
    }
    final ids = _checked.toList();
    setState(() => _busy = true);
    final api = context.read<ApiClient>();
    var okCount = 0;
    final failures = <String>[];
    for (final id in ids) {
      try {
        final path = '/settlements/${widget.settlementId}/expenses/$id/${approve ? 'approve' : 'reject'}';
        await api.post(path, approve ? null : {'reason': reason});
        okCount++;
      } on ApiException catch (e) {
        failures.add(e.message);
      } catch (e) {
        failures.add('$e');
      }
    }
    if (mounted) {
      final verb = approve ? 'approved' : 'rejected';
      final message = failures.isEmpty
          ? '$okCount expense(s) $verb'
          : '$okCount $verb, ${failures.length} failed: ${failures.first}${failures.length > 1 ? ' (+${failures.length - 1} more)' : ''}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      setState(() => _busy = false);
    }
    _refresh();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final api = context.read<ApiClient>();
    try {
      await api.post('/settlements/${widget.settlementId}/submit');
      if (mounted) Navigator.of(context).pop(true);
      return;
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _busy = false);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Settlement')),
      body: FutureBuilder<SettlementDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(message: '${snapshot.error}', onRetry: _refresh);
          }
          final s = snapshot.data!;
          final myTurn = s.isMyTurn(user?.id);
          // Only rows not yet reviewed at this tier can be acted on - an already
          // approved one would just collect a duplicate.
          final pendingRows = s.expenses.where((e) => !e.reviewedAt(s.currentStep)).toList();
          final allChecked = pendingRows.isNotEmpty && _checked.length == pendingRows.length;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s.settlementNo, style: Theme.of(context).textTheme.titleLarge)),
                        StatusBadge(status: s.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _row('Department', s.departmentName ?? '-'),
                            _row('Created by', s.createdByName),
                            _row('Total amount', formatCurrency(s.totalAmount), bold: true),
                            _row('Expenses', '${s.expenses.length}'),
                          ],
                        ),
                      ),
                    ),
                    if (s.currentPositionName != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        myTurn
                            ? 'Your approval as ${s.currentPositionName}: review every expense, then Submit.'
                            : 'Waiting on ${s.currentPositionName} to review and submit.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (myTurn) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy || !s.allReviewed ? null : _submit,
                          icon: const Icon(Icons.send),
                          label: Text(s.allReviewed ? 'Submit' : 'Submit (review all expenses first)'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      children: [
                        Text('Expenses', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (myTurn && pendingRows.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() {
                              if (allChecked) {
                                _checked.clear();
                              } else {
                                _checked
                                  ..clear()
                                  ..addAll(pendingRows.map((e) => e.id));
                              }
                            }),
                            child: Text(allChecked ? 'Clear' : 'Select all'),
                          ),
                      ],
                    ),
                    for (final e in s.expenses)
                      _ExpenseCheckRow(
                        expense: e,
                        reviewed: e.reviewedAt(s.currentStep),
                        checked: _checked.contains(e.id),
                        selectable: myTurn && !e.reviewedAt(s.currentStep),
                        onCheckedChanged: (v) => setState(() {
                          if (v) {
                            _checked.add(e.id);
                          } else {
                            _checked.remove(e.id);
                          }
                        }),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expenseId: e.id)));
                          _refresh();
                        },
                      ),
                  ],
                ),
              ),
              if (myTurn)
                SafeArea(
                  minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: _checked.isNotEmpty
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE5484D)),
                                onPressed: _busy ? null : () => _bulkAct(approve: false),
                                icon: const Icon(Icons.close),
                                label: Text('Reject (${_checked.length})'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy ? null : () => _bulkAct(approve: true),
                                icon: const Icon(Icons.check),
                                label: Text('Approve (${_checked.length})'),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy || !s.allReviewed ? null : _submit,
                            icon: const Icon(Icons.send),
                            label: Text(s.allReviewed ? 'Submit' : 'Submit (review all expenses first)'),
                          ),
                        ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}

class _ExpenseCheckRow extends StatelessWidget {
  final SettlementExpenseRow expense;
  final bool reviewed;
  final bool checked;
  final bool selectable;
  final ValueChanged<bool> onCheckedChanged;
  final VoidCallback onTap;

  const _ExpenseCheckRow({
    required this.expense,
    required this.reviewed,
    required this.checked,
    required this.selectable,
    required this.onCheckedChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          if (reviewed)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.check_circle, size: 20, color: Color(0xFF2E9E5B)),
            )
          else
            Checkbox(value: checked, onChanged: selectable ? (v) => onCheckedChanged(v ?? false) : null),
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(expense.expenseNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        StatusBadge(status: expense.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${expense.advertiserName ?? '-'} / ${expense.brandName ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDate(expense.expenseDate), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                        Text(formatCurrency(expense.amount), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (reviewed) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Approved at this stage',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF2E9E5B), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
