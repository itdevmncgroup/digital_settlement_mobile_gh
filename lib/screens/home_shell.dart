import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    // Settlement (bank statement matching) is Finance/Admin back-office work,
    // same restriction as the /bank-settlements API and web-admin's own nav.
    final canSeeStatements = user?.hasAnyRole(['ADMIN', 'FINANCE']) ?? false;

    final tabs = <_Tab>[
      _Tab(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Expenses', screen: const ExpensesListScreen()),
      if (canSeeStatements)
        _Tab(icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check, label: 'Settlement', screen: const StatementsScreen()),
      _Tab(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile', screen: const ProfileScreen()),
    ];

    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(index: index, children: [for (final t in tabs) t.screen]),
      bottomNavigationBar: NavigationBar(
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
