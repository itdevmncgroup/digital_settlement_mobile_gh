class DashboardDepartment {
  final String id;
  final String name;
  DashboardDepartment({required this.id, required this.name});
  factory DashboardDepartment.fromJson(Map<String, dynamic> json) =>
      DashboardDepartment(id: json['id'] as String? ?? '', name: json['name'] as String? ?? '');
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

  DashboardData({
    required this.positionCode,
    required this.pendingApprovalCount,
    required this.departments,
    required this.departmentName,
    required this.totalSettledAmount,
    required this.approvedExpenseCount,
    required this.approvedSettlementCount,
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
    );
  }
}
