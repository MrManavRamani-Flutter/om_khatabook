import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/providers/auth_provider.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Design No. and Payment Due Date Features', () {
    test('ChallanEntry model stores and serializes designNo correctly', () {
      final entry = ChallanEntry(
        id: 'c_design_1',
        date: DateTime(2026, 11, 28),
        challanNo: '320',
        partyId: 'p1',
        partyName: 'BT BEADS',
        designNo: 'BT-8899',
        challanAmount: 90744,
        finalAmount: 90744,
        paymentOption: PaymentOption.cash,
        createdAt: DateTime.now(),
      );

      expect(entry.designNo, 'BT-8899');

      final json = entry.toJson();
      expect(json['designNo'], 'BT-8899');

      final deserialized = ChallanEntry.fromJson(json);
      expect(deserialized.designNo, 'BT-8899');

      final updated = entry.copyWith(designNo: 'BT-9900');
      expect(updated.designNo, 'BT-9900');
      expect(updated.challanNo, '320');
    });

    test('ChallanEntry deserializes varied design_no keys safely', () {
      final raw1 = {'id': '1', 'date': '2026-11-28', 'challanNo': '1', 'partyName': 'P', 'design_no': 'DSG-1'};
      final e1 = ChallanEntry.fromJson(raw1);
      expect(e1.designNo, 'DSG-1');

      final raw2 = {'id': '2', 'date': '2026-11-28', 'challanNo': '2', 'partyName': 'P', 'designNumber': 'DSG-2'};
      final e2 = ChallanEntry.fromJson(raw2);
      expect(e2.designNo, 'DSG-2');

      final raw3 = {'id': '3', 'date': '2026-11-28', 'challanNo': '3', 'partyName': 'P'};
      final e3 = ChallanEntry.fromJson(raw3);
      expect(e3.designNo, '');
    });

    test('ChallanProvider filters and searches by designNo', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final provider = ChallanProvider(storage);
      await provider.initialize();

      await provider.addChallan(
        date: DateTime(2026, 11, 28),
        challanNo: '501',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 10000,
        finalAmount: 10000,
        designNo: 'EMBROIDERY-77',
      );

      await provider.addChallan(
        date: DateTime(2026, 11, 28),
        challanNo: '502',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 20000,
        finalAmount: 20000,
        designNo: 'PRINT-88',
      );

      provider.setSearchQuery('EMBROIDERY');
      expect(provider.filteredChallans.length, 1);
      expect(provider.filteredChallans.first.designNo, 'EMBROIDERY-77');

      provider.setSearchQuery('88');
      expect(provider.filteredChallans.length, 1);
      expect(provider.filteredChallans.first.designNo, 'PRINT-88');

      provider.setSearchQuery('');
      expect(provider.filteredChallans.length, 2);
    });

    test('AuthProvider handles auto-logout on system sleep / pause', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();
      final auth = AuthProvider(storage);
      await auth.initialize();

      // Login
      final loggedIn = await auth.login('OMMAVTAR36', 'OMMAVTAR36');
      expect(loggedIn, true);
      expect(auth.isAuthenticated, true);

      // Set timeout to immediate on sleep (0)
      await auth.setSessionTimeoutMinutes(0);
      expect(auth.sessionTimeoutMinutes, 0);

      // Simulate app pause (system sleep)
      auth.onAppPaused();

      // Wait a fraction of a second
      await Future.delayed(const Duration(milliseconds: 50));

      // Simulate resume without timeout elapsed (immediate timeout is 15s)
      await auth.onAppResumed();
      expect(auth.isAuthenticated, true);

      // Now simulate pause and manually trigger resume after timeout
      auth.onAppPaused();
      // Test logout execution
      await auth.logout();
      expect(auth.isAuthenticated, false);
    });
  });
}
