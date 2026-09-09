import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/expense_row.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../utils/format.dart';
import '../../widgets/error_view.dart';
import '../../widgets/status_badge.dart';
import 'expense_detail_screen.dart';
import 'new_expense_screen.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  late Future<List<ExpenseRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // No salesId is ever sent - the backend already scopes this correctly:
  // ADMIN/FINANCE/SUPERVISOR/MANAGEMENT get every Sales's expenses, a plain
  // SALES caller only ever gets their own (see ExpensesController.findAll /
  // canViewAllRecords). The heading below just reflects that back visually.
  Future<List<ExpenseRow>> _load() async {
    final api = context.read<ApiClient>();
    final data = await api.get('/expenses?status=ALL') as List;
    return data.map((e) => ExpenseRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Returns the new Future so RefreshIndicator's spinner stays visible until
  // the reload actually completes, instead of dismissing immediately.
  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Surfaced by FutureBuilder's error branch - nothing more to do here.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    // expense.create.all/owndept (Role/Permission master) lets a caller outside
    // SALES/ADMIN/FINANCE - e.g. HEAD_POD/Management - submit an Expense too
    // (scoped server-side to their own Department for .owndept, see
    // ExpensesService.assertCanCreateForDepartment).
    final canCreate = (user?.hasAnyRole(['SALES', 'ADMIN', 'FINANCE']) ?? false) ||
        (user?.hasAnyPermission(['expense.create.all', 'expense.create.owndept']) ?? false);
    final seesAll = user?.hasAnyRole(['ADMIN', 'FINANCE', 'SUPERVISOR', 'MANAGEMENT']) ?? false;
    // HEAD_POD is neither "all Sales" nor "my own" - the backend scopes their
    // GET /expenses to just their Department, so the heading should say so.
    final isHeadPod = user?.positionCode == 'HEAD_POD';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(seesAll ? Icons.groups : (isHeadPod ? Icons.groups_outlined : Icons.person), size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Text(
                    seesAll ? 'All Sales' : (isHeadPod ? 'Department Expenses' : 'My Expenses'),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ExpenseRow>>(
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
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(child: Text('No expenses yet', style: TextStyle(color: Colors.grey))),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ExpenseCard(
                row: rows[i],
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expenseId: rows[i].id)));
                  _refresh();
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const NewExpenseScreen()),
                );
                if (created == true) _refresh();
              },
              icon: const Icon(Icons.add),
              label: const Text('New Expense'),
            )
          : null,
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseRow row;
  final VoidCallback onTap;
  const _ExpenseCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(row.expenseNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  StatusBadge(status: row.status),
                ],
              ),
              const SizedBox(height: 6),
              Text('${row.advertiserName} / ${row.brandName}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 2),
              Text(row.purpose, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDate(row.expenseDate), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  Text(formatCurrency(row.amount), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (row.departmentName != null) ...[
                    Icon(Icons.groups_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text(row.departmentName!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                    const SizedBox(width: 12),
                  ],
                  Icon(row.matched ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: row.matched ? Colors.green : Colors.grey.shade400),
                  const SizedBox(width: 3),
                  Text(row.matched ? 'Matched' : 'Unmatched', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
