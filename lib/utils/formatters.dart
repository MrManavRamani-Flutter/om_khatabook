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

  static String currency(double amount, {bool showDecimals = false}) {
    if (showDecimals || amount % 1 != 0) {
      return _inrDecimalFormatter.format(amount);
    }
    return _inrFormatter.format(amount);
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
}
