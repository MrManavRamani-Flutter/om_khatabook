import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challan Discount Feature Tests', () {
    test('ChallanEntry model initializes with discountAmount and handles default 0.0', () {
      final defaultEntry = ChallanEntry(
        id: 'c1',
        date: DateTime(2026, 11, 24),
        challanNo: '168',
        partyId: 'p1',
        partyName: 'KAMDAR SILK MILLS',
        challanAmount: 57200,
        finalAmount: 57200,
        paymentOption: PaymentOption.cash,
        createdAt: DateTime.now(),
      );

      expect(defaultEntry.discountAmount, 0.0);

      final discountedEntry = ChallanEntry(
        id: 'c2',
        date: DateTime(2026, 11, 24),
        challanNo: '169',
        partyId: 'p1',
        partyName: 'KAMDAR SILK MILLS',
        challanAmount: 57200,
        discountAmount: 2200,
        finalAmount: 55000,
        paymentOption: PaymentOption.cash,
        createdAt: DateTime.now(),
      );

      expect(discountedEntry.challanAmount, 57200);
      expect(discountedEntry.discountAmount, 2200);
      expect(discountedEntry.finalAmount, 55000);
    });

    test('ChallanEntry serialization and deserialization preserves discountAmount', () {
      final entry = ChallanEntry(
        id: 'c3',
        date: DateTime(2026, 11, 24),
        challanNo: '170',
        partyId: 'p2',
        partyName: 'HEERA ENTERPRISE',
        challanAmount: 100000,
        discountAmount: 5000,
        finalAmount: 95000,
        paidAmount: 50000,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        createdAt: DateTime(2026, 11, 24, 10, 0),
      );

      final json = entry.toJson();
      expect(json['discountAmount'], 5000.0);

      final restored = ChallanEntry.fromJson(json);
      expect(restored.discountAmount, 5000.0);
      expect(restored.challanAmount, 100000.0);
      expect(restored.finalAmount, 95000.0);

      // Backward compatibility with legacy json lacking discount
      final legacyJson = {
        'id': 'legacy_1',
        'date': '2026-11-20T00:00:00.000',
        'challanNo': '101',
        'partyId': 'p1',
        'partyName': 'TEST',
        'challanAmount': 50000,
        'finalAmount': 50000,
        'paymentOption': 'cash',
        'isCashPaid': true,
        'createdAt': '2026-11-20T00:00:00.000',
      };
      final fromLegacy = ChallanEntry.fromJson(legacyJson);
      expect(fromLegacy.discountAmount, 0.0);
    });

    test('ChallanEntry copyWith correctly modifies discountAmount', () {
      final entry = ChallanEntry(
        id: 'c4',
        date: DateTime(2026, 11, 24),
        challanNo: '171',
        partyId: 'p1',
        partyName: 'MANAV FAB',
        challanAmount: 80000,
        discountAmount: 0.0,
        finalAmount: 80000,
        paymentOption: PaymentOption.cash,
        createdAt: DateTime.now(),
      );

      final updated = entry.copyWith(
        discountAmount: 4000,
        finalAmount: 76000,
      );

      expect(updated.discountAmount, 4000.0);
      expect(updated.finalAmount, 76000.0);
    });

    test('ChallanProvider records discount and computes totalDiscountAmount', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final provider = ChallanProvider(storage);
      await provider.initialize();

      await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-901',
        partyId: 'p1',
        partyName: 'KAMDAR SILK MILLS',
        challanAmount: 50000,
        discountAmount: 2500,
        finalAmount: 47500,
        paymentOption: PaymentOption.cash,
        isCashPaid: true,
      );

      await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-902',
        partyId: 'p2',
        partyName: 'HEERA ENTERPRISE',
        challanAmount: 100000,
        discountAmount: 7500,
        finalAmount: 92500,
        paymentOption: PaymentOption.cash,
        isCashPaid: true,
      );

      expect(provider.totalDiscountAmount, 10000.0);
      expect(provider.filteredChallans.first.discountAmount, 7500.0);
    });
  });
}

