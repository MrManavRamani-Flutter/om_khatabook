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
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    double parseAmount(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return ChequeDetails(
      chequeDate: parseDate(json['chequeDate']),
      chequeNo: json['chequeNo']?.toString().trim() ?? '',
      bankName: json['bankName']?.toString().trim() ?? '',
      chequeAmount: parseAmount(json['chequeAmount']),
      status: ChequeStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == json['status']?.toString().toLowerCase(),
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
    return double.tryParse(val.toString()) ?? 0.0;
  }

  static DateTime _parseDate(dynamic val, {DateTime? fallback}) {
    if (val == null) return fallback ?? DateTime.now();
    if (val is DateTime) return val;
    final str = val.toString().trim();
    if (str.isEmpty) return fallback ?? DateTime.now();
    return DateTime.tryParse(str) ?? (fallback ?? DateTime.now());
  }

  factory ChallanEntry.fromJson(Map<String, dynamic> json) {
    final finalAmt = _parseAmount(json['finalAmount'] ?? json['totalAmount'] ?? json['amount']);
    final isCashPaidVal = json['isCashPaid'] is bool
        ? json['isCashPaid'] as bool
        : (json['isCashPaid']?.toString().toLowerCase() == 'true' || json['isCashPaid'] == null);

    final paidAmt = json['paidAmount'] != null
        ? _parseAmount(json['paidAmount'])
        : (isCashPaidVal ? finalAmt : 0.0);

    final rawId = json['id']?.toString().trim();
    final id = (rawId != null && rawId.isNotEmpty)
        ? rawId
        : 'challan_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 8)}';

    ChequeDetails? cheque;
    if (json['chequeDetails'] != null && json['chequeDetails'] is Map) {
      try {
        cheque = ChequeDetails.fromJson(
            Map<String, dynamic>.from(json['chequeDetails'] as Map));
      } catch (_) {
        cheque = null;
      }
    }

    return ChallanEntry(
      id: id,
      date: _parseDate(json['date']),
      challanNo: json['challanNo']?.toString().trim() ?? '',
      partyId: json['partyId']?.toString().trim() ?? '',
      partyName: json['partyName']?.toString().trim() ?? '',
      challanAmount: _parseAmount(json['challanAmount']),
      discountAmount: _parseAmount(json['discountAmount'] ?? json['discount']),
      finalAmount: finalAmt,
      paidAmount: paidAmt,
      gstBillNo: json['gstBillNo']?.toString().trim() ?? '',
      gstAmount: _parseAmount(json['gstAmount']),
      paymentOption: PaymentOption.values.firstWhere(
        (e) => e.name.toLowerCase() == json['paymentOption']?.toString().toLowerCase(),
        orElse: () => PaymentOption.cash,
      ),
      isCashPaid: isCashPaidVal,
      chequeDetails: cheque,
      paymentDueDate: json['paymentDueDate'] != null ? _parseDate(json['paymentDueDate']) : null,
      notes: json['notes']?.toString().trim() ?? '',
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString().trim() ?? 'system',
      lastModifiedBy: json['lastModifiedBy']?.toString().trim(),
      lastModifiedAt: json['lastModifiedAt'] != null ? _parseDate(json['lastModifiedAt']) : null,
      isDeleted: json['isDeleted'] == true || json['isDeleted']?.toString() == 'true',
      deletedAt: json['deletedAt'] != null ? _parseDate(json['deletedAt']) : null,
      deletedBy: json['deletedBy']?.toString().trim(),
    );
  }

  ChallanEntry copyWith({
    String? id,
    DateTime? date,
    String? challanNo,
    String? partyId,
    String? partyName,
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

