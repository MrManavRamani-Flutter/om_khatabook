import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/income_expense_entry.dart';
import '../models/ledger_category_item.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/password_confirmation_dialog.dart';
import '../services/whatsapp_share_service.dart';

class NetProfitLossView extends StatefulWidget {
  const NetProfitLossView({super.key});

  @override
  State<NetProfitLossView> createState() => _NetProfitLossViewState();
}

class _NetProfitLossViewState extends State<NetProfitLossView> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _monthFormat = DateFormat('MMM yyyy');

  // Month & Item filtering state
  // If empty -> All Months mode
  Set<String> _selectedMonthKeys = {};
  String _activePreset = 'all'; // 'all', 'current', 'last_2', 'last_3', 'custom'
  String? _selectedParticularFilter; // null = All Items

  @override
  void initState() {
    super.initState();
    // Default to 'all' as requested by user ("all month ka bhi dekha shake")
    _selectedMonthKeys = {};
    _activePreset = 'all';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setPreset(String preset, ChallanProvider provider) {
    final available = provider.availableProfitLossMonths;
    setState(() {
      _activePreset = preset;
      if (preset == 'all') {
        _selectedMonthKeys.clear();
      } else if (preset == 'current') {
        final now = DateTime.now();
        final currentKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
        _selectedMonthKeys = {currentKey};
      } else if (preset == 'last_2') {
        _selectedMonthKeys = available.take(2).toSet();
      } else if (preset == 'last_3') {
        _selectedMonthKeys = available.take(3).toSet();
      }
    });
  }

  String _formatMonthKey(String key) {
    try {
      final parts = key.split('-');
      if (parts.length == 2) {
        final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        return _monthFormat.format(date);
      }
    } catch (_) {}
    return key;
  }

  void _showMultiMonthPickerDialog(BuildContext context, ChallanProvider provider) {
    final available = provider.availableProfitLossMonths;
    final tempSelection = Set<String>.from(_selectedMonthKeys);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.calendar_month, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Select Months (Filter)'),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select 1, 2, 3 or more months to analyze Income, Expenses, and Net Profit / Loss.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.select_all, size: 16),
                        label: const Text('Select All'),
                        onPressed: () {
                          setDialogState(() {
                            tempSelection.clear();
                            tempSelection.addAll(available);
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Clear Selection'),
                        onPressed: () {
                          setDialogState(() {
                            tempSelection.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final key = available[index];
                        final isChecked = tempSelection.contains(key);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(
                            _formatMonthKey(key),
                            style: TextStyle(
                              fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                              color: isChecked ? AppColors.primary : null,
                            ),
                          ),
                          subtitle: Text(key, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          value: isChecked,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                tempSelection.add(key);
                              } else {
                                tempSelection.remove(key);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _selectedMonthKeys = tempSelection;
                    _activePreset = tempSelection.isEmpty ? 'all' : 'custom';
                  });
                },
                child: const Text('Apply Filter'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openNoteDialog(BuildContext context, IncomeExpenseEntry entry) {
    final provider = context.read<ChallanProvider>();
    final isExpense = entry.isExpense;
    final accentColor = isExpense ? const Color(0xFFE11D48) : const Color(0xFF059669);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noteController = TextEditingController(text: entry.notes);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final currentNote = noteController.text.trim();
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.note_alt, size: 20, color: Colors.amber),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Entry Note & Remarks 📝',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${entry.particular} • ${Formatters.currency(entry.amount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 5),
                          Text(_dateFormat.format(entry.date), style: const TextStyle(fontSize: 11.5)),
                          const SizedBox(width: 12),
                          Icon(Icons.category_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              entry.category,
                              style: const TextStyle(fontSize: 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              entry.paymentMode,
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: accentColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text(
                          'Note Content:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (currentNote.isNotEmpty)
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: noteController.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Note copied to clipboard!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy, size: 13, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 5,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Enter note, calculation breakdown, or remarks here...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save Note'),
                onPressed: () async {
                  final newNote = noteController.text.trim();
                  final updated = entry.copyWith(notes: newNote);
                  await provider.updateIncomeExpenseEntry(updated);
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Note saved successfully!'),
                        backgroundColor: AppColors.primary,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _openAddEditEntryDialog(
    BuildContext context, {
    required EntryType type,
    IncomeExpenseEntry? entryToEdit,
  }) {
    final provider = context.read<ChallanProvider>();
    final isEdit = entryToEdit != null;
    final particularController = TextEditingController(text: entryToEdit?.particular ?? '');
    final amountController = TextEditingController(
        text: entryToEdit != null ? entryToEdit.amount.toStringAsFixed(2) : '');
    final categoryController = TextEditingController(
        text: entryToEdit?.category ?? (type == EntryType.expense ? 'Utility & Bills' : 'Party Sales'));
    final notesController = TextEditingController(text: entryToEdit?.notes ?? '');
    DateTime selectedDate = entryToEdit?.date ?? DateTime.now();
    String paymentMode = entryToEdit?.paymentMode ?? 'Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final isExpense = type == EntryType.expense;
          final accentColor = isExpense ? const Color(0xFFE11D48) : const Color(0xFF059669);
          final dynamicCategoryItems = isExpense
              ? provider.expenseCategoryItems
              : provider.incomeCategoryItems;

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
                    isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isEdit
                      ? (isExpense ? 'Edit Expense' : 'Edit Income')
                      : (isExpense ? 'Add New Expense' : 'Add New Income'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LOCKED PREDEFINED ITEM SELECTOR (NO FREE TEXT TYPING)
                    if (particularController.text.trim().isEmpty)
                      DropdownButtonFormField<LedgerCategoryItem>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: isExpense ? 'Select Expense Item *' : 'Select Income Item *',
                          prefixIcon: const Icon(Icons.category_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                        ),
                        hint: Text(
                          isExpense ? 'Choose an expense item...' : 'Choose an income item...',
                          style: const TextStyle(fontSize: 13),
                        ),
                        items: dynamicCategoryItems.map((item) {
                          return DropdownMenuItem<LedgerCategoryItem>(
                            value: item,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(ctx).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (item) {
                          if (item != null) {
                            setDialogState(() {
                              particularController.text = item.name;
                              categoryController.text = item.category;
                              if (item.defaultAmount > 0) {
                                amountController.text = item.defaultAmount.toStringAsFixed(2);
                              }
                            });
                          }
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentColor.withValues(alpha: 0.45), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, size: 18, color: accentColor),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isExpense ? 'Selected Expense Item' : 'Selected Income Item',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    particularController.text,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Change / Clear Selection',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setDialogState(() {
                                  particularController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 14),

                    // AMOUNT
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount (₹) *',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // DATE & PAYMENT MODE ROW
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date',
                                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(_dateFormat.format(selectedDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: paymentMode,
                            decoration: InputDecoration(
                              labelText: 'Payment Mode',
                              prefixIcon: const Icon(Icons.payment, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                              DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                              DropdownMenuItem(value: 'Online / UPI', child: Text('UPI / Online')),
                              DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => paymentMode = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // CATEGORY
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        hintText: 'e.g. Utility, Salary, Rent, Sales',
                        prefixIcon: const Icon(Icons.category_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // NOTES / DETAILS
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Notes / Remarks 📝 (Breakdown, Details, Ref)',
                        hintText: 'e.g. BEADS=571140/400=370598, bill breakdown, vendor ref...',
                        prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: Text(isEdit ? 'Save Changes' : (isExpense ? 'Save Expense' : 'Save Income')),
                onPressed: () async {
                  final part = particularController.text.trim();
                  final amt = double.tryParse(amountController.text.trim()) ?? 0.0;

                  if (part.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter Particulars / Details')),
                    );
                    return;
                  }
                  if (amt <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount greater than 0')),
                    );
                    return;
                  }

                  if (isEdit) {
                    final confirmed = await promptPasswordConfirmation(
                      context,
                      title: isExpense ? 'Confirm Edit Expense' : 'Confirm Edit Income',
                      message: 'Enter password to confirm updating "$part" (${Formatters.currency(amt)}).',
                      actionLabel: 'Save Changes',
                      icon: isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                      iconColor: accentColor,
                    );
                    if (!confirmed) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password verification cancelled. Your entry details are preserved.'),
                            backgroundColor: AppColors.primaryDark,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      return;
                    }

                    final updated = entryToEdit.copyWith(
                      particular: part,
                      amount: amt,
                      date: selectedDate,
                      category: categoryController.text.trim(),
                      paymentMode: paymentMode,
                      notes: notesController.text.trim(),
                    );
                    await provider.updateIncomeExpenseEntry(updated);
                  } else {
                    final confirmed = await promptPasswordConfirmation(
                      context,
                      title: isExpense ? 'Confirm Add Expense' : 'Confirm Add Income',
                      message: 'Enter password to confirm adding "$part" (${Formatters.currency(amt)}).',
                      actionLabel: isExpense ? 'Save Expense' : 'Save Income',
                      icon: isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                      iconColor: accentColor,
                    );
                    if (!confirmed) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Password verification cancelled. Your entry details are preserved.'),
                            backgroundColor: AppColors.primaryDark,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      return;
                    }

                    final newEntry = IncomeExpenseEntry(
                      id: 'entry_${DateTime.now().millisecondsSinceEpoch}',
                      type: type,
                      date: selectedDate,
                      particular: part,
                      amount: amt,
                      category: categoryController.text.trim().isNotEmpty
                          ? categoryController.text.trim()
                          : (isExpense ? 'Utility & Bills' : 'Party Sales'),
                      paymentMode: paymentMode,
                      notes: notesController.text.trim(),
                      createdAt: DateTime.now(),
                      createdBy: 'OM MAVTAR',
                    );
                    await provider.addIncomeExpenseEntry(newEntry);
                  }

                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteEntry(BuildContext context, IncomeExpenseEntry entry) async {
    final confirmed = await promptPasswordConfirmation(
      context,
      title: 'Confirm Delete ${entry.isExpense ? "Expense" : "Income"}',
      message: 'Enter password to confirm deleting "${entry.particular}" (${Formatters.currency(entry.amount)}).',
      actionLabel: 'Delete',
      icon: Icons.delete_outline,
      iconColor: AppColors.warningText,
    );

    if (!confirmed || !context.mounted) return;

    await context.read<ChallanProvider>().deleteIncomeExpenseEntry(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 850;

    // Compute Profit & Loss with active month filter, search, and particular item filter
    final rawCalc = provider.computeProfitLoss(
      selectedMonthKeys: _selectedMonthKeys,
      searchQuery: _searchController.text,
    );

    final ProfitLossCalculation calc;
    if (_selectedParticularFilter != null && _selectedParticularFilter!.isNotEmpty) {
      final q = _selectedParticularFilter!.trim().toLowerCase();
      final filteredExp = rawCalc.expenses.where((e) => e.particular.trim().toLowerCase() == q).toList();
      final filteredInc = rawCalc.incomes.where((e) => e.particular.trim().toLowerCase() == q).toList();
      final totExp = filteredExp.fold(0.0, (s, e) => s + e.amount);
      final totInc = filteredInc.fold(0.0, (s, e) => s + e.amount);
      final net = totInc - totExp;
      calc = ProfitLossCalculation(
        expenses: filteredExp,
        incomes: filteredInc,
        totalExpenses: totExp,
        totalIncome: totInc,
        netAmount: net,
        isProfit: net >= 0,
      );
    } else {
      calc = rawCalc;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER BAR
            _buildHeader(context, provider, isMobile),
            const SizedBox(height: 16),

            // MONTH FILTER & ACTIONS TOOLBAR
            _buildFilterToolbar(context, provider, calc, isDark, isMobile),
            const SizedBox(height: 16),

            // TOP 3 KPI SUMMARY CARDS
            _buildSummaryCards(context, calc, isDark, isMobile),
            const SizedBox(height: 20),

            // T-LEDGER: 2-COLUMN VIEW (EXPENSES ON LEFT IN RED, INCOME ON RIGHT IN GREEN)
            if (isMobile)
              Column(
                children: [
                  _buildExpensesCard(context, calc, isDark, isMobile),
                  const SizedBox(height: 16),
                  _buildIncomeCard(context, calc, isDark, isMobile),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildExpensesCard(context, calc, isDark, isMobile)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildIncomeCard(context, calc, isDark, isMobile)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ChallanProvider provider, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Net Profit - Loss Ledger',
                    style: TextStyle(
                      fontSize: isMobile ? 19 : 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'FINANCIAL',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    backgroundColor: Color(0x1500A86B),
                    side: BorderSide(color: Color(0x3300A86B)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Track Income & Collections vs Operating Expenses',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterToolbar(
    BuildContext context,
    ChallanProvider provider,
    ProfitLossCalculation calc,
    bool isDark,
    bool isMobile,
  ) {
    String filterLabel;
    if (_activePreset == 'all' || _selectedMonthKeys.isEmpty) {
      filterLabel = 'All Months (All Time)';
    } else if (_selectedMonthKeys.length == 1) {
      filterLabel = '1 Month: ${_formatMonthKey(_selectedMonthKeys.first)}';
    } else {
      filterLabel = '${_selectedMonthKeys.length} Months: ${_selectedMonthKeys.map(_formatMonthKey).join(', ')}';
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // ALL MONTHS
                  ChoiceChip(
                    label: const Text('All Months'),
                    selected: _activePreset == 'all' || _selectedMonthKeys.isEmpty,
                    onSelected: (_) => _setPreset('all', provider),
                  ),
                  // CURRENT MONTH
                  ChoiceChip(
                    label: const Text('Current Month'),
                    selected: _activePreset == 'current',
                    onSelected: (_) => _setPreset('current', provider),
                  ),
                  // LAST 2 MONTHS
                  ChoiceChip(
                    label: const Text('Last 2 Months'),
                    selected: _activePreset == 'last_2',
                    onSelected: (_) => _setPreset('last_2', provider),
                  ),
                  // LAST 3 MONTHS
                  ChoiceChip(
                    label: const Text('Last 3 Months (Quarter)'),
                    selected: _activePreset == 'last_3',
                    onSelected: (_) => _setPreset('last_3', provider),
                  ),
                  // CUSTOM MULTI-MONTH PICKER
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 16),
                    label: const Text('Select Months...'),
                    backgroundColor: _activePreset == 'custom'
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : null,
                    onPressed: () => _showMultiMonthPickerDialog(context, provider),
                  ),
                  // ITEM / CATEGORY FILTER DROPDOWN (DESKTOP)
                  ActionChip(
                    avatar: Icon(
                      Icons.filter_alt_outlined,
                      size: 16,
                      color: _selectedParticularFilter != null ? AppColors.primary : null,
                    ),
                    label: Text(
                      _selectedParticularFilter ?? 'All Items',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedParticularFilter != null ? FontWeight.bold : FontWeight.normal,
                        color: _selectedParticularFilter != null ? AppColors.primary : null,
                      ),
                    ),
                    backgroundColor: _selectedParticularFilter != null
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : null,
                    onPressed: () => _showItemFilterDialog(context, provider),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ],

            // SEARCH BAR & QUICK ACTION BUTTONS (RESPONSIVE)
            if (isMobile) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search Particulars, Category...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (ctx) {
                      int activeFilters = 0;
                      if (_activePreset != 'all' && _selectedMonthKeys.isNotEmpty) activeFilters++;
                      if (_selectedParticularFilter != null) activeFilters++;
                      return FilledButton.tonalIcon(
                        onPressed: () => _showMobileMonthFilterSheet(context, provider),
                        icon: const Icon(Icons.tune_rounded, size: 17),
                        label: Text(
                          activeFilters > 0 ? 'Filters ($activeFilters)' : 'Filters',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          backgroundColor: activeFilters > 0
                              ? AppColors.primary.withValues(alpha: 0.16)
                              : null,
                          foregroundColor: activeFilters > 0 ? AppColors.primary : null,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _openAddEditEntryDialog(context, type: EntryType.expense),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Income', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _openAddEditEntryDialog(context, type: EntryType.income),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.share, size: 15),
                    label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => WhatsAppShareService.shareProfitLossStatement(context, calc, filterLabel),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search Particulars, Category, or Party...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _openAddEditEntryDialog(context, type: EntryType.expense),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Income', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _openAddEditEntryDialog(context, type: EntryType.income),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share (WhatsApp)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => WhatsAppShareService.shareProfitLossStatement(context, calc, filterLabel),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Period: $filterLabel',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    ProfitLossCalculation calc,
    bool isDark,
    bool isMobile,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // 1. TOTAL INCOME (GREEN)
            SizedBox(
              width: cardWidth,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0x33059669), width: 1.5),
                ),
                elevation: isDark ? 0 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_downward, color: Color(0xFF059669), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL INCOME',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.currency(calc.totalIncome),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                            Text(
                              '${calc.incomes.length} Incomes',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 2. TOTAL EXPENSES (RED)
            SizedBox(
              width: cardWidth,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0x33E11D48), width: 1.5),
                ),
                elevation: isDark ? 0 : 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_upward, color: Color(0xFFE11D48), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL EXPENSES',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE11D48),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.currency(calc.totalExpenses),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE11D48),
                              ),
                            ),
                            Text(
                              '${calc.expenses.length} Expenses',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. NET PROFIT / LOSS
            SizedBox(
              width: cardWidth,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: calc.isProfit ? const Color(0xFF059669) : const Color(0xFFE11D48),
                    width: 2,
                  ),
                ),
                elevation: isDark ? 0 : 2,
                color: calc.isProfit
                    ? (isDark ? const Color(0x1A059669) : const Color(0xFFECFDF5))
                    : (isDark ? const Color(0x1AE11D48) : const Color(0xFFFFF1F2)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: calc.isProfit
                              ? const Color(0xFF059669).withValues(alpha: 0.2)
                              : const Color(0xFFE11D48).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          calc.isProfit ? Icons.trending_up : Icons.trending_down,
                          color: calc.isProfit ? const Color(0xFF059669) : const Color(0xFFE11D48),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  calc.isProfit ? 'NET PROFIT' : 'NET LOSS',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: calc.isProfit ? const Color(0xFF059669) : const Color(0xFFE11D48),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (calc.isProfit ? '+ ' : '- ') + Formatters.currency(calc.netAmount),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: calc.isProfit ? const Color(0xFF059669) : const Color(0xFFE11D48),
                              ),
                            ),
                            Text(
                              calc.isProfit
                                  ? 'Surplus (Profit)'
                                  : 'Deficit (Loss)',
                              style: TextStyle(
                                fontSize: 11,
                                color: calc.isProfit ? const Color(0xFF047857) : const Color(0xFFBE123C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- EXPENSES COLUMN CARD (LEFT - RED) ---
  Widget _buildExpensesCard(BuildContext context, ProfitLossCalculation calc, bool isDark, bool isMobile) {
    const redColor = Color(0xFFE11D48);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: redColor.withValues(alpha: 0.3), width: 1.5),
      ),
      elevation: isDark ? 0 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER (EXPENSES - RED COLOR)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: redColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: redColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_upward, color: redColor, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expenses',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: redColor),
                      ),
                      Text('Operating Costs', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: redColor,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  onPressed: () => _openAddEditEntryDialog(context, type: EntryType.expense),
                ),
              ],
            ),
          ),

          // TABLE HEADER (DESKTOP ONLY)
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade100,
              child: Row(
                children: [
                  const SizedBox(width: 32, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(flex: 3, child: Text('Particulars / Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text('Amount (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 82, child: Text('Action', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // ROWS LIST
          if (calc.expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text('No expenses recorded for this period.', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: calc.expenses.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = calc.expenses[index];
                if (isMobile) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: redColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: redColor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.particular,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${e.category} • ${_dateFormat.format(e.date)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (e.notes.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                InkWell(
                                  onTap: () => _openNoteDialog(context, e),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sticky_note_2_outlined, size: 11, color: Colors.amber),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          e.notes.trim(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.currency(e.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: redColor,
                          ),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (val) {
                            if (val == 'note') _openNoteDialog(context, e);
                            if (val == 'edit') {
                              _openAddEditEntryDialog(context, type: EntryType.expense, entryToEdit: e);
                            }
                            if (val == 'delete') _confirmDeleteEntry(context, e);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'note',
                              child: Row(
                                children: [
                                  Icon(
                                    e.notes.trim().isNotEmpty ? Icons.note_alt : Icons.note_alt_outlined,
                                    size: 18,
                                    color: Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(e.notes.trim().isNotEmpty ? 'View / Edit Note' : 'Add Note'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 10),
                                  Text('Edit Expense'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  SizedBox(width: 10),
                                  Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.particular,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              e.category,
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (e.notes.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: () => _openNoteDialog(context, e),
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sticky_note_2_outlined, size: 11, color: Colors.amber),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        e.notes.trim(),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _dateFormat.format(e.date),
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            Formatters.currency(e.amount),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: redColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 82,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // NOTE 📝 BUTTON
                            InkWell(
                              onTap: () => _openNoteDialog(context, e),
                              borderRadius: BorderRadius.circular(6),
                              child: Tooltip(
                                message: e.notes.trim().isNotEmpty ? 'View Note:\n${e.notes}' : 'Add Note',
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: e.notes.trim().isNotEmpty
                                        ? Colors.amber.withValues(alpha: 0.18)
                                        : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: e.notes.trim().isNotEmpty
                                        ? Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1)
                                        : null,
                                  ),
                                  child: Icon(
                                    e.notes.trim().isNotEmpty ? Icons.note_alt : Icons.note_alt_outlined,
                                    size: 14,
                                    color: e.notes.trim().isNotEmpty
                                        ? Colors.amber.shade700
                                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // EDIT BUTTON
                            InkWell(
                              onTap: () => _openAddEditEntryDialog(
                                context,
                                type: EntryType.expense,
                                entryToEdit: e,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.edit_outlined, size: 14),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // DELETE BUTTON
                            InkWell(
                              onTap: () => _confirmDeleteEntry(context, e),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // FOOTER / TOTAL ROW (CLEAN ACCOUNTING BADGE, NO TEXT UNDERLINE)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: redColor.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(
                top: BorderSide(color: redColor.withValues(alpha: 0.35), width: 1.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 18, color: redColor),
                    SizedBox(width: 8),
                    Text(
                      'Total Expenses',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: redColor),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: redColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: redColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    Formatters.currency(calc.totalExpenses),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: redColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- INCOME COLUMN CARD (RIGHT - GREEN) ---
  Widget _buildIncomeCard(BuildContext context, ProfitLossCalculation calc, bool isDark, bool isMobile) {
    const greenColor = Color(0xFF059669);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: greenColor.withValues(alpha: 0.3), width: 1.5),
      ),
      elevation: isDark ? 0 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER (INCOME - GREEN COLOR)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: greenColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: greenColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_downward, color: greenColor, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Income',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: greenColor),
                      ),
                      Text('Revenue & Collections', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greenColor,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add', style: TextStyle(fontSize: 12)),
                  onPressed: () => _openAddEditEntryDialog(context, type: EntryType.income),
                ),
              ],
            ),
          ),

          // TABLE HEADER (DESKTOP ONLY)
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade100,
              child: Row(
                children: [
                  const SizedBox(width: 32, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(flex: 3, child: Text('Particulars / Party', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(flex: 2, child: Text('Source / Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const Expanded(
                    flex: 2,
                    child: Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text('Amount (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 82, child: Text('Action', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // ROWS LIST
          if (calc.incomes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text('No income recorded for this period.', style: TextStyle(color: Colors.grey, fontSize: 12.5)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: calc.incomes.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = calc.incomes[index];
                final isPartyCollection = e.id.startsWith('party_inc_');

                if (isMobile) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: greenColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: greenColor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.particular,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isPartyCollection ? 'Party Payment' : '${e.category} • ${_dateFormat.format(e.date)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isPartyCollection ? greenColor.withValues(alpha: 0.85) : Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (!isPartyCollection && e.notes.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                InkWell(
                                  onTap: () => _openNoteDialog(context, e),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sticky_note_2_outlined, size: 11, color: Colors.amber),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          e.notes.trim(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.currency(e.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: greenColor,
                          ),
                        ),
                        if (isPartyCollection)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.check_circle_outline, size: 18, color: greenColor),
                          )
                        else
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (val) {
                              if (val == 'note') _openNoteDialog(context, e);
                              if (val == 'edit') {
                                _openAddEditEntryDialog(context, type: EntryType.income, entryToEdit: e);
                              }
                              if (val == 'delete') _confirmDeleteEntry(context, e);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'note',
                                child: Row(
                                  children: [
                                    Icon(
                                      e.notes.trim().isNotEmpty ? Icons.note_alt : Icons.note_alt_outlined,
                                      size: 18,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(e.notes.trim().isNotEmpty ? 'View / Edit Note' : 'Add Note'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18),
                                    SizedBox(width: 10),
                                    Text('Edit Income'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                    SizedBox(width: 10),
                                    Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.particular,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              isMobile
                                  ? (isPartyCollection ? 'Party Payment' : '${e.category} • ${_dateFormat.format(e.date)}')
                                  : (isPartyCollection ? 'Party Challan Payment' : e.category),
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isPartyCollection ? AppColors.primary : Colors.grey,
                                fontWeight: isPartyCollection ? FontWeight.w500 : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isPartyCollection && e.notes.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              InkWell(
                                onTap: () => _openNoteDialog(context, e),
                                borderRadius: BorderRadius.circular(4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.sticky_note_2_outlined, size: 11, color: Colors.amber),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        e.notes.trim(),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isMobile)
                        Expanded(
                          flex: 2,
                          child: Text(
                            isPartyCollection ? 'Challan Ledger' : _dateFormat.format(e.date),
                            style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ),
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            Formatters.currency(e.amount),
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: greenColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 82,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: isPartyCollection
                              ? [
                                  Tooltip(
                                    message: 'Auto-calculated from party receipts',
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: greenColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.check_circle_outline, size: 14, color: greenColor),
                                    ),
                                  ),
                                ]
                              : [
                                  // NOTE 📝 BUTTON
                                  InkWell(
                                    onTap: () => _openNoteDialog(context, e),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Tooltip(
                                      message: e.notes.trim().isNotEmpty ? 'View Note:\n${e.notes}' : 'Add Note 📝',
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: e.notes.trim().isNotEmpty
                                              ? Colors.amber.withValues(alpha: 0.18)
                                              : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                          border: e.notes.trim().isNotEmpty
                                              ? Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1)
                                              : null,
                                        ),
                                        child: Icon(
                                          e.notes.trim().isNotEmpty ? Icons.note_alt : Icons.note_alt_outlined,
                                          size: 14,
                                          color: e.notes.trim().isNotEmpty
                                              ? Colors.amber.shade700
                                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // EDIT BUTTON
                                  InkWell(
                                    onTap: () => _openAddEditEntryDialog(
                                      context,
                                      type: EntryType.income,
                                      entryToEdit: e,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.edit_outlined, size: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // DELETE BUTTON
                                  InkWell(
                                    onTap: () => _confirmDeleteEntry(context, e),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          // FOOTER / TOTAL ROW (CLEAN ACCOUNTING BADGE, NO TEXT UNDERLINE)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: greenColor.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              border: Border(
                top: BorderSide(color: greenColor.withValues(alpha: 0.35), width: 1.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 18, color: greenColor),
                    SizedBox(width: 8),
                    Text(
                      'Total Income',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: greenColor),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: greenColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: greenColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    Formatters.currency(calc.totalIncome),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: greenColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showItemFilterDialog(BuildContext context, ChallanProvider provider) {
    final Set<String> allItemNames = {};
    for (final item in provider.expenseCategoryItems) {
      allItemNames.add(item.name);
    }
    for (final item in provider.incomeCategoryItems) {
      allItemNames.add(item.name);
    }
    for (final e in provider.incomeExpenseEntries) {
      if (e.particular.trim().isNotEmpty) {
        allItemNames.add(e.particular.trim());
      }
    }
    final sortedNames = allItemNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.filter_alt_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Text('Filter by Expense / Income Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.all_inclusive),
                  title: const Text('All Items (Show Everything)', style: TextStyle(fontWeight: FontWeight.bold)),
                  selected: _selectedParticularFilter == null,
                  onTap: () {
                    setState(() => _selectedParticularFilter = null);
                    Navigator.of(ctx).pop();
                  },
                ),
                const Divider(),
                ...sortedNames.map((name) {
                  final isSelected = _selectedParticularFilter?.toLowerCase() == name.toLowerCase();
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.label_outline,
                      size: 18,
                      color: isSelected ? AppColors.primary : Colors.grey,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      setState(() => _selectedParticularFilter = name);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showMobileMonthFilterSheet(BuildContext context, ChallanProvider provider) {
    final Set<String> allItemNames = {};
    for (final item in provider.expenseCategoryItems) {
      allItemNames.add(item.name);
    }
    for (final item in provider.incomeCategoryItems) {
      allItemNames.add(item.name);
    }
    for (final e in provider.incomeExpenseEntries) {
      if (e.particular.trim().isNotEmpty) {
        allItemNames.add(e.particular.trim());
      }
    }
    final sortedNames = allItemNames.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Filter P & L Records',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _setPreset('all', provider);
                          setState(() => _selectedParticularFilter = null);
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Filter by Expense / Income Item',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: sortedNames.contains(_selectedParticularFilter) ? _selectedParticularFilter : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Item Filter (e.g. Staff Salary)',
                      isDense: true,
                      prefixIcon: Icon(Icons.category_outlined, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Items (Show Everything)')),
                      ...sortedNames.map((name) => DropdownMenuItem(
                            value: name,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedParticularFilter = val);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Period',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All Months'),
                        selected: _activePreset == 'all' || _selectedMonthKeys.isEmpty,
                        onSelected: (_) {
                          _setPreset('all', provider);
                          setSheetState(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Current Month'),
                        selected: _activePreset == 'current',
                        onSelected: (_) {
                          _setPreset('current', provider);
                          setSheetState(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Last 2 Months'),
                        selected: _activePreset == 'last_2',
                        onSelected: (_) {
                          _setPreset('last_2', provider);
                          setSheetState(() {});
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Last 3 Months (Quarter)'),
                        selected: _activePreset == 'last_3',
                        onSelected: (_) {
                          _setPreset('last_3', provider);
                          setSheetState(() {});
                        },
                      ),
                      ActionChip(
                        avatar: Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                        label: const Text('Select Custom Months...'),
                        backgroundColor: _activePreset == 'custom'
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : null,
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          _showMultiMonthPickerDialog(context, provider);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
