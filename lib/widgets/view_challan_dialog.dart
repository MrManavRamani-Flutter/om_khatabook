import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../providers/challan_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'add_edit_challan_dialog.dart';

class ViewChallanDialog extends StatelessWidget {
  final ChallanEntry entry;

  const ViewChallanDialog({super.key, required this.entry});

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Challan Entry?'),
        content: Text(
          'Are you sure you want to permanently delete Challan #${entry.challanNo} for ${entry.partyName}?',
        ),
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
            onPressed: () {
              Navigator.of(ctx).pop(); // Close confirm
              context.read<ChallanProvider>().deleteChallan(entry.id);
              Navigator.of(context).pop(); // Close view dialog
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (_) => AddEditChallanDialog(entryToEdit: entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasWarning = entry.hasWarning;
    final isCash = entry.paymentOption == PaymentOption.cash;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                            ? 'ALERT: Partial Cash Payment (Paid: ${Formatters.currency(entry.paidAmount)} • Due: ${Formatters.currency(entry.remainingAmount)})'
                            : hasWarning
                                ? 'ALERT: Cash Payment is UNPAID / PENDING'
                                : (isCash && entry.isCashPaid)
                                    ? 'Cash Payment Received & Completed in Full'
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
                    const Divider(height: 16),
                    _buildRow('Challan Amount', Formatters.currency(entry.challanAmount)),
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
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ACTION BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warningText,
                      side: const BorderSide(color: AppColors.warningBorder),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    onPressed: () => _showDeleteConfirm(context),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
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

