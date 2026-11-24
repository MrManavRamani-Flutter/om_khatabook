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

  static double _parseAmount(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final clean = val.toString().replaceAll('₹', '').replaceAll(',', '').replaceAll('Rs.', '').replaceAll(' ', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }

  factory IncomeExpenseEntry.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? json['entryType'])?.toString().toLowerCase().trim();
    final type = typeStr == 'income' ? EntryType.income : EntryType.expense;

    final parsedDate = _parseDate(json['date'] ?? json['createdAt'] ?? json['created_at']);
    final parsedCreated = _parseDate(json['createdAt'] ?? json['created_at'], fallback: parsedDate);
    final amt = _parseAmount(json['amount'] ?? json['amt'] ?? json['total']);

    final id = json['id']?.toString().trim();
    final particular = (json['particular'] ?? json['particulars'] ?? json['description'] ?? json['title'] ?? json['item'])?.toString().trim() ?? 'Particulars';
    final notes = (json['notes'] ?? json['note'] ?? json['remark'] ?? json['remarks'] ?? '')?.toString().trim() ?? '';
    final category = (json['category'] ?? json['group'] ?? json['cat'])?.toString().trim() ?? (type == EntryType.income ? 'Income' : 'Expense');
    final paymentMode = (json['paymentMode'] ?? json['payment_mode'] ?? json['mode'])?.toString().trim() ?? 'Cash';

    return IncomeExpenseEntry(
      id: (id != null && id.isNotEmpty) ? id : 'entry_${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4().substring(0, 6)}',
      type: type,
      date: parsedDate,
      particular: particular,
      amount: amt,
      category: category,
      paymentMode: paymentMode,
      notes: notes,
      createdAt: parsedCreated,
      createdBy: (json['createdBy'] ?? json['created_by'])?.toString().trim() ?? 'OM MAVTAR',
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
    );
  }
}

