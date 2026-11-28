import 'package:uuid/uuid.dart';
import 'income_expense_entry.dart';

class LedgerCategoryItem {
  final String id;
  final String name; // e.g., "Electricity Bill", "Staff Salary / Wages", "Om Kiran (Sales)"
  final EntryType type; // expense or income
  final String category; // e.g., "Utility & Bills", "Salary & Wages", "Party Sales"
  final double defaultAmount; // optional default amount, 0.0 if variable
  final DateTime createdAt;

  LedgerCategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    this.defaultAmount = 0.0,
    required this.createdAt,
  });

  bool get isExpense => type == EntryType.expense;
  bool get isIncome => type == EntryType.income;

  LedgerCategoryItem copyWith({
    String? id,
    String? name,
    EntryType? type,
    String? category,
    double? defaultAmount,
    DateTime? createdAt,
  }) {
    return LedgerCategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category ?? this.category,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'category': category,
      'defaultAmount': defaultAmount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LedgerCategoryItem.fromJson(Map<String, dynamic> json) {
    return LedgerCategoryItem(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '',
      type: json['type'] == 'income' ? EntryType.income : EntryType.expense,
      category: json['category'] as String? ?? (json['type'] == 'income' ? 'Party Sales' : 'General'),
      defaultAmount: (json['defaultAmount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Default initial preset items
  static List<LedgerCategoryItem> defaultItems() {
    final now = DateTime(2026, 1, 1);
    return [
      // EXPENSES
      LedgerCategoryItem(
        id: 'cat_exp_1',
        name: 'Electricity Bill',
        type: EntryType.expense,
        category: 'Utility & Bills',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_exp_2',
        name: 'Staff Salary / Wages',
        type: EntryType.expense,
        category: 'Salary & Wages',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_exp_3',
        name: 'Office Rent',
        type: EntryType.expense,
        category: 'Rent & Maintenance',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_exp_4',
        name: 'Refreshments & Tea',
        type: EntryType.expense,
        category: 'Office Supplies',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_exp_5',
        name: 'Transportation & Travel',
        type: EntryType.expense,
        category: 'Travel & Logistics',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_exp_6',
        name: 'Stationary & Printing',
        type: EntryType.expense,
        category: 'Office Supplies',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_exp_7',
        name: 'Packing Materials',
        type: EntryType.expense,
        category: 'Packaging',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_exp_8',
        name: 'Repairs & Maintenance',
        type: EntryType.expense,
        category: 'Maintenance',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_exp_9',
        name: 'Other Operating Expenses',
        type: EntryType.expense,
        category: 'Miscellaneous',
        defaultAmount: 0.0,
        createdAt: now,
      ),

      // INCOME
      LedgerCategoryItem(
        id: 'cat_inc_1',
        name: 'Om Kiran (Sales)',
        type: EntryType.income,
        category: 'Party Sales',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_inc_2',
        name: 'Pradip (Sales)',
        type: EntryType.income,
        category: 'Party Sales',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_inc_3',
        name: 'Direct Cash Sales',
        type: EntryType.income,
        category: 'Sales Revenue',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_inc_4',
        name: 'Commission Received',
        type: EntryType.income,
        category: 'Commission',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_inc_5',
        name: 'Interest Received',
        type: EntryType.income,
        category: 'Other Income',
        defaultAmount: 0.0,
        createdAt: now,
      ),
      LedgerCategoryItem(
        id: 'cat_inc_6',
        name: 'Other Business Income',
        type: EntryType.income,
        category: 'Miscellaneous',
        defaultAmount: 0.0,
        createdAt: now,
      ),
    ];
  }
}

