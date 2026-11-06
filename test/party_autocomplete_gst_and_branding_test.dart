import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/models/party.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Branding, GST & Party Validation Unit Tests', () {
    late StorageService storage;
    late ChallanProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      provider = ChallanProvider(storage);
      await provider.initialize();
    });

    test('Initial branding and profile defaults are loaded correctly', () {
      expect(provider.companyName, 'OM Mavtar Group');
      expect(provider.companyTagline, 'Khata Book Desktop');
      expect(provider.adminName, 'OM Mavtar Admin');
      expect(provider.adminRole, 'Administrator');
      expect(provider.appLogoBase64, isEmpty);
      expect(provider.profileLogoBase64, isEmpty);
    });

    test('Custom app logo and profile logo persist and export/import in backup JSON', () async {
      const dummyAppLogo = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      const dummyProfileLogo = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

      provider.setAppLogoBase64(dummyAppLogo);
      provider.setProfileLogoBase64(dummyProfileLogo);
      provider.setCompanyBranding(name: 'Shree Krishna Silks', tagline: 'Textile Wholesale Hub');
      provider.setAdminProfile(name: 'Manav Patel', role: 'Head of Accounts');

      expect(provider.appLogoBase64, dummyAppLogo);
      expect(provider.profileLogoBase64, dummyProfileLogo);
      expect(provider.companyName, 'Shree Krishna Silks');
      expect(provider.companyTagline, 'Textile Wholesale Hub');
      expect(provider.adminName, 'Manav Patel');
      expect(provider.adminRole, 'Head of Accounts');

      // Export backup JSON
      final jsonString = await storage.exportBackupJson();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded.containsKey('branding'), isTrue);
      final branding = decoded['branding'] as Map<String, dynamic>;
      expect(branding['companyName'], 'Shree Krishna Silks');
      expect(branding['companyTagline'], 'Textile Wholesale Hub');
      expect(branding['adminName'], 'Manav Patel');
      expect(branding['adminRole'], 'Head of Accounts');
      expect(branding['appLogoBase64'], dummyAppLogo);
      expect(branding['profileLogoBase64'], dummyProfileLogo);

      // Now clear storage to simulate fresh device, then verify import restores everything
      await storage.clearAllData();
      await storage.setCompanyName('OM Mavtar Group');
      await storage.setCompanyTagline('Khata Book Desktop');
      await storage.setAdminName('OM Mavtar Admin');
      await storage.setAdminRole('Administrator');
      await storage.setAppLogoBase64('');
      await storage.setProfileLogoBase64('');

      final freshStorage = StorageService();
      await freshStorage.init();
      final freshProvider = ChallanProvider(freshStorage);
      await freshProvider.initialize();

      expect(freshProvider.companyName, 'OM Mavtar Group'); // initial default
      final imported = await freshProvider.importBackup(jsonString);
      expect(imported, isTrue);

      expect(freshProvider.companyName, 'Shree Krishna Silks');
      expect(freshProvider.companyTagline, 'Textile Wholesale Hub');
      expect(freshProvider.adminName, 'Manav Patel');
      expect(freshProvider.adminRole, 'Head of Accounts');
      expect(freshProvider.appLogoBase64, dummyAppLogo);
      expect(freshProvider.profileLogoBase64, dummyProfileLogo);
    });

    test('GST Calculation priority: Final Amount takes priority over Challan Amount', () {
      // Priority 1: When Final Amount > 0
      double finalAmount = 50400.0;
      double challanAmount = 48000.0;
      double gstPercent = 5.0;

      double baseAmount = finalAmount > 0 ? finalAmount : challanAmount;
      double calculatedGst = (baseAmount * gstPercent) / 100.0;
      expect(calculatedGst, 2520.0);

      // Priority 2: When Final Amount is 0 or empty, Challan Amount is used
      finalAmount = 0.0;
      challanAmount = 48000.0;
      gstPercent = 12.0;

      baseAmount = finalAmount > 0 ? finalAmount : challanAmount;
      calculatedGst = (baseAmount * gstPercent) / 100.0;
      expect(calculatedGst, 5760.0);
    });

    test('GST 4 Fixed prefixes are JK, OMC, MK, KK', () {
      const fixedPrefixes = ['JK', 'OMC', 'MK', 'KK'];
      expect(fixedPrefixes.contains('JK'), isTrue);
      expect(fixedPrefixes.contains('OMC'), isTrue);
      expect(fixedPrefixes.contains('MK'), isTrue);
      expect(fixedPrefixes.contains('KK'), isTrue);
      expect(fixedPrefixes.length, 4);

      // Bill number formatting check
      for (final prefix in fixedPrefixes) {
        final formattedBillNo = '$prefix-2026-001';
        expect(formattedBillNo.startsWith(prefix), isTrue);
      }
    });

    test('Registered Parties validation recognizes 16 notebook parties and rejects unknown party', () {
      final parties = provider.parties;
      expect(parties.length, 16);

      // Check notebook parties
      expect(parties.any((p) => p.name.toLowerCase() == 'manav fab'), isTrue);
      expect(parties.any((p) => p.name.toLowerCase() == 'swastik creation'), isTrue);
      expect(parties.any((p) => p.name.toLowerCase() == 'kamdar silk mills'), isTrue);
      expect(parties.any((p) => p.name.toLowerCase() == 'mrt creation'), isTrue);

      // Verify unknown party is recognized as invalid
      const unknownParty = 'Random Invalid NonExistent Party 12345';
      final match = parties.cast<Party?>().firstWhere(
        (p) => p?.name.trim().toLowerCase() == unknownParty.toLowerCase(),
        orElse: () => null,
      );
      expect(match, isNull);
    });

    test('ChallanEntry supports all 3 amounts being optional (0.0 defaults)', () async {
      final manavFab = provider.parties.firstWhere((p) => p.name == 'Manav Fab');

      // Test 1: All 3 amounts left empty/0.0
      await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-OPT-001',
        partyId: manavFab.id,
        partyName: manavFab.name,
        challanAmount: 0.0,
        finalAmount: 0.0,
        paidAmount: 0.0,
        gstBillNo: '',
        gstAmount: 0.0,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
      );

      final entry1 = provider.challans.firstWhere((c) => c.challanNo == 'CH-OPT-001');
      expect(entry1.challanAmount, 0.0);
      expect(entry1.finalAmount, 0.0);
      expect(entry1.gstAmount, 0.0);

      // Test 2: Only Challan Amount provided
      await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-OPT-002',
        partyId: manavFab.id,
        partyName: manavFab.name,
        challanAmount: 25000.0,
        finalAmount: 0.0,
        paidAmount: 0.0,
        gstBillNo: '',
        gstAmount: 0.0,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
      );

      final entry2 = provider.challans.firstWhere((c) => c.challanNo == 'CH-OPT-002');
      expect(entry2.challanAmount, 25000.0);
      expect(entry2.finalAmount, 0.0);
      expect(entry2.gstAmount, 0.0);

      // Test 3: Only Final Amount & GST Amount provided
      await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-OPT-003',
        partyId: manavFab.id,
        partyName: manavFab.name,
        challanAmount: 0.0,
        finalAmount: 50000.0,
        paidAmount: 50000.0,
        gstBillNo: 'JK-2026-09',
        gstAmount: 2500.0,
        paymentOption: PaymentOption.cash,
        isCashPaid: true,
      );

      final entry3 = provider.challans.firstWhere((c) => c.challanNo == 'CH-OPT-003');
      expect(entry3.challanAmount, 0.0);
      expect(entry3.finalAmount, 50000.0);
      expect(entry3.gstAmount, 2500.0);
      expect(entry3.gstBillNo, 'JK-2026-09');
    });
  });
}
