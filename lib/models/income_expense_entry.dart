import 'package:uuid/uuid.dart';

enum EntryType {
  income,
  expense,
}

class IncomeExpenseEntry {
  final String id;
  final EntryType type; // income or expense
  final DateTime date;
  final String particular; // Particulars (e.g., "Electricity Bill", "Staff Salary", "Om Kiran", "Office Rent")
  final double amount; // Amount in INR
  final String category; // Category (e.g. "Electricity", "Salary", "Rent", "Office", "Party Payment")
  final String paymentMode; // "Cash", "Cheque", "Online / UPI", "Bank Transfer"
  final String notes;
  final DateTime createdAt;
  final String createdBy;
  final bool isDeleted;

  IncomeExpenseEntry({
    required this.id,
    required this.type,
    required this.date,
    required this.particular,
    required this.amount,
    this.category = 'General',
    this.paymentMode = 'Cash',
    this.notes = '',
    required this.createdAt,
    this.createdBy = 'OM MAVTAR',
    this.isDeleted = false,
  });

  bool get isExpense => type == EntryType.expense;
  bool get isIncome => type == EntryType.income;

  IncomeExpenseEntry copyWith({
    String? id,
    EntryType? type,
    DateTime? date,
    String? particular,
    double? amount,
    String? category,
    String? paymentMode,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
    bool? isDeleted,
  }) {
    return IncomeExpenseEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      particular: particular ?? this.particular,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMode: paymentMode ?? this.paymentMode,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'date': date.toIso8601String(),
      'particular': particular,
      'amount': amount,
      'category': category,
      'paymentMode': paymentMode,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
    };
  }

  factory IncomeExpenseEntry.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type']?.toString().toLowerCase();
    final type = typeStr == 'income' ? EntryType.income : EntryType.expense;

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['date'].toString());
    } catch (_) {
      parsedDate = DateTime.now();
    }

    DateTime parsedCreated;
    try {
      parsedCreated = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : parsedDate;
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    double amt = 0.0;
    if (json['amount'] is num) {
      amt = (json['amount'] as num).toDouble();
    } else if (json['amount'] != null) {
      amt = double.tryParse(json['amount'].toString()) ?? 0.0;
    }

    final id = json['id']?.toString().trim();

    return IncomeExpenseEntry(
      id: (id != null && id.isNotEmpty) ? id : 'entry_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 6)}',
      type: type,
      date: parsedDate,
      particular: json['particular']?.toString().trim() ?? 'Particulars',
      amount: amt,
      category: json['category']?.toString().trim() ?? 'General',
      paymentMode: json['paymentMode']?.toString().trim() ?? 'Cash',
      notes: json['notes']?.toString().trim() ?? '',
      createdAt: parsedCreated,
      createdBy: json['createdBy']?.toString().trim() ?? 'OM MAVTAR',
      isDeleted: json['isDeleted'] == true,
    );
  }
}

