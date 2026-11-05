import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/challan_entry.dart';
import '../utils/formatters.dart';

class ExportService {
  /// Generates a PDF document for the given challans
  static Future<Uint8List> generatePdfData({
    required List<ChallanEntry> entries,
    String title = 'OM Mavtar Group',
    String subtitle = 'Challan & Billing Ledger Report',
    String filterSummary = 'All Records',
    bool sortAscending = false,
  }) async {
    final pdf = pw.Document();

    final sorted = List<ChallanEntry>.from(entries);
    sorted.sort((a, b) =>
        sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

    final totalChallan =
        sorted.fold(0.0, (sum, item) => sum + item.challanAmount);
    final totalFinal = sorted.fold(0.0, (sum, item) => sum + item.finalAmount);
    final totalGst = sorted.fold(0.0, (sum, item) => sum + item.gstAmount);
    final totalUnpaid = sorted
        .where((c) =>
            (c.paymentOption == PaymentOption.cash && !c.isCashPaid) ||
            (c.paymentOption == PaymentOption.cheque &&
                c.chequeDetails?.status != ChequeStatus.cleared))
        .fold(0.0, (sum, item) => sum + item.finalAmount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => _buildPdfHeader(title, subtitle, filterSummary, context),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 10),
          _buildPdfKpiSummary(
            totalChallan: totalChallan,
            totalFinal: totalFinal,
            totalGst: totalGst,
            totalUnpaid: totalUnpaid,
            count: sorted.length,
          ),
          pw.SizedBox(height: 14),
          _buildPdfTable(sorted),
        ],
      ),
    );

    return await pdf.save();
  }

  /// Preview / Print PDF natively
  static Future<void> printOrPreviewPdf({
    required List<ChallanEntry> entries,
    String title = 'OM Mavtar Group',
    String subtitle = 'Challan & Billing Ledger Report',
    String filterSummary = 'All Records',
    bool sortAscending = false,
  }) async {
    final bytes = await generatePdfData(
      entries: entries,
      title: title,
      subtitle: subtitle,
      filterSummary: filterSummary,
      sortAscending: sortAscending,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'OM_Mavtar_Challan_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Saves PDF to the user's Documents folder and returns the file path
  static Future<String> savePdfToDocuments({
    required List<ChallanEntry> entries,
    String title = 'OM Mavtar Group',
    String subtitle = 'Challan & Billing Ledger Report',
    String filterSummary = 'All Records',
    bool sortAscending = false,
  }) async {
    final bytes = await generatePdfData(
      entries: entries,
      title: title,
      subtitle: subtitle,
      filterSummary: filterSummary,
      sortAscending: sortAscending,
    );

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'OM_Mavtar_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Generates and saves a Microsoft Excel (.xlsx) file in Documents folder
  static Future<String> generateAndSaveExcel({
    required List<ChallanEntry> entries,
    String title = 'OM Mavtar Group',
    String filterSummary = 'All Records',
    bool sortAscending = false,
  }) async {
    final sorted = List<ChallanEntry>.from(entries);
    sorted.sort((a, b) =>
        sortAscending ? a.date.compareTo(b.date) : b.date.compareTo(a.date));

    final excel = Excel.createExcel();
    final Sheet sheet = excel[excel.getDefaultSheet() ?? 'Challan Ledger'];

    // Title Row
    sheet.appendRow([
      TextCellValue(title),
      TextCellValue(''),
      TextCellValue('Challan & Billing Report'),
      TextCellValue(''),
      TextCellValue('Filter: $filterSummary'),
      TextCellValue('Generated: ${Formatters.date(DateTime.now())}'),
    ]);
    sheet.appendRow([TextCellValue('')]); // empty line

    // Table Headers
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Challan No.'),
      TextCellValue('Party Name'),
      TextCellValue('Challan Amount (INR)'),
      TextCellValue('Final Amount (INR)'),
      TextCellValue('GST Bill No.'),
      TextCellValue('GST Amount (INR)'),
      TextCellValue('Payment Option'),
      TextCellValue('Payment Status'),
      TextCellValue('Cheque No.'),
      TextCellValue('Bank Name'),
      TextCellValue('Cheque Date'),
      TextCellValue('Cheque Amount (INR)'),
      TextCellValue('Cheque Clearance'),
      TextCellValue('Notes'),
    ]);

    // Data Rows
    double sumChallan = 0.0;
    double sumFinal = 0.0;
    double sumGst = 0.0;

    for (var c in sorted) {
      sumChallan += c.challanAmount;
      sumFinal += c.finalAmount;
      sumGst += c.gstAmount;

      String chkNo = '';
      String chkBank = '';
      String chkDate = '';
      String chkAmt = '';
      String chkStatus = '';

      if (c.paymentOption == PaymentOption.cheque && c.chequeDetails != null) {
        chkNo = c.chequeDetails!.chequeNo;
        chkBank = c.chequeDetails!.bankName;
        chkDate = Formatters.date(c.chequeDetails!.chequeDate);
        chkAmt = c.chequeDetails!.chequeAmount.toStringAsFixed(2);
        chkStatus = c.chequeDetails!.status.label;
      }

      sheet.appendRow([
        TextCellValue(Formatters.date(c.date)),
        TextCellValue(c.challanNo),
        TextCellValue(c.partyName),
        DoubleCellValue(c.challanAmount),
        DoubleCellValue(c.finalAmount),
        TextCellValue(c.gstBillNo.isNotEmpty ? c.gstBillNo : '-'),
        DoubleCellValue(c.gstAmount),
        TextCellValue(c.paymentOption.label),
        TextCellValue(c.statusDisplay),
        TextCellValue(chkNo),
        TextCellValue(chkBank),
        TextCellValue(chkDate),
        TextCellValue(chkAmt),
        TextCellValue(chkStatus),
        TextCellValue(c.notes),
      ]);
    }

    // Total Row
    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue('${sorted.length} Entries'),
      DoubleCellValue(sumChallan),
      DoubleCellValue(sumFinal),
      TextCellValue(''),
      DoubleCellValue(sumGst),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'OM_Mavtar_Challans_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File('${dir.path}/$filename');

    final fileBytes = excel.save();
    if (fileBytes != null) {
      await file.writeAsBytes(fileBytes);
    }
    return file.path;
  }

  // --- PDF PRIVATE HELPERS ---
  static pw.Widget _buildPdfHeader(
    String title,
    String subtitle,
    String filterSummary,
    pw.Context context,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.teal800,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                subtitle,
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Filter: $filterSummary',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Date: ${Formatters.date(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'OM Mavtar Group Khata Book • Confidential Business Statement',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfKpiSummary({
    required double totalChallan,
    required double totalFinal,
    required double totalGst,
    required double totalUnpaid,
    required int count,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPdfKpiItem('Total Entries', '$count'),
          _buildPdfKpiItem('Challan Gross', Formatters.currency(totalChallan)),
          _buildPdfKpiItem('Final Billed', Formatters.currency(totalFinal), isBold: true),
          _buildPdfKpiItem('Total GST', Formatters.currency(totalGst)),
          _buildPdfKpiItem('Unpaid Dues', Formatters.currency(totalUnpaid), isWarning: totalUnpaid > 0),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfKpiItem(String label, String value,
      {bool isBold = false, bool isWarning = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: isWarning
                ? PdfColors.red800
                : (isBold ? PdfColors.teal900 : PdfColors.black),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildPdfTable(List<ChallanEntry> entries) {
    const headers = [
      'Date',
      'Challan #',
      'Party Name',
      'Challan Amt',
      'Final Amt',
      'GST Bill & Amt',
      'Payment Mode',
      'Status / Details',
    ];

    final data = entries.map((c) {
      final isCash = c.paymentOption == PaymentOption.cash;
      final isWarning = c.hasWarning;

      String details = '';
      if (!isCash && c.chequeDetails != null) {
        details =
            'Chk #${c.chequeDetails!.chequeNo} (${c.chequeDetails!.bankName}) - ${c.chequeDetails!.status.label}';
      } else {
        details = isWarning ? 'WARNING: UNPAID' : 'PAID';
      }

      return [
        Formatters.shortDate(c.date),
        c.challanNo,
        c.partyName,
        Formatters.currency(c.challanAmount),
        Formatters.currency(c.finalAmount),
        c.gstBillNo.isNotEmpty
            ? '${c.gstBillNo}\n${Formatters.currency(c.gstAmount)}'
            : '-',
        c.paymentOption.label,
        details,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.teal800,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      cellHeight: 24,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerLeft,
        6: pw.Alignment.center,
        7: pw.Alignment.centerLeft,
      },
    );
  }
}

