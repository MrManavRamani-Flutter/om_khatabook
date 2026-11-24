import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _inrFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 0,
  );

  static final NumberFormat _inrDecimalFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹ ',
    decimalDigits: 2,
  );

  static final NumberFormat _inrPdfFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  static final NumberFormat _inrPdfDecimalFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: 'Rs. ',
    decimalDigits: 2,
  );

  static String currency(double amount, {bool showDecimals = false}) {
    if (showDecimals || amount % 1 != 0) {
      return _inrDecimalFormatter.format(amount);
    }
    return _inrFormatter.format(amount);
  }

  /// ASCII-safe currency format specifically for PDF generation and document printing.
  /// Uses 'Rs. ' prefix to guarantee 100% reliable rendering without Unicode glyph errors
  /// on all operating systems, legacy PDF viewers, and printers.
  static String currencyPdf(double amount, {bool showDecimals = false}) {
    if (showDecimals || amount % 1 != 0) {
      return _inrPdfDecimalFormatter.format(amount);
    }
    return _inrPdfFormatter.format(amount);
  }

  static String date(DateTime dt) {
    return DateFormat('dd MMM yyyy').format(dt);
  }

  static String dateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  static String shortDate(DateTime dt) {
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  static const List<String> _units = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen'
  ];

  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
  ];

  /// Converts a numeric amount to Indian currency words
  /// e.g. 50400 -> "Rupees Fifty Thousand Four Hundred Only"
  static String numberToWords(double amount) {
    if (amount <= 0) return 'Rupees Zero Only';

    final intPart = amount.floor();
    final decimalPart = ((amount - intPart) * 100).round();

    String result = _convertIndianNumber(intPart).trim();
    if (result.isEmpty) {
      result = 'Zero';
    }

    if (decimalPart > 0) {
      final decimalWords = _convertIndianNumber(decimalPart).trim();
      return 'Rupees $result and $decimalWords Paise Only';
    }
    return 'Rupees $result Only';
  }

  static String _convertIndianNumber(int n) {
    if (n == 0) return '';
    if (n < 20) return _units[n];
    if (n < 100) {
      return '${_tens[n ~/ 10]}${n % 10 != 0 ? ' ${_units[n % 10]}' : ''}';
    }
    if (n < 1000) {
      final rem = n % 100;
      return '${_units[n ~/ 100]} Hundred${rem != 0 ? ' ${_convertIndianNumber(rem)}' : ''}';
    }
    if (n < 100000) {
      final rem = n % 1000;
      return '${_convertIndianNumber(n ~/ 1000)} Thousand${rem != 0 ? ' ${_convertIndianNumber(rem)}' : ''}';
    }
    if (n < 10000000) {
      final rem = n % 100000;
      return '${_convertIndianNumber(n ~/ 100000)} Lakh${rem != 0 ? ' ${_convertIndianNumber(rem)}' : ''}';
    }
    final rem = n % 10000000;
    return '${_convertIndianNumber(n ~/ 10000000)} Crore${rem != 0 ? ' ${_convertIndianNumber(rem)}' : ''}';
  }

  /// Natural alphanumeric comparison for challan numbers and codes
  /// Ensures 1 < 2 < 10 < 100 and CH-2 < CH-10 rather than pure alphabetical order.
  static int compareNatural(String a, String b) {
    final regex = RegExp(r'(\d+|\D+)');
    final matchesA = regex.allMatches(a.trim()).map((m) => m.group(0)!).toList();
    final matchesB = regex.allMatches(b.trim()).map((m) => m.group(0)!).toList();

    final minLen = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;
    for (int i = 0; i < minLen; i++) {
      final partA = matchesA[i];
      final partB = matchesB[i];

      final numA = BigInt.tryParse(partA);
      final numB = BigInt.tryParse(partB);

      if (numA != null && numB != null) {
        final comp = numA.compareTo(numB);
        if (comp != 0) return comp;
      } else {
        final comp = partA.toLowerCase().compareTo(partB.toLowerCase());
        if (comp != 0) return comp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  /// Compares two challan numbers respecting ascending/descending order.
  static int compareChallanNumbers(String a, String b, {bool ascending = true}) {
    final res = compareNatural(a, b);
    return ascending ? res : -res;
  }
}
