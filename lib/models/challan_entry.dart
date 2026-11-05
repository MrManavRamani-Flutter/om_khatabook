enum PaymentOption {
  cash,
  cheque;

  String get label => this == PaymentOption.cash ? 'Cash' : 'Cheque';
}

enum ChequeStatus {
  pending,
  cleared,
  bounced;

  String get label {
    switch (this) {
      case ChequeStatus.pending:
        return 'Pending Clearance';
      case ChequeStatus.cleared:
        return 'Cleared';
      case ChequeStatus.bounced:
        return 'Bounced';
    }
  }
}

class ChequeDetails {
  final DateTime chequeDate;
  final String chequeNo;
  final String bankName;
  final double chequeAmount;
  final ChequeStatus status;

  ChequeDetails({
    required this.chequeDate,
    required this.chequeNo,
    required this.bankName,
    required this.chequeAmount,
    this.status = ChequeStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'chequeDate': chequeDate.toIso8601String(),
      'chequeNo': chequeNo,
      'bankName': bankName,
      'chequeAmount': chequeAmount,
      'status': status.name,
    };
  }

  factory ChequeDetails.fromJson(Map<String, dynamic> json) {
    return ChequeDetails(
      chequeDate: DateTime.parse(json['chequeDate'] as String),
      chequeNo: json['chequeNo'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      chequeAmount: (json['chequeAmount'] as num?)?.toDouble() ?? 0.0,
      status: ChequeStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ChequeStatus.pending,
      ),
    );
  }

  ChequeDetails copyWith({
    DateTime? chequeDate,
    String? chequeNo,
    String? bankName,
    double? chequeAmount,
    ChequeStatus? status,
  }) {
    return ChequeDetails(
      chequeDate: chequeDate ?? this.chequeDate,
      chequeNo: chequeNo ?? this.chequeNo,
      bankName: bankName ?? this.bankName,
      chequeAmount: chequeAmount ?? this.chequeAmount,
      status: status ?? this.status,
    );
  }
}

class ChallanEntry {
  final String id;
  final DateTime date;
  final String challanNo;
  final String partyId;
  final String partyName;
  final double challanAmount;
  final double finalAmount;
  final String gstBillNo;
  final double gstAmount;
  final PaymentOption paymentOption;
  final bool isCashPaid; // If false for cash, highlighted in warning/light-red
  final ChequeDetails? chequeDetails;
  final String notes;
  final DateTime createdAt; // Hidden from form, set to DateTime.now()

  ChallanEntry({
    required this.id,
    required this.date,
    required this.challanNo,
    required this.partyId,
    required this.partyName,
    required this.challanAmount,
    required this.finalAmount,
    this.gstBillNo = '',
    this.gstAmount = 0.0,
    required this.paymentOption,
    this.isCashPaid = true,
    this.chequeDetails,
    this.notes = '',
    required this.createdAt,
  });

  /// Indicates if this record requires warning highlight
  /// (e.g. Cash and not paid, or Cheque and bounced)
  bool get hasWarning {
    if (paymentOption == PaymentOption.cash && !isCashPaid) {
      return true;
    }
    if (paymentOption == PaymentOption.cheque &&
        chequeDetails?.status == ChequeStatus.bounced) {
      return true;
    }
    return false;
  }

  bool get isPending {
    if (paymentOption == PaymentOption.cash && !isCashPaid) {
      return true;
    }
    if (paymentOption == PaymentOption.cheque &&
        chequeDetails?.status == ChequeStatus.pending) {
      return true;
    }
    return false;
  }

  String get statusDisplay {
    if (paymentOption == PaymentOption.cash) {
      return isCashPaid ? 'Cash Paid' : 'Cash Unpaid';
    } else {
      final s = chequeDetails?.status ?? ChequeStatus.pending;
      return 'Cheque ${s.label}';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'challanNo': challanNo,
      'partyId': partyId,
      'partyName': partyName,
      'challanAmount': challanAmount,
      'finalAmount': finalAmount,
      'gstBillNo': gstBillNo,
      'gstAmount': gstAmount,
      'paymentOption': paymentOption.name,
      'isCashPaid': isCashPaid,
      'chequeDetails': chequeDetails?.toJson(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChallanEntry.fromJson(Map<String, dynamic> json) {
    return ChallanEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      challanNo: json['challanNo'] as String? ?? '',
      partyId: json['partyId'] as String? ?? '',
      partyName: json['partyName'] as String? ?? '',
      challanAmount: (json['challanAmount'] as num?)?.toDouble() ?? 0.0,
      finalAmount: (json['finalAmount'] as num?)?.toDouble() ?? 0.0,
      gstBillNo: json['gstBillNo'] as String? ?? '',
      gstAmount: (json['gstAmount'] as num?)?.toDouble() ?? 0.0,
      paymentOption: PaymentOption.values.firstWhere(
        (e) => e.name == json['paymentOption'],
        orElse: () => PaymentOption.cash,
      ),
      isCashPaid: json['isCashPaid'] as bool? ?? true,
      chequeDetails: json['chequeDetails'] != null
          ? ChequeDetails.fromJson(
              json['chequeDetails'] as Map<String, dynamic>)
          : null,
      notes: json['notes'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  ChallanEntry copyWith({
    DateTime? date,
    String? challanNo,
    String? partyId,
    String? partyName,
    double? challanAmount,
    double? finalAmount,
    String? gstBillNo,
    double? gstAmount,
    PaymentOption? paymentOption,
    bool? isCashPaid,
    ChequeDetails? chequeDetails,
    String? notes,
  }) {
    return ChallanEntry(
      id: id,
      date: date ?? this.date,
      challanNo: challanNo ?? this.challanNo,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      challanAmount: challanAmount ?? this.challanAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      gstBillNo: gstBillNo ?? this.gstBillNo,
      gstAmount: gstAmount ?? this.gstAmount,
      paymentOption: paymentOption ?? this.paymentOption,
      isCashPaid: isCashPaid ?? this.isCashPaid,
      chequeDetails: chequeDetails ?? this.chequeDetails,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

