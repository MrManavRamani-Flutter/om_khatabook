import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/income_expense_entry.dart';
import '../providers/challan_provider.dart';
import '../utils/formatters.dart';
import 'export_service.dart';

class WhatsAppShareService {
  /// Opens WhatsApp with pre-filled text and copies text to clipboard as safety fallback
  static Future<bool> launchWhatsAppText(
    BuildContext context,
    String text, {
    String? successMessage,
  }) async {
    // 1. Always copy to clipboard as reliable fallback
    await Clipboard.setData(ClipboardData(text: text));

    // 2. Launch WhatsApp URL
    final encoded = Uri.encodeComponent(text);
    final whatsappUri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');

    bool opened = false;
    try {
      if (await canLaunchUrl(whatsappUri)) {
        opened = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      opened = false;
    }

    if (!opened) {
      try {
        if (Platform.isMacOS) {
          await Process.run('open', [whatsappUri.toString()]);
          opened = true;
        } else if (Platform.isWindows) {
          await Process.run('cmd', ['/c', 'start', '', whatsappUri.toString()], runInShell: true);
          opened = true;
        } else if (Platform.isLinux) {
          await Process.run('xdg-open', [whatsappUri.toString()]);
          opened = true;
        }
      } catch (_) {
        opened = false;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  successMessage ??
                      'WhatsApp opened! Details also copied to clipboard.',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF15803D), // WhatsApp Green
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return opened;
  }

  /// Formats and shares a single expense or income entry to WhatsApp
  static Future<void> shareEntry(BuildContext context, IncomeExpenseEntry entry) async {
    final typeLabel = entry.isExpense ? 'EXPENSE DETAILS' : 'INCOME DETAILS';
    final amountText = Formatters.currency(entry.amount);
    final dateText = Formatters.date(entry.date);

    final sb = StringBuffer();
    sb.writeln('*OM MAVTAR GROUP*');
    sb.writeln('*$typeLabel*');
    sb.writeln('--------------------------------');
    sb.writeln('📌 *Particulars:* ${entry.particular}');
    sb.writeln('🏷️ *Category:* ${entry.category}');
    sb.writeln('📅 *Date:* $dateText');
    sb.writeln('💰 *Amount:* Rs. $amountText');
    if (entry.notes.trim().isNotEmpty) {
      sb.writeln('📝 *Notes / Calculation:* ${entry.notes.trim()}');
    }
    sb.writeln('--------------------------------');
    sb.writeln('_Om Mavtar Group Khata Book_');

    await launchWhatsAppText(
      context,
      sb.toString(),
      successMessage: 'Opening WhatsApp for "${entry.particular}" (₹$amountText)... Copied to clipboard!',
    );
  }

  /// Formats and shares the entire Net Profit & Loss statement for the filtered period as PDF and WhatsApp summary
  static Future<void> shareProfitLossStatement(
    BuildContext context,
    ProfitLossCalculation calc,
    String periodLabel,
  ) async {
    final provider = context.read<ChallanProvider>();
    final cName = provider.companyName;
    final cTagline = provider.companyTagline;

    String? pdfPath;
    Uint8List? pdfBytes;

    try {
      pdfBytes = await ExportService.generateProfitLossPdfData(
        calc: calc,
        periodLabel: periodLabel,
        companyName: cName,
        companyTagline: cTagline,
      );
      pdfPath = await ExportService.exportProfitLossPdf(
        calc: calc,
        periodLabel: periodLabel,
        companyName: cName,
        companyTagline: cTagline,
      );
    } catch (e) {
      debugPrint('Error generating Profit & Loss PDF: $e');
    }

    final netLabel = calc.isProfit ? 'NET PROFIT (Surplus)' : 'NET LOSS (Deficit)';
    final netSymbol = calc.isProfit ? '+' : '-';

    final sb = StringBuffer();
    sb.writeln('*${cName.toUpperCase()}*');
    sb.writeln('*NET PROFIT & LOSS FINANCIAL STATEMENT*');
    sb.writeln('--------------------------------');
    sb.writeln('📅 *Period:* $periodLabel');
    sb.writeln('💵 *Total Income:* Rs. ${Formatters.currency(calc.totalIncome)} (${calc.incomes.length} entries)');
    sb.writeln('💸 *Total Expenses:* Rs. ${Formatters.currency(calc.totalExpenses)} (${calc.expenses.length} entries)');
    sb.writeln('--------------------------------');
    sb.writeln('📊 *CONCLUSION: $netLabel*');
    sb.writeln('💰 *Net Balance:* $netSymbol Rs. ${Formatters.currency(calc.netAmount)}');
    sb.writeln('--------------------------------');
    if (pdfPath != null) {
      sb.writeln('📄 *Complete PDF Statement generated:*');
      sb.writeln(File(pdfPath).uri.pathSegments.last);
    }
    sb.writeln('_Generated by OM Mavtar Group Khata Book_');

    if (!context.mounted) return;

    // Show PDF & WhatsApp Share Confirmation Dialog
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final resultColor = calc.isProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Color(0xFF16A34A), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net Profit & Loss Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('PDF Statement with Expenses & Income Tables', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PERIOD BANNER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).dividerColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Period: $periodLabel', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // SUMMARY METRICS
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL INCOME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                            const SizedBox(height: 2),
                            Text('₹ ${Formatters.currency(calc.totalIncome)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('${calc.incomes.length} records', style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TOTAL EXPENSES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
                            const SizedBox(height: 2),
                            Text('₹ ${Formatters.currency(calc.totalExpenses)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('${calc.expenses.length} records', style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // CONCLUSION CARD
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: resultColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(calc.isProfit ? Icons.trending_up : Icons.trending_down, color: resultColor, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              calc.isProfit ? '🎉 NET PROFIT (SURPLUS)' : '⚠️ NET LOSS (DEFICIT)',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: resultColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${calc.isProfit ? '+' : '-'} ₹ ${Formatters.currency(calc.netAmount)}',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: resultColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (pdfPath != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '✓ PDF saved: ${File(pdfPath).uri.pathSegments.last}',
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            if (pdfBytes != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF0F766E)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('Open / Print PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Printing.layoutPdf(
                    onLayout: (format) async => pdfBytes!,
                    name: 'OM_Mavtar_Profit_Loss_${DateTime.now().millisecondsSinceEpoch}',
                  );
                },
              ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.share, size: 16),
              label: const Text('Share (WhatsApp)', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(ctx).pop();
                launchWhatsAppText(
                  context,
                  sb.toString(),
                  successMessage: 'Opening WhatsApp with Profit & Loss Statement... Summary copied to clipboard!',
                );
              },
            ),
          ],
        );
      },
    );
  }
}
