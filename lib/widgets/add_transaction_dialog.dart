import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/party.dart';
import '../models/transaction_entry.dart';
import '../providers/khata_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class AddTransactionDialog extends StatefulWidget {
  final Party party;
  final TransactionType initialType;
  final TransactionEntry? transactionToEdit;

  const AddTransactionDialog({
    super.key,
    required this.party,
    this.initialType = TransactionType.got,
    this.transactionToEdit,
  });

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TransactionType _type;
  late PaymentMode _mode;
  late DateTime _selectedDate;
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _billController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _type = t.type;
      _mode = t.paymentMode;
      _selectedDate = t.date;
      _amountController.text = t.amount.toStringAsFixed(0);
      _descController.text = t.description;
      _billController.text = t.billNumber;
    } else {
      _type = widget.initialType;
      _mode = PaymentMode.cash;
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _billController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addAmount(double val) {
    final cur = double.tryParse(_amountController.text) ?? 0;
    _amountController.text = (cur + val).toStringAsFixed(0);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    final provider = context.read<KhataProvider>();

    if (widget.transactionToEdit != null) {
      final updated = widget.transactionToEdit!.copyWith(
        amount: amount,
        type: _type,
        paymentMode: _mode,
        date: _selectedDate,
        description: _descController.text.trim(),
        billNumber: _billController.text.trim(),
      );
      await provider.updateTransaction(updated);
    } else {
      await provider.addTransaction(
        partyId: widget.party.id,
        amount: amount,
        type: _type,
        paymentMode: _mode,
        date: _selectedDate,
        description: _descController.text.trim(),
        billNumber: _billController.text.trim(),
      );
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isGave = _type == TransactionType.gave;
    final themeColor = isGave ? AppColors.gaveRed : AppColors.gotGreen;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.transactionToEdit != null
                                ? 'Edit Entry'
                                : 'Add New Entry',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Party: ${widget.party.name}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // TYPE TOGGLE
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _type = TransactionType.gave),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isGave
                                    ? AppColors.gaveRed
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'YOU GAVE (Diye ₹)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isGave
                                        ? Colors.white
                                        : AppColors.gaveRed,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _type = TransactionType.got),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !isGave
                                    ? AppColors.gotGreen
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'YOU GOT (Mile ₹)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: !isGave
                                        ? Colors.white
                                        : AppColors.gotGreen,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // AMOUNT FIELD
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      ),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: '0.00',
                      labelText: 'Amount (Rakkam)',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter amount';
                      }
                      final num = double.tryParse(val.trim());
                      if (num == null || num <= 0) {
                        return 'Enter a valid amount greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // QUICK AMOUNT SHORTCUTS
                  Wrap(
                    spacing: 8,
                    children: [500, 1000, 2000, 5000, 10000].map((amt) {
                      return ActionChip(
                        label: Text('+₹$amt'),
                        labelStyle: const TextStyle(fontSize: 12),
                        onPressed: () => _addAmount(amt.toDouble()),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // DATE AND PAYMENT MODE ROW
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(10),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              prefixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            child: Text(
                              Formatters.date(_selectedDate),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<PaymentMode>(
                          value: _mode,
                          decoration: const InputDecoration(
                            labelText: 'Payment Mode',
                            prefixIcon: Icon(Icons.payment, size: 18),
                          ),
                          items: PaymentMode.values.map((mode) {
                            return DropdownMenuItem(
                              value: mode,
                              child: Text(mode.displayName),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _mode = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // BILL NO
                  TextFormField(
                    controller: _billController,
                    decoration: const InputDecoration(
                      labelText: 'Bill / Invoice No. (Optional)',
                      prefixIcon: Icon(Icons.receipt_long, size: 18),
                      hintText: 'e.g. INV-1042',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // DESCRIPTION / NOTE
                  TextFormField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description / Note (Optional)',
                      prefixIcon: Icon(Icons.notes, size: 18),
                      hintText: 'e.g. Payment for material supply',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SUBMIT BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        widget.transactionToEdit != null
                            ? 'Update Entry'
                            : 'Save Entry (${isGave ? "Gave ₹" : "Got ₹"})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
