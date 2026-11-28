import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

enum LedgerViewMode {
  table('Table (Excel Grid)'),
  compact('Compact List'),
  cards('Large Cards');

  final String label;
  const LedgerViewMode(this.label);
}

enum TextCasingStyle {
  uppercase('ALL CAPITAL LETTERS (UPPERCASE)'),
  titleCase('Capitalize Each Word (Title Case)'),
  lowercase('all small letters (lowercase)');

  final String label;
  const TextCasingStyle(this.label);

  String get example {
    switch (this) {
      case TextCasingStyle.uppercase:
        return 'e.g. MANAV FAB, RING ROAD, SURAT';
      case TextCasingStyle.titleCase:
        return 'e.g. Manav Fab, Ring Road, Surat';
      case TextCasingStyle.lowercase:
        return 'e.g. manav fab, ring road, surat';
    }
  }

  String apply(String text) {
    if (text.isEmpty) return text;
    switch (this) {
      case TextCasingStyle.uppercase:
        return text.toUpperCase();
      case TextCasingStyle.lowercase:
        return text.toLowerCase();
      case TextCasingStyle.titleCase:
        final words = text.split(' ');
        final capitalized = words.map((w) {
          if (w.isEmpty) return w;
          if (w.length == 1) return w.toUpperCase();
          return w[0].toUpperCase() + w.substring(1).toLowerCase();
        });
        return capitalized.join(' ');
    }
  }
}

class DynamicCaseTextInputFormatter extends TextInputFormatter {
  final TextCasingStyle style;

  const DynamicCaseTextInputFormatter(this.style);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = style.apply(newValue.text);
    return newValue.copyWith(
      text: formatted,
      selection: newValue.selection,
    );
  }
}

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
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      final str = val.toString().trim();
      final dt = DateTime.tryParse(str);
      if (dt != null) return dt;
      final dmyRegex = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})');
      final match = dmyRegex.firstMatch(str);
      if (match != null) {
        final d = int.tryParse(match.group(1)!) ?? 1;
        final m = int.tryParse(match.group(2)!) ?? 1;
        final y = int.tryParse(match.group(3)!) ?? DateTime.now().year;
        return DateTime(y, m, d);
      }
      return DateTime.now();
    }

    double parseAmount(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      final clean = val.toString().replaceAll('₹', '').replaceAll(',', '').replaceAll('Rs.', '').replaceAll(' ', '').trim();
      return double.tryParse(clean) ?? 0.0;
    }

    return ChequeDetails(
      chequeDate: parseDate(json['chequeDate'] ?? json['cheque_date']),
      chequeNo: (json['chequeNo'] ?? json['chequeNumber'] ?? json['cheque_no'] ?? json['cheque_number'])?.toString().trim() ?? '',
      bankName: (json['bankName'] ?? json['bank_name'] ?? json['bank'])?.toString().trim() ?? '',
      chequeAmount: parseAmount(json['chequeAmount'] ?? json['cheque_amount'] ?? json['amount']),
      status: ChequeStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['status'] ?? json['chequeStatus'])?.toString().toLowerCase(),
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
  final String designNo; // Optional design number (e.g. D-101, 550, etc.)
  final double challanAmount;
  final double discountAmount; // Discount given on challan (Challan Amt - Discount = Final Amt)
  final double finalAmount;
  final double paidAmount; // Received amount (supports partial payments)
  final String gstBillNo;
  final double gstAmount;
  final PaymentOption paymentOption;
  final bool isCashPaid; // False if unpaid or partially paid
  final ChequeDetails? chequeDetails;
  final DateTime? paymentDueDate; // Promised payment date / due date for unpaid or partial challans
  final String notes;
  final DateTime createdAt; // Hidden from form, set to DateTime.now()
  final String createdBy; // Username who added this record
  final String? lastModifiedBy; // Username who last modified this record
  final DateTime? lastModifiedAt; // Timestamp when last modified
  final bool isDeleted; // Recycle bin flag
  final DateTime? deletedAt; // Timestamp when moved to bin
  final String? deletedBy; // Username who moved record to bin

  ChallanEntry({
    required this.id,
    required this.date,
    required this.challanNo,
    required this.partyId,
    required this.partyName,
    this.designNo = '',
    required this.challanAmount,
    this.discountAmount = 0.0,
    required this.finalAmount,
    double? paidAmount,
    this.gstBillNo = '',
    this.gstAmount = 0.0,
    required this.paymentOption,
    this.isCashPaid = true,
    this.chequeDetails,
    this.paymentDueDate,
    this.notes = '',
    required this.createdAt,
    this.createdBy = 'admin',
    this.lastModifiedBy,
    this.lastModifiedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  }) : paidAmount = (paidAmount != null)
            ? paidAmount
            : (isCashPaid ? finalAmount : 0.0);

  /// Calculated remaining balance due for this challan
  double get remainingAmount =>
      (finalAmount - paidAmount).clamp(0.0, double.infinity);

  /// True if customer made a partial payment (more than 0, but less than final amount)
  bool get isPartiallyPaid =>
      paymentOption == PaymentOption.cash &&
      paidAmount > 0 &&
      paidAmount < finalAmount;

  /// True if transaction is 100% settled/cleared
  bool get isFullyPaid {
    if (paymentOption == PaymentOption.cash) {
      return isCashPaid && remainingAmount <= 0.001;
    }
    return chequeDetails?.status == ChequeStatus.cleared;
  }

  /// Indicates if this record requires warning highlight
  /// (e.g. Cash unpaid/partially paid, or Cheque bounced)
  bool get hasWarning {
    if (paymentOption == PaymentOption.cash) {
      return !isCashPaid || remainingAmount > 0.001;
    }
    if (paymentOption == PaymentOption.cheque &&
        chequeDetails?.status == ChequeStatus.bounced) {
      return true;
    }
    return false;
  }

  bool get isPending {
    if (paymentOption == PaymentOption.cash) {
      return remainingAmount > 0.001;
    }
    if (paymentOption == PaymentOption.cheque &&
        chequeDetails?.status == ChequeStatus.pending) {
      return true;
    }
    return false;
  }

  String get statusDisplay {
    if (paymentOption == PaymentOption.cash) {
      if (isPartiallyPaid) {
        return 'Partial Paid (Due: ₹${remainingAmount.toStringAsFixed(0)})';
      }
      return isCashPaid ? 'Cash Paid' : 'Cash Unpaid';
    } else {
      final s = chequeDetails?.status ?? ChequeStatus.pending;
      return 'Cheque ${s.label}';
    }
  }

  /// Whether this unpaid/partial challan has crossed its payment due date
  bool get isPaymentOverdue {
    if (isFullyPaid) return false;
    if (paymentDueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(paymentDueDate!.year, paymentDueDate!.month, paymentDueDate!.day);
    return today.isAfter(due);
  }

  /// Number of days remaining until payment due (positive = days left, 0 = due today, negative = days overdue)
  int? get daysUntilPaymentDue {
    if (paymentDueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(paymentDueDate!.year, paymentDueDate!.month, paymentDueDate!.day);
    return due.difference(today).inDays;
  }

  /// Countdown and status label for UI countdowns and badges
  String get paymentDueCountdownText {
    final days = daysUntilPaymentDue;
    if (days == null) return '';
    if (isFullyPaid) return 'Paid';
    if (days > 1) return '$days Days Left';
    if (days == 1) return 'Due Tomorrow';
    if (days == 0) return 'Due Today ⚠️';
    final overdueDays = days.abs();
    return '$overdueDays Days Overdue 🚨';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'challanNo': challanNo,
      'partyId': partyId,
      'partyName': partyName,
      'designNo': designNo,
      'challanAmount': challanAmount,
      'discountAmount': discountAmount,
      'finalAmount': finalAmount,
      'paidAmount': paidAmount,
      'gstBillNo': gstBillNo,
      'gstAmount': gstAmount,
      'paymentOption': paymentOption.name,
      'isCashPaid': isCashPaid,
      'chequeDetails': chequeDetails?.toJson(),
      'paymentDueDate': paymentDueDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'lastModifiedBy': lastModifiedBy,
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'deletedBy': deletedBy,
    };
  }

  static double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final clean = val.toString().replaceAll('₹', '').replaceAll(',', '').replaceAll('Rs.', '').replaceAll(' ', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  static DateTime _parseDate(dynamic val, {DateTime? fallback}) {
    if (val == null) return fallback ?? DateTime.now();
    if (val is DateTime) return val;
    if (val is num) {
      return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    }
    final str = val.toString().trim();
    if (str.isEmpty) return fallback ?? DateTime.now();
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed;
    // Support DD/MM/YYYY or DD-MM-YYYY
    final dmyRegex = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})');
    final match = dmyRegex.firstMatch(str);
    if (match != null) {
      final d = int.tryParse(match.group(1)!) ?? 1;
      final m = int.tryParse(match.group(2)!) ?? 1;
      final y = int.tryParse(match.group(3)!) ?? DateTime.now().year;
      return DateTime(y, m, d);
    }
    return fallback ?? DateTime.now();
  }

  factory ChallanEntry.fromJson(Map<String, dynamic> json) {
    final rawChallanNo = (json['challanNo'] ?? json['challanNumber'] ?? json['challan_no'] ?? json['referenceNo'] ?? json['refNo'] ?? json['billNo'] ?? '').toString().trim();
    final rawPartyName = (json['partyName'] ?? json['party'] ?? json['party_name'] ?? json['customerName'] ?? json['clientName'] ?? '').toString().trim();
    final rawPartyId = (json['partyId'] ?? json['party_id'] ?? json['customerId'] ?? '').toString().trim();
    final rawDesignNo = (json['designNo'] ?? json['design_no'] ?? json['designNumber'] ?? json['design'] ?? '').toString().trim();
    final rawGstBillNo = (json['gstBillNo'] ?? json['gst_bill_no'] ?? json['billNo'] ?? json['invoiceNo'] ?? json['taxInvoiceNo'] ?? '').toString().trim();

    final parsedChallanAmt = _parseAmount(json['challanAmount'] ?? json['challan_amount'] ?? json['billAmount'] ?? json['subTotal']);
    final parsedDiscountAmt = _parseAmount(json['discountAmount'] ?? json['discount_amount'] ?? json['discount'] ?? json['discountAmt']);
    final parsedGstAmt = _parseAmount(json['gstAmount'] ?? json['gst_amount'] ?? json['taxAmount'] ?? json['gst']);

    var finalAmt = _parseAmount(json['finalAmount'] ?? json['final_amount'] ?? json['totalAmount'] ?? json['total_amount'] ?? json['amount'] ?? json['netAmount']);
    if (finalAmt == 0.0 && parsedChallanAmt > 0) {
      finalAmt = (parsedChallanAmt - parsedDiscountAmt + parsedGstAmt).clamp(0.0, double.infinity);
    }

    final paymentStatusRaw = (json['paymentStatus'] ?? json['payment_status'] ?? json['status'])?.toString().toLowerCase().trim();
    final isCashPaidField = json['isCashPaid'] ?? json['is_cash_paid'];

    bool isCashPaidVal;
    if (isCashPaidField is bool) {
      isCashPaidVal = isCashPaidField;
    } else if (isCashPaidField != null) {
      final str = isCashPaidField.toString().toLowerCase().trim();
      isCashPaidVal = str == 'true' || str == '1' || str == 'yes' || str == 'paid';
    } else if (paymentStatusRaw != null) {
      isCashPaidVal = paymentStatusRaw == 'paid' || paymentStatusRaw == 'cleared' || paymentStatusRaw == 'completed';
    } else {
      isCashPaidVal = true;
    }

    final paidAmt = (json['paidAmount'] != null || json['paid_amount'] != null)
        ? _parseAmount(json['paidAmount'] ?? json['paid_amount'])
        : ((json['receivedAmount'] != null || json['received_amount'] != null)
            ? _parseAmount(json['receivedAmount'] ?? json['received_amount'])
            : (isCashPaidVal ? finalAmt : 0.0));

    final rawId = json['id']?.toString().trim();
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'challan_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';

    ChequeDetails? cheque;
    final rawCheque = json['chequeDetails'] ?? json['cheque_details'] ?? json['cheque'];
    if (rawCheque != null && rawCheque is Map) {
      try {
        cheque = ChequeDetails.fromJson(
            Map<String, dynamic>.from(rawCheque));
      } catch (_) {
        cheque = null;
      }
    } else if (json['chequeNumber'] != null || json['cheque_number'] != null || json['chequeNo'] != null || json['cheque_no'] != null) {
      cheque = ChequeDetails(
        chequeNo: (json['chequeNumber'] ?? json['cheque_number'] ?? json['chequeNo'] ?? json['cheque_no'])?.toString().trim() ?? '',
        bankName: (json['bankName'] ?? json['bank_name'] ?? json['bank'])?.toString().trim() ?? '',
        chequeDate: _parseDate(json['chequeDate'] ?? json['cheque_date']),
        chequeAmount: _parseAmount(json['chequeAmount'] ?? json['cheque_amount'] ?? finalAmt),
        status: ChequeStatus.values.firstWhere(
          (s) => s.name.toLowerCase() == (json['chequeStatus'] ?? json['cheque_status'] ?? json['status'])?.toString().toLowerCase(),
          orElse: () => ChequeStatus.pending,
        ),
      );
    }

    final paymentOptStr = (json['paymentOption'] ?? json['payment_option'] ?? json['mode'] ?? json['paymentMode'])?.toString().toLowerCase().trim();
    final paymentOption = paymentOptStr == 'cheque' ? PaymentOption.cheque : PaymentOption.cash;

    final dueDateRaw = json['paymentDueDate'] ?? json['payment_due_date'] ?? json['dueDate'] ?? json['due_date'];
    final paymentDueDate = dueDateRaw != null ? _parseDate(dueDateRaw) : null;

    final notes = (json['notes'] ?? json['note'] ?? json['remarks'] ?? json['remark'] ?? json['description'])?.toString().trim() ?? '';

    return ChallanEntry(
      id: id,
      date: _parseDate(json['date'] ?? json['createdAt'] ?? json['created_at']),
      challanNo: rawChallanNo,
      partyId: rawPartyId,
      partyName: rawPartyName,
      designNo: rawDesignNo,
      challanAmount: parsedChallanAmt,
      discountAmount: parsedDiscountAmt,
      finalAmount: finalAmt,
      paidAmount: paidAmt,
      gstBillNo: rawGstBillNo,
      gstAmount: parsedGstAmt,
      paymentOption: paymentOption,
      isCashPaid: isCashPaidVal,
      chequeDetails: cheque,
      paymentDueDate: paymentDueDate,
      notes: notes,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      createdBy: (json['createdBy'] ?? json['created_by'])?.toString().trim() ?? 'OM MAVTAR',
      lastModifiedBy: (json['lastModifiedBy'] ?? json['last_modified_by'])?.toString().trim(),
      lastModifiedAt: (json['lastModifiedAt'] ?? json['last_modified_at']) != null ? _parseDate(json['lastModifiedAt'] ?? json['last_modified_at']) : null,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true || json['isDeleted']?.toString() == 'true',
      deletedAt: (json['deletedAt'] ?? json['deleted_at']) != null ? _parseDate(json['deletedAt'] ?? json['deleted_at']) : null,
      deletedBy: (json['deletedBy'] ?? json['deleted_by'])?.toString().trim(),
    );
  }

  ChallanEntry copyWith({
    String? id,
    DateTime? date,
    String? challanNo,
    String? partyId,
    String? partyName,
    String? designNo,
    double? challanAmount,
    double? discountAmount,
    double? finalAmount,
    double? paidAmount,
    String? gstBillNo,
    double? gstAmount,
    PaymentOption? paymentOption,
    bool? isCashPaid,
    ChequeDetails? chequeDetails,
    DateTime? paymentDueDate,
    bool clearPaymentDueDate = false,
    String? notes,
    String? createdBy,
    String? lastModifiedBy,
    DateTime? lastModifiedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearDeletedAt = false,
  }) {
    return ChallanEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      challanNo: challanNo ?? this.challanNo,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      designNo: designNo ?? this.designNo,
      challanAmount: challanAmount ?? this.challanAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      finalAmount: finalAmount ?? this.finalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      gstBillNo: gstBillNo ?? this.gstBillNo,
      gstAmount: gstAmount ?? this.gstAmount,
      paymentOption: paymentOption ?? this.paymentOption,
      isCashPaid: isCashPaid ?? this.isCashPaid,
      chequeDetails: chequeDetails ?? this.chequeDetails,
      paymentDueDate: clearPaymentDueDate ? null : (paymentDueDate ?? this.paymentDueDate),
      notes: notes ?? this.notes,
      createdAt: createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }
}

