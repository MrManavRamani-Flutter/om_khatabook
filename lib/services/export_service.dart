import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/audit_log_entry.dart';
import '../models/challan_entry.dart';
import '../models/party.dart';
import '../providers/challan_provider.dart';
import '../utils/formatters.dart';

class ExportService {
  /// Generates a PDF document for the given challans (Multi-row Report)
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
    final totalUnpaid = sorted.fold(0.0, (sum, c) {
      if (c.paymentOption == PaymentOption.cash) {
        return sum + c.remainingAmount;
      } else if (c.chequeDetails?.status != ChequeStatus.cleared) {
        return sum + c.finalAmount;
      }
      return sum;
    });

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

  // =========================================================================
  // SINGLE-PAGE COMMERCIAL GST TAX INVOICE PRINTING (A4 / A5)
  // =========================================================================

  /// Generates a Single-Page Commercial GST Tax Invoice PDF (in A4 or A5 format)
  static Future<Uint8List> generateSingleInvoicePdfData({
    required ChallanEntry entry,
    Party? party,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    String? companyName,
    String? companyTagline,
    String? companyAddress,
    String? companyGstin,
    String? companyPhone,
    String? companyEmail,
    String? bankName,
    String? bankAccountNo,
    String? bankIfsc,
    String? bankBranch,
    Uint8List? customLogoBytes,
  }) async {
    final pdf = pw.Document();
    final isA5 = pageFormat == PdfPageFormat.a5;

    // Load logo image if available
    pw.MemoryImage? logoImage;
    if (customLogoBytes != null && customLogoBytes.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(customLogoBytes);
      } catch (e) {
        debugPrint('Custom logo image parse error: $e');
      }
    }
    if (logoImage == null) {
      try {
        final logoAsset = await rootBundle.load('assets/logo/app_logo.png');
        logoImage = pw.MemoryImage(logoAsset.buffer.asUint8List());
      } catch (e) {
        debugPrint('Default logo asset load error: $e');
      }
    }

    final cName = (companyName != null && companyName.isNotEmpty)
        ? companyName
        : 'OM MAVTAR GROUP';
    final cTagline = (companyTagline != null && companyTagline.isNotEmpty)
        ? companyTagline
        : 'Commercial Textile Trading & Challan Ledger';
    final cAddress = companyAddress ?? 'Ring Road, Surat, Gujarat - 395002';
    final cGstin = companyGstin ?? '24AAAFO8899M1Z3';
    final cPhone = companyPhone ?? '+91 98250 12345';
    final cEmail = companyEmail ?? 'om.mavtar.group@gmail.com';

    final bBankName = bankName ?? 'State Bank of India';
    final bAccount = bankAccountNo ?? '39820011002233';
    final bIfsc = bankIfsc ?? 'SBIN0001234';
    final bBranch = bankBranch ?? 'Ring Road Branch, Surat';

    final buyerName = (party != null && party.name.isNotEmpty)
        ? party.name
        : entry.partyName;
    final buyerAddress = (party != null && party.address.isNotEmpty)
        ? party.address
        : 'Ring Road, Surat, Gujarat';
    final buyerPhone = (party != null && party.phone.isNotEmpty)
        ? party.phone
        : '-';
    final buyerGstin = (party != null && party.gstNumber.isNotEmpty)
        ? party.gstNumber
        : 'URP (Unregistered)';

    final baseAmount =
        entry.finalAmount > 0 ? entry.finalAmount : entry.challanAmount;
    final taxableValue = baseAmount;
    final gstAmount = entry.gstAmount;
    final hasGst = gstAmount > 0 || entry.gstBillNo.isNotEmpty;

    // Determine GST rate %
    double effectiveGstRate = 0.0;
    if (taxableValue > 0 && gstAmount > 0) {
      effectiveGstRate = (gstAmount / taxableValue) * 100.0;
    }

    final cgstRate = effectiveGstRate / 2.0;
    final sgstRate = effectiveGstRate / 2.0;
    final cgstAmount = gstAmount / 2.0;
    final sgstAmount = gstAmount / 2.0;
    final totalInvoiceAmount = taxableValue + (hasGst ? gstAmount : 0.0);
    final paidAmount = entry.paidAmount;
    final remainingDue =
        (totalInvoiceAmount - paidAmount).clamp(0.0, double.infinity);
    final amountInWords = Formatters.numberToWords(totalInvoiceAmount);
    final invoiceNumber = entry.gstBillNo.isNotEmpty
        ? entry.gstBillNo
        : 'INV-${entry.challanNo}';

    // Real QR Code data string for verification
    final qrData =
        'GSTIN:$cGstin|INV:$invoiceNumber|DATE:${Formatters.shortDate(entry.date)}|VAL:${totalInvoiceAmount.toStringAsFixed(2)}|TAX:${gstAmount.toStringAsFixed(2)}|BUYER:${buyerGstin.startsWith('URP') ? 'URP' : buyerGstin}';

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: isA5
            ? const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12)
            : const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.grey800,
                width: isA5 ? 0.75 : 1.0,
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. TOP HEADER BANNER
                _buildInvoiceHeaderBanner(isA5),

                // 2. SUPPLIER & INVOICE META
                _buildSupplierAndInvoiceMeta(
                  isA5: isA5,
                  logoImage: logoImage,
                  companyName: cName,
                  companyTagline: cTagline,
                  companyAddress: cAddress,
                  companyGstin: cGstin,
                  companyPhone: cPhone,
                  companyEmail: cEmail,
                  invoiceNumber: invoiceNumber,
                  challanNo: entry.challanNo,
                  date: entry.date,
                ),

                // DIVIDER
                pw.Container(height: 1, color: PdfColors.grey700),

                // 3. BUYER (BILL TO) & TRANSPORT / PAYMENT PARTICULARS
                _buildBuyerAndPaymentMeta(
                  isA5: isA5,
                  buyerName: buyerName,
                  buyerAddress: buyerAddress,
                  buyerPhone: buyerPhone,
                  buyerGstin: buyerGstin,
                  entry: entry,
                ),

                // DIVIDER
                pw.Container(height: 1, color: PdfColors.grey700),

                // 4. ITEMS & TAX CALCULATION TABLE
                _buildInvoiceItemsTable(
                  isA5: isA5,
                  challanNo: entry.challanNo,
                  taxableValue: taxableValue,
                  hasGst: hasGst,
                  effectiveGstRate: effectiveGstRate,
                  cgstRate: cgstRate,
                  sgstRate: sgstRate,
                  cgstAmount: cgstAmount,
                  sgstAmount: sgstAmount,
                  gstAmount: gstAmount,
                  totalInvoiceAmount: totalInvoiceAmount,
                ),

                // DIVIDER
                pw.Container(height: 1, color: PdfColors.grey700),

                // 5. AMOUNT IN WORDS & SETTLEMENT SUMMARY
                _buildAmountInWordsAndSettlement(
                  isA5: isA5,
                  amountInWords: amountInWords,
                  totalInvoiceAmount: totalInvoiceAmount,
                  paidAmount: paidAmount,
                  remainingDue: remainingDue,
                  entry: entry,
                ),

                // DIVIDER
                pw.Container(height: 1, color: PdfColors.grey700),

                // 6. LOWER GRID: BANK DETAILS, QR CODE, TERMS & SIGNATURES
                _buildInvoiceFooterGrid(
                  isA5: isA5,
                  companyName: cName,
                  bankName: bBankName,
                  bankAccount: bAccount,
                  bankIfsc: bIfsc,
                  bankBranch: bBranch,
                  qrData: qrData,
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Print or preview single tax invoice using native OS print dialog
  static Future<void> printOrPreviewSingleInvoice({
    required ChallanEntry entry,
    Party? party,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    String? companyName,
    String? companyTagline,
    Uint8List? customLogoBytes,
  }) async {
    final bytes = await generateSingleInvoicePdfData(
      entry: entry,
      party: party,
      pageFormat: pageFormat,
      companyName: companyName,
      companyTagline: companyTagline,
      customLogoBytes: customLogoBytes,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Tax_Invoice_${entry.challanNo}.pdf',
    );
  }

  /// Saves single tax invoice PDF to the user's Documents folder
  static Future<String> saveSingleInvoicePdfToDocuments({
    required ChallanEntry entry,
    Party? party,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    String? companyName,
    String? companyTagline,
    Uint8List? customLogoBytes,
  }) async {
    final bytes = await generateSingleInvoicePdfData(
      entry: entry,
      party: party,
      pageFormat: pageFormat,
      companyName: companyName,
      companyTagline: companyTagline,
      customLogoBytes: customLogoBytes,
    );

    final dir = await getApplicationDocumentsDirectory();
    final cleanParty = entry.partyName
        .replaceAll(RegExp(r'[^\w\s]+'), '')
        .replaceAll(' ', '_');
    final filename =
        'Tax_Invoice_${entry.challanNo}_${cleanParty}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // --- SUB-WIDGETS FOR SINGLE-PAGE TAX INVOICE ---

  static pw.Widget _buildInvoiceHeaderBanner(bool isA5) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(
        horizontal: isA5 ? 6 : 10,
        vertical: isA5 ? 3 : 5,
      ),
      decoration: const pw.BoxDecoration(color: PdfColors.teal900),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'COMMERCIAL TAX INVOICE',
            style: pw.TextStyle(
              fontSize: isA5 ? 9.0 : 12.0,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(
              horizontal: isA5 ? 4 : 6,
              vertical: isA5 ? 1 : 2,
            ),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.white, width: 0.5),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Text(
              'ORIGINAL FOR RECIPIENT',
              style: pw.TextStyle(
                fontSize: isA5 ? 6.0 : 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSupplierAndInvoiceMeta({
    required bool isA5,
    pw.MemoryImage? logoImage,
    required String companyName,
    required String companyTagline,
    required String companyAddress,
    required String companyGstin,
    required String companyPhone,
    required String companyEmail,
    required String invoiceNumber,
    required String challanNo,
    required DateTime date,
  }) {
    final pad = isA5 ? 4.0 : 6.0;
    final labelSize = isA5 ? 6.5 : 8.0;
    final titleSize = isA5 ? 10.0 : 13.0;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Seller Details
        pw.Expanded(
          flex: 3,
          child: pw.Padding(
            padding: pw.EdgeInsets.all(pad),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (logoImage != null) ...[
                      pw.Container(
                        width: isA5 ? 26 : 36,
                        height: isA5 ? 26 : 36,
                        child: pw.Image(logoImage),
                      ),
                      pw.SizedBox(width: isA5 ? 5 : 8),
                    ],
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            companyName,
                            style: pw.TextStyle(
                              fontSize: titleSize,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900,
                            ),
                          ),
                          pw.Text(
                            companyTagline,
                            style: pw.TextStyle(
                              fontSize: labelSize,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: isA5 ? 2 : 4),
                pw.Text(
                  companyAddress,
                  style: pw.TextStyle(
                      fontSize: labelSize, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 1),
                pw.Row(
                  children: [
                    pw.Text('GSTIN: ',
                        style: pw.TextStyle(
                            fontSize: labelSize,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(companyGstin,
                        style: pw.TextStyle(
                            fontSize: labelSize,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900)),
                    pw.SizedBox(width: 8),
                    pw.Text('State Code: 24 (Gujarat)',
                        style: pw.TextStyle(fontSize: labelSize)),
                  ],
                ),
                pw.Text(
                  'Phone: $companyPhone | Email: $companyEmail',
                  style: pw.TextStyle(
                      fontSize: labelSize, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ),
        // Vertical Divider
        pw.Container(width: 1, color: PdfColors.grey700),
        // Right: Invoice Metadata
        pw.Expanded(
          flex: 2,
          child: pw.Padding(
            padding: pw.EdgeInsets.all(pad),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildMetaRow('Invoice No.:', invoiceNumber, isA5,
                    isBoldVal: true),
                _buildMetaRow('Invoice Date:', Formatters.date(date), isA5),
                _buildMetaRow('Challan No.:', challanNo, isA5, isBoldVal: true),
                _buildMetaRow('Challan Date:', Formatters.date(date), isA5),
                _buildMetaRow('Place of Supply:', 'Gujarat (24)', isA5),
                _buildMetaRow('Reverse Charge:', 'No', isA5),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildBuyerAndPaymentMeta({
    required bool isA5,
    required String buyerName,
    required String buyerAddress,
    required String buyerPhone,
    required String buyerGstin,
    required ChallanEntry entry,
  }) {
    final pad = isA5 ? 4.0 : 6.0;
    final labelSize = isA5 ? 6.5 : 8.0;
    final headerSize = isA5 ? 7.5 : 9.0;
    final titleSize = isA5 ? 8.5 : 10.5;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Buyer (Bill To)
        pw.Expanded(
          flex: 3,
          child: pw.Padding(
            padding: pw.EdgeInsets.all(pad),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BILLED TO / BUYER DETAILS:',
                  style: pw.TextStyle(
                    fontSize: headerSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal900,
                  ),
                ),
                pw.SizedBox(height: isA5 ? 2 : 3),
                pw.Text(
                  buyerName,
                  style: pw.TextStyle(
                    fontSize: titleSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  buyerAddress,
                  style: pw.TextStyle(
                      fontSize: labelSize, color: PdfColors.grey800),
                ),
                pw.Text(
                  'Contact: $buyerPhone',
                  style: pw.TextStyle(
                      fontSize: labelSize, color: PdfColors.grey800),
                ),
                pw.Row(
                  children: [
                    pw.Text('Buyer GSTIN: ',
                        style: pw.TextStyle(
                            fontSize: labelSize,
                            fontWeight: pw.FontWeight.bold)),
                    pw.Text(buyerGstin,
                        style: pw.TextStyle(
                            fontSize: labelSize,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900)),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Vertical Divider
        pw.Container(width: 1, color: PdfColors.grey700),
        // Right: Dispatch / Payment
        pw.Expanded(
          flex: 2,
          child: pw.Padding(
            padding: pw.EdgeInsets.all(pad),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PAYMENT & DISPATCH PARTICULARS:',
                  style: pw.TextStyle(
                    fontSize: headerSize,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.teal900,
                  ),
                ),
                pw.SizedBox(height: isA5 ? 2 : 3),
                _buildMetaRow(
                    'Payment Mode:', entry.paymentOption.label, isA5,
                    isBoldVal: true),
                _buildMetaRow('Payment Status:', entry.statusDisplay, isA5),
                if (entry.paymentOption == PaymentOption.cheque &&
                    entry.chequeDetails != null) ...[
                  _buildMetaRow(
                      'Cheque #:', entry.chequeDetails!.chequeNo, isA5),
                  _buildMetaRow(
                      'Bank:', entry.chequeDetails!.bankName, isA5),
                ],
                _buildMetaRow(
                    'Remarks:',
                    entry.notes.isNotEmpty
                        ? entry.notes
                        : 'Goods Delivered via Challan',
                    isA5),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInvoiceItemsTable({
    required bool isA5,
    required String challanNo,
    required double taxableValue,
    required bool hasGst,
    required double effectiveGstRate,
    required double cgstRate,
    required double sgstRate,
    required double cgstAmount,
    required double sgstAmount,
    required double gstAmount,
    required double totalInvoiceAmount,
  }) {
    final headerPad = isA5
        ? const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3)
        : const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5);
    final cellPad = isA5
        ? const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3)
        : const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4);

    final hSize = isA5 ? 6.5 : 8.0;
    final dSize = isA5 ? 6.5 : 8.0;

    return pw.Table(
      border: pw.TableBorder.all(
          color: PdfColors.grey700, width: isA5 ? 0.5 : 0.75),
      columnWidths: isA5
          ? const {
              0: pw.FixedColumnWidth(16),
              1: pw.FlexColumnWidth(3.0),
              2: pw.FixedColumnWidth(32),
              3: pw.FixedColumnWidth(26),
              4: pw.FixedColumnWidth(48),
              5: pw.FixedColumnWidth(48),
              6: pw.FixedColumnWidth(48),
              7: pw.FixedColumnWidth(52),
            }
          : const {
              0: pw.FixedColumnWidth(22),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FixedColumnWidth(42),
              3: pw.FixedColumnWidth(34),
              4: pw.FixedColumnWidth(68),
              5: pw.FixedColumnWidth(68),
              6: pw.FixedColumnWidth(68),
              7: pw.FixedColumnWidth(74),
            },
      children: [
        // HEADER ROW
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
                padding: headerPad,
                child: pw.Text('Sr.',
                    style: pw.TextStyle(
                        fontSize: hSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center)),
            pw.Padding(
                padding: headerPad,
                child: pw.Text('Description of Goods / Fabrics',
                    style: pw.TextStyle(
                        fontSize: hSize, fontWeight: pw.FontWeight.bold))),
            pw.Padding(
                padding: headerPad,
                child: pw.Text('HSN/SAC',
                    style: pw.TextStyle(
                        fontSize: hSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center)),
            pw.Padding(
                padding: headerPad,
                child: pw.Text('Qty',
                    style: pw.TextStyle(
                        fontSize: hSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center)),
            pw.Padding(
                padding: headerPad,
                child: pw.Text('Taxable (Rs.)',
                    style: pw.TextStyle(
                        fontSize: hSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
            pw.Padding(
                padding: headerPad,
                child: pw.Text('CGST',
                    style: pw.TextStyle(
                        fontSize: hSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
            pw.Padding(
                padding: headerPad,
                child: pw.Text('SGST',
                    style: pw.TextStyle(
                        fontSize: hSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
            pw.Padding(
                padding: headerPad,
                child: pw.Text('Total (Rs.)',
                    style: pw.TextStyle(
                        fontSize: hSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
          ],
        ),
        // ITEM ROW
        pw.TableRow(
          children: [
            pw.Padding(
                padding: cellPad,
                child: pw.Text('1',
                    style: pw.TextStyle(fontSize: dSize),
                    textAlign: pw.TextAlign.center)),
            pw.Padding(
              padding: cellPad,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('COMMERCIAL TEXTILE FABRICS',
                      style: pw.TextStyle(
                          fontSize: dSize, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Dispatched as per Delivery Challan #$challanNo',
                      style: pw.TextStyle(
                          fontSize: isA5 ? 5.5 : 7.0,
                          color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.Padding(
                padding: cellPad,
                child: pw.Text('5407',
                    style: pw.TextStyle(fontSize: dSize),
                    textAlign: pw.TextAlign.center)),
            pw.Padding(
                padding: cellPad,
                child: pw.Text('1 LOT',
                    style: pw.TextStyle(fontSize: dSize),
                    textAlign: pw.TextAlign.center)),
            pw.Padding(
                padding: cellPad,
                child: pw.Text(Formatters.currencyPdf(taxableValue),
                    style: pw.TextStyle(fontSize: dSize),
                    textAlign: pw.TextAlign.right)),
            pw.Padding(
              padding: cellPad,
              child: pw.Text(
                hasGst
                    ? '${cgstRate.toStringAsFixed(1)}%\n${Formatters.currencyPdf(cgstAmount)}'
                    : '0.0%',
                style: pw.TextStyle(fontSize: dSize),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: cellPad,
              child: pw.Text(
                hasGst
                    ? '${sgstRate.toStringAsFixed(1)}%\n${Formatters.currencyPdf(sgstAmount)}'
                    : '0.0%',
                style: pw.TextStyle(fontSize: dSize),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Padding(
              padding: cellPad,
              child: pw.Text(
                Formatters.currencyPdf(totalInvoiceAmount),
                style: pw.TextStyle(
                    fontSize: dSize, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        // TOTAL SUMMARY ROW
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(
                padding: cellPad,
                child: pw.Text('', style: pw.TextStyle(fontSize: dSize))),
            pw.Padding(
                padding: cellPad,
                child: pw.Text('TOTAL AMOUNT',
                    style: pw.TextStyle(
                        fontSize: dSize, fontWeight: pw.FontWeight.bold))),
            pw.Padding(
                padding: cellPad,
                child: pw.Text('', style: pw.TextStyle(fontSize: dSize))),
            pw.Padding(
                padding: cellPad,
                child: pw.Text('', style: pw.TextStyle(fontSize: dSize))),
            pw.Padding(
                padding: cellPad,
                child: pw.Text(Formatters.currencyPdf(taxableValue),
                    style: pw.TextStyle(
                        fontSize: dSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
            pw.Padding(
                padding: cellPad,
                child: pw.Text(Formatters.currencyPdf(cgstAmount),
                    style: pw.TextStyle(
                        fontSize: dSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
            pw.Padding(
                padding: cellPad,
                child: pw.Text(Formatters.currencyPdf(sgstAmount),
                    style: pw.TextStyle(
                        fontSize: dSize, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
            pw.Padding(
                padding: cellPad,
                child: pw.Text(Formatters.currencyPdf(totalInvoiceAmount),
                    style: pw.TextStyle(
                        fontSize: dSize,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.teal900),
                    textAlign: pw.TextAlign.right)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildAmountInWordsAndSettlement({
    required bool isA5,
    required String amountInWords,
    required double totalInvoiceAmount,
    required double paidAmount,
    required double remainingDue,
    required ChallanEntry entry,
  }) {
    final pad = isA5 ? 3.0 : 5.0;
    final fontSize = isA5 ? 6.5 : 8.0;

    return pw.Padding(
      padding: pw.EdgeInsets.all(pad),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'Amount in Words: ',
                style: pw.TextStyle(
                    fontSize: fontSize, fontWeight: pw.FontWeight.bold),
              ),
              pw.Expanded(
                child: pw.Text(
                  amountInWords,
                  style: pw.TextStyle(
                      fontSize: fontSize, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: isA5 ? 2 : 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Gross Invoice: ${Formatters.currencyPdf(totalInvoiceAmount)}',
                style: pw.TextStyle(
                    fontSize: fontSize, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Amount Received: ${Formatters.currencyPdf(paidAmount)}',
                style: pw.TextStyle(
                    fontSize: fontSize,
                    color: PdfColors.green800,
                    fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Balance Due: ${Formatters.currencyPdf(remainingDue)}',
                style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight: pw.FontWeight.bold,
                  color: remainingDue > 0 ? PdfColors.red800 : PdfColors.teal800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInvoiceFooterGrid({
    required bool isA5,
    required String companyName,
    required String bankName,
    required String bankAccount,
    required String bankIfsc,
    required String bankBranch,
    required String qrData,
  }) {
    final pad = isA5 ? 4.0 : 6.0;
    final labelSize = isA5 ? 6.0 : 7.5;
    final headerSize = isA5 ? 7.0 : 8.5;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: Bank Details & Terms
        pw.Expanded(
          flex: 3,
          child: pw.Padding(
            padding: pw.EdgeInsets.all(pad),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'BANK ACCOUNT DETAILS:',
                  style: pw.TextStyle(
                      fontSize: headerSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900),
                ),
                pw.SizedBox(height: 1),
                pw.Text('Bank: $bankName',
                    style: pw.TextStyle(fontSize: labelSize)),
                pw.Text('A/C No.: $bankAccount',
                    style: pw.TextStyle(
                        fontSize: labelSize, fontWeight: pw.FontWeight.bold)),
                pw.Text('IFSC: $bankIfsc | Branch: $bankBranch',
                    style: pw.TextStyle(fontSize: labelSize)),
                pw.SizedBox(height: isA5 ? 2 : 4),
                pw.Text(
                  'TERMS & CONDITIONS:',
                  style: pw.TextStyle(
                      fontSize: headerSize,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.teal900),
                ),
                pw.Text('1. Goods once sold will not be taken back.',
                    style: pw.TextStyle(
                        fontSize: isA5 ? 5.5 : 7.0, color: PdfColors.grey700)),
                pw.Text('2. Subject to Surat jurisdiction only.',
                    style: pw.TextStyle(
                        fontSize: isA5 ? 5.5 : 7.0, color: PdfColors.grey700)),
              ],
            ),
          ),
        ),
        // Vertical Divider
        pw.Container(width: 1, color: PdfColors.grey700),
        // Center: Real QR Code
        pw.Padding(
          padding: pw.EdgeInsets.all(pad),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrData,
                width: isA5 ? 42 : 56,
                height: isA5 ? 42 : 56,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Official GST Verification',
                style: pw.TextStyle(
                    fontSize: isA5 ? 5.0 : 6.5, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        // Vertical Divider
        pw.Container(width: 1, color: PdfColors.grey700),
        // Right: Signatures
        pw.Expanded(
          flex: 2,
          child: pw.Padding(
            padding: pw.EdgeInsets.all(pad),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Customer / Receiver Signature',
                  style: pw.TextStyle(
                      fontSize: labelSize, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: isA5 ? 18 : 28),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'For $companyName',
                      style: pw.TextStyle(
                          fontSize: labelSize, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '[ Authorized Signatory ]',
                      style: pw.TextStyle(
                          fontSize: labelSize,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildMetaRow(String label, String value, bool isA5,
      {bool isBoldVal = false}) {
    final fontSize = isA5 ? 6.5 : 8.0;
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: isA5 ? 0.75 : 1.25),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: isA5 ? 55 : 75,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: fontSize, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight:
                    isBoldVal ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // EXCEL (.XLSX) GENERATION
  // =========================================================================

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
      TextCellValue('Design No.'),
      TextCellValue('Challan Amount (INR)'),
      TextCellValue('Discount (INR)'),
      TextCellValue('Final Amount (INR)'),
      TextCellValue('Paid Amount (INR)'),
      TextCellValue('Balance Due (INR)'),
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
    double sumDiscount = 0.0;
    double sumFinal = 0.0;
    double sumPaid = 0.0;
    double sumDue = 0.0;
    double sumGst = 0.0;

    for (var c in sorted) {
      sumChallan += c.challanAmount;
      sumDiscount += c.discountAmount;
      sumFinal += c.finalAmount;
      sumPaid += c.paidAmount;
      final due = c.paymentOption == PaymentOption.cash
          ? c.remainingAmount
          : (c.chequeDetails?.status != ChequeStatus.cleared
              ? c.finalAmount
              : 0.0);
      sumDue += due;
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
        TextCellValue(c.designNo.isNotEmpty ? c.designNo : '-'),
        DoubleCellValue(c.challanAmount),
        DoubleCellValue(c.discountAmount),
        DoubleCellValue(c.finalAmount),
        DoubleCellValue(c.paidAmount),
        DoubleCellValue(due),
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
      TextCellValue(''), // Design No. (blank for total)
      DoubleCellValue(sumChallan),
      DoubleCellValue(sumDiscount),
      DoubleCellValue(sumFinal),
      DoubleCellValue(sumPaid),
      DoubleCellValue(sumDue),
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

  // --- PDF PRIVATE HELPERS FOR MULTI-ROW REPORT ---

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
                style:
                    const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Filter: $filterSummary',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Date: ${Formatters.date(DateTime.now())}',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
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
          _buildPdfKpiItem('Challan Gross', Formatters.currencyPdf(totalChallan)),
          _buildPdfKpiItem('Final Billed', Formatters.currencyPdf(totalFinal),
              isBold: true),
          _buildPdfKpiItem('Total GST', Formatters.currencyPdf(totalGst)),
          _buildPdfKpiItem('Unpaid Dues', Formatters.currencyPdf(totalUnpaid),
              isWarning: totalUnpaid > 0),
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
      'Discount',
      'Final Amt',
      'GST Bill & Amt',
      'Payment Mode',
      'Status / Details',
    ];

    final data = entries.map((c) {
      final isCash = c.paymentOption == PaymentOption.cash;

      String details = '';
      if (!isCash && c.chequeDetails != null) {
        details =
            'Chk #${c.chequeDetails!.chequeNo} (${c.chequeDetails!.bankName}) - ${c.chequeDetails!.status.label}';
      } else if (c.isPartiallyPaid) {
        details =
            'PARTIAL: Paid ${Formatters.currencyPdf(c.paidAmount)}, Due ${Formatters.currencyPdf(c.remainingAmount)}';
      } else if (c.isCashPaid) {
        details = 'PAID IN FULL';
      } else {
        details =
            'WARNING: UNPAID (Due ${Formatters.currencyPdf(c.finalAmount)})';
      }

      return [
        Formatters.shortDate(c.date),
        c.challanNo,
        c.partyName,
        Formatters.currencyPdf(c.challanAmount),
        c.discountAmount > 0 ? Formatters.currencyPdf(c.discountAmount) : '-',
        Formatters.currencyPdf(c.finalAmount),
        c.gstBillNo.isNotEmpty
            ? '${c.gstBillNo}\n${Formatters.currencyPdf(c.gstAmount)}'
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
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerLeft,
        7: pw.Alignment.center,
        8: pw.Alignment.centerLeft,
      },
    );
  }

  /// Exports full audit trail history to Microsoft Excel (.xlsx) file
  static Future<String> exportAuditLogsToExcel({
    required List<AuditLogEntry> logs,
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel[excel.getDefaultSheet() ?? 'Audit Trail'];

    sheet.appendRow([
      TextCellValue('OM Mavtar Group - Audit Trail & Activity Log'),
      TextCellValue(''),
      TextCellValue('Generated: ${Formatters.date(DateTime.now())}'),
      TextCellValue('Total Records: ${logs.length}'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([
      TextCellValue('Timestamp'),
      TextCellValue('Action'),
      TextCellValue('Entity Type'),
      TextCellValue('Entity / Reference'),
      TextCellValue('User Name'),
      TextCellValue('User Role'),
      TextCellValue('Activity Description'),
    ]);

    for (var l in logs) {
      sheet.appendRow([
        TextCellValue(Formatters.dateTime(l.timestamp)),
        TextCellValue(l.action.label),
        TextCellValue(l.entityType.label),
        TextCellValue(l.entityTitle),
        TextCellValue(l.performedBy),
        TextCellValue(l.userRole),
        TextCellValue(l.description),
      ]);
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'OM_Mavtar_Audit_Trail_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File('${dir.path}/$filename');
    final bytes = excel.save();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }
    return file.path;
  }

  // =========================================================================
  // NET PROFIT & LOSS FINANCIAL STATEMENT PDF EXPORT
  // =========================================================================

  /// Generates a comprehensive Net Profit & Loss Statement PDF with separate Expenses & Income tables and conclusion
  static Future<Uint8List> generateProfitLossPdfData({
    required ProfitLossCalculation calc,
    required String periodLabel,
    String? companyName,
    String? companyTagline,
  }) async {
    final pdf = pw.Document();

    final cName = companyName?.trim().isNotEmpty == true ? companyName!.trim() : 'OM Mavtar Group';
    final cTagline = companyTagline?.trim().isNotEmpty == true ? companyTagline!.trim() : 'Khata Book Desktop';

    final netLabel = calc.isProfit ? 'NET PROFIT (Surplus)' : 'NET LOSS (Deficit)';
    final netColor = calc.isProfit ? PdfColors.green800 : PdfColors.red800;
    final netBgColor = calc.isProfit ? PdfColors.green50 : PdfColors.red50;

    final expenseHeaders = ['#', 'Date', 'Particulars / Description', 'Category', 'Notes', 'Amount (Rs.)'];
    final expenseData = <List<String>>[];
    for (int i = 0; i < calc.expenses.length; i++) {
      final e = calc.expenses[i];
      expenseData.add([
        '${i + 1}',
        Formatters.shortDate(e.date),
        e.particular,
        e.category,
        e.notes.isNotEmpty ? e.notes : '-',
        Formatters.currencyPdf(e.amount),
      ]);
    }
    if (calc.expenses.isNotEmpty) {
      expenseData.add([
        '',
        'TOTAL',
        'Total Operating Expenses (${calc.expenses.length} entries)',
        '',
        '',
        Formatters.currencyPdf(calc.totalExpenses),
      ]);
    }

    final incomeHeaders = ['#', 'Date', 'Particulars / Party', 'Source / Mode', 'Notes', 'Amount (Rs.)'];
    final incomeData = <List<String>>[];
    for (int i = 0; i < calc.incomes.length; i++) {
      final e = calc.incomes[i];
      incomeData.add([
        '${i + 1}',
        Formatters.shortDate(e.date),
        e.particular,
        e.category,
        e.notes.isNotEmpty ? e.notes : '-',
        Formatters.currencyPdf(e.amount),
      ]);
    }
    if (calc.incomes.isNotEmpty) {
      incomeData.add([
        '',
        'TOTAL',
        'Total Revenue & Collections (${calc.incomes.length} entries)',
        '',
        '',
        Formatters.currencyPdf(calc.totalIncome),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(cName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.teal800)),
                  pw.SizedBox(height: 2),
                  pw.Text(cTagline, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(height: 2),
                  pw.Text('NET PROFIT & LOSS FINANCIAL STATEMENT', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Period: $periodLabel', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('Date: ${Formatters.date(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 10),

          // SUMMARY KPIS (INCOME, EXPENSES, RESULT)
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.green300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL REVENUE / INCOME', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.green800)),
                      pw.SizedBox(height: 3),
                      pw.Text('Rs. ${Formatters.currencyPdf(calc.totalIncome)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      pw.Text('${calc.incomes.length} Entries', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.red300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL OPERATING EXPENSES', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.red800)),
                      pw.SizedBox(height: 3),
                      pw.Text('Rs. ${Formatters.currencyPdf(calc.totalExpenses)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      pw.Text('${calc.expenses.length} Entries', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: netBgColor,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: netColor),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(calc.isProfit ? 'NET PROFIT (SURPLUS)' : 'NET LOSS (DEFICIT)', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: netColor)),
                      pw.SizedBox(height: 3),
                      pw.Text('${calc.isProfit ? '+' : '-'}Rs. ${Formatters.currencyPdf(calc.netAmount)}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: netColor)),
                      pw.Text(calc.isProfit ? 'Net Operating Surplus' : 'Net Operating Deficit', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // 1. EXPENSES TABLE
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.red300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('1. OPERATING EXPENSES', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                pw.Text('Total: Rs. ${Formatters.currencyPdf(calc.totalExpenses)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          if (calc.expenses.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              alignment: pw.Alignment.center,
              child: pw.Text('No operating expenses recorded for this period.', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600)),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: expenseHeaders,
              data: expenseData,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 20,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerRight,
              },
            ),

          pw.SizedBox(height: 18),

          // 2. REVENUE / INCOME TABLE
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.green300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('2. REVENUE & COLLECTIONS', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                pw.Text('Total: Rs. ${Formatters.currencyPdf(calc.totalIncome)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          if (calc.incomes.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              alignment: pw.Alignment.center,
              child: pw.Text('No revenue or collections recorded for this period.', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey600)),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: incomeHeaders,
              data: incomeData,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 20,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.centerRight,
              },
            ),

          pw.SizedBox(height: 18),

          // 3. FINAL FINANCIAL CONCLUSION BOX
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: netBgColor,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: netColor, width: 1.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('3. FINANCIAL CONCLUSION', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: netColor)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(color: netColor, borderRadius: pw.BorderRadius.circular(4)),
                      child: pw.Text(netLabel, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Operational Revenue:', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                    pw.Text('Rs. ${Formatters.currencyPdf(calc.totalIncome)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Less Total Operating Costs:', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                    pw.Text('- Rs. ${Formatters.currencyPdf(calc.totalExpenses)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  ],
                ),
                pw.Container(margin: const pw.EdgeInsets.symmetric(vertical: 4), height: 1, color: netColor),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NET FINANCIAL BALANCE:', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: netColor)),
                    pw.Text('${calc.isProfit ? '+' : '-'}Rs. ${Formatters.currencyPdf(calc.netAmount)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: netColor)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return await pdf.save();
  }

  /// Generates and exports Net Profit & Loss PDF to application documents directory
  static Future<String> exportProfitLossPdf({
    required ProfitLossCalculation calc,
    required String periodLabel,
    String? companyName,
    String? companyTagline,
  }) async {
    final bytes = await generateProfitLossPdfData(
      calc: calc,
      periodLabel: periodLabel,
      companyName: companyName,
      companyTagline: companyTagline,
    );

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'OM_Mavtar_Profit_Loss_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}
