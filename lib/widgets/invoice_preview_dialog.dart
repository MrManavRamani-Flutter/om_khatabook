import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/challan_provider.dart';
import '../services/export_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class InvoicePreviewDialog extends StatefulWidget {
  final ChallanEntry entry;
  final Party? party;

  const InvoicePreviewDialog({
    super.key,
    required this.entry,
    this.party,
  });

  @override
  State<InvoicePreviewDialog> createState() => _InvoicePreviewDialogState();
}

class _InvoicePreviewDialogState extends State<InvoicePreviewDialog> {
  PdfPageFormat _selectedPageFormat = PdfPageFormat.a4;
  bool _isSaving = false;

  Future<void> _handleSavePdf(StorageService storage) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    try {
      final path = await ExportService.saveSingleInvoicePdfToDocuments(
        entry: widget.entry,
        party: widget.party,
        pageFormat: _selectedPageFormat,
        companyName: storage.companyName,
        companyTagline: storage.companyTagline,
        customLogoBytes: storage.appLogoBase64.isNotEmpty
            ? base64Decode(storage.appLogoBase64)
            : null,
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tax invoice saved to Documents:\n$path',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.successText,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save PDF: $e'),
            backgroundColor: AppColors.warningText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDirectPrint(StorageService storage) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ExportService.printOrPreviewSingleInvoice(
        entry: widget.entry,
        party: widget.party,
        pageFormat: _selectedPageFormat,
        companyName: storage.companyName,
        companyTagline: storage.companyTagline,
        customLogoBytes: storage.appLogoBase64.isNotEmpty
            ? base64Decode(storage.appLogoBase64)
            : null,
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Print dialog error: $e'),
            backgroundColor: AppColors.warningText,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.read<StorageService>();
    final provider = context.watch<ChallanProvider>();
    final isA4 = _selectedPageFormat == PdfPageFormat.a4;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 720;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 24,
        vertical: isMobile ? 10 : 20,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 960,
          maxHeight: 820,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TOP MODAL TOOLBAR
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 10 : 14,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Tax Invoice',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '#${widget.entry.challanNo}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    provider.formatCasedText(widget.entry.partyName),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildFormatToggleOption(
                                    label: 'A4',
                                    isSelected: isA4,
                                    onTap: () {
                                      if (!isA4) setState(() => _selectedPageFormat = PdfPageFormat.a4);
                                    },
                                  ),
                                  _buildFormatToggleOption(
                                    label: 'A5',
                                    isSelected: !isA4,
                                    onTap: () {
                                      if (isA4) setState(() => _selectedPageFormat = PdfPageFormat.a5);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download_outlined, size: 16),
                              label: const Text('Save PDF', style: TextStyle(fontSize: 12)),
                              onPressed: _isSaving ? null : () => _handleSavePdf(storage),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              icon: const Icon(Icons.print, size: 16),
                              label: const Text('Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _handleDirectPrint(storage),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Commercial GST Tax Invoice',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${widget.entry.challanNo}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Party: ${provider.formatCasedText(widget.entry.partyName)} • Date: ${Formatters.date(widget.entry.date)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // A4 vs A5 FORMAT SWITCHER
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildFormatToggleOption(
                                label: 'A4 (Full Page)',
                                isSelected: isA4,
                                onTap: () {
                                  if (!isA4) {
                                    setState(() => _selectedPageFormat = PdfPageFormat.a4);
                                  }
                                },
                              ),
                              const SizedBox(width: 2),
                              _buildFormatToggleOption(
                                label: 'A5 (Compact Slip)',
                                isSelected: !isA4,
                                onTap: () {
                                  if (isA4) {
                                    setState(() => _selectedPageFormat = PdfPageFormat.a5);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // SAVE PDF BUTTON
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Save PDF', style: TextStyle(fontSize: 13)),
                          onPressed: _isSaving ? null : () => _handleSavePdf(storage),
                        ),
                        const SizedBox(width: 8),

                        // DIRECT PRINT BUTTON
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Print Invoice', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          onPressed: () => _handleDirectPrint(storage),
                        ),
                        const SizedBox(width: 8),

                        // CLOSE BUTTON
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Close Preview',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
            ),

            // INTERACTIVE PDF PREVIEW BODY
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: PdfPreview(
                  key: ValueKey(_selectedPageFormat),
                  build: (format) => ExportService.generateSingleInvoicePdfData(
                    entry: widget.entry,
                    party: widget.party,
                    pageFormat: _selectedPageFormat,
                    companyName: storage.companyName,
                    companyTagline: storage.companyTagline,
                    companyAddress: storage.companyAddress,
                    companyGstin: storage.companyGstin,
                    companyPhone: storage.companyPhone,
                    companyEmail: storage.companyEmail,
                    bankName: storage.bankName,
                    bankAccountNo: storage.bankAccountNo,
                    bankIfsc: storage.bankIfsc,
                    bankBranch: storage.bankBranch,
                    customLogoBytes: storage.appLogoBase64.isNotEmpty
                        ? base64Decode(storage.appLogoBase64)
                        : null,
                  ),
                  initialPageFormat: _selectedPageFormat,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: true,
                  allowSharing: true,
                  maxPageWidth: 720,
                  pdfFileName: 'Tax_Invoice_${widget.entry.challanNo}.pdf',
                  loadingWidget: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Rendering Single-Page Tax Invoice...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatToggleOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}
