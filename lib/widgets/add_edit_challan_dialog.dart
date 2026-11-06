import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'add_edit_party_dialog.dart';

enum CashPaymentMode {
  fullyPaid('Fully Paid'),
  partiallyPaid('Partially Paid'),
  unpaid('Unpaid / Due');

  final String label;
  const CashPaymentMode(this.label);
}

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
  final _paidAmountController = TextEditingController();
  final _gstBillNoController = TextEditingController();
  final _gstAmountController = TextEditingController(text: '0');
  final _gstPercentageController = TextEditingController(text: '5');
  final _notesController = TextEditingController();

  TextEditingController? _partyTextEditingController;
  TextEditingController? _gstBillTextController;
  String? _selectedGstPrefix;
  bool _hasGst = false;
  Party? _selectedParty;
  PaymentOption _paymentOption = PaymentOption.cash;
  CashPaymentMode _cashPaymentMode = CashPaymentMode.unpaid;

  String? get _activePrefix {
    final current = _gstBillNoController.text.trim().toUpperCase();
    for (final p in ['JK', 'OMC', 'MK', 'KK']) {
      if (current.startsWith(p)) return p;
    }
    return _selectedGstPrefix;
  }

  void _selectPrefix(String prefix) {
    _selectedGstPrefix = prefix;
    final current = _gstBillNoController.text.trim().toUpperCase();
    String rest = current;
    for (final p in ['JK', 'OMC', 'MK', 'KK']) {
      if (current.startsWith(p)) {
        rest = current.substring(p.length).replaceFirst(RegExp(r'^[-\s/]+'), '');
        break;
      }
    }
    final newText = rest.isEmpty ? '$prefix-' : '$prefix-$rest';
    setState(() {
      _gstBillNoController.text = newText;
      if (_gstBillTextController != null) {
        _gstBillTextController!.text = newText;
      }
    });
  }

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
      for (final p in ['JK', 'OMC', 'MK', 'KK']) {
        if (e.gstBillNo.toUpperCase().startsWith(p)) {
          _selectedGstPrefix = p;
          break;
        }
      }
      _gstAmountController.text = e.gstAmount.toStringAsFixed(0);
      _hasGst = e.gstAmount > 0 || e.gstBillNo.isNotEmpty;
      if (_hasGst) {
        final base = e.finalAmount > 0 ? e.finalAmount : e.challanAmount;
        if (base > 0 && e.gstAmount > 0) {
          final pct = (e.gstAmount / base) * 100;
          _gstPercentageController.text = pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1);
        }
      }
      _notesController.text = e.notes;
      _paymentOption = e.paymentOption;
      if (e.paymentOption == PaymentOption.cash) {
        if (e.isPartiallyPaid) {
          _cashPaymentMode = CashPaymentMode.partiallyPaid;
          _paidAmountController.text = e.paidAmount.toStringAsFixed(0);
        } else if (e.isCashPaid || e.paidAmount >= e.finalAmount) {
          _cashPaymentMode = CashPaymentMode.fullyPaid;
          _paidAmountController.text = e.finalAmount.toStringAsFixed(0);
        } else {
          _cashPaymentMode = CashPaymentMode.unpaid;
          _paidAmountController.text = '0';
        }
      }

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
    _paidAmountController.dispose();
    _gstBillNoController.dispose();
    _gstAmountController.dispose();
    _gstPercentageController.dispose();
    _notesController.dispose();
    _chequeNoController.dispose();
    _bankNameController.dispose();
    _chequeAmountController.dispose();
    super.dispose();
  }

  String _calcHintText() {
    final finalAmt = double.tryParse(_finalAmountController.text.trim()) ?? 0.0;
    final challanAmt = double.tryParse(_challanAmountController.text.trim()) ?? 0.0;
    final pct = double.tryParse(_gstPercentageController.text.trim()) ?? 5.0;
    if (finalAmt > 0) {
      return 'Auto: ₹${finalAmt.toStringAsFixed(0)} × $pct%';
    } else if (challanAmt > 0) {
      return 'Auto: ₹${challanAmt.toStringAsFixed(0)} × $pct%';
    }
    return 'Optional: Manual or auto';
  }

  void _recalculateGst() {
    if (!_hasGst) {
      _gstAmountController.text = '0';
      return;
    }
    final finalAmt = double.tryParse(_finalAmountController.text.trim()) ?? 0.0;
    final challanAmt = double.tryParse(_challanAmountController.text.trim()) ?? 0.0;
    // 1st Priority: Final Amount if > 0, else Challan Amount
    final baseAmt = finalAmt > 0 ? finalAmt : challanAmt;
    if (baseAmt <= 0) {
      return;
    }
    final percent = double.tryParse(_gstPercentageController.text.trim()) ?? 5.0;
    final calculatedGst = (baseAmt * percent) / 100.0;
    _gstAmountController.text = calculatedGst.toStringAsFixed(calculatedGst % 1 == 0 ? 0 : 2);
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
    if (_cashPaymentMode == CashPaymentMode.fullyPaid) {
      _paidAmountController.text = val;
    }
    _recalculateGst();
    setState(() {});
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
        if (_partyTextEditingController != null) {
          _partyTextEditingController!.text = newParty.name;
        }
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

    final provider = context.read<ChallanProvider>();
    final formattedPartyName = provider.formatCasedText(partyName);

    // Validate party exists in registered parties (Prevent invalid/unregistered party saving)
    final matchingParty = provider.parties.cast<Party?>().firstWhere(
      (p) =>
          p?.name.trim().toLowerCase() == partyName.toLowerCase() ||
          p?.name.trim().toLowerCase() == formattedPartyName.toLowerCase(),
      orElse: () => null,
    );
    if (matchingParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid party name. Please select an existing party or click "+" to add new party.'),
          backgroundColor: AppColors.warningText,
        ),
      );
      return;
    }
    _selectedParty = matchingParty;

    final challanAmt = double.tryParse(_challanAmountController.text.trim()) ?? 0.0;
    final finalAmt = double.tryParse(_finalAmountController.text.trim()) ?? 0.0;
    final gstAmt = _hasGst ? (double.tryParse(_gstAmountController.text.trim()) ?? 0.0) : 0.0;
    final formattedGstBillNo = _hasGst ? _gstBillNoController.text.trim().toUpperCase() : '';

    double paidAmt = 0.0;
    bool cashPaidBool = false;

    if (_paymentOption == PaymentOption.cash) {
      if (_cashPaymentMode == CashPaymentMode.fullyPaid) {
        paidAmt = finalAmt;
        cashPaidBool = true;
      } else if (_cashPaymentMode == CashPaymentMode.unpaid) {
        paidAmt = 0.0;
        cashPaidBool = false;
      } else {
        // Partially Paid
        paidAmt = double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
        if (paidAmt >= finalAmt) {
          paidAmt = finalAmt;
          cashPaidBool = true;
        } else if (paidAmt <= 0) {
          paidAmt = 0.0;
          cashPaidBool = false;
        } else {
          cashPaidBool = false;
        }
      }
    }

    final formattedChallanNo = _challanNoController.text.trim().toUpperCase();
    final formattedNotes = provider.formatCasedText(_notesController.text.trim());
    final formattedBankName = provider.formatCasedText(_bankNameController.text.trim());

    ChequeDetails? cheque;
    if (_paymentOption == PaymentOption.cheque) {
      final chkAmt = double.tryParse(_chequeAmountController.text.trim()) ?? finalAmt;
      cheque = ChequeDetails(
        chequeDate: _chequeDate,
        chequeNo: _chequeNoController.text.trim(),
        bankName: formattedBankName,
        chequeAmount: chkAmt,
        status: _chequeStatus,
      );
    }

    final partyId = _selectedParty?.id ??
        provider.parties
            .firstWhere(
              (p) => p.name.toLowerCase() == formattedPartyName.toLowerCase(),
              orElse: () => Party(id: '', name: formattedPartyName, createdAt: DateTime.now()),
            )
            .id;

    if (widget.entryToEdit != null) {
      final updated = widget.entryToEdit!.copyWith(
        date: _selectedDate,
        challanNo: formattedChallanNo,
        partyId: partyId.isNotEmpty ? partyId : widget.entryToEdit!.partyId,
        partyName: formattedPartyName,
        challanAmount: challanAmt,
        finalAmount: finalAmt,
        paidAmount: paidAmt,
        gstBillNo: formattedGstBillNo,
        gstAmount: gstAmt,
        paymentOption: _paymentOption,
        isCashPaid: cashPaidBool,
        chequeDetails: cheque,
        notes: formattedNotes,
      );
      await provider.updateChallan(updated);
    } else {
      await provider.addChallan(
        date: _selectedDate,
        challanNo: formattedChallanNo,
        partyId: partyId,
        partyName: formattedPartyName,
        challanAmount: challanAmt,
        finalAmount: finalAmt,
        paidAmount: paidAmt,
        gstBillNo: formattedGstBillNo,
        gstAmount: gstAmt,
        paymentOption: _paymentOption,
        isCashPaid: cashPaidBool,
        chequeDetails: cheque,
        notes: formattedNotes,
      );
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entryToEdit != null;
    final provider = context.watch<ChallanProvider>();
    final parties = provider.parties;
    final casingStyle = provider.textCasingStyle;

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
                                inputFormatters: const [DynamicCaseTextInputFormatter(TextCasingStyle.uppercase)],
                                textCapitalization: TextCapitalization.characters,
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
                                  final q = textEditingValue.text.trim().toLowerCase();
                                  final startsWith = parties.where((p) => p.name.toLowerCase().startsWith(q));
                                  final contains = parties.where((p) =>
                                      !p.name.toLowerCase().startsWith(q) &&
                                      (p.name.toLowerCase().contains(q) || p.phone.contains(q)));
                                  return [...startsWith, ...contains];
                                },
                                onSelected: (Party selection) {
                                  setState(() {
                                    _selectedParty = selection;
                                    _partySearchController.text = selection.name;
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                                  _partyTextEditingController = controller;
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
                                    inputFormatters: [DynamicCaseTextInputFormatter(casingStyle)],
                                    textCapitalization: casingStyle == TextCasingStyle.uppercase
                                        ? TextCapitalization.characters
                                        : (casingStyle == TextCasingStyle.titleCase
                                            ? TextCapitalization.words
                                            : TextCapitalization.none),
                                    decoration: InputDecoration(
                                      labelText: 'Party / Business Name *',
                                      prefixIcon: const Icon(Icons.business, size: 18),
                                      hintText: casingStyle.apply('Type to search or select party...'),
                                    ),
                                    onFieldSubmitted: (val) {
                                      final q = val.trim().toLowerCase();
                                      if (q.isNotEmpty) {
                                        // Pick first matching suggestion on Enter
                                        final match = parties.cast<Party?>().firstWhere(
                                          (p) => p?.name.trim().toLowerCase() == q,
                                          orElse: () => parties.cast<Party?>().firstWhere(
                                            (p) => p?.name.trim().toLowerCase().startsWith(q) ?? false,
                                            orElse: () => parties.cast<Party?>().firstWhere(
                                              (p) =>
                                                  (p?.name.trim().toLowerCase().contains(q) ?? false) ||
                                                  (p?.phone.contains(q) ?? false),
                                              orElse: () => null,
                                            ),
                                          ),
                                        );
                                        if (match != null) {
                                          setState(() {
                                            _selectedParty = match;
                                            controller.text = match.name;
                                            _partySearchController.text = match.name;
                                          });
                                        }
                                      }
                                      onEditingComplete();
                                    },
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Party name is required';
                                      }
                                      final q = v.trim().toLowerCase();
                                      final exists = parties.any((p) => p.name.trim().toLowerCase() == q);
                                      if (!exists) {
                                        return 'Invalid party name. Select from suggestions or click "+" to add party.';
                                      }
                                      return null;
                                    },
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

                        // ROW 3: CHALLAN AMOUNT & FINAL AMOUNT (OPTIONAL)
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _challanAmountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Challan Amount (₹)',
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                                  hintText: '0.00 (Optional)',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return null; // Optional
                                  final n = double.tryParse(v.trim());
                                  if (n == null || n < 0) return 'Invalid amount';
                                  return null;
                                },
                                onChanged: (val) {
                                  if (_finalAmountController.text.isEmpty && val.isNotEmpty) {
                                    _finalAmountController.text = val;
                                    _onFinalAmountChanged(val);
                                  } else {
                                    _recalculateGst();
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
                                  labelText: 'Final Amount (₹)',
                                  prefixIcon: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                                  hintText: '0.00 (Optional)',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return null; // Optional
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

                        // ROW 4: GST BILL SECTION WITH CHECKBOX, AUTO-CALCULATION & 4 PREFIXES
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _hasGst
                                ? AppColors.primary.withValues(alpha: 0.05)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _hasGst
                                  ? AppColors.primary.withValues(alpha: 0.35)
                                  : Theme.of(context).dividerColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _hasGst,
                                      activeColor: AppColors.primary,
                                      onChanged: (val) {
                                        setState(() {
                                          _hasGst = val ?? false;
                                          if (_hasGst) {
                                            _recalculateGst();
                                          } else {
                                            _gstAmountController.text = '0';
                                            _gstBillNoController.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _hasGst = !_hasGst;
                                        if (_hasGst) {
                                          _recalculateGst();
                                        } else {
                                          _gstAmountController.text = '0';
                                          _gstBillNoController.clear();
                                        }
                                      });
                                    },
                                    child: const Text(
                                      'Apply GST Bill',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_hasGst)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Auto-calc (Priority: Final Amt > Challan Amt)',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (_hasGst) ...[
                                const SizedBox(height: 12),
                                // ROW A: GST BILL NO & 4 FIXED PREFIXES
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Prefix (Choose 1): ',
                                          style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey),
                                        ),
                                        ...['JK', 'OMC', 'MK', 'KK'].map((prefix) {
                                          final isSelected = _activePrefix == prefix;
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: InkWell(
                                              onTap: () => _selectPrefix(prefix),
                                              borderRadius: BorderRadius.circular(6),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 150),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 11, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? AppColors.primary
                                                      : Theme.of(context).cardColor,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : AppColors.primary.withValues(alpha: 0.35),
                                                    width: isSelected ? 1.5 : 1.0,
                                                  ),
                                                  boxShadow: isSelected
                                                      ? [
                                                          BoxShadow(
                                                            color: AppColors.primary
                                                                .withValues(alpha: 0.25),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 1.5),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (isSelected) ...[
                                                      const Icon(Icons.check,
                                                          size: 12, color: Colors.white),
                                                      const SizedBox(width: 4),
                                                    ],
                                                    Text(
                                                      prefix,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Autocomplete<String>(
                                      initialValue: TextEditingValue(text: _gstBillNoController.text),
                                      optionsBuilder: (TextEditingValue textVal) {
                                        const prefixes = ['JK', 'OMC', 'MK', 'KK'];
                                        final q = textVal.text.trim().toUpperCase();
                                        if (q.isEmpty) return prefixes;
                                        return prefixes
                                            .where((p) => p.startsWith(q) || q.startsWith(p));
                                      },
                                      onSelected: (String sel) {
                                        _selectPrefix(sel);
                                      },
                                      fieldViewBuilder:
                                          (context, controller, focusNode, onEditingComplete) {
                                        _gstBillTextController = controller;
                                        controller.addListener(() {
                                          if (_gstBillNoController.text != controller.text) {
                                            _gstBillNoController.text = controller.text;
                                            setState(() {});
                                          }
                                        });
                                        if (_gstBillNoController.text.isNotEmpty &&
                                            controller.text.isEmpty) {
                                          controller.text = _gstBillNoController.text;
                                        }
                                        return TextFormField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          inputFormatters: const [
                                            DynamicCaseTextInputFormatter(TextCasingStyle.uppercase),
                                          ],
                                          textCapitalization: TextCapitalization.characters,
                                          decoration: const InputDecoration(
                                            labelText: 'GST Bill No.',
                                            prefixIcon: Icon(Icons.receipt_long, size: 18),
                                            hintText: 'e.g. JK-101, OMC-045, MK-99, KK-12',
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // ROW B: GST RATE & GST AMOUNT (BALANCED SIDE-BY-SIDE)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          TextFormField(
                                            controller: _gstPercentageController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(
                                              labelText: 'GST Rate %',
                                              suffixText: '%',
                                            ),
                                            onChanged: (_) => _recalculateGst(),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            children: ['5', '12', '18', '28'].map((rate) {
                                              final isSel = _gstPercentageController.text == rate;
                                              return ChoiceChip(
                                                label:
                                                    Text('$rate%', style: const TextStyle(fontSize: 11)),
                                                selected: isSel,
                                                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                                                onSelected: (selected) {
                                                  if (selected) {
                                                    _gstPercentageController.text = rate;
                                                    _recalculateGst();
                                                  }
                                                },
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          TextFormField(
                                            controller: _gstAmountController,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(
                                              labelText: 'GST Amount (₹)',
                                              prefixIcon: Padding(
                                                padding:
                                                    EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                                child: Text('₹',
                                                    style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                              prefixIconConstraints:
                                                  BoxConstraints(minWidth: 0, minHeight: 0),
                                              hintText: '0.00 (Optional)',
                                            ),
                                            validator: (v) {
                                              if (v == null || v.trim().isEmpty) return null;
                                              final n = double.tryParse(v.trim());
                                              if (n == null || n < 0) return 'Invalid amount';
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 6),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: Text(
                                              _calcHintText(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
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
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _cashPaymentMode == CashPaymentMode.fullyPaid
                                  ? AppColors.successBgLight
                                  : _cashPaymentMode == CashPaymentMode.partiallyPaid
                                      ? const Color(0xFFFFFBEB)
                                      : AppColors.warningBgLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _cashPaymentMode == CashPaymentMode.fullyPaid
                                    ? AppColors.successBorder
                                    : _cashPaymentMode == CashPaymentMode.partiallyPaid
                                        ? const Color(0xFFFDE68A)
                                        : AppColors.warningBorder,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _cashPaymentMode == CashPaymentMode.fullyPaid
                                          ? Icons.check_circle
                                          : _cashPaymentMode == CashPaymentMode.partiallyPaid
                                              ? Icons.pie_chart
                                              : Icons.warning_amber_rounded,
                                      color: _cashPaymentMode == CashPaymentMode.fullyPaid
                                          ? AppColors.successText
                                          : _cashPaymentMode == CashPaymentMode.partiallyPaid
                                              ? const Color(0xFFB45309)
                                              : AppColors.warningText,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cash Payment Status *',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: _cashPaymentMode == CashPaymentMode.fullyPaid
                                            ? AppColors.successText
                                            : _cashPaymentMode == CashPaymentMode.partiallyPaid
                                                ? const Color(0xFF92400E)
                                                : AppColors.warningText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 3 CASH PAYMENT MODES
                                SegmentedButton<CashPaymentMode>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(
                                      value: CashPaymentMode.fullyPaid,
                                      label: Text('Fully Paid'),
                                      icon: Icon(Icons.check_circle_outline, size: 16),
                                    ),
                                    ButtonSegment(
                                      value: CashPaymentMode.partiallyPaid,
                                      label: Text('Partially Paid'),
                                      icon: Icon(Icons.pie_chart_outline, size: 16),
                                    ),
                                    ButtonSegment(
                                      value: CashPaymentMode.unpaid,
                                      label: Text('Unpaid / Due'),
                                      icon: Icon(Icons.pending_actions, size: 16),
                                    ),
                                  ],
                                  selected: {_cashPaymentMode},
                                  onSelectionChanged: (val) {
                                    final mode = val.first;
                                    setState(() {
                                      _cashPaymentMode = mode;
                                      final finalAmt = double.tryParse(_finalAmountController.text.trim()) ?? 0.0;
                                      if (mode == CashPaymentMode.fullyPaid) {
                                        _paidAmountController.text = finalAmt > 0 ? finalAmt.toStringAsFixed(0) : '';
                                      } else if (mode == CashPaymentMode.unpaid) {
                                        _paidAmountController.text = '0';
                                      } else {
                                        if (_paidAmountController.text == '0' || _paidAmountController.text.isEmpty) {
                                          _paidAmountController.text = '';
                                        }
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),

                                if (_cashPaymentMode == CashPaymentMode.fullyPaid) ...[
                                  const Text(
                                    'Full cash amount has been received. This transaction will be marked as Cleared / Paid.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.successText,
                                    ),
                                  ),
                                ] else if (_cashPaymentMode == CashPaymentMode.partiallyPaid) ...[
                                  // Cash Received text input
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _paidAmountController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            labelText: 'Cash Received / Paid Amount (₹) *',
                                            prefixIcon: Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                              child: Text('₹', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                            prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                                            hintText: 'Enter partial amount received',
                                          ),
                                          validator: (v) {
                                            if (_paymentOption != PaymentOption.cash || _cashPaymentMode != CashPaymentMode.partiallyPaid) {
                                              return null;
                                            }
                                            if (v == null || v.trim().isEmpty) {
                                              return 'Please enter partial cash received';
                                            }
                                            final paid = double.tryParse(v.trim());
                                            final finalAmt = double.tryParse(_finalAmountController.text.trim()) ?? 0.0;
                                            if (paid == null || paid <= 0) {
                                              return 'Must be greater than 0';
                                            }
                                            if (paid >= finalAmt && finalAmt > 0) {
                                              return 'Should be less than Final Amount (use Fully Paid instead)';
                                            }
                                            return null;
                                          },
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Live calculation banner
                                  Builder(
                                    builder: (context) {
                                      final finalAmt = double.tryParse(_finalAmountController.text.trim()) ?? 0.0;
                                      final paidAmt = double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
                                      final remaining = (finalAmt - paidAmt).clamp(0.0, double.infinity);

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFFCD34D)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Cash Received: ${Formatters.currency(paidAmt)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                            Text(
                                              'Remaining Due: ${Formatters.currency(remaining)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.warningText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ] else ...[
                                  const Text(
                                    'Warning: Zero cash received. Full amount will remain pending and highlighted in RED in ledger.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.warningText,
                                    ),
                                  ),
                                ],
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
                                        inputFormatters: [DynamicCaseTextInputFormatter(casingStyle)],
                                        textCapitalization: casingStyle == TextCasingStyle.uppercase
                                            ? TextCapitalization.characters
                                            : (casingStyle == TextCasingStyle.titleCase
                                                ? TextCapitalization.words
                                                : TextCapitalization.none),
                                        decoration: InputDecoration(
                                          labelText: 'Bank Name *',
                                          hintText: casingStyle.apply('e.g. HDFC, State Bank of India'),
                                          prefixIcon: const Icon(Icons.account_balance, size: 18),
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
                          inputFormatters: [DynamicCaseTextInputFormatter(casingStyle)],
                          textCapitalization: casingStyle == TextCasingStyle.uppercase
                              ? TextCapitalization.characters
                              : (casingStyle == TextCasingStyle.titleCase
                                  ? TextCapitalization.words
                                  : TextCapitalization.none),
                          decoration: InputDecoration(
                            labelText: 'Notes / Remarks (Optional)',
                            prefixIcon: const Icon(Icons.notes, size: 18),
                            hintText: casingStyle.apply('Any delivery details or payment remarks'),
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
