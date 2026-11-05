enum DayEntryType {
  income,  // Cash In (Aavak)
  expense; // Cash Out (Javak)

  String get label {
    switch (this) {
      case DayEntryType.income:
        return 'Income (Aavak / In)';
      case DayEntryType.expense:
        return 'Expense (Javak / Out)';
    }
  }
}

class DayEntry {
  final String id;
  final String title;
  final double amount;
  final DayEntryType type;
  final String category;
  final DateTime date;
  final String note;
  final DateTime createdAt;

  DayEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    this.category = 'General',
    required this.date,
    this.note = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DayEntry.fromJson(Map<String, dynamic> json) {
    return DayEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: DayEntryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DayEntryType.expense,
      ),
      category: json['category'] as String? ?? 'General',
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
