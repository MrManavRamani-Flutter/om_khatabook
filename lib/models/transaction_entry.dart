enum TransactionType {
  gave, // You gave money/goods (Maine diye / Udhar diya) - Red
  got;  // You got money/goods (Mujhe mile / Jama hua) - Green

  String get label {
    switch (this) {
      case TransactionType.gave:
        return 'You Gave (Maine Diye)';
      case TransactionType.got:
        return 'You Got (Mujhe Mile)';
    }
  }

  String get shortLabel {
    switch (this) {
      case TransactionType.gave:
        return 'GAVE';
      case TransactionType.got:
        return 'GOT';
    }
  }
}

enum PaymentMode {
  cash,
  upi,
  bankTransfer,
  cheque;

  String get displayName {
    switch (this) {
      case PaymentMode.cash:
        return 'Cash';
      case PaymentMode.upi:
        return 'UPI / QR';
      case PaymentMode.bankTransfer:
        return 'Bank Transfer';
      case PaymentMode.cheque:
        return 'Cheque';
    }
  }
}

class TransactionEntry {
  final String id;
  final String partyId;
  final double amount;
  final TransactionType type;
  final PaymentMode paymentMode;
  final DateTime date;
  final String description;
  final String billNumber;
  final DateTime createdAt;

  TransactionEntry({
    required this.id,
    required this.partyId,
    required this.amount,
    required this.type,
    this.paymentMode = PaymentMode.cash,
    required this.date,
    this.description = '',
    this.billNumber = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'partyId': partyId,
      'amount': amount,
      'type': type.name,
      'paymentMode': paymentMode.name,
      'date': date.toIso8601String(),
      'description': description,
      'billNumber': billNumber,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TransactionEntry.fromJson(Map<String, dynamic> json) {
    return TransactionEntry(
      id: json['id'] as String,
      partyId: json['partyId'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.got,
      ),
      paymentMode: PaymentMode.values.firstWhere(
        (e) => e.name == json['paymentMode'],
        orElse: () => PaymentMode.cash,
      ),
      date: DateTime.parse(json['date'] as String),
      description: json['description'] as String? ?? '',
      billNumber: json['billNumber'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  TransactionEntry copyWith({
    double? amount,
    TransactionType? type,
    PaymentMode? paymentMode,
    DateTime? date,
    String? description,
    String? billNumber,
  }) {
    return TransactionEntry(
      id: id,
      partyId: partyId,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      paymentMode: paymentMode ?? this.paymentMode,
      date: date ?? this.date,
      description: description ?? this.description,
      billNumber: billNumber ?? this.billNumber,
      createdAt: createdAt,
    );
  }
}
