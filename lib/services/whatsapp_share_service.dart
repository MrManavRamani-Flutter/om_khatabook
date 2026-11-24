import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/income_expense_entry.dart';
import '../providers/challan_provider.dart';
import '../utils/formatters.dart';

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

  /// Formats and shares the entire Net Profit & Loss statement for the filtered period
  static Future<void> shareProfitLossStatement(
    BuildContext context,
    ProfitLossCalculation calc,
    String periodLabel,
  ) async {
    final netLabel = calc.isProfit ? 'NET PROFIT (Surplus)' : 'NET LOSS (Deficit)';
    final netSymbol = calc.isProfit ? '+' : '-';

    final sb = StringBuffer();
    sb.writeln('*OM MAVTAR GROUP*');
    sb.writeln('*NET PROFIT & LOSS STATEMENT*');
    sb.writeln('--------------------------------');
    sb.writeln('📅 *Period:* $periodLabel');
    sb.writeln('💵 *Total Income:* Rs. ${Formatters.currency(calc.totalIncome)}');
    sb.writeln('💸 *Total Expenses:* Rs. ${Formatters.currency(calc.totalExpenses)}');
    sb.writeln('📊 *$netLabel:* $netSymbol Rs. ${Formatters.currency(calc.netAmount)}');
    sb.writeln('--------------------------------');
    if (calc.expenses.isNotEmpty) {
      sb.writeln('*Expenses Summary:*');
      for (final e in calc.expenses.take(10)) {
        sb.writeln('• ${e.particular}: Rs. ${Formatters.currency(e.amount)}');
      }
      if (calc.expenses.length > 10) {
        sb.writeln('... and ${calc.expenses.length - 10} more');
      }
      sb.writeln('--------------------------------');
    }
    sb.writeln('_Om Mavtar Group Khata Book_');

    await launchWhatsAppText(
      context,
      sb.toString(),
      successMessage: 'Opening WhatsApp with Net Profit & Loss Statement... Copied to clipboard!',
    );
  }
}
