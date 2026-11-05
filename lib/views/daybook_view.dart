import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/day_entry.dart';
import '../providers/khata_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class DayBookView extends StatefulWidget {
  const DayBookView({super.key});

  @override
  State<DayBookView> createState() => _DayBookViewState();
}

class _DayBookViewState extends State<DayBookView> {
  DateTime _selectedDate = DateTime.now();

  void _showAddDayEntryDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DayEntryType type = DayEntryType.expense;
    String category = 'Expense';
    DateTime entryDate = _selectedDate;

    final categories = [
      'General',
      'Refreshment',
      'Office Supply',
      'Staff / Salary',
      'Travel / Petrol',
      'Rent & Utilities',
      'Group Contribution',
      'Misc Income',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Rojmel Entry',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // TYPE SELECTOR
                      SegmentedButton<DayEntryType>(
                        segments: const [
                          ButtonSegment(
                            value: DayEntryType.income,
                            label: Text('Income (Aavak)'),
                            icon: Icon(Icons.arrow_downward,
                                color: AppColors.gotGreen),
                          ),
                          ButtonSegment(
                            value: DayEntryType.expense,
                            label: Text('Expense (Javak)'),
                            icon: Icon(Icons.arrow_upward,
                                color: AppColors.gaveRed),
                          ),
                        ],
                        selected: {type},
                        onSelectionChanged: (val) {
                          setDialogState(() => type = val.first);
                        },
                      ),
                      const SizedBox(height: 16),

                      // TITLE
                      TextFormField(
                        controller: titleController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Title / Purpose *',
                          hintText: 'e.g. Office tea, Courier, Printing',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // AMOUNT
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹) *',
                          prefixIcon: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            child: Text('₹',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                          prefixIconConstraints:
                              BoxConstraints(minWidth: 0, minHeight: 0),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Amount is required';
                          }
                          final n = double.tryParse(v.trim());
                          if (n == null || n <= 0) {
                            return 'Enter valid amount > 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // CATEGORY
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: categories
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => category = v);
                        },
                      ),
                      const SizedBox(height: 14),

                      // NOTE
                      TextFormField(
                        controller: noteController,
                        decoration: const InputDecoration(
                          labelText: 'Note / Remark (Optional)',
                          hintText: 'Any extra details',
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: type == DayEntryType.income
                                ? AppColors.gotGreen
                                : AppColors.gaveRed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final amt =
                                double.parse(amountController.text.trim());
                            await context.read<KhataProvider>().addDayEntry(
                                  title: titleController.text.trim(),
                                  amount: amt,
                                  type: type,
                                  category: category,
                                  date: entryDate,
                                  note: noteController.text.trim(),
                                );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          child: Text(
                            type == DayEntryType.income
                                ? 'Save Income Entry (+₹)'
                                : 'Save Expense Entry (-₹)',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KhataProvider>();
    final entries = provider.dayEntries;

    // Filter by selected date (day, month, year match)
    final dayEntries = entries.where((e) {
      return e.date.year == _selectedDate.year &&
          e.date.month == _selectedDate.month &&
          e.date.day == _selectedDate.day;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalIncome = dayEntries
        .where((e) => e.type == DayEntryType.income)
        .fold(0.0, (s, e) => s + e.amount);

    final totalExpense = dayEntries
        .where((e) => e.type == DayEntryType.expense)
        .fold(0.0, (s, e) => s + e.amount);

    final netDay = totalIncome - totalExpense;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Day Book (Rojmel / Roznamcha)',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track daily miscellaneous cash income & business expenses',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDayEntryDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Daily Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // DATE SELECTOR BAR & SUMMARY
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        setState(() {
                          _selectedDate =
                              _selectedDate.subtract(const Duration(days: 1));
                        });
                      },
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              Formatters.date(_selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          _selectedDate =
                              _selectedDate.add(const Duration(days: 1));
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      label: const Text('Today'),
                      onPressed: () =>
                          setState(() => _selectedDate = DateTime.now()),
                    ),
                    const Spacer(),

                    // TOTALS
                    Row(
                      children: [
                        _buildTotalBadge('Income (In)', totalIncome,
                            AppColors.gotGreen, AppColors.gotGreenLight),
                        const SizedBox(width: 12),
                        _buildTotalBadge('Expense (Out)', totalExpense,
                            AppColors.gaveRed, AppColors.gaveRedLight),
                        const SizedBox(width: 12),
                        _buildTotalBadge(
                          'Daily Net',
                          netDay,
                          netDay >= 0 ? AppColors.primary : AppColors.gaveRed,
                          AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // LIST OF ENTRIES
            Expanded(
              child: dayEntries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 60,
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Rojmel entries for ${Formatters.date(_selectedDate)}',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _showAddDayEntryDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Daily Entry'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: dayEntries.length,
                      itemBuilder: (context, index) {
                        final item = dayEntries[index];
                        final isIncome = item.type == DayEntryType.income;
                        final color =
                            isIncome ? AppColors.gotGreen : AppColors.gaveRed;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? AppColors.gotGreenLight
                                      : AppColors.gaveRedLight,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isIncome
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: color,
                                  size: 20,
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
                                          item.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .dividerColor
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.category,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.note.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        item.note,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color
                                              ?.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                (isIncome ? '+' : '-') +
                                    Formatters.currency(item.amount),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.grey),
                                tooltip: 'Delete Entry',
                                onPressed: () {
                                  context
                                      .read<KhataProvider>()
                                      .deleteDayEntry(item.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBadge(
      String label, double amount, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
          Text(
            Formatters.currency(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
