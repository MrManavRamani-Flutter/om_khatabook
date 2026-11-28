import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import 'password_confirmation_dialog.dart';

class AddEditPartyDialog extends StatefulWidget {
  final Party? partyToEdit;

  const AddEditPartyDialog({super.key, this.partyToEdit});

  @override
  State<AddEditPartyDialog> createState() => _AddEditPartyDialogState();
}

class _AddEditPartyDialogState extends State<AddEditPartyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.partyToEdit != null) {
      final p = widget.partyToEdit!;
      _nameController.text = p.name;
      _phoneController.text = p.phone;
      _addressController.text = p.address;
      _gstController.text = p.gstNumber;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ChallanProvider>();

    final formattedName = provider.formatCasedText(_nameController.text.trim());
    final formattedAddress = provider.formatCasedText(_addressController.text.trim());
    final phone = _phoneController.text.trim();
    final gstin = _gstController.text.trim().toUpperCase();

    const uName = 'OM MAVTAR';
    const uRole = 'MASTER';

    final isEdit = widget.partyToEdit != null;
    final confirmed = await promptPasswordConfirmation(
      context,
      title: isEdit ? 'Confirm Edit Party' : 'Confirm Add Party',
      message: isEdit
          ? 'Enter password to confirm updating party "$formattedName".'
          : 'Enter password to confirm adding new party "$formattedName".',
      actionLabel: isEdit ? 'Save Changes' : 'Add Party',
      icon: isEdit ? Icons.edit : Icons.person_add,
      iconColor: AppColors.primary,
    );

    if (!confirmed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password verification cancelled. Party details preserved.'),
            backgroundColor: AppColors.primaryDark,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (widget.partyToEdit != null) {
      final updated = widget.partyToEdit!.copyWith(
        name: formattedName,
        phone: phone,
        address: formattedAddress,
        gstNumber: gstin,
      );
      await provider.updateParty(updated, performedBy: uName, userRole: uRole);
      if (mounted) Navigator.of(context).pop(updated);
    } else {
      final created = await provider.addParty(
        name: formattedName,
        phone: phone,
        address: formattedAddress,
        gstNumber: gstin,
        performedBy: uName,
        userRole: uRole,
      );
      if (mounted) Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.partyToEdit != null;
    final provider = context.watch<ChallanProvider>();
    final casingStyle = provider.textCasingStyle;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Party' : 'Add New Party',
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  inputFormatters: [DynamicCaseTextInputFormatter(casingStyle)],
                  textCapitalization: casingStyle == TextCasingStyle.uppercase
                      ? TextCapitalization.characters
                      : (casingStyle == TextCasingStyle.titleCase
                          ? TextCapitalization.words
                          : TextCapitalization.none),
                  decoration: InputDecoration(
                    labelText: 'Party / Business Name *',
                    prefixIcon: const Icon(Icons.business, size: 20),
                    hintText: casingStyle.apply('Manav Fab'),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Party name is required'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone Number',
                    prefixIcon: Icon(Icons.phone, size: 20),
                    hintText: 'e.g. 98250 12345',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressController,
                  inputFormatters: [DynamicCaseTextInputFormatter(casingStyle)],
                  textCapitalization: casingStyle == TextCasingStyle.uppercase
                      ? TextCapitalization.characters
                      : (casingStyle == TextCasingStyle.titleCase
                          ? TextCapitalization.words
                          : TextCapitalization.none),
                  decoration: InputDecoration(
                    labelText: 'Address / City',
                    prefixIcon: const Icon(Icons.location_on, size: 20),
                    hintText: casingStyle.apply('Ring Road, Surat'),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _gstController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN Number (Optional)',
                    prefixIcon: Icon(Icons.verified, size: 20),
                    hintText: 'e.g. 24AAAAA0000A1Z5',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _submit,
                    child: Text(
                      isEdit ? 'Update Party' : 'Save Party',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

