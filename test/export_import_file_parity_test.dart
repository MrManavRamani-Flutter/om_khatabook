import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late ChallanProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    provider = ChallanProvider(storage);
    await provider.initialize();
  });

  group('Export & Import Backup Round-trip Parity Tests', () {
    test('exportBackupJson produces full backup with branding, parties, and challans', () async {
      // Set custom branding
      provider.setCompanyBranding(name: 'OM Mavtar Special', tagline: 'Khata Book Premium');
      provider.setAdminProfile(name: 'OM MAVTAR', role: 'Business Owner');

      // Add a test challan
      await provider.addChallan(
        date: DateTime.parse('2026-11-18'),
        challanNo: 'CH-101',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 15000.0,
        finalAmount: 15000.0,
        paidAmount: 15000.0,
        paymentOption: PaymentOption.cash,
      );

      // Export JSON
      final jsonString = await storage.exportBackupJson();
      expect(jsonString, isNotEmpty);

      final dynamic decoded = jsonDecode(jsonString);
      expect(decoded, isA<Map<String, dynamic>>());
      final map = decoded as Map<String, dynamic>;

      expect(map['app'], equals('OM Mavtar Group Khata Book'));
      expect(map['version'], equals('2.1.0'));
      expect(map['exportedAt'], isNotNull);
      expect(map['parties'], isA<List>());
      expect(map['challans'], isA<List>());
      expect(map['branding'], isA<Map>());
      expect(map['branding']['companyName'], equals('OM Mavtar Special'));
      expect(map['branding']['companyTagline'], equals('Khata Book Premium'));
      expect(map['branding']['adminName'], equals('OM MAVTAR'));
    });

    test('analyzeBackupJson validates and analyzes exported backup JSON cleanly', () async {
      await provider.addChallan(
        date: DateTime.parse('2026-11-18'),
        challanNo: 'CH-102',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 20000.0,
        finalAmount: 20000.0,
      );

      final jsonString = await storage.exportBackupJson();
      final analysis = provider.analyzeBackupJson(jsonString);

      expect(analysis.isValid, isTrue);
      expect(analysis.totalChallans, equals(provider.challans.length));
      expect(analysis.totalParties, equals(provider.parties.length));
      expect(analysis.branding, isNotNull);
      expect(analysis.branding?['companyName'], isNotNull);
    });

    test('Round-trip file import in Combine & Merge mode deduplicates and sorts newest date first', () async {
      // 1. Add base challans
      await provider.addChallan(
        date: DateTime.parse('2026-11-10'),
        challanNo: 'CH-EARLY',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 10000.0,
        finalAmount: 10000.0,
      );

      // 2. Export initial data
      final exportedJson = await storage.exportBackupJson();

      // 3. Add a new newer challan to provider
      await provider.addChallan(
        date: DateTime.parse('2026-12-01'),
        challanNo: 'CH-LATER',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 50000.0,
        finalAmount: 50000.0,
        paidAmount: 50000.0,
        paymentOption: PaymentOption.cash,
      );

      final countBeforeImport = provider.challans.length;

      // 4. Import the previously exported JSON in Merge mode
      final result = await provider.importBackupWithStrategy(
        jsonString: exportedJson,
        mode: BackupImportMode.merge,
        importBranding: true,
      );

      expect(result.success, isTrue);
      expect(provider.challans.length, equals(countBeforeImport));

      // Check sorting: newest date first (descending)
      for (int i = 0; i < provider.challans.length - 1; i++) {
        final current = provider.challans[i].date;
        final next = provider.challans[i + 1].date;
        expect(current.isAfter(next) || current.isAtSameMomentAs(next), isTrue,
            reason: 'Challan at index $i (${current.toIso8601String()}) must be >= index ${i + 1} (${next.toIso8601String()})');
      }
    });

    test('Collision resolution generates new unique ID when primary ID matches but data is modified', () async {
      await provider.addChallan(
        date: DateTime.parse('2026-11-05'),
        challanNo: 'CH-ORIGINAL',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 10000.0,
        finalAmount: 10000.0,
      );

      final originalChallan = provider.challans.first;

      // Create a modified version of the same ID
      final modifiedBackup = jsonEncode({
        'challans': [
          {
            'id': originalChallan.id,
            'challanNo': 'CH-DIFFERENT-DATA',
            'partyName': originalChallan.partyName,
            'date': '2026-11-20T00:00:00.000',
            'challanAmount': 999999.0,
            'finalAmount': 999999.0,
            'isCashPaid': false,
          }
        ]
      });

      final initialCount = provider.challans.length;
      final result = await provider.importBackupWithStrategy(
        jsonString: modifiedBackup,
        mode: BackupImportMode.merge,
        importBranding: false,
      );

      expect(result.success, isTrue);
      expect(result.challansAdded, equals(1));
      expect(provider.challans.length, equals(initialCount + 1));

      // Verify original is still intact
      final originalStillExists = provider.challans.any((c) => c.id == originalChallan.id && c.challanNo == originalChallan.challanNo);
      expect(originalStillExists, isTrue);

      // Verify the new record was assigned a unique ID
      final modifiedRecord = provider.challans.firstWhere((c) => c.challanNo == 'CH-DIFFERENT-DATA');
      expect(modifiedRecord.id, isNot(equals(originalChallan.id)));
      expect(modifiedRecord.challanAmount, equals(999999.0));
    });

    test('Clean Overwrite (Replace) mode replaces existing records cleanly', () async {
      await provider.addChallan(
        date: DateTime.parse('2026-11-01'),
        challanNo: 'CH-OLD',
        partyId: provider.parties.first.id,
        partyName: provider.parties.first.name,
        challanAmount: 5000.0,
        finalAmount: 5000.0,
      );

      final customBackup = jsonEncode({
        'challans': [
          {
            'id': 'CH-REPLACE-001',
            'challanNo': 'CH-ONLY-ONE',
            'partyName': 'RAMESHBHAI JENTIBHAI MAVANI',
            'date': '2026-11-15T00:00:00.000',
            'challanAmount': 12000.0,
            'finalAmount': 12000.0,
            'isCashPaid': true,
          }
        ],
        'parties': [
          {
            'id': 'P-REPLACE-001',
            'name': 'RAMESHBHAI JENTIBHAI MAVANI',
          }
        ],
        'branding': {
          'companyName': 'Restored Company Ltd',
          'companyTagline': 'Tagline Restored',
        }
      });

      final result = await provider.importBackupWithStrategy(
        jsonString: customBackup,
        mode: BackupImportMode.replace,
        importBranding: true,
      );

      expect(result.success, isTrue);
      expect(provider.challans.length, equals(1));
      expect(provider.challans.first.challanNo, equals('CH-ONLY-ONE'));
      expect(provider.parties.length, equals(1));
      expect(provider.companyName, equals('Restored Company Ltd'));
      expect(provider.companyTagline, equals('Tagline Restored'));
    });
  });
}
