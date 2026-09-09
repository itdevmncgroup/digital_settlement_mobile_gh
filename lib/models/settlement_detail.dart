/// GET /settlements/:id - a Settlement batch plus its own approval chain
/// (SLS_MAR_DIR -> VP_ACC_BIL_TAX_3TV -> CO_CFO_3TV).
///
/// A tier does not advance per Expense: its approver reviews each member Expense
/// (approve marks it, reject drops it out of the batch), then presses Submit
/// once to close the tier and move the whole batch on. The Settlement and its
/// Expenses always carry the same tier in their status.
class SettlementDetail {
  final String id;
  final String settlementNo;
  final String? departmentName;
  final String totalAmount;
  final String status;
  final String createdByName;

  /// Current tier of the batch's chain - null once it is finished.
  final int? currentStep;
  final String? currentPositionName;
  final String? currentApproverId;

  final List<SettlementExpenseRow> expenses;

  SettlementDetail({
    required this.id,
    required this.settlementNo,
    required this.departmentName,
    required this.totalAmount,
    required this.status,
    required this.createdByName,
    required this.currentStep,
    required this.currentPositionName,
    required this.currentApproverId,
    required this.expenses,
  });

  /// True when the signed-in user is this tier's approver, i.e. may review the
  /// Expenses below and press Submit.
  bool isMyTurn(String? userId) => currentApproverId != null && currentApproverId == userId;

  /// Submit closes the tier, so every Expense still in the batch must have been
  /// reviewed at this tier first (the backend enforces the same rule).
  bool get allReviewed =>
      expenses.isNotEmpty && currentStep != null && expenses.every((e) => (e.settlementApprovedStep ?? -1) >= currentStep!);

  factory SettlementDetail.fromJson(Map<String, dynamic> json) {
    final department = json['department'] as Map<String, dynamic>?;
    final createdBy = json['createdBy'] as Map<String, dynamic>? ?? {};
    final approvalRequest = json['approvalRequest'] as Map<String, dynamic>?;

    Map<String, dynamic>? currentStepRow;
    int? currentStep;
    if (approvalRequest != null && approvalRequest['status'] == 'PENDING') {
      currentStep = approvalRequest['currentStep'] as int?;
      for (final s in (approvalRequest['steps'] as List?) ?? []) {
        final step = s as Map<String, dynamic>;
        if (step['stepOrder'] == currentStep) {
          currentStepRow = step;
          break;
        }
      }
    }

    return SettlementDetail(
      id: json['id'] as String,
      settlementNo: json['settlementNo'] as String? ?? '',
      departmentName: department?['name'] as String?,
      totalAmount: '${json['totalAmount'] ?? '0'}',
      status: json['status'] as String? ?? '',
      createdByName: createdBy['name'] as String? ?? '',
      currentStep: currentStepRow == null ? null : currentStep,
      currentPositionName: (currentStepRow?['position'] as Map<String, dynamic>?)?['name'] as String?,
      currentApproverId: (currentStepRow?['resolvedApprover'] as Map<String, dynamic>?)?['id'] as String?,
      expenses: ((json['expenses'] as List?) ?? []).map((e) => SettlementExpenseRow.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class SettlementExpenseRow {
  final String id;
  final String expenseNo;
  final String amount;
  final String expenseDate;
  final String purpose;
  final String status;
  final String salesName;
  final String? advertiserName;
  final String? brandName;

  /// Highest Settlement tier this Expense has been individually approved at -
  /// null means it has not been reviewed at any tier yet.
  final int? settlementApprovedStep;

  SettlementExpenseRow({
    required this.id,
    required this.expenseNo,
    required this.amount,
    required this.expenseDate,
    required this.purpose,
    required this.status,
    required this.salesName,
    required this.advertiserName,
    required this.brandName,
    required this.settlementApprovedStep,
  });

  bool reviewedAt(int? tier) => tier != null && (settlementApprovedStep ?? -1) >= tier;

  factory SettlementExpenseRow.fromJson(Map<String, dynamic> json) {
    final sales = json['sales'] as Map<String, dynamic>? ?? {};
    final advertiser = json['advertiser'] as Map<String, dynamic>?;
    final brand = json['brand'] as Map<String, dynamic>?;

    return SettlementExpenseRow(
      id: json['id'] as String,
      expenseNo: json['expenseNo'] as String? ?? '',
      amount: '${json['amount'] ?? '0'}',
      expenseDate: json['expenseDate'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      status: json['status'] as String? ?? '',
      salesName: sales['name'] as String? ?? '',
      advertiserName: advertiser?['name'] as String?,
      brandName: brand?['name'] as String?,
      settlementApprovedStep: json['settlementApprovedStep'] as int?,
    );
  }
}
