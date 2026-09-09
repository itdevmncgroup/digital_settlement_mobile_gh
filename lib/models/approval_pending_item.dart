enum ApprovalItemType { expense, settlement }

/// One row of GET /approvals/pending. Two document types show up here:
///
///  * EXPENSES   - the Expense's own chain (HEAD_POD -> CO-CSO-1 -> CO-CSO-2),
///                 started when the Expense is created and ending in
///                 READY_TO_MATCHING. One row per Expense.
///  * SETTLEMENT - the Settlement batch's chain (SLS_MAR_DIR ->
///                 VP_ACC_BIL_TAX_3TV -> CO_CFO_3TV). One row per Settlement:
///                 that tier's approver reviews the member Expenses inside the
///                 batch and then submits to close the tier.
///
/// Event/Pre-Event approvals are a retired flow, so rows that are neither are
/// skipped. `isMyTurn` is actor-relative: false means the row is visible only
/// through a BOD position or an approval.read.* / expense.approve.* permission,
/// and someone else is the current step's resolved approver.
class ApprovalPendingItem {
  final ApprovalItemType type;
  final String approvalRequestId;
  final String amount;
  final String status;
  final String? departmentName;
  final bool isMyTurn;

  // type == expense only
  final String? expenseId;
  final String? expenseNo;
  final String? expenseDate;
  final String? purpose;
  final String? salesName;
  final String? advertiserName;
  final String? brandName;

  // type == settlement only
  final String? settlementId;
  final String? settlementNo;
  final int? expenseCount;
  final String? createdByName;

  ApprovalPendingItem({
    required this.type,
    required this.approvalRequestId,
    required this.amount,
    required this.status,
    required this.departmentName,
    required this.isMyTurn,
    this.expenseId,
    this.expenseNo,
    this.expenseDate,
    this.purpose,
    this.salesName,
    this.advertiserName,
    this.brandName,
    this.settlementId,
    this.settlementNo,
    this.expenseCount,
    this.createdByName,
  });

  static ApprovalPendingItem? fromJson(Map<String, dynamic> json) {
    final isMyTurn = json['isMyTurn'] as bool? ?? true;

    final expense = json['expense'] as Map<String, dynamic>?;
    if (expense != null) {
      final sales = expense['sales'] as Map<String, dynamic>? ?? {};
      final advertiser = expense['advertiser'] as Map<String, dynamic>? ?? {};
      final brand = expense['brand'] as Map<String, dynamic>? ?? {};
      final department = expense['department'] as Map<String, dynamic>?;
      return ApprovalPendingItem(
        type: ApprovalItemType.expense,
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
        departmentName: department?['name'] as String?,
        isMyTurn: isMyTurn,
      );
    }

    final settlement = json['settlement'] as Map<String, dynamic>?;
    if (settlement != null) {
      final department = settlement['department'] as Map<String, dynamic>?;
      final createdBy = settlement['createdBy'] as Map<String, dynamic>?;
      final expenses = (settlement['expenses'] as List?) ?? [];
      return ApprovalPendingItem(
        type: ApprovalItemType.settlement,
        approvalRequestId: json['id'] as String,
        settlementId: settlement['id'] as String,
        settlementNo: settlement['settlementNo'] as String? ?? '',
        amount: '${settlement['totalAmount'] ?? '0'}',
        status: settlement['status'] as String? ?? '',
        departmentName: department?['name'] as String?,
        createdByName: createdBy?['name'] as String?,
        expenseCount: expenses.length,
        isMyTurn: isMyTurn,
      );
    }

    return null;
  }
}
