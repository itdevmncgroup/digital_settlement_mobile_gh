/// One uploaded bank/credit-card settlement PDF (GET /bank-settlements).
class StatementBatch {
  final String id;
  final String fileName;
  final String createdAt;
  final String uploadedByName;
  final int transactionCount;

  StatementBatch({
    required this.id,
    required this.fileName,
    required this.createdAt,
    required this.uploadedByName,
    required this.transactionCount,
  });

  factory StatementBatch.fromJson(Map<String, dynamic> json) {
    final uploadedBy = json['uploadedBy'] as Map<String, dynamic>? ?? {};
    final count = json['_count'] as Map<String, dynamic>?;
    return StatementBatch(
      id: json['id'] as String,
      fileName: json['fileName'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      uploadedByName: uploadedBy['name'] as String? ?? '',
      transactionCount: (count?['transactions'] as int?) ?? 0,
    );
  }
}

/// One parsed line of a statement (BankTransaction) - the unit that gets
/// approved (confirmed matched) or rejected (unmatched).
class StatementTransaction {
  final String id;
  final int lineNo;
  final String? transactionDate;
  final String rawDescription;
  final String amount;
  final String? cardLast4;
  final String status; // UNMATCHED | AUTO_MATCHED | REVIEW_REQUIRED | MANUAL_MATCHED
  final MatchedExpenseRef? matchedExpense;

  StatementTransaction({
    required this.id,
    required this.lineNo,
    required this.transactionDate,
    required this.rawDescription,
    required this.amount,
    required this.cardLast4,
    required this.status,
    required this.matchedExpense,
  });

  bool get isCreditCard => cardLast4 != null;
  bool get isMatched => status == 'AUTO_MATCHED' || status == 'MANUAL_MATCHED';
  bool get hasCandidate => matchedExpense != null;

  factory StatementTransaction.fromJson(Map<String, dynamic> json) {
    final matched = json['matchedExpense'] as Map<String, dynamic>?;
    return StatementTransaction(
      id: json['id'] as String,
      lineNo: json['lineNo'] as int? ?? 0,
      transactionDate: json['transactionDate'] as String?,
      rawDescription: json['rawDescription'] as String? ?? '',
      amount: '${json['amount'] ?? '0'}',
      cardLast4: json['cardLast4'] as String?,
      status: json['status'] as String? ?? 'UNMATCHED',
      matchedExpense: matched != null ? MatchedExpenseRef.fromJson(matched) : null,
    );
  }
}

class MatchedExpenseRef {
  final String id;
  final String expenseNo;
  final String amount;
  final String salesName;

  MatchedExpenseRef({required this.id, required this.expenseNo, required this.amount, required this.salesName});

  factory MatchedExpenseRef.fromJson(Map<String, dynamic> json) {
    final sales = json['sales'] as Map<String, dynamic>? ?? {};
    return MatchedExpenseRef(
      id: json['id'] as String,
      expenseNo: json['expenseNo'] as String? ?? '',
      amount: '${json['amount'] ?? '0'}',
      salesName: sales['name'] as String? ?? '',
    );
  }
}

class StatementBatchDetail extends StatementBatch {
  final List<StatementTransaction> transactions;

  StatementBatchDetail({
    required super.id,
    required super.fileName,
    required super.createdAt,
    required super.uploadedByName,
    required super.transactionCount,
    required this.transactions,
  });

  factory StatementBatchDetail.fromJson(Map<String, dynamic> json) {
    final uploadedBy = json['uploadedBy'] as Map<String, dynamic>? ?? {};
    final txns = (json['transactions'] as List? ?? []).map((t) => StatementTransaction.fromJson(t as Map<String, dynamic>)).toList();
    return StatementBatchDetail(
      id: json['id'] as String,
      fileName: json['fileName'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      uploadedByName: uploadedBy['name'] as String? ?? '',
      transactionCount: txns.length,
      transactions: txns,
    );
  }
}
