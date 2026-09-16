import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_notification.dart';
import '../../services/deep_link_handler.dart';
import '../../services/notifications_service.dart';
import '../../widgets/error_view.dart';
import '../../main.dart' show rootNavigatorKey;

/// Approval-activity inbox (GET /notifications) - lists both "awaiting your
/// approval" and "your expense/settlement was rejected/completed" events
/// (see NotificationType on the backend). Tapping a row marks it read and
/// navigates the same way a push-tap or deep link does.
class NotificationsListScreen extends StatefulWidget {
  const NotificationsListScreen({super.key});

  @override
  State<NotificationsListScreen> createState() => _NotificationsListScreenState();
}

class _NotificationsListScreenState extends State<NotificationsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotificationsService>().refresh());
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'EXPENSE_PENDING':
      case 'EVENT_PENDING':
        return Icons.receipt_long_outlined;
      case 'SETTLEMENT_PENDING':
        return Icons.summarize_outlined;
      case 'EXPENSE_REJECTED':
      case 'EVENT_REJECTED':
      case 'SETTLEMENT_REJECTED':
        return Icons.cancel_outlined;
      case 'SETTLEMENT_COMPLETE':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Future<void> _open(AppNotification n) async {
    await context.read<NotificationsService>().markRead(n.id);
    if (!mounted) return;
    final path = n.deepLink ?? '/${n.objectType.toLowerCase()}s/${n.objectId}';
    Navigator.of(context).pop();
    handleDeepLink(rootNavigatorKey, path);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = context.watch<NotificationsService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: notifications.refresh,
        child: notifications.loading && notifications.items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : notifications.items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      ErrorView(message: 'No notifications yet', onRetry: _noop),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: notifications.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = notifications.items[i];
                      return ListTile(
                        leading: Icon(_iconFor(n.type), color: n.read ? Colors.grey : Theme.of(context).colorScheme.primary),
                        title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.w700)),
                        subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: Text(DateFormat('d MMM, HH:mm').format(n.createdAt.toLocal()), style: const TextStyle(fontSize: 11)),
                        onTap: () => _open(n),
                      );
                    },
                  ),
      ),
    );
  }
}

void _noop() {}
