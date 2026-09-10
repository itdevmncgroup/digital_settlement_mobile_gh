import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/dashboard_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../utils/format.dart';
import '../../widgets/error_view.dart';
import '../approvals/approvals_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardData> _load() async {
    final api = context.read<ApiClient>();
    final data = await api.get('/dashboard/me') as Map<String, dynamic>;
    return DashboardData.fromJson(data);
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ErrorView(message: '${snapshot.error}', onRetry: _refresh);
            }
            final d = snapshot.data!;
            final scopeLabel = d.departments != null && d.departments!.isNotEmpty
                ? d.departments!.map((p) => p.name).join(', ')
                : d.departmentName;
            final isPodRestricted = d.positionCode == 'HEAD_POD' || (user?.hasAnyRole(['SALES', 'SALES_ADMIN']) ?? false);
            final expenseScopeLabel = isPodRestricted ? (scopeLabel ?? 'Pod Anda') : 'Seluruh Pod';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Halo, ${user?.name ?? ''}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('Selamat datang kembali', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : '?',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _StatCard(
                  icon: Icons.checklist_outlined,
                  label: 'Pending approval',
                  value: '${d.pendingApprovalCount}',
                  onTap: d.pendingApprovalCount > 0
                      ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApprovalsListScreen()))
                      : null,
                ),
                const SizedBox(height: 12),
                _StatCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Jumlah expense (settlement complete) — $expenseScopeLabel',
                  value: formatCurrency(d.totalExpenseAmount ?? '0'),
                ),
                if (scopeLabel != null) ...[
                  const SizedBox(height: 12),
                  _StatCard(
                    icon: Icons.summarize_outlined,
                    label: 'Total expense (SETTLED) — $scopeLabel',
                    value: formatCurrency(d.totalSettledAmount ?? '0'),
                  ),
                ],
                if (d.positionCode == 'BOD') ...[
                  const SizedBox(height: 12),
                  _StatCard(
                    icon: Icons.public_outlined,
                    label: 'Total expense (SETTLED) — All Departments',
                    value: formatCurrency(d.totalSettledAmount ?? '0'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(icon: Icons.receipt_long_outlined, label: 'Expenses approved', value: '${d.approvedExpenseCount ?? 0}'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(icon: Icons.task_alt_outlined, label: 'Settlements approved', value: '${d.approvedSettlementCount ?? 0}'),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _StatCard({required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                    const SizedBox(height: 2),
                    Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
