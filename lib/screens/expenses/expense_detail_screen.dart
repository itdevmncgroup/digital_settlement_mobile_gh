import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/expense_detail.dart';
import '../../services/api_client.dart';
import '../../utils/format.dart';
import '../../widgets/authed_image.dart';
import '../../widgets/error_view.dart';
import '../../widgets/status_badge.dart';
import 'edit_expense_screen.dart';

const _paymentMethodLabels = {
  'CREDIT_CARD': 'Credit Card',
  'GOPAY': 'GoPay',
  'SHOPEEPAY': 'ShopeePay',
  'DANA': 'Dana',
  'OVO': 'OVO',
  'BANK_TRANSFER': 'Bank Transfer',
  'CASH': 'Cash',
  'OTHER': 'Others',
};

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;
  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late Future<ExpenseDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ExpenseDetail> _load() async {
    final api = context.read<ApiClient>();
    final data = await api.get('/expenses/${widget.expenseId}') as Map<String, dynamic>;
    return ExpenseDetail.fromJson(data);
  }

  void _refresh() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense')),
        body: FutureBuilder<ExpenseDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(message: '${snapshot.error}', onRetry: _refresh);
            }
            final e = snapshot.data!;
            // Only DRAFT (never submitted / never went through approval) is editable.
            final canEdit = e.status == 'DRAFT';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(child: Text(e.expenseNo, style: Theme.of(context).textTheme.titleLarge)),
                    StatusBadge(status: e.status),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(e.matched ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: e.matched ? Colors.green : Colors.grey),
                    const SizedBox(width: 4),
                    Text(e.matched ? 'Matched' : 'Unmatched', style: Theme.of(context).textTheme.bodySmall),
                    if (e.settlementNo != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.summarize_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(e.settlementNo!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _row('Sales', e.salesName),
                        _row('Advertiser / Brand', '${e.advertiserName} / ${e.brandName}'),
                        _row('Unit', e.unitName),
                        if (e.podName != null) _row('POD', e.podName!),
                        _row('Date', formatDate(e.expenseDate)),
                        _row('Amount', formatCurrency(e.amount), bold: true),
                        _row('Purpose', e.purpose),
                        if (e.merchantName != null) _row('Merchant', e.merchantName!),
                        if (e.location != null) _row('Location', e.location!),
                        if (e.paymentMethodType != null)
                          _row(
                            'Payment Method',
                            '${_paymentMethodLabels[e.paymentMethodType] ?? e.paymentMethodType}'
                                '${e.creditCardLabel != null ? ' (${e.creditCardLabel})' : ''}'
                                '${e.paymentMethodNote != null ? ' — ${e.paymentMethodNote}' : ''}',
                          ),
                      ],
                    ),
                  ),
                ),
                if (e.items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Line Items', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        for (final item in e.items)
                          ListTile(
                            dense: true,
                            title: Text(item.description),
                            trailing: Text(formatCurrency(item.amount)),
                          ),
                      ],
                    ),
                  ),
                ],
                if (e.photos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Foto Kegiatan', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in e.photos)
                        AuthedThumb(path: '/expenses/photos/${p.id}/download', fileName: p.fileName, isImage: p.mimeType.startsWith('image/')),
                    ],
                  ),
                ],
                if (e.invoices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Invoices', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final inv in e.invoices)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(inv.merchantName ?? 'Unnamed merchant', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(inv.total != null ? formatCurrency(inv.total!) : '-'),
                              ],
                            ),
                            Text('Matching: ${inv.matchingStatus}', style: Theme.of(context).textTheme.bodySmall),
                            if (inv.files.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final f in inv.files)
                                    AuthedThumb(path: '/invoices/files/${f.id}/download', fileName: f.fileName, isImage: f.mimeType.startsWith('image/')),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
                if (canEdit) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () async {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => EditExpenseScreen(expense: e)),
                      );
                      if (changed == true) _refresh();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Text(
                    'This expense can no longer be edited (only DRAFT expenses that have never been submitted for approval can be changed).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
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
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }
}
