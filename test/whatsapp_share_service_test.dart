import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/models/income_expense_entry.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/utils/formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsApp Share Formatting Tests', () {
    test('Expense voucher WhatsApp text formatting includes particulars, amount and notes', () {
      final entry = IncomeExpenseEntry(
        id: 'exp_1',
        date: DateTime(2026, 10, 1),
        type: EntryType.expense,
        particular: 'SALARY',
        category: 'Operating Costs',
        amount: 1386857,
        notes: '370598/250=299119/LADIES',
        paymentMode: 'Cash',
        createdAt: DateTime.now(),
      );

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

      final text = sb.toString();
      expect(text.contains('OM MAVTAR GROUP'), isTrue);
      expect(text.contains('EXPENSE DETAILS'), isTrue);
      expect(text.contains('SALARY'), isTrue);
      expect(text.contains('13,86,857'), isTrue);
      expect(text.contains('370598/250=299119/LADIES'), isTrue);
    });

    test('Profit & Loss statement WhatsApp text formatting includes totals and net status', () {
      final calc = ProfitLossCalculation(
        expenses: [
          IncomeExpenseEntry(
            id: 'e1',
            date: DateTime(2026, 10, 1),
            type: EntryType.expense,
            particular: 'SALARY',
            category: 'Operating Costs',
            amount: 270000,
            paymentMode: 'Cash',
            createdAt: DateTime.now(),
          ),
        ],
        incomes: [],
        totalExpenses: 270000,
        totalIncome: 10406013,
        netAmount: 10136013,
        isProfit: true,
      );

      final netLabel = calc.isProfit ? 'NET PROFIT (Surplus)' : 'NET LOSS (Deficit)';
      final netSymbol = calc.isProfit ? '+' : '-';

      final sb = StringBuffer();
      sb.writeln('*OM MAVTAR GROUP*');
      sb.writeln('*NET PROFIT & LOSS STATEMENT*');
      sb.writeln('--------------------------------');
      sb.writeln('📅 *Period:* All Months (All Time)');
      sb.writeln('💵 *Total Income:* Rs. ${Formatters.currency(calc.totalIncome)}');
      sb.writeln('💸 *Total Expenses:* Rs. ${Formatters.currency(calc.totalExpenses)}');
      sb.writeln('📊 *$netLabel:* $netSymbol Rs. ${Formatters.currency(calc.netAmount)}');
      sb.writeln('--------------------------------');

      final text = sb.toString();
      expect(text.contains('NET PROFIT (Surplus)'), isTrue);
      expect(text.contains('1,04,06,013'), isTrue);
      expect(text.contains('2,70,000'), isTrue);
    });
  });
}
