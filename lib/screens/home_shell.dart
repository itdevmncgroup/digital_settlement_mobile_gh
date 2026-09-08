import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'approvals/approvals_list_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'expenses/expenses_list_screen.dart';
import 'statements/statements_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  // Who is entitled to approve (resolved approver / ADMIN / expense.approve.*
  // permission) is dynamic and not reflected in AppUser.roles, so it can't be
  // decided client-side from the role list - ask the backend instead and only
  // show the tab once it says there's actually something for this user to act on.
  bool _canApprove = false;

  @override
  void initState() {
    super.initState();
    _checkApprovalAccess();
  }

  Future<void> _checkApprovalAccess() async {
    try {
      final api = context.read<ApiClient>();
      final pending = await api.get('/approvals/pending') as List;
      if (mounted) setState(() => _canApprove = pending.isNotEmpty);
    } catch (_) {
      // Leave the tab hidden on failure - ApprovalsListScreen surfaces the
      // real error if the user reaches it some other way.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    // Settlement (bank statement matching) is Finance/Admin back-office work,
    // same restriction as the /bank-settlements API and web-admin's own nav.
    final canSeeStatements = user?.hasAnyRole(['ADMIN', 'FINANCE']) ?? false;
    // Expenses (create/browse own or team submissions) is a Sales-side page -
    // an approver-only role (SUPERVISOR/FINANCE/MANAGEMENT) has no reason to
    // see it, since their entire job on it is covered by the Approvals tab.
    final canSeeExpenses = user?.hasAnyRole(['SALES', 'SALES_ADMIN', 'ADMIN']) ?? false;
    // BOD sits at (almost always) the end of the chain and can monitor the
    // whole pipeline read-only ahead of their own turn (see ApprovalsListScreen/
    // isMyTurn), so their tab must always show, not just when they currently
    // have something actionable.
    final isBod = user?.positionCode == 'BOD';
    final showApprovals = isBod || _canApprove;

    final tabs = <_Tab>[
      _Tab(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard', screen: const DashboardScreen()),
      if (canSeeExpenses)
        _Tab(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Expenses', screen: const ExpensesListScreen()),
      if (showApprovals)
        _Tab(icon: Icons.checklist_outlined, selectedIcon: Icons.checklist, label: 'Approvals', screen: const ApprovalsListScreen()),
      if (canSeeStatements)
        _Tab(icon: Icons.summarize_outlined, selectedIcon: Icons.summarize, label: 'Settlement', screen: const StatementsScreen()),
      _Tab(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile', screen: const ProfileScreen()),
    ];

    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(index: index, children: [for (final t in tabs) t.screen]),
      // NavigationBar asserts destinations.length >= 2 - a role with nothing
      // to see but Profile (e.g. a plain SUPERVISOR/MANAGEMENT with no
      // pending approvals right now) would otherwise crash on that assert.
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final t in tabs) NavigationDestination(icon: Icon(t.icon), selectedIcon: Icon(t.selectedIcon), label: t.label),
              ],
            ),
    );
  }
}

class _Tab {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget screen;
  _Tab({required this.icon, required this.selectedIcon, required this.label, required this.screen});
}
