import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/models/app_user.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/models/income_expense_entry.dart';
import 'package:om_khatabook/providers/auth_provider.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late ChallanProvider challanProvider;
  late AuthProvider authProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    challanProvider = ChallanProvider(storage);
    await challanProvider.initialize();

    authProvider = AuthProvider(storage);
    await authProvider.initialize();
  });

  group('Requirement 1: Total Paid Amount Tests', () {
    test('totalPaidAmount aggregates only collected/paid amounts across challans', () async {
      final p = challanProvider.parties.first;

      // Add a fully paid challan
      await challanProvider.addChallan(
        date: DateTime.parse('2026-11-15'),
        challanNo: 'CH-PAID-01',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 10000.0,
        finalAmount: 10000.0,
        paidAmount: 10000.0,
        paymentOption: PaymentOption.cash,
      );

      // Add a partially paid challan (paid 3,000 out of 8,000)
      await challanProvider.addChallan(
        date: DateTime.parse('2026-11-16'),
        challanNo: 'CH-PARTIAL-02',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 8000.0,
        finalAmount: 8000.0,
        paidAmount: 3000.0,
        paymentOption: PaymentOption.cash,
      );

      // Total Final Amount is 18,000
      expect(challanProvider.totalFinalAmount, equals(18000.0));
      // Total Paid Amount is 10,000 + 3,000 = 13,000
      expect(challanProvider.totalPaidAmount, equals(13000.0));
    });
  });

  group('Requirement 4: Password Confirmation Gate Tests', () {
    test('verifyPassword accepts default master credentials OMMAVTAR36', () {
      expect(authProvider.verifyPassword('OMMAVTAR36'), isTrue);
      expect(authProvider.verifyPassword('  OMMAVTAR36  '), isTrue);
      expect(authProvider.verifyPassword('wrongpass'), isFalse);
      expect(authProvider.verifyPassword(''), isFalse);
    });

    test('verifyPassword validates updated password after user password change', () async {
      await authProvider.updatePassword(
        oldPassword: 'OMMAVTAR36',
        newPassword: 'NEWPASSWORD789',
        confirmPassword: 'NEWPASSWORD789',
      );

      expect(authProvider.verifyPassword('NEWPASSWORD789'), isTrue);
      expect(authProvider.verifyPassword('wrong'), isFalse);
    });
  });

  group('Requirements 2 & 3: Net Profit - Loss & Income/Expense Analysis Tests', () {
    test('Initial sample entries load notebook breakdown (Light bill 50, Salary 50, Om Kiran 10, Pradip 20)', () {
      final calc = challanProvider.computeProfitLoss();

      // Expenses: 50 + 50 = 100
      expect(calc.totalExpenses, equals(100.0));
      expect(calc.expenses.length, equals(2));

      // Incomes: 10 + 20 = 30
      expect(calc.totalIncome, equals(30.0));
      expect(calc.incomes.length, equals(2));

      // Net: 30 - 100 = -70 (Net Loss)
      expect(calc.netAmount, equals(70.0));
      expect(calc.isProfit, isFalse);
    });

    test('Adding income flips Net Loss into Net Profit when Income > Expenses', () async {
      // Add custom income of 200
      await challanProvider.addIncomeExpenseEntry(IncomeExpenseEntry(
        id: 'inc_test_1',
        type: EntryType.income,
        date: DateTime.now(),
        particular: 'Big Project Advance',
        amount: 200.0,
        createdAt: DateTime.now(),
      ));

      final calc = challanProvider.computeProfitLoss();
      // Total Income = 30 + 200 = 230
      expect(calc.totalIncome, equals(230.0));
      // Total Expenses = 100
      expect(calc.totalExpenses, equals(100.0));
      // Net Profit = 230 - 100 = 130
      expect(calc.netAmount, equals(130.0));
      expect(calc.isProfit, isTrue);
    });

    test('Monthly filtering filters for single month, 2 months, or all months', () async {
      final now = DateTime.now();
      final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final pastDate = DateTime(now.year, now.month - 2, 10);
      final pastMonthKey = '${pastDate.year}-${pastDate.month.toString().padLeft(2, '0')}';

      // Add expense in past month
      await challanProvider.addIncomeExpenseEntry(IncomeExpenseEntry(
        id: 'exp_past_1',
        type: EntryType.expense,
        date: pastDate,
        particular: 'Past Transport Bill',
        amount: 500.0,
        createdAt: pastDate,
      ));

      // 1. Filter single month (current month only)
      final calcCurrentOnly = challanProvider.computeProfitLoss(
        selectedMonthKeys: {currentMonthKey},
      );
      // Past expense should NOT be included
      expect(calcCurrentOnly.expenses.any((e) => e.particular == 'Past Transport Bill'), isFalse);
      expect(calcCurrentOnly.totalExpenses, equals(100.0));

      // 2. Filter multi-month (current + past month)
      final calcTwoMonths = challanProvider.computeProfitLoss(
        selectedMonthKeys: {currentMonthKey, pastMonthKey},
      );
      // Past expense SHOULD be included
      expect(calcTwoMonths.expenses.any((e) => e.particular == 'Past Transport Bill'), isTrue);
      expect(calcTwoMonths.totalExpenses, equals(600.0)); // 100 + 500

      // 3. All months (empty set or null)
      final calcAll = challanProvider.computeProfitLoss(selectedMonthKeys: {});
      expect(calcAll.expenses.any((e) => e.particular == 'Past Transport Bill'), isTrue);
      expect(calcAll.totalExpenses, equals(600.0));
    });

    test('Party challan collections automatically reflect in Income column', () async {
      final p = challanProvider.parties.first;

      await challanProvider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-AUTO-INC',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 12000.0,
        finalAmount: 12000.0,
        paidAmount: 12000.0,
        paymentOption: PaymentOption.cash,
      );

      final calc = challanProvider.computeProfitLoss();

      // Income list should contain an entry with party name
      final partyEntry = calc.incomes.firstWhere((i) => i.particular == p.name);
      expect(partyEntry.amount, equals(12000.0));
      expect(calc.totalIncome, greaterThanOrEqualTo(12000.0));
    });

    test('Backup export and import preserves all income and expense entries', () async {
      await challanProvider.addIncomeExpenseEntry(IncomeExpenseEntry(
        id: 'exp_export_test',
        type: EntryType.expense,
        date: DateTime.now(),
        particular: 'Special Factory Repair',
        amount: 7500.0,
        createdAt: DateTime.now(),
      ));

      final exported = await storage.exportBackupJson();
      final analysis = challanProvider.analyzeBackupJson(exported);

      expect(analysis.isValid, isTrue);
      expect(analysis.incomeExpenseEntries.any((e) => e.particular == 'Special Factory Repair'), isTrue);

      // Verify restore in replace mode
      final result = await challanProvider.importBackupWithStrategy(
        jsonString: exported,
        mode: BackupImportMode.replace,
      );
      expect(result.success, isTrue);
      expect(challanProvider.allExpenses.any((e) => e.particular == 'Special Factory Repair'), isTrue);
    });
  });
}

