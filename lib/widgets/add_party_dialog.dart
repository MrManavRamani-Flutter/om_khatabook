import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/party.dart';
import '../providers/khata_provider.dart';
import '../theme/app_theme.dart';

class AddPartyDialog extends StatefulWidget {
  final Party? partyToEdit;

  const AddPartyDialog({super.key, this.partyToEdit});

  @override
  State<AddPartyDialog> createState() => _AddPartyDialogState();
}

class _AddPartyDialogState extends State<AddPartyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  PartyType _type = PartyType.customer;
  bool _openingBalancePositive = true; // true: they owe you, false: you owe them

  @override
  void initState() {
    super.initState();
    if (widget.partyToEdit != null) {
      final p = widget.partyToEdit!;
      _nameController.text = p.name;
      _phoneController.text = p.phone;
      _addressController.text = p.address;
      _notesController.text = p.notes;
      _type = p.type;
      _openingBalancePositive = p.openingBalance >= 0;
      _balanceController.text = p.openingBalance.abs().toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _balanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final balanceNum = double.tryParse(_balanceController.text.trim()) ?? 0.0;
    final openingBalance = _openingBalancePositive ? balanceNum : -balanceNum;
    final provider = context.read<KhataProvider>();

    if (widget.partyToEdit != null) {
      final updated = widget.partyToEdit!.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        type: _type,
        openingBalance: openingBalance,
        notes: _notesController.text.trim(),
      );
      await provider.updateParty(updated);
      if (mounted) Navigator.of(context).pop(updated);
    } else {
      final newParty = await provider.addParty(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        type: _type,
        openingBalance: openingBalance,
        notes: _notesController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(newParty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.partyToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                      Text(
                        isEdit ? 'Edit Party' : 'Add New Party (Khata)',
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
                  const SizedBox(height: 20),

                  // TYPE SELECTOR
                  SegmentedButton<PartyType>(
                    segments: const [
                      ButtonSegment(
                        value: PartyType.customer,
                        label: Text('Customer'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: PartyType.supplier,
                        label: Text('Supplier'),
                        icon: Icon(Icons.store),
                      ),
                      ButtonSegment(
                        value: PartyType.member,
                        label: Text('Member'),
                        icon: Icon(Icons.group),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (val) {
                      setState(() => _type = val.first);
                    },
                  ),
                  const SizedBox(height: 16),

                  // NAME
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Party / Business Name *',
                      prefixIcon: Icon(Icons.badge, size: 20),
                      hintText: 'e.g. Ramesh Patel / Shreeji Enterprises',
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Party name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // PHONE
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone, size: 20),
                      hintText: 'e.g. 98250 12345',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ADDRESS / CITY
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address / City',
                      prefixIcon: Icon(Icons.location_on, size: 20),
                      hintText: 'e.g. Surat, Gujarat',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // OPENING BALANCE
                  if (!isEdit) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _balanceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Opening Balance (₹)',
                              prefixIcon: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                child: Text('₹',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                              ),
                              prefixIconConstraints: BoxConstraints(
                                  minWidth: 0, minHeight: 0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<bool>(
                            value: _openingBalancePositive,
                            decoration: const InputDecoration(
                              labelText: 'Balance Type',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: true,
                                child: Text(
                                  'You\'ll Get (Lene)',
                                  style: TextStyle(
                                      color: AppColors.gaveRed,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              DropdownMenuItem(
                                value: false,
                                child: Text(
                                  'You\'ll Give (Dene)',
                                  style: TextStyle(
                                      color: AppColors.gotGreen,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _openingBalancePositive = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],

                  // NOTES
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Notes',
                      prefixIcon: Icon(Icons.note_alt, size: 20),
                      hintText: 'Additional details or reference',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        isEdit ? 'Update Party' : 'Add Party to Khata',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
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
