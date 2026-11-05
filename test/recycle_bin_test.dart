import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';

void main() {
  group('Recycle Bin & Data Integrity Tests', () {
    late StorageService storageService;
    late ChallanProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storageService = StorageService();
      await storageService.init();
      provider = ChallanProvider(storageService);
      await provider.initialize();

      // Add a test challan for recycle bin testing
      await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-TEST-001',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 10000,
        finalAmount: 10500,
        paymentOption: PaymentOption.cash,
        isCashPaid: true,
      );
    });

    test('Initial seeded data loads active entries and empty recycle bin', () {
      expect(provider.parties.length, 16);
      expect(provider.challans.length, 1);
      expect(provider.deletedParties.length, 0);
      expect(provider.deletedChallans.length, 0);
      expect(provider.recycleBinCount, 0);
    });

    test('Moving Challan to Recycle Bin soft-deletes it', () async {
      final firstChallan = provider.challans.first;
      final initialActiveCount = provider.challans.length;

      await provider.moveToBinChallan(firstChallan.id);

      expect(provider.challans.length, initialActiveCount - 1);
      expect(provider.deletedChallans.length, 1);
      expect(provider.deletedChallans.first.id, firstChallan.id);
      expect(provider.deletedChallans.first.isDeleted, isTrue);
      expect(provider.deletedChallans.first.deletedAt, isNotNull);
      expect(provider.recycleBinCount, 1);

      // Verify filtered list does not include soft-deleted challan
      expect(provider.filteredChallans.any((c) => c.id == firstChallan.id), isFalse);
    });

    test('Restoring Challan from Recycle Bin returns it to active ledger', () async {
      final target = provider.challans.first;
      await provider.moveToBinChallan(target.id);
      expect(provider.recycleBinCount, 1);

      await provider.restoreChallan(target.id);

      expect(provider.recycleBinCount, 0);
      expect(provider.deletedChallans.length, 0);
      expect(provider.challans.any((c) => c.id == target.id), isTrue);

      final restored = provider.challans.firstWhere((c) => c.id == target.id);
      expect(restored.isDeleted, isFalse);
      expect(restored.deletedAt, isNull);
    });

    test('Permanently deleting Challan from bin removes it completely', () async {
      final target = provider.challans.first;
      await provider.moveToBinChallan(target.id);
      expect(provider.deletedChallans.length, 1);

      await provider.deletePermanentlyChallan(target.id);

      expect(provider.deletedChallans.length, 0);
      expect(provider.challans.any((c) => c.id == target.id), isFalse);
      expect(provider.recycleBinCount, 0);
    });

    test('Moving Party to Recycle Bin soft-deletes party', () async {
      final party = provider.parties.first;
      await provider.moveToBinParty(party.id);

      expect(provider.parties.any((p) => p.id == party.id), isFalse);
      expect(provider.deletedParties.length, 1);
      expect(provider.deletedParties.first.id, party.id);
      expect(provider.deletedParties.first.isDeleted, isTrue);

      // Restore party
      await provider.restoreParty(party.id);
      expect(provider.parties.any((p) => p.id == party.id), isTrue);
      expect(provider.deletedParties.length, 0);
    });

    test('Emptying Recycle Bin removes all soft-deleted items permanently', () async {
      final challan = provider.challans.first;
      final party = provider.parties.first;

      await provider.moveToBinChallan(challan.id);
      await provider.moveToBinParty(party.id);

      expect(provider.recycleBinCount, 2);

      await provider.emptyRecycleBin();

      expect(provider.recycleBinCount, 0);
      expect(provider.deletedChallans.length, 0);
      expect(provider.deletedParties.length, 0);
      expect(provider.challans.any((c) => c.id == challan.id), isFalse);
      expect(provider.parties.any((p) => p.id == party.id), isFalse);
    });

    test('Warning highlight for unpaid cash entries', () async {
      await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-UNPAID-001',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 15000,
        finalAmount: 15750,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
      );

      final unpaidCashChallan = provider.challans.firstWhere(
        (c) => c.challanNo == 'CH-UNPAID-001',
      );
      expect(unpaidCashChallan.hasWarning, isTrue);

      final paidCashChallan = provider.challans.firstWhere(
        (c) => c.challanNo == 'CH-TEST-001',
      );
      expect(paidCashChallan.hasWarning, isFalse);
    });
  });
}
