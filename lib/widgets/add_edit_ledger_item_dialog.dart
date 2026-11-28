import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/income_expense_entry.dart';
import '../models/ledger_category_item.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';

class AddEditLedgerItemDialog extends StatefulWidget {
  final LedgerCategoryItem? itemToEdit;
  final EntryType defaultType;

  const AddEditLedgerItemDialog({
    super.key,
    this.itemToEdit,
    this.defaultType = EntryType.expense,
  });

  @override
  State<AddEditLedgerItemDialog> createState() => _AddEditLedgerItemDialogState();
}

class _AddEditLedgerItemDialogState extends State<AddEditLedgerItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _categoryController;
  late TextEditingController _amountController;
  late EntryType _type;

  static const List<String> _expenseCategorySuggestions = [
    'Utility & Bills',
    'Salary & Wages',
    'Rent & Maintenance',
    'Office Supplies',
    'Travel & Logistics',
    'Packaging',
    'Maintenance',
    'Tea & Refreshments',
    'Marketing & Ads',
    'Miscellaneous',
  ];

  static const List<String> _incomeCategorySuggestions = [
    'Party Sales',
    'Sales Revenue',
    'Commission',
    'Other Income',
    'Interest Received',
    'Rental Income',
    'Miscellaneous',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _type = item?.type ?? widget.defaultType;
    _nameController = TextEditingController(text: item?.name ?? '');
    _categoryController = TextEditingController(
      text: item?.category ?? (_type == EntryType.expense ? 'Utility & Bills' : 'Party Sales'),
    );
    _amountController = TextEditingController(
      text: (item != null && item.defaultAmount > 0) ? item.defaultAmount.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final category = _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim();
    final amtText = _amountController.text.trim();
    final defaultAmount = double.tryParse(amtText) ?? 0.0;

    final provider = context.read<ChallanProvider>();

    if (widget.itemToEdit == null) {
      final newItem = LedgerCategoryItem(
        id: 'cat_${const Uuid().v4()}',
        name: name,
        type: _type,
        category: category,
        defaultAmount: defaultAmount,
        createdAt: DateTime.now(),
      );
      provider.addLedgerCategoryItem(newItem);
    } else {
      final updated = widget.itemToEdit!.copyWith(
        name: name,
        type: _type,
        category: category,
        defaultAmount: defaultAmount,
      );
      provider.updateLedgerCategoryItem(updated);
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.itemToEdit != null;
    final isExpense = _type == EntryType.expense;
    final accentColor = isExpense ? const Color(0xFFE11D48) : const Color(0xFF059669);
    final categorySuggestions = isExpense ? _expenseCategorySuggestions : _incomeCategorySuggestions;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isExpense ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isEdit ? 'Edit Ledger Item' : 'Add New Ledger Item',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TYPE TOGGLE (EXPENSE / INCOME)
                SegmentedButton<EntryType>(
                  segments: const [
                    ButtonSegment(
                      value: EntryType.expense,
                      label: Text('Expense Item'),
                      icon: Icon(Icons.arrow_upward_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: EntryType.income,
                      label: Text('Income Item'),
                      icon: Icon(Icons.arrow_downward_rounded, size: 16),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (newSet) {
                    setState(() {
                      _type = newSet.first;
                      if (_categoryController.text.trim().isEmpty ||
                          _categoryController.text == 'Utility & Bills' ||
                          _categoryController.text == 'Party Sales') {
                        _categoryController.text =
                            _type == EntryType.expense ? 'Utility & Bills' : 'Party Sales';
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),

                // ITEM NAME / PARTICULAR
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Item Name / Particular *',
                    hintText: isExpense ? 'e.g. Electricity Bill, Tea & Snacks' : 'e.g. Scrap Sales, Commission',
                    prefixIcon: const Icon(Icons.label_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter item name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // CATEGORY GROUP
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: 'Category Group',
                    hintText: isExpense ? 'e.g. Utility & Bills' : 'e.g. Party Sales',
                    prefixIcon: const Icon(Icons.folder_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),

                // CATEGORY SUGGESTIONS CHIPS
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: categorySuggestions.take(6).map((cat) {
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(cat, style: const TextStyle(fontSize: 10.5)),
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      onPressed: () {
                        setState(() {
                          _categoryController.text = cat;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // OPTIONAL DEFAULT AMOUNT
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Default Amount (Optional)',
                    hintText: '0.00 (leave empty if amount varies)',
                    prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: _save,
          child: Text(isEdit ? 'Save Changes' : 'Add Item'),
        ),
      ],
    );
  }
}

