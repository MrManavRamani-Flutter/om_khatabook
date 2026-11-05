import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/challan_entry.dart';
import '../providers/challan_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/export_report_dialog.dart';

class SummaryReportsView extends StatelessWidget {
  const SummaryReportsView({super.key});

  void _openCustomReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const ExportReportDialog(),
    );
  }

  Future<void> _quickExportPdf(BuildContext context) async {
    final provider = context.read<ChallanProvider>();
    await ExportService.printOrPreviewPdf(
      entries: provider.filteredChallans,
      filterSummary: provider.activeFilterSummary,
      sortAscending: provider.sortAscending,
    );
  }

  Future<void> _quickExportExcel(BuildContext context) async {
    final provider = context.read<ChallanProvider>();
    try {
      final path = await ExportService.generateAndSaveExcel(
        entries: provider.filteredChallans,
        filterSummary: provider.activeFilterSummary,
        sortAscending: provider.sortAscending,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel (.xlsx) saved to: $path'),
            backgroundColor: AppColors.primary,
            action: SnackBarAction(
              label: 'Copy Path',
              textColor: Colors.white,
              onPressed: () => Clipboard.setData(ClipboardData(text: path)),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel export error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final challans = provider.challans;

    final totalChallan = provider.totalChallanAmount;
    final totalFinal = provider.totalFinalAmount;
    final totalGst = provider.totalGstAmount;
    final totalUnpaid = provider.totalUnpaidAmount;

    final cashChallans =
        challans.where((c) => c.paymentOption == PaymentOption.cash).toList();
    final chequeChallans =
        challans.where((c) => c.paymentOption == PaymentOption.cheque).toList();

    final cashPaidAmt =
        cashChallans.fold(0.0, (s, c) => s + c.paidAmount);
    final cashUnpaidAmt =
        cashChallans.fold(0.0, (s, c) => s + c.remainingAmount);

    final chequeClearedAmt = chequeChallans
        .where((c) => c.chequeDetails?.status == ChequeStatus.cleared)
        .fold(0.0, (s, c) => s + c.finalAmount);
    final chequePendingAmt = chequeChallans
        .where((c) => c.chequeDetails?.status == ChequeStatus.pending)
        .fold(0.0, (s, c) => s + c.finalAmount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER WITH ACTIONS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Financial & Billing Summary',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Comprehensive breakdown of billing, cash receipts, and cheque clearances',
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
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _quickExportPdf(context),
                      icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 18),
                      label: const Text('Quick PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _quickExportExcel(context),
                      icon: const Icon(Icons.table_chart, color: Color(0xFF15803D), size: 18),
                      label: const Text('Quick Excel'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openCustomReportDialog(context),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Custom Report Generator'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // OVERVIEW TILES
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'TOTAL BILLED',
                    Formatters.currency(totalFinal),
                    'Gross Challan: ${Formatters.currency(totalChallan)}',
                    AppColors.primary,
                    Icons.account_balance_wallet,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricTile(
                    'TOTAL GST BILLED',
                    Formatters.currency(totalGst),
                    'Across ${challans.where((c) => c.gstBillNo.isNotEmpty).length} Invoices',
                    const Color(0xFF7C3AED),
                    Icons.calculate,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricTile(
                    'PENDING / UNPAID DUES',
                    Formatters.currency(totalUnpaid),
                    '${provider.unpaidWarningCount} Entries Require Action',
                    AppColors.warningText,
                    Icons.warning_amber_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // DUAL BREAKDOWN: CASH vs CHEQUE
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CASH BREAKDOWN
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.money, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text(
                                'Cash Transactions Breakdown',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow('Total Cash Challans', '${cashChallans.length} Entries'),
                          const Divider(height: 16),
                          _buildStatRow(
                            'Cash Received & Cleared',
                            Formatters.currency(cashPaidAmt),
                            valueColor: AppColors.successText,
                          ),
                          const Divider(height: 16),
                          _buildStatRow(
                            '⚠️ Cash Pending / Unpaid',
                            Formatters.currency(cashUnpaidAmt),
                            valueColor: AppColors.warningText,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // CHEQUE BREAKDOWN
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance, color: AppColors.primary),
                              SizedBox(width: 10),
                              Text(
                                'Cheque Transactions Breakdown',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildStatRow('Total Cheque Challans', '${chequeChallans.length} Entries'),
                          const Divider(height: 16),
                          _buildStatRow(
                            'Cheques Cleared',
                            Formatters.currency(chequeClearedAmt),
                            valueColor: AppColors.successText,
                          ),
                          const Divider(height: 16),
                          _buildStatRow(
                            '⏳ Cheques Pending Clearance',
                            Formatters.currency(chequePendingAmt),
                            valueColor: AppColors.pendingText,
                            isBold: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, String subtitle, Color color, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                Icon(icon, size: 20, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
