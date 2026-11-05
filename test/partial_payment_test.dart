import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/providers/challan_provider.dart';

void main() {
  group('Partial Cash Payment Tests', () {
    test('Calculates remaining balance and partial payment flags accurately', () {
      final partialEntry = ChallanEntry(
        id: '1',
        date: DateTime.now(),
        challanNo: 'CH-101',
        partyId: 'p1',
        partyName: 'Test Party',
        challanAmount: 50000,
        finalAmount: 52500,
        paidAmount: 20000,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        createdAt: DateTime.now(),
      );

      expect(partialEntry.paidAmount, 20000);
      expect(partialEntry.remainingAmount, 32500);
      expect(partialEntry.isPartiallyPaid, true);
      expect(partialEntry.isFullyPaid, false);
      expect(partialEntry.hasWarning, true);
      expect(partialEntry.isPending, true);
      expect(partialEntry.statusDisplay, contains('Partial Paid'));
    });

    test('Fully paid cash entry has zero remaining balance and no warning', () {
      final fullyPaidEntry = ChallanEntry(
        id: '2',
        date: DateTime.now(),
        challanNo: 'CH-102',
        partyId: 'p1',
        partyName: 'Test Party',
        challanAmount: 30000,
        finalAmount: 31500,
        paidAmount: 31500,
        paymentOption: PaymentOption.cash,
        isCashPaid: true,
        createdAt: DateTime.now(),
      );

      expect(fullyPaidEntry.remainingAmount, 0.0);
      expect(fullyPaidEntry.isPartiallyPaid, false);
      expect(fullyPaidEntry.isFullyPaid, true);
      expect(fullyPaidEntry.hasWarning, false);
      expect(fullyPaidEntry.isPending, false);
    });

    test('Unpaid cash entry defaults paidAmount to 0 and full balance is remaining', () {
      final unpaidEntry = ChallanEntry(
        id: '3',
        date: DateTime.now(),
        challanNo: 'CH-103',
        partyId: 'p1',
        partyName: 'Test Party',
        challanAmount: 40000,
        finalAmount: 42000,
        paidAmount: 0,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        createdAt: DateTime.now(),
      );

      expect(unpaidEntry.paidAmount, 0.0);
      expect(unpaidEntry.remainingAmount, 42000);
      expect(unpaidEntry.isPartiallyPaid, false);
      expect(unpaidEntry.isFullyPaid, false);
      expect(unpaidEntry.hasWarning, true);
      expect(unpaidEntry.isPending, true);
    });

    test('Backward compatibility: json without paidAmount defaults safely based on isCashPaid', () {
      final legacyPaidJson = {
        'id': 'legacy_1',
        'date': DateTime.now().toIso8601String(),
        'challanNo': 'CH-LEGACY-01',
        'partyId': 'p1',
        'partyName': 'Legacy Party',
        'challanAmount': 10000.0,
        'finalAmount': 10500.0,
        'gstBillNo': 'GST-01',
        'gstAmount': 500.0,
        'paymentOption': 'cash',
        'isCashPaid': true,
        'notes': 'Old record',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final parsedPaid = ChallanEntry.fromJson(legacyPaidJson);
      expect(parsedPaid.paidAmount, 10500.0);
      expect(parsedPaid.remainingAmount, 0.0);
      expect(parsedPaid.isFullyPaid, true);

      final legacyUnpaidJson = {
        'id': 'legacy_2',
        'date': DateTime.now().toIso8601String(),
        'challanNo': 'CH-LEGACY-02',
        'partyId': 'p1',
        'partyName': 'Legacy Party',
        'challanAmount': 20000.0,
        'finalAmount': 21000.0,
        'gstBillNo': '',
        'gstAmount': 0.0,
        'paymentOption': 'cash',
        'isCashPaid': false,
        'notes': 'Old unpaid record',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final parsedUnpaid = ChallanEntry.fromJson(legacyUnpaidJson);
      expect(parsedUnpaid.paidAmount, 0.0);
      expect(parsedUnpaid.remainingAmount, 21000.0);
      expect(parsedUnpaid.isFullyPaid, false);
      expect(parsedUnpaid.hasWarning, true);
    });
  });
}

