import 'package:flutter/material.dart';

Color expenseStatusColor(String status) {
  switch (status) {
    case 'APPROVED':
    case 'SETTLED':
    case 'COMPLETE':
    case 'AUTO_MATCHED':
    case 'MANUAL_MATCHED':
      return const Color(0xFF2E9E5B);
    case 'REJECTED':
      return const Color(0xFFE5484D);
    case 'PENDING_APPROVAL':
    case 'REVIEW_REQUIRED':
      return const Color(0xFFF5A524);
    case 'REVISION':
      return const Color(0xFF8B5CF6);
    default:
      if (status.startsWith('APPROVAL_')) return const Color(0xFFF5A524);
      return const Color(0xFF64748B);
  }
}

/// Small rounded pill used for Expense/Settlement/Transaction status
/// everywhere in the app - keeps the color mapping in one place.
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = expenseStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.2),
      ),
    );
  }
}
