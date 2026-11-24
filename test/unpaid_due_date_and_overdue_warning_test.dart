import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Payment Due Date Countdown & Overdue Logic Tests', () {
    test('Calculates positive days remaining, due today, and overdue correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Future due date (+5 days)
      final futureChallan = ChallanEntry(
        id: 'c1',
        date: today,
        challanNo: '101',
        partyId: 'p1',
        partyName: 'Test Mills',
        challanAmount: 10000,
        finalAmount: 10000,
        paidAmount: 0,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        paymentDueDate: today.add(const Duration(days: 5)),
        createdAt: now,
      );

      expect(futureChallan.isFullyPaid, false);
      expect(futureChallan.isPaymentOverdue, false);
      expect(futureChallan.daysUntilPaymentDue, 5);
      expect(futureChallan.paymentDueCountdownText, contains('5 Days Left'));

      // Due today (0 days)
      final dueTodayChallan = futureChallan.copyWith(
        paymentDueDate: today,
      );
      expect(dueTodayChallan.isPaymentOverdue, false);
      expect(dueTodayChallan.daysUntilPaymentDue, 0);
      expect(dueTodayChallan.paymentDueCountdownText, contains('Due Today'));

      // Overdue (-3 days)
      final overdueChallan = futureChallan.copyWith(
        paymentDueDate: today.subtract(const Duration(days: 3)),
      );
      expect(overdueChallan.isPaymentOverdue, true);
      expect(overdueChallan.daysUntilPaymentDue, -3);
      expect(overdueChallan.paymentDueCountdownText, contains('3 Days Overdue'));

      // Once marked paid, isPaymentOverdue becomes false
      final paidChallan = overdueChallan.copyWith(
        isCashPaid: true,
        paidAmount: 10000,
      );
      expect(paidChallan.isFullyPaid, true);
      expect(paidChallan.isPaymentOverdue, false);
      expect(paidChallan.paymentDueCountdownText, 'Paid');
    });

    test('toJson and fromJson preserves paymentDueDate reliably', () {
      final now = DateTime.now();
      final dueDate = DateTime(2026, 12, 15);

      final entry = ChallanEntry(
        id: 'json_test_1',
        date: DateTime(2026, 11, 24),
        challanNo: '168',
        partyId: 'p1',
        partyName: 'KAMDAR SILK MILLS',
        challanAmount: 57200,
        finalAmount: 57200,
        paidAmount: 0,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        paymentDueDate: dueDate,
        createdAt: now,
      );

      final json = entry.toJson();
      expect(json['paymentDueDate'], dueDate.toIso8601String());

      final restored = ChallanEntry.fromJson(json);
      expect(restored.paymentDueDate?.year, 2026);
      expect(restored.paymentDueDate?.month, 12);
      expect(restored.paymentDueDate?.day, 15);
      expect(restored.isPaymentOverdue, false);
    });
  });

  group('ChallanProvider Overdue Tracking & Top Warning Integration Tests', () {
    late StorageService storage;
    late ChallanProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      provider = ChallanProvider(storage);
      await provider.initialize();

      // Clear existing default entries
      for (final c in List.of(provider.challans)) {
        await provider.deleteChallan(c.id);
      }
    });

    test('Tracks overdue challans and resolves them when cash/cheque details are updated', () async {
      final p = provider.parties.first;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Add 1 overdue unpaid challan (due 2 days ago)
      final overdueEntry = await provider.addChallan(
        date: today.subtract(const Duration(days: 10)),
        challanNo: '168',
        partyId: p.id,
        partyName: 'KAMDAR SILK MILLS',
        challanAmount: 57200,
        finalAmount: 57200,
        paidAmount: 0,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        paymentDueDate: today.subtract(const Duration(days: 2)),
      );

      // Add 1 not-overdue unpaid challan (due in 15 days)
      await provider.addChallan(
        date: today,
        challanNo: '169',
        partyId: p.id,
        partyName: 'MAYA SILK MILLS',
        challanAmount: 40000,
        finalAmount: 40000,
        paidAmount: 0,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        paymentDueDate: today.add(const Duration(days: 15)),
      );

      // Overdue stats
      expect(provider.overdueCount, 1);
      expect(provider.overdueAmount, 57200);
      expect(provider.overdueChallans.first.challanNo, '168');

      // Filter by overdue
      provider.setStatusFilter('overdue');
      expect(provider.filteredChallans.length, 1);
      expect(provider.filteredChallans.first.challanNo, '168');
      expect(provider.activeFilterSummary, contains('OVERDUE'));

      // User enters cash received / payment details to mark entry as paid
      final paidUpdate = overdueEntry.copyWith(
        isCashPaid: true,
        paidAmount: 57200,
        clearPaymentDueDate: true,
      );
      await provider.updateChallan(paidUpdate);

      // Overdue warning clears completely because details have been entered and paid!
      expect(provider.overdueCount, 0);
      expect(provider.overdueAmount, 0.0);
      expect(provider.overdueChallans.isEmpty, true);
    });
  });
}

