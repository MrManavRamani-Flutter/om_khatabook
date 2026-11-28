import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/auth_provider.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'add_edit_challan_dialog.dart';
import 'invoice_preview_dialog.dart';
import 'password_confirmation_dialog.dart';

class ViewChallanDialog extends StatelessWidget {
  final ChallanEntry entry;

  const ViewChallanDialog({super.key, required this.entry});

  Future<void> _showDeleteConfirm(BuildContext context) async {
    final confirmed = await promptPasswordConfirmation(
      context,
      title: 'Confirm Delete Challan',
      message: 'Enter your password to confirm permanently deleting Challan #${entry.challanNo} for ${entry.partyName}.',
      actionLabel: 'Delete Challan',
      icon: Icons.delete_forever,
      iconColor: AppColors.warningText,
    );

    if (!confirmed || !context.mounted) return;

    context.read<ChallanProvider>().deleteChallan(entry.id);
    Navigator.of(context).pop();
  }

  void _openEdit(BuildContext context) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditChallanDialog(entryToEdit: entry),
    );
  }

  void _openInvoiceDialog(BuildContext context) {
    final provider = context.read<ChallanProvider>();
    Party? party;
    try {
      party = provider.parties.firstWhere(
        (p) =>
            p.id == entry.partyId ||
            p.name.trim().toUpperCase() == entry.partyName.trim().toUpperCase(),
      );
    } catch (_) {
      party = null;
    }

    showDialog(
      context: context,
      builder: (_) => InvoicePreviewDialog(
        entry: entry,
        party: party,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final auth = context.watch<AuthProvider>();
    final challanLogs = provider.auditLogs.where((l) => l.entityId == entry.id).toList();
    final hasWarning = entry.hasWarning;
    final isCash = entry.paymentOption == PaymentOption.cash;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Challan #${entry.challanNo}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dated: ${Formatters.date(entry.date)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
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
              const SizedBox(height: 16),

              // STATUS ALERT BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: entry.isPartiallyPaid
                      ? const Color(0xFFFFFBEB)
                      : hasWarning
                          ? AppColors.warningBgLight
                          : (isCash && entry.isCashPaid)
                              ? AppColors.successBgLight
                              : AppColors.pendingBgLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: entry.isPartiallyPaid
                        ? const Color(0xFFFDE68A)
                        : hasWarning
                            ? AppColors.warningBorder
                            : (isCash && entry.isCashPaid)
                                ? AppColors.successBorder
                                : AppColors.pendingBorder,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.isPartiallyPaid
                          ? Icons.pie_chart
                          : hasWarning
                              ? Icons.warning_amber_rounded
                              : (isCash && entry.isCashPaid)
                                  ? Icons.check_circle_outline
                                  : Icons.schedule,
                      color: entry.isPartiallyPaid
                          ? const Color(0xFFB45309)
                          : hasWarning
                              ? AppColors.warningText
                              : (isCash && entry.isCashPaid)
                                  ? AppColors.successText
                                  : AppColors.pendingText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.isPartiallyPaid
                            ? 'Partial Payment: Paid ${Formatters.currency(entry.paidAmount)} • Due ${Formatters.currency(entry.remainingAmount)}'
                            : hasWarning
                                ? 'Cash Payment: Pending / Due'
                                : (isCash && entry.isCashPaid)
                                    ? 'Cash Payment: Fully Paid'
                                    : 'Cheque Payment: ${entry.chequeDetails?.status.label ?? "Pending"}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: entry.isPartiallyPaid
                              ? const Color(0xFF92400E)
                              : hasWarning
                                  ? AppColors.warningText
                                  : (isCash && entry.isCashPaid)
                                      ? AppColors.successText
                                      : AppColors.pendingText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // DETAILS GRID
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _buildRow('Party Name', entry.partyName, isBold: true),
                    if (entry.designNo.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildRow(
                        'Design No.',
                        entry.designNo,
                        isBold: true,
                        highlightColor: const Color(0xFF0284C7),
                      ),
                    ],
                    const Divider(height: 16),
                    _buildRow('Challan Amount', Formatters.currency(entry.challanAmount)),
                    if (entry.discountAmount > 0) ...[
                      const Divider(height: 16),
                      _buildRow(
                        'Discount',
                        Formatters.currency(entry.discountAmount),
                        highlightColor: const Color(0xFFD97706),
                      ),
                    ],
                    const Divider(height: 16),
                    _buildRow('Final Amount', Formatters.currency(entry.finalAmount), isBold: true, highlightColor: AppColors.primary),
                    if (isCash) ...[
                      const Divider(height: 16),
                      _buildRow(
                        'Cash Received / Paid',
                        Formatters.currency(entry.paidAmount),
                        isBold: true,
                        highlightColor: entry.isFullyPaid ? AppColors.successText : const Color(0xFFB45309),
                      ),
                      if (entry.remainingAmount > 0) ...[
                        const Divider(height: 16),
                        _buildRow(
                          'Remaining Balance Due',
                          Formatters.currency(entry.remainingAmount),
                          isBold: true,
                          highlightColor: AppColors.warningText,
                        ),
                      ],
                    ],
                    const Divider(height: 16),
                    _buildRow('GST Bill No.', entry.gstBillNo.isNotEmpty ? entry.gstBillNo : 'N/A'),
                    const Divider(height: 16),
                    _buildRow('GST Amount', Formatters.currency(entry.gstAmount)),
                    const Divider(height: 16),
                    _buildRow('Payment Option', entry.paymentOption.label),
                    if (entry.paymentDueDate != null) ...[
                      const Divider(height: 16),
                      _buildRow(
                        'Payment Due Date',
                        '${Formatters.date(entry.paymentDueDate!)} • ${entry.paymentDueCountdownText}',
                      ),
                    ],
                    if (!isCash && entry.chequeDetails != null) ...[
                      const Divider(height: 16),
                      _buildRow('Cheque No.', entry.chequeDetails!.chequeNo),
                      const Divider(height: 16),
                      _buildRow('Bank Name', entry.chequeDetails!.bankName),
                      const Divider(height: 16),
                      _buildRow('Cheque Date', Formatters.date(entry.chequeDetails!.chequeDate)),
                      const Divider(height: 16),
                      _buildRow('Cheque Amount', Formatters.currency(entry.chequeDetails!.chequeAmount)),
                      const Divider(height: 16),
                      _buildRow('Cheque Status', entry.chequeDetails!.status.label),
                    ],
                    if (entry.notes.isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildRow('Notes', entry.notes),
                    ],
                    const Divider(height: 16),
                    _buildRow(
                      'Created By',
                      '@${entry.createdBy} (${Formatters.dateTime(entry.createdAt)})',
                    ),
                    if (entry.lastModifiedBy != null) ...[
                      const Divider(height: 16),
                      _buildRow(
                        'Last Modified By',
                        '@${entry.lastModifiedBy} (${entry.lastModifiedAt != null ? Formatters.dateTime(entry.lastModifiedAt!) : 'Updated'})',
                      ),
                    ],
                    if (auth.canViewAuditLogs && challanLogs.isNotEmpty) ...[
                      const Divider(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.history, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'Modification History (${challanLogs.length}):',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...challanLogs.take(5).map((l) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Formatters.dateTime(l.timestamp),
                                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${l.description} by @${l.performedBy} [${l.userRole}]',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ACTION BUTTONS
              if (isMobile)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 10,
                  children: [
                    if (auth.canDelete)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warningText,
                          side: const BorderSide(color: AppColors.warningBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        onPressed: () => _showDeleteConfirm(context),
                      ),
                    if (auth.canPrintInvoice)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Invoice'),
                        onPressed: () => _openInvoiceDialog(context),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    if (auth.canEditChallan)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit Entry'),
                        onPressed: () => _openEdit(context),
                      ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (auth.canDelete)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warningText,
                          side: const BorderSide(color: AppColors.warningBorder),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        onPressed: () => _showDeleteConfirm(context),
                      )
                    else
                      const SizedBox.shrink(),
                    Row(
                      children: [
                        if (auth.canPrintInvoice) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                            ),
                            icon: const Icon(Icons.receipt_long, size: 18),
                            label: const Text('Tax Invoice (A4/A5)'),
                            onPressed: () => _openInvoiceDialog(context),
                          ),
                          const SizedBox(width: 8),
                        ],
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        if (auth.canEditChallan) ...[
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit Entry'),
                            onPressed: () => _openEdit(context),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: highlightColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

