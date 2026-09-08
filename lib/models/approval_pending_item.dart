/// One row of GET /approvals/pending - an ApprovalRequest either waiting on
/// the signed-in user's own turn (or covered by their expense.approve.*
/// permission), or - for a BOD position holder only - still stuck on an
/// earlier approver, shown read-only so BOD can monitor the pipeline ahead of
/// their own turn (`isMyTurn: false`; see backend ApprovalsService.findPendingFor).
/// Event/Pre-Event approvals are a retired flow, so rows without an `expense`
/// are skipped.
class ApprovalPendingItem {
  final String approvalRequestId;
  final String expenseId;
  final String expenseNo;
  final String expenseDate;
  final String purpose;
  final String amount;
  final String status;
  final String salesName;
  final String advertiserName;
  final String brandName;
  final String? podName;
  final bool isMyTurn;

  ApprovalPendingItem({
    required this.approvalRequestId,
    required this.expenseId,
    required this.expenseNo,
    required this.expenseDate,
    required this.purpose,
    required this.amount,
    required this.status,
    required this.salesName,
    required this.advertiserName,
    required this.brandName,
    required this.podName,
    required this.isMyTurn,
  });

  /// Returns null for a row with no `expense` (event/pre-event approval).
  static ApprovalPendingItem? fromJson(Map<String, dynamic> json) {
    final expense = json['expense'] as Map<String, dynamic>?;
    if (expense == null) return null;
    final sales = expense['sales'] as Map<String, dynamic>? ?? {};
    final advertiser = expense['advertiser'] as Map<String, dynamic>? ?? {};
    final brand = expense['brand'] as Map<String, dynamic>? ?? {};
    final pod = expense['pod'] as Map<String, dynamic>?;
    return ApprovalPendingItem(
      approvalRequestId: json['id'] as String,
      expenseId: expense['id'] as String,
      expenseNo: expense['expenseNo'] as String? ?? '',
      expenseDate: expense['expenseDate'] as String? ?? '',
      purpose: expense['purpose'] as String? ?? '',
      amount: '${expense['amount'] ?? '0'}',
      status: expense['status'] as String? ?? '',
      salesName: sales['name'] as String? ?? '',
      advertiserName: advertiser['name'] as String? ?? '',
      brandName: brand['name'] as String? ?? '',
      podName: pod?['name'] as String?,
      isMyTurn: json['isMyTurn'] as bool? ?? true,
    );
  }
}
