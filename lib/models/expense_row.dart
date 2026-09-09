const matchedTxnStatuses = ['AUTO_MATCHED', 'MANUAL_MATCHED'];

/// One row of GET /expenses.
class ExpenseRow {
  final String id;
  final String expenseNo;
  final String expenseDate;
  final String purpose;
  final String amount;
  final String status;
  final String salesId;
  final String salesName;
  final String advertiserName;
  final String brandName;
  final String? departmentName;
  final bool matched;

  ExpenseRow({
    required this.id,
    required this.expenseNo,
    required this.expenseDate,
    required this.purpose,
    required this.amount,
    required this.status,
    required this.salesId,
    required this.salesName,
    required this.advertiserName,
    required this.brandName,
    required this.departmentName,
    required this.matched,
  });

  factory ExpenseRow.fromJson(Map<String, dynamic> json) {
    final sales = json['sales'] as Map<String, dynamic>? ?? {};
    final advertiser = json['advertiser'] as Map<String, dynamic>? ?? {};
    final brand = json['brand'] as Map<String, dynamic>? ?? {};
    final department = json['department'] as Map<String, dynamic>?;
    final bankTransactions = (json['bankTransactions'] as List?) ?? [];
    final matched = bankTransactions.any((t) => matchedTxnStatuses.contains((t as Map)['status']));
    return ExpenseRow(
      id: json['id'] as String,
      expenseNo: json['expenseNo'] as String? ?? '',
      expenseDate: json['expenseDate'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      amount: '${json['amount'] ?? '0'}',
      status: json['status'] as String? ?? '',
      salesId: json['salesId'] as String? ?? '',
      salesName: sales['name'] as String? ?? '',
      advertiserName: advertiser['name'] as String? ?? '',
      brandName: brand['name'] as String? ?? '',
      departmentName: department?['name'] as String?,
      matched: matched,
    );
  }
}
