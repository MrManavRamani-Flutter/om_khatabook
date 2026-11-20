import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/income_expense_entry.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class NetProfitLossView extends StatefulWidget {
  const NetProfitLossView({super.key});

  @override
  State<NetProfitLossView> createState() => _NetProfitLossViewState();
}

class _NetProfitLossViewState extends State<NetProfitLossView> {
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  final DateFormat _monthFormat = DateFormat('MMM yyyy');

  // Month filtering state
  // If empty -> All Months mode
  Set<String> _selectedMonthKeys = {};
  String _activePreset = 'all'; // 'all', 'current', 'last_2', 'last_3', 'custom'

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
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
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

    // Preset quick chips for common business ledger entries
    final expenseSuggestions = [
      'Electricity Bill',
      'Staff Salary / Wages',
      'Office Rent',
      'Refreshments & Tea',
      'Transportation & Travel',
      'Stationary & Printing',
      'Packing Materials',
      'Repairs & Maintenance',
      'Other Operating Expenses',
    ];

    final incomeSuggestions = [
      'Om Kiran (Sales)',
      'Pradip (Sales)',
      'Direct Cash Sales',
      'Commission Received',
      'Interest Received',
      'Other Business Income',
    ];

    final suggestions = type == EntryType.expense ? expenseSuggestions : incomeSuggestions;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final isExpense = type == EntryType.expense;
          final accentColor = isExpense ? const Color(0xFFE11D48) : const Color(0xFF059669);

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
                    // QUICK SUGGESTION CHIPS
                    Text(
                      'Quick Presets:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(ctx).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: suggestions.take(6).map((s) {
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(s, style: const TextStyle(fontSize: 11)),
                          backgroundColor: accentColor.withValues(alpha: 0.08),
                          side: BorderSide(color: accentColor.withValues(alpha: 0.2)),
                          onPressed: () {
                            setDialogState(() {
                              particularController.text = s;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // PARTICULAR / DETAILS
                    TextField(
                      controller: particularController,
                      decoration: InputDecoration(
                        labelText: 'Particulars / Details *',
                        hintText: isExpense ? 'e.g. Electricity Bill, Staff Salary' : 'e.g. Om Kiran, Cash Sales',
                        prefixIcon: const Icon(Icons.description_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
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

                    // NOTES
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes / Remarks',
                        hintText: 'Optional remarks or bill reference',
                        prefixIcon: const Icon(Icons.note_alt_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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

  void _confirmDeleteEntry(BuildContext context, IncomeExpenseEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${entry.isExpense ? "Expense" : "Income"} Entry?'),
        content: Text('Are you sure you want to delete "${entry.particular}" (${Formatters.currency(entry.amount)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningText,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context.read<ChallanProvider>().deleteIncomeExpenseEntry(entry.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 850;

    // Compute Profit & Loss with active month filter and search
    final calc = provider.computeProfitLoss(
      selectedMonthKeys: _selectedMonthKeys,
      searchQuery: _searchController.text,
    );

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
            _buildFilterToolbar(context, provider, isDark, isMobile),
            const SizedBox(height: 16),

            // TOP 3 KPI SUMMARY CARDS
            _buildSummaryCards(context, calc, isDark, isMobile),
            const SizedBox(height: 20),

            // T-LEDGER: 2-COLUMN VIEW (EXPENSES ON LEFT IN RED, INCOME ON RIGHT IN GREEN)
            if (isMobile)
              Column(
                children: [
                  _buildExpensesCard(context, calc, isDark),
                  const SizedBox(height: 16),
                  _buildIncomeCard(context, calc, isDark),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildExpensesCard(context, calc, isDark)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildIncomeCard(context, calc, isDark)),
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
              const Row(
                children: [
                  Text(
                    'Net Profit - Loss Ledger',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.4),
                  ),
                  SizedBox(width: 10),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'FINANCIAL LEDGER',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    backgroundColor: Color(0x1500A86B),
                    side: BorderSide(color: Color(0x3300A86B)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Comprehensive 2-column breakdown of Business Incomes (Party Collections) vs Operating Expenses.',
                style: TextStyle(
                  fontSize: 12.5,
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // SEARCH BAR & QUICK ACTION BUTTONS
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
                // ADD EXPENSE (RED BUTTON)
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
                // ADD INCOME (GREEN BUTTON)
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
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Active Period: $filterLabel',
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
                              '${calc.incomes.length} Income Sources / Parties',
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
                              '${calc.expenses.length} Expense Entries Recorded',
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
                                  ? 'Income exceeds expenses (Surplus)'
                                  : 'Expenses exceed income (Deficit)',
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
  Widget _buildExpensesCard(BuildContext context, ProfitLossCalculation calc, bool isDark) {
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
                      Text('Operating expenses & overhead costs', style: TextStyle(fontSize: 11, color: Colors.grey)),
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

          // TABLE HEADER (Sr | Particulars | Date | Amount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade100,
            child: const Row(
              children: [
                SizedBox(width: 40, child: Text('Sr.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 3, child: Text('Particulars / Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('Amount (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                SizedBox(width: 64, child: Text('Action', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          const Divider(height: 1),

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
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
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
                            ),
                            Text(
                              e.category,
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
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
                        width: 64,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () => _openAddEditEntryDialog(
                                context,
                                type: EntryType.expense,
                                entryToEdit: e,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.edit_outlined, size: 14),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _confirmDeleteEntry(context, e),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(5),
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
  Widget _buildIncomeCard(BuildContext context, ProfitLossCalculation calc, bool isDark) {
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
                      Text('Business revenue & party collections', style: TextStyle(fontSize: 11, color: Colors.grey)),
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

          // TABLE HEADER (Sr | Particulars | Source | Amount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade100,
            child: const Row(
              children: [
                SizedBox(width: 40, child: Text('Sr.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 3, child: Text('Particulars / Party Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Source / Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('Amount (₹)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                SizedBox(width: 64, child: Text('Action', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          const Divider(height: 1),

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

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
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
                            ),
                            Text(
                              isPartyCollection ? 'Party Challan Payment' : e.category,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isPartyCollection ? AppColors.primary : Colors.grey,
                                fontWeight: isPartyCollection ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        width: 64,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: isPartyCollection
                              ? [
                                  Tooltip(
                                    message: 'Auto-calculated from party challan receipts',
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: greenColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.check_circle_outline, size: 14, color: greenColor),
                                    ),
                                  ),
                                ]
                              : [
                                  InkWell(
                                    onTap: () => _openAddEditEntryDialog(
                                      context,
                                      type: EntryType.income,
                                      entryToEdit: e,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.edit_outlined, size: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => _confirmDeleteEntry(context, e),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
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
}
