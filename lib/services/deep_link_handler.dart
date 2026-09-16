import 'package:flutter/material.dart';
import '../screens/approvals/approvals_list_screen.dart';
import '../screens/expenses/expense_detail_screen.dart';
import '../screens/settlements/settlement_approval_detail_screen.dart';

/// Resolves a deep-link target - either the `deepLink` string on a push
/// payload/Notification row (`/expenses/<id>`, `/events/<id>`,
/// `/settlement?open=<id>`, matching src/approvals/approvals.service.ts's
/// notifyStep - and settlement/page.tsx's own `?open=` handling on the web
/// side) or the path+query of an incoming `digitalsettlement://...` /
/// `https://<app-domain>/...` link - and pushes the matching screen.
///
/// No named-route table exists in this app (see main.dart) - navigation is
/// plain `Navigator.push`, so this needs the global navigatorKey to reach a
/// NavigatorState without a BuildContext (push-notification taps and cold-start
/// deep links both fire before any screen's `context` is guaranteed usable).
void handleDeepLink(GlobalKey<NavigatorState> navigatorKey, String pathAndQuery) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;

  final uri = Uri.parse(pathAndQuery.startsWith('/') ? 'app:/$pathAndQuery' : pathAndQuery);
  final segments = uri.pathSegments;

  if (segments.length >= 2 && segments[0] == 'expenses') {
    nav.push(MaterialPageRoute(builder: (_) => ExpenseDetailScreen(expenseId: segments[1])));
    return;
  }
  if (segments.isNotEmpty && segments[0] == 'settlement') {
    final id = uri.queryParameters['open'] ?? (segments.length >= 2 ? segments[1] : null);
    if (id != null) {
      nav.push(MaterialPageRoute(builder: (_) => SettlementApprovalDetailScreen(settlementId: id)));
      return;
    }
  }

  // Events (Pre-Event) have no mobile detail screen yet, so a recognized-but-
  // unhandled path falls back here - the approvals inbox is a safe, relevant
  // landing spot for an approval-activity notification. An empty path is not
  // a link at all (e.g. app_links' web getInitialLink() returning the page's
  // own bare load URL) and must not trigger any navigation.
  if (segments.isEmpty) return;
  nav.push(MaterialPageRoute(builder: (_) => const ApprovalsListScreen()));
}
