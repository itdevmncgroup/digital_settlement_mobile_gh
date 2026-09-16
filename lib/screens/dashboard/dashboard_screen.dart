import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/dashboard_data.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../services/notifications_service.dart';
import '../../widgets/error_view.dart';
import '../approvals/approvals_list_screen.dart';
import '../notifications/notifications_list_screen.dart';

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
      backgroundColor: const Color(0xFFF4F5FA),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: ErrorView(message: '${snapshot.error}', onRetry: _refresh),
                  ),
                ],
              );
            }
            final d = snapshot.data!;

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _Header(userName: user?.name ?? ''),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.pending_actions_outlined,
                              iconColor: const Color(0xFFE5484D),
                              label: 'Total Expense Incomplete',
                              caption: 'Dalam proses draf/revisi',
                              value: formatCurrency(d.totalExpenseIncompleteAmount),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.check_circle_outline,
                              iconColor: const Color(0xFF1FA971),
                              label: 'Total Expense Complete',
                              caption: 'Telah disetujui & bayar',
                              value: formatCurrency(d.totalExpenseCompleteAmount),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              icon: Icons.hourglass_top_outlined,
                              iconColor: const Color(0xFFF2A93B),
                              label: 'Total Expense Pending',
                              caption: 'Butuh review finance',
                              value: '${d.totalExpensePendingCount}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatTile(
                              icon: Icons.checklist_outlined,
                              iconColor: brandSeed,
                              label: 'Total Approval Pending',
                              caption: 'Menunggu persetujuan Anda',
                              value: '${d.pendingApprovalCount}',
                              onTap: d.pendingApprovalCount > 0
                                  ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ApprovalsListScreen()))
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      if (d.expenseByDepartment.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _DepartmentBarChart(
                                title: 'Expense Incomplete per Departemen',
                                icon: Icons.groups_outlined,
                                barColor: const Color(0xFFE5484D),
                                data: d.expenseByDepartment,
                                valueOf: (row) => row.incompleteCount,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DepartmentBarChart(
                                title: 'Expense Complete per Departemen',
                                icon: Icons.groups_2_outlined,
                                barColor: const Color(0xFF1FA971),
                                data: d.expenseByDepartment,
                                valueOf: (row) => row.completeCount,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Aktivitas Terkini', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          if (d.recentActivity.isNotEmpty)
                            Text('Lihat Semua', style: TextStyle(color: brandSeed, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (d.recentActivity.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('Belum ada aktivitas', style: TextStyle(color: Colors.grey.shade600)),
                          ),
                        )
                      else
                        ...d.recentActivity.map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ActivityTile(activity: a),
                            )),
                      if (d.positionCode == 'BOD') ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _StatTile(
                                icon: Icons.receipt_long_outlined,
                                iconColor: brandSeed,
                                label: 'Expenses approved',
                                caption: 'Seluruh Departemen',
                                value: '${d.approvedExpenseCount ?? 0}',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatTile(
                                icon: Icons.task_alt_outlined,
                                iconColor: brandSeed,
                                label: 'Settlements approved',
                                caption: 'Seluruh Departemen',
                                value: '${d.approvedSettlementCount ?? 0}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationsService>().unreadCount;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsListScreen())),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Badge(
          isLabelVisible: unreadCount > 0,
          label: Text('$unreadCount'),
          backgroundColor: Colors.redAccent,
          child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  const _Header({required this.userName});

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [brandGradientStart, brandGradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Dashboard Keuangan', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              _NotificationBell(),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Halo, $userName!', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(today, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String caption;
  final String value;
  final VoidCallback? onTap;
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.caption,
    required this.value,
    this.onTap,
  });

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
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: iconColor, width: 4))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(caption, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepartmentBarChart extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color barColor;
  final List<DashboardDepartmentBreakdown> data;
  final int Function(DashboardDepartmentBreakdown) valueOf;
  const _DepartmentBarChart({
    required this.title,
    required this.icon,
    required this.barColor,
    required this.data,
    required this.valueOf,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data.map(valueOf).fold<int>(0, (a, b) => a > b ? a : b);
    // 110 + reserve 34 overflowed ~6px - value-text + gaps + label-text line
    // heights run past 34px in practice, so give both a little more room.
    const chartHeight = 116.0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Icon(icon, size: 16, color: Colors.grey.shade500),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: chartHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: data.map((row) {
                    final value = valueOf(row);
                    final barHeight = maxValue == 0 ? 0.0 : (value / maxValue) * (chartHeight - 40);
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Container(
                            width: 22,
                            height: barHeight < 2 ? 2 : barHeight,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 42,
                            child: Text(
                              row.departmentName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final DashboardActivity activity;
  const _ActivityTile({required this.activity});

  (IconData, Color) get _iconAndColor {
    switch (activity.title) {
      case 'Revisi Expense':
        return (Icons.refresh_rounded, const Color(0xFFE5484D));
      case 'Expense Ditolak':
        return (Icons.close_rounded, const Color(0xFFE5484D));
      case 'Persetujuan Final':
      case 'Persetujuan':
        return (Icons.check_rounded, const Color(0xFF1FA971));
      case 'Review Expense':
        return (Icons.hourglass_top_rounded, const Color(0xFFF2A93B));
      default:
        return (Icons.description_outlined, brandSeed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconAndColor;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${activity.title} - ${activity.purpose}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(formatCurrency(activity.amount), style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
                      if (activity.departmentName != null) ...[
                        const SizedBox(width: 8),
                        Text(activity.departmentName!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(formatRelativeTime(activity.timestamp), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
