import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bank_statement.dart';
import '../../services/api_client.dart';
import '../../utils/format.dart';
import '../../widgets/error_view.dart';
import '../../widgets/status_badge.dart';
import '../expenses/expense_detail_screen.dart';

class StatementDetailScreen extends StatefulWidget {
  final String batchId;
  const StatementDetailScreen({super.key, required this.batchId});

  @override
  State<StatementDetailScreen> createState() => _StatementDetailScreenState();
}

class _StatementDetailScreenState extends State<StatementDetailScreen> {
  late Future<StatementBatchDetail> _future;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StatementBatchDetail> _load() async {
    final api = context.read<ApiClient>();
    final data = await api.get('/bank-settlements/${widget.batchId}') as Map<String, dynamic>;
    return StatementBatchDetail.fromJson(data);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _reject(StatementTransaction txn) async {
    setState(() => _busyIds.add(txn.id));
    final api = context.read<ApiClient>();
    try {
      await api.post('/bank-settlements/transactions/${txn.id}/unmatch');
      _refresh();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyIds.remove(txn.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statement')),
      body: FutureBuilder<StatementBatchDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(message: '${snapshot.error}', onRetry: _refresh);
          }
          final batch = snapshot.data!;
          // Only already-matched transactions (AUTO_MATCHED/MANUAL_MATCHED) show here -
          // unmatched/review-required lines are back-office's job in web-admin.
          final matched = batch.transactions.where((t) => t.isMatched).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(batch.fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${formatDate(batch.createdAt)} · ${matched.length} matched of ${batch.transactionCount} · uploaded by ${batch.uploadedByName}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (matched.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('No matched transactions in this statement yet', style: TextStyle(color: Colors.grey))),
                ),
              for (final txn in matched)
                _TransactionCard(
                  txn: txn,
                  busy: _busyIds.contains(txn.id),
                  onReject: () => _reject(txn),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final StatementTransaction txn;
  final bool busy;
  final VoidCallback onReject;

  const _TransactionCard({
    required this.txn,
    required this.busy,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: txn.matchedExpense == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expenseId: txn.matchedExpense!.id))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(txn.isCreditCard ? Icons.credit_card : Icons.account_balance_wallet_outlined, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(txn.rawDescription, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(txn.transactionDate != null ? formatDate(txn.transactionDate!) : '-', style: Theme.of(context).textTheme.bodySmall),
                  Text(formatCurrency(txn.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  StatusBadge(status: txn.status),
                  if (txn.matchedExpense != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${txn.matchedExpense!.expenseNo} · ${txn.matchedExpense!.salesName}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: busy
                      ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.close, size: 16),
                  label: const Text('Reject (Unmatch)'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
