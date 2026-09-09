class SimpleRef {
  final String id;
  final String name;
  SimpleRef({required this.id, required this.name});
  factory SimpleRef.fromJson(Map<String, dynamic> json) => SimpleRef(id: json['id'] as String, name: json['name'] as String? ?? '');
}

class ParticipantDetail {
  final String category;
  final String name;
  final String? position;
  final String? agencyId;
  final String? advertiserId;
  final String? unitId;
  ParticipantDetail({
    required this.category,
    required this.name,
    required this.position,
    required this.agencyId,
    required this.advertiserId,
    required this.unitId,
  });
  factory ParticipantDetail.fromJson(Map<String, dynamic> json) => ParticipantDetail(
        category: json['category'] as String? ?? '',
        name: json['name'] as String? ?? '',
        position: json['position'] as String?,
        agencyId: json['agencyId'] as String?,
        advertiserId: json['advertiserId'] as String?,
        unitId: json['unitId'] as String?,
      );
}

class ExpenseDetail {
  final String id;
  final String expenseNo;
  final String status;
  final String expenseDate;
  final String purpose;
  final String amount;
  final String? merchantName;
  final String? location;
  final String? paymentMethodType;
  final String? paymentMethodNote;
  final String? creditCardLabel;
  final String? creditCardId;
  final String salesName;
  final String unitName;
  final String advertiserId;
  final String advertiserName;
  final String brandId;
  final String brandName;
  final String activityTypeName;
  final String? departmentId;
  final String? departmentName;
  final String? settlementNo;
  final List<ExpenseItemDetail> items;
  final List<ExpensePhotoRef> photos;
  final List<ExpenseInvoiceRef> invoices;
  final bool matched;
  final List<SimpleRef> extraAgencies;
  final List<SimpleRef> extraAdvertisers;
  final List<SimpleRef> extraBrands;
  final List<ParticipantDetail> participants;
  // Who the current pending approval step (if any) is resolved to - lets the
  // detail screen show Approve/Reject only to that person (or an override).
  final String? approvalResolvedApproverId;
  final String? approvalPositionName;

  ExpenseDetail({
    required this.id,
    required this.expenseNo,
    required this.status,
    required this.expenseDate,
    required this.purpose,
    required this.amount,
    required this.merchantName,
    required this.location,
    required this.paymentMethodType,
    required this.paymentMethodNote,
    required this.creditCardLabel,
    required this.creditCardId,
    required this.salesName,
    required this.unitName,
    required this.advertiserId,
    required this.advertiserName,
    required this.brandId,
    required this.brandName,
    required this.activityTypeName,
    required this.departmentId,
    required this.departmentName,
    required this.settlementNo,
    required this.items,
    required this.photos,
    required this.invoices,
    required this.matched,
    required this.extraAgencies,
    required this.extraAdvertisers,
    required this.extraBrands,
    required this.participants,
    required this.approvalResolvedApproverId,
    required this.approvalPositionName,
  });

  factory ExpenseDetail.fromJson(Map<String, dynamic> json) {
    final sales = json['sales'] as Map<String, dynamic>? ?? {};
    final unit = json['unit'] as Map<String, dynamic>? ?? {};
    final advertiser = json['advertiser'] as Map<String, dynamic>? ?? {};
    final brand = json['brand'] as Map<String, dynamic>? ?? {};
    final activityType = json['activityType'] as Map<String, dynamic>? ?? {};
    final department = json['department'] as Map<String, dynamic>?;
    final creditCard = json['creditCard'] as Map<String, dynamic>?;
    final settlement = json['settlement'] as Map<String, dynamic>?;
    final bankTransactions = (json['bankTransactions'] as List?) ?? [];
    final matched = bankTransactions.any((t) => ['AUTO_MATCHED', 'MANUAL_MATCHED'].contains((t as Map)['status']));

    final approvalRequest = json['approvalRequest'] as Map<String, dynamic>?;
    Map<String, dynamic>? currentStep;
    if (approvalRequest != null && approvalRequest['status'] == 'PENDING') {
      final steps = (approvalRequest['steps'] as List?) ?? [];
      for (final s in steps) {
        final step = s as Map<String, dynamic>;
        if (step['stepOrder'] == approvalRequest['currentStep']) {
          currentStep = step;
          break;
        }
      }
    }
    final resolvedApprover = currentStep?['resolvedApprover'] as Map<String, dynamic>?;
    final position = currentStep?['position'] as Map<String, dynamic>?;

    return ExpenseDetail(
      id: json['id'] as String,
      expenseNo: json['expenseNo'] as String? ?? '',
      status: json['status'] as String? ?? '',
      expenseDate: json['expenseDate'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      amount: '${json['amount'] ?? '0'}',
      merchantName: json['merchantName'] as String?,
      location: json['location'] as String?,
      paymentMethodType: json['paymentMethodType'] as String?,
      paymentMethodNote: json['paymentMethodNote'] as String?,
      creditCardLabel: creditCard != null ? '${creditCard['bank']} •••• ${creditCard['last4']}' : null,
      creditCardId: json['creditCardId'] as String?,
      salesName: sales['name'] as String? ?? '',
      unitName: unit['name'] as String? ?? '',
      advertiserId: json['advertiserId'] as String? ?? '',
      advertiserName: advertiser['name'] as String? ?? '',
      brandId: json['brandId'] as String? ?? '',
      brandName: brand['name'] as String? ?? '',
      activityTypeName: activityType['name'] as String? ?? '',
      departmentId: json['departmentId'] as String?,
      departmentName: department?['name'] as String?,
      settlementNo: settlement?['settlementNo'] as String?,
      items: (json['items'] as List? ?? []).map((e) => ExpenseItemDetail.fromJson(e as Map<String, dynamic>)).toList(),
      photos: (json['photos'] as List? ?? []).map((e) => ExpensePhotoRef.fromJson(e as Map<String, dynamic>)).toList(),
      invoices: (json['invoices'] as List? ?? []).map((e) => ExpenseInvoiceRef.fromJson(e as Map<String, dynamic>)).toList(),
      matched: matched,
      extraAgencies: (json['extraAgencies'] as List? ?? [])
          .map((e) => SimpleRef.fromJson((e as Map<String, dynamic>)['agency'] as Map<String, dynamic>))
          .toList(),
      extraAdvertisers: (json['extraAdvertisers'] as List? ?? [])
          .map((e) => SimpleRef.fromJson((e as Map<String, dynamic>)['advertiser'] as Map<String, dynamic>))
          .toList(),
      extraBrands: (json['extraBrands'] as List? ?? [])
          .map((e) => SimpleRef.fromJson((e as Map<String, dynamic>)['brand'] as Map<String, dynamic>))
          .toList(),
      participants: (json['participants'] as List? ?? []).map((e) => ParticipantDetail.fromJson(e as Map<String, dynamic>)).toList(),
      approvalResolvedApproverId: resolvedApprover?['id'] as String?,
      approvalPositionName: position?['name'] as String?,
    );
  }
}

class ExpenseItemDetail {
  final String description;
  final String amount;
  ExpenseItemDetail({required this.description, required this.amount});
  factory ExpenseItemDetail.fromJson(Map<String, dynamic> json) =>
      ExpenseItemDetail(description: json['description'] as String? ?? '', amount: '${json['amount'] ?? '0'}');
}

class ExpensePhotoRef {
  final String id;
  final String fileName;
  final String mimeType;
  ExpensePhotoRef({required this.id, required this.fileName, required this.mimeType});
  factory ExpensePhotoRef.fromJson(Map<String, dynamic> json) => ExpensePhotoRef(
        id: json['id'] as String,
        fileName: json['fileName'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? '',
      );
}

class ExpenseInvoiceRef {
  final String id;
  final String? merchantName;
  final String? total;
  final String matchingStatus;
  final List<ExpensePhotoRef> files;
  ExpenseInvoiceRef({required this.id, required this.merchantName, required this.total, required this.matchingStatus, required this.files});
  factory ExpenseInvoiceRef.fromJson(Map<String, dynamic> json) => ExpenseInvoiceRef(
        id: json['id'] as String,
        merchantName: json['finalMerchantName'] as String?,
        total: json['finalTotal'] != null ? '${json['finalTotal']}' : null,
        matchingStatus: json['matchingStatus'] as String? ?? 'UNMATCHED',
        files: ((json['files'] as List?) ?? []).map((f) => ExpensePhotoRef.fromJson(f as Map<String, dynamic>)).toList(),
      );
}
