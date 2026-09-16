class DashboardDepartment {
  final String id;
  final String name;
  DashboardDepartment({required this.id, required this.name});
  factory DashboardDepartment.fromJson(Map<String, dynamic> json) =>
      DashboardDepartment(id: json['id'] as String? ?? '', name: json['name'] as String? ?? '');
}

/// One row of the "Expense Incomplete/Complete per Departemen" bar charts.
class DashboardDepartmentBreakdown {
  final String departmentId;
  final String departmentName;
  final int incompleteCount;
  final int completeCount;
  DashboardDepartmentBreakdown({
    required this.departmentId,
    required this.departmentName,
    required this.incompleteCount,
    required this.completeCount,
  });
  factory DashboardDepartmentBreakdown.fromJson(Map<String, dynamic> json) => DashboardDepartmentBreakdown(
        departmentId: json['departmentId'] as String? ?? '',
        departmentName: json['departmentName'] as String? ?? '-',
        incompleteCount: (json['incompleteCount'] as num?)?.toInt() ?? 0,
        completeCount: (json['completeCount'] as num?)?.toInt() ?? 0,
      );
}

/// One "Aktivitas Terkini" feed row.
class DashboardActivity {
  final String id;
  final String title;
  final String purpose;
  final String amount;
  final String? departmentName;
  final String status;
  final DateTime timestamp;
  DashboardActivity({
    required this.id,
    required this.title,
    required this.purpose,
    required this.amount,
    required this.departmentName,
    required this.status,
    required this.timestamp,
  });
  factory DashboardActivity.fromJson(Map<String, dynamic> json) => DashboardActivity(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '-',
        purpose: json['purpose'] as String? ?? '-',
        amount: json['amount'] != null ? '${json['amount']}' : '0',
        departmentName: json['departmentName'] as String?,
        status: json['status'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

/// GET /dashboard/me - tailored to the caller's approval Position (HEAD_POD /
/// DEPT_HEAD / DIV_HEAD / BOD / none). Every field beyond pendingApprovalCount
/// is nullable: only the fields relevant to the caller's position come back.
class DashboardData {
  final String? positionCode;
  final int pendingApprovalCount;
  // HEAD_POD branch: the Department(s) they're an explicit approver for.
  final List<DashboardDepartment>? departments;
  // DEPT_HEAD/DIV_HEAD branch: their own single Department's name.
  final String? departmentName;
  final String? totalSettledAmount;
  final int? approvedExpenseCount;
  final int? approvedSettlementCount;
  // Sum of Expense.amount whose Settlement has reached COMPLETE - own pod(s)
  // for SALES/SALES_ADMIN/HEAD_POD, company-wide for every other role.
  final String? totalExpenseAmount;
  // Home-screen stat cards + charts - present for every position branch.
  final String totalExpenseIncompleteAmount;
  final String totalExpenseCompleteAmount;
  final int totalExpensePendingCount;
  final List<DashboardDepartmentBreakdown> expenseByDepartment;
  final List<DashboardActivity> recentActivity;

  DashboardData({
    required this.positionCode,
    required this.pendingApprovalCount,
    required this.departments,
    required this.departmentName,
    required this.totalSettledAmount,
    required this.approvedExpenseCount,
    required this.approvedSettlementCount,
    required this.totalExpenseAmount,
    required this.totalExpenseIncompleteAmount,
    required this.totalExpenseCompleteAmount,
    required this.totalExpensePendingCount,
    required this.expenseByDepartment,
    required this.recentActivity,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final department = json['department'] as Map<String, dynamic>?;
    return DashboardData(
      positionCode: json['positionCode'] as String?,
      pendingApprovalCount: (json['pendingApprovalCount'] as num?)?.toInt() ?? 0,
      departments: (json['departments'] as List?)?.map((p) => DashboardDepartment.fromJson(p as Map<String, dynamic>)).toList(),
      departmentName: department?['name'] as String?,
      totalSettledAmount: json['totalSettledAmount'] != null ? '${json['totalSettledAmount']}' : null,
      approvedExpenseCount: (json['approvedExpenseCount'] as num?)?.toInt(),
      approvedSettlementCount: (json['approvedSettlementCount'] as num?)?.toInt(),
      totalExpenseAmount: json['totalExpenseAmount'] != null ? '${json['totalExpenseAmount']}' : null,
      totalExpenseIncompleteAmount: json['totalExpenseIncompleteAmount'] != null ? '${json['totalExpenseIncompleteAmount']}' : '0',
      totalExpenseCompleteAmount: json['totalExpenseCompleteAmount'] != null ? '${json['totalExpenseCompleteAmount']}' : '0',
      totalExpensePendingCount: (json['totalExpensePendingCount'] as num?)?.toInt() ?? 0,
      expenseByDepartment: (json['expenseByDepartment'] as List?)
              ?.map((p) => DashboardDepartmentBreakdown.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      recentActivity: (json['recentActivity'] as List?)?.map((p) => DashboardActivity.fromJson(p as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
