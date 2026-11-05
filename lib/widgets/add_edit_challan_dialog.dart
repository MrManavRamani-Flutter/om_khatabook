import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'add_edit_party_dialog.dart';

class AddEditChallanDialog extends StatefulWidget {
  final ChallanEntry? entryToEdit;
  final Party? initialParty;

  const AddEditChallanDialog({super.key, this.entryToEdit, this.initialParty});

  @override
  State<AddEditChallanDialog> createState() => _AddEditChallanDialogState();
}

class _AddEditChallanDialogState extends State<AddEditChallanDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  final _challanNoController = TextEditingController();
  final _partySearchController = TextEditingController();
  final _challanAmountController = TextEditingController();
  final _finalAmountController = TextEditingController();
  final _gstBillNoController = TextEditingController();
  final _gstAmountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  Party? _selectedParty;
  PaymentOption _paymentOption = PaymentOption.cash;
  bool _isCashPaid = false; // Default to unpaid so user is mindful, or user can toggle

  // Cheque fields
  late DateTime _chequeDate;
  final _chequeNoController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _chequeAmountController = TextEditingController();
  ChequeStatus _chequeStatus = ChequeStatus.pending;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _chequeDate = DateTime.now();

    if (widget.entryToEdit != null) {
      final e = widget.entryToEdit!;
      _selectedDate = e.date;
      _challanNoController.text = e.challanNo;
      _partySearchController.text = e.partyName;
      _challanAmountController.text = e.challanAmount.toStringAsFixed(0);
      _finalAmountController.text = e.finalAmount.toStringAsFixed(0);
      _gstBillNoController.text = e.gstBillNo;
      _gstAmountController.text = e.gstAmount.toStringAsFixed(0);
      _notesController.text = e.notes;
      _paymentOption = e.paymentOption;
      _isCashPaid = e.isCashPaid;

      if (e.chequeDetails != null) {
        final c = e.chequeDetails!;
        _chequeDate = c.chequeDate;
        _chequeNoController.text = c.chequeNo;
        _bankNameController.text = c.bankName;
        _chequeAmountController.text = c.chequeAmount.toStringAsFixed(0);
        _chequeStatus = c.status;
      }
    } else if (widget.initialParty != null) {
      _selectedParty = widget.initialParty;
      _partySearchController.text = widget.initialParty!.name;
    }
  }

  @override
  void dispose() {
    _challanNoController.dispose();
    _partySearchController.dispose();
    _challanAmountController.dispose();
    _finalAmountController.dispose();
    _gstBillNoController.dispose();
    _gstAmountController.dispose();
    _notesController.dispose();
    _chequeNoController.dispose();
    _bankNameController.dispose();
    _chequeAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickChequeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _chequeDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _chequeDate = picked);
    }
  }

  void _onFinalAmountChanged(String val) {
    if (_chequeAmountController.text.isEmpty && val.isNotEmpty) {
      _chequeAmountController.text = val;
    }
  }

  Future<void> _openQuickAddParty() async {
    final newParty = await showDialog<Party>(
      context: context,
      builder: (_) => const AddEditPartyDialog(),
    );
    if (newParty != null) {
      setState(() {
        _selectedParty = newParty;
        _partySearchController.text = newParty.name;
      });
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final partyName = _partySearchController.text.trim();
    if (partyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter a Party name'),
          backgroundColor: AppColors.warningText,
        ),
      );
      return;
    }

    final challanAmt = double.parse(_challanAmountController.text.trim());
    final finalAmt = double.parse(_finalAmountController.text.trim());
    final gstAmt = double.tryParse(_gstAmountController.text.trim()) ?? 0.0;

    ChequeDetails? cheque;
    if (_paymentOption == PaymentOption.cheque) {
      final chkAmt = double.tryParse(_chequeAmountController.text.trim()) ?? finalAmt;
      cheque = ChequeDetails(
        chequeDate: _chequeDate,
        chequeNo: _chequeNoController.text.trim(),
        bankName: _bankNameController.text.trim(),
        chequeAmount: chkAmt,
        status: _chequeStatus,
      );
    }

    final provider = context.read<ChallanProvider>();
    final partyId = _selectedParty?.id ??
        provider.parties
            .firstWhere(
              (p) => p.name.toLowerCase() == partyName.toLowerCase(),
              orElse: () => Party(id: '', name: partyName, createdAt: DateTime.now()),
            )
            .id;

    if (widget.entryToEdit != null) {
      final updated = widget.entryToEdit!.copyWith(
        date: _selectedDate,
        challanNo: _challanNoController.text.trim(),
        partyId: partyId.isNotEmpty ? partyId : widget.entryToEdit!.partyId,
        partyName: partyName,
        challanAmount: challanAmt,
        finalAmount: finalAmt,
        gstBillNo: _gstBillNoController.text.trim(),
        gstAmount: gstAmt,
        paymentOption: _paymentOption,
        isCashPaid: _isCashPaid,
        chequeDetails: cheque,
        notes: _notesController.text.trim(),
      );
      await provider.updateChallan(updated);
    } else {
      await provider.addChallan(
        date: _selectedDate,
        challanNo: _challanNoController.text.trim(),
        partyId: partyId,
        partyName: partyName,
        challanAmount: challanAmt,
        finalAmount: finalAmt,
        gstBillNo: _gstBillNoController.text.trim(),
        gstAmount: gstAmt,
        paymentOption: _paymentOption,
        isCashPaid: _isCashPaid,
        chequeDetails: cheque,
        notes: _notesController.text.trim(),
      );
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entryToEdit != null;
    final parties = context.watch<ChallanProvider>().parties;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Challan & Bill Entry' : 'New Challan & Bill Entry',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // SCROLLABLE FORM BODY
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ROW 1: DATE & CHALLAN NO
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(10),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date *',
                                    prefixIcon: Icon(Icons.calendar_today, size: 18),
                                  ),
                                  child: Text(
                                    Formatters.date(_selectedDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: _challanNoController,
                                autofocus: !isEdit,
                                decoration: const InputDecoration(
                                  labelText: 'Challan No. *',
                                  prefixIcon: Icon(Icons.tag, size: 18),
                                  hintText: 'e.g. CH-2026-105',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Challan Number is required'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ROW 2: PARTY AUTOCOMPLETE SEARCH & QUICK ADD
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Autocomplete<Party>(
                                initialValue: TextEditingValue(text: _partySearchController.text),
                                displayStringForOption: (Party p) => p.name,
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return parties;
                                  }
                                  final q = textEditingValue.text.toLowerCase();
                                  return parties.where((p) =>
                                      p.name.toLowerCase().contains(q) ||
                                      p.phone.contains(q));
                                },
                                onSelected: (Party selection) {
                                  setState(() {
                                    _selectedParty = selection;
                                    _partySearchController.text = selection.name;
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                  // Keep text sync
                                  controller.addListener(() {
                                    _partySearchController.text = controller.text;
                                  });
                                  if (_partySearchController.text.isNotEmpty &&
                                      controller.text.isEmpty) {
                                    controller.text = _partySearchController.text;
                                  }

                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'Party / Business Name *',
                                      prefixIcon: Icon(Icons.business, size: 18),
                                      hintText: 'Type to search existing party...',
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty
                                        ? 'Party name is required'
                                        : null,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              tooltip: 'Pre-add New Party',
                              icon: const Icon(Icons.person_add, size: 20),
                              onPressed: _openQuickAddParty,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ROW 3: CHALLAN AMOUNT & FINAL AMOUNT
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _challanAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Challan Amount (₹) *',
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                                  hintText: '0.00',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final n = double.tryParse(v.trim());
                                  if (n == null || n < 0) return 'Invalid amount';
                                  return null;
                                },
                                onChanged: (val) {
                                  if (_finalAmountController.text.isEmpty) {
                                    _finalAmountController.text = val;
                                    _onFinalAmountChanged(val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _finalAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Final Amount (₹) *',
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                                  hintText: '0.00',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  final n = double.tryParse(v.trim());
                                  if (n == null || n < 0) return 'Invalid amount';
                                  return null;
                                },
                                onChanged: _onFinalAmountChanged,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ROW 4: GST BILL NO & GST AMOUNT
                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: TextFormField(
                                controller: _gstBillNoController,
                                decoration: const InputDecoration(
                                  labelText: 'GST Bill No.',
                                  prefixIcon: Icon(Icons.receipt, size: 18),
                                  hintText: 'e.g. GST-2026-052',
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 4,
                              child: TextFormField(
                                controller: _gstAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'GST Amount (₹)',
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                                  hintText: '0.00',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // PAYMENT OPTION SELECTOR (CASH vs CHEQUE)
                        const Text(
                          'Payment Option *',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<PaymentOption>(
                          segments: const [
                            ButtonSegment(
                              value: PaymentOption.cash,
                              label: Text('Cash'),
                              icon: Icon(Icons.money),
                            ),
                            ButtonSegment(
                              value: PaymentOption.cheque,
                              label: Text('Cheque'),
                              icon: Icon(Icons.account_balance),
                            ),
                          ],
                          selected: {_paymentOption},
                          onSelectionChanged: (val) {
                            setState(() => _paymentOption = val.first);
                          },
                        ),
                        const SizedBox(height: 14),

                        // DYNAMIC SUB-FORM FOR CASH OR CHEQUE
                        if (_paymentOption == PaymentOption.cash) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _isCashPaid
                                  ? AppColors.successBgLight
                                  : AppColors.warningBgLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _isCashPaid
                                    ? AppColors.successBorder
                                    : AppColors.warningBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          _isCashPaid
                                              ? Icons.check_circle
                                              : Icons.warning_amber_rounded,
                                          color: _isCashPaid
                                              ? AppColors.successText
                                              : AppColors.warningText,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isCashPaid
                                              ? 'Cash Payment Received (Paid)'
                                              : 'Cash Payment Pending / Unpaid',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _isCashPaid
                                                ? AppColors.successText
                                                : AppColors.warningText,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Switch(
                                      value: _isCashPaid,
                                      activeThumbColor: AppColors.successText,
                                      onChanged: (val) => setState(() => _isCashPaid = val),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isCashPaid
                                      ? 'Marked as completed cash transaction.'
                                      : 'Warning: This entry will be highlighted in LIGHT-RED in the ledger table until paid.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _isCashPaid
                                        ? AppColors.successText
                                        : AppColors.warningText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // CHEQUE SUB-FORM
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cheque Details',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: InkWell(
                                        onTap: _pickChequeDate,
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                            labelText: 'Cheque Date *',
                                            prefixIcon: Icon(Icons.date_range, size: 18),
                                          ),
                                          child: Text(
                                            Formatters.date(_chequeDate),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 5,
                                      child: TextFormField(
                                        controller: _chequeNoController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Cheque No. *',
                                          hintText: 'e.g. 408912',
                                          prefixIcon: Icon(Icons.confirmation_number, size: 18),
                                        ),
                                        validator: (v) {
                                          if (_paymentOption == PaymentOption.cheque) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Cheque No. is required';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: TextFormField(
                                        controller: _bankNameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Bank Name *',
                                          hintText: 'e.g. HDFC, State Bank of India',
                                          prefixIcon: Icon(Icons.account_balance, size: 18),
                                        ),
                                        validator: (v) {
                                          if (_paymentOption == PaymentOption.cheque) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Bank Name is required';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 4,
                                      child: TextFormField(
                                        controller: _chequeAmountController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Cheque Amount (₹) *',
                                          prefixIcon: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                            child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                          prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                                        ),
                                        validator: (v) {
                                          if (_paymentOption == PaymentOption.cheque) {
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Required';
                                            }
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<ChequeStatus>(
                                  initialValue: _chequeStatus,
                                  decoration: const InputDecoration(
                                    labelText: 'Cheque Clearance Status',
                                    prefixIcon: Icon(Icons.rule, size: 18),
                                  ),
                                  items: ChequeStatus.values.map((s) {
                                    return DropdownMenuItem(
                                      value: s,
                                      child: Text(s.label),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _chequeStatus = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // NOTES / DESCRIPTION
                        TextFormField(
                          controller: _notesController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Notes / Remarks (Optional)',
                            prefixIcon: Icon(Icons.notes, size: 18),
                            hintText: 'Any delivery details or payment remarks',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // FOOTER ACTIONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _saveEntry,
                      icon: const Icon(Icons.save),
                      label: Text(isEdit ? 'Update Entry' : 'Save Challan Entry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
