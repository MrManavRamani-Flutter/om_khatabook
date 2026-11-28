import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';

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

  group('Loose Structure & Database Schema Tolerance Tests', () {
    test('Recovers and parses raw JSON Array with missing database structure', () {
      final rawListJson = jsonEncode([
        {
          'challanNo': 'CH-TEST-1',
          'partyName': 'MANAV FAB',
          'finalAmount': 15000.0,
          'date': '2026-11-18T10:00:00.000',
        },
        {
          'challanNo': 'CH-TEST-2',
          'partyName': 'NEW EMBROIDERY WORKS',
          'finalAmount': 28500.0,
          'date': '2026-11-17T10:00:00.000',
        },
      ]);

      final analysis = provider.analyzeBackupJson(rawListJson);
      expect(analysis.isValid, isTrue);
      expect(analysis.isPartialOrLegacy, isTrue);
      expect(analysis.totalChallans, equals(2));
      // Auto-extracts distinct parties from challan records
      expect(analysis.totalParties, equals(2));
      expect(analysis.parties.any((p) => p.name == 'MANAV FAB'), isTrue);
      expect(analysis.parties.any((p) => p.name == 'NEW EMBROIDERY WORKS'), isTrue);
    });

    test('Tolerates missing fields and String numbers safely', () {
      final legacyJson = jsonEncode({
        'challans': [
          {
            'challanNo': 'CH-LEGACY-1',
            'partyName': 'SWASTIK CREATION',
            'amount': '45000.50', // string amount
            'isCashPaid': 'true', // string bool
            // missing id, createdAt, etc.
          }
        ]
      });

      final analysis = provider.analyzeBackupJson(legacyJson);
      expect(analysis.isValid, isTrue);
      expect(analysis.totalChallans, equals(1));
      final c = analysis.challans.first;
      expect(c.challanNo, equals('CH-LEGACY-1'));
      expect(c.finalAmount, equals(45000.50));
      expect(c.isCashPaid, isTrue);
      expect(c.id, isNotEmpty);
    });
  });

  group('Duplicate Detection & Collision Resolution (Merge Mode) Tests', () {
    test('Skips duplicate when ID and data are identical', () async {
      // 1. Add an existing challan
      final initial = await provider.addChallan(
        date: DateTime(2026, 11, 15),
        challanNo: 'CH-DUP-1',
        partyId: 'party_manav',
        partyName: 'MANAV FAB',
        challanAmount: 10000,
        finalAmount: 10000,
        paymentOption: PaymentOption.cash,
        isCashPaid: true,
      );

      final initialCount = provider.challans.length;

      // 2. Incoming backup with the EXACT same ID and data
      final backupJson = jsonEncode({
        'challans': [
          {
            'id': initial.id,
            'date': DateTime(2026, 11, 15).toIso8601String(),
            'challanNo': 'CH-DUP-1',
            'partyId': 'party_manav',
            'partyName': 'MANAV FAB',
            'challanAmount': 10000.0,
            'finalAmount': 10000.0,
            'paymentOption': 'cash',
            'isCashPaid': true,
          }
        ],
        'parties': [
          {
            'id': 'party_manav',
            'name': 'MANAV FAB',
            'phone': '',
            'address': '',
            'gstNumber': '',
          }
        ]
      });

      final summary = await provider.importBackupWithStrategy(
        jsonString: backupJson,
        mode: BackupImportMode.merge,
      );

      expect(summary.success, isTrue);
      expect(summary.challansDuplicateSkipped, equals(1));
      expect(summary.challansAdded, equals(0));
      expect(provider.challans.length, equals(initialCount));
    });

    test('Assigns brand new primary ID when ID matches but data is different (preserves both)', () async {
      // 1. Existing challan with ID "ch_collision_1"
      final initial = await provider.addChallan(
        date: DateTime(2026, 11, 10),
        challanNo: 'CH-ORIGINAL',
        partyId: 'party_1',
        partyName: 'MANAV FAB',
        challanAmount: 5000,
        finalAmount: 5000,
        paymentOption: PaymentOption.cash,
        isCashPaid: true,
      );

      final initialId = initial.id;

      // 2. Incoming backup has SAME ID initialId, BUT DIFFERENT DATA (amount 99000, different challanNo)
      final backupJson = jsonEncode({
        'challans': [
          {
            'id': initialId,
            'date': DateTime(2026, 11, 18).toIso8601String(),
            'challanNo': 'CH-NEW-INCOMING',
            'partyId': 'party_1',
            'partyName': 'MANAV FAB',
            'challanAmount': 99000.0,
            'finalAmount': 99000.0,
            'paymentOption': 'cash',
            'isCashPaid': false,
          }
        ],
        'parties': []
      });

      final summary = await provider.importBackupWithStrategy(
        jsonString: backupJson,
        mode: BackupImportMode.merge,
      );

      expect(summary.success, isTrue);
      expect(summary.challansAdded, equals(1));
      expect(summary.challansDuplicateSkipped, equals(0));

      // Verify BOTH records exist in database
      final originalRecord = provider.challans.firstWhere((c) => c.id == initialId);
      expect(originalRecord.challanNo, equals('CH-ORIGINAL'));
      expect(originalRecord.finalAmount, equals(5000.0));

      final incomingRecord = provider.challans.firstWhere((c) => c.challanNo == 'CH-NEW-INCOMING');
      expect(incomingRecord.finalAmount, equals(99000.0));
      // Primary ID must be newly assigned and DIFFERENT from initialId
      expect(incomingRecord.id, isNot(equals(initialId)));
    });
  });

  group('Descending Date Sorting (Current / Newest Date First) Tests', () {
    test('Challans are arranged in descending order by date after import and merge', () async {
      final multiDateBackup = jsonEncode({
        'challans': [
          {
            'id': 'c_oldest',
            'date': '2026-09-01T10:00:00.000',
            'challanNo': 'CH-OLD',
            'partyName': 'PARTY A',
            'finalAmount': 1000.0,
          },
          {
            'id': 'c_current',
            'date': '2026-11-18T18:00:00.000', // Today / Newest
            'challanNo': 'CH-NEWEST',
            'partyName': 'PARTY B',
            'finalAmount': 5000.0,
          },
          {
            'id': 'c_middle',
            'date': '2026-10-15T12:00:00.000',
            'challanNo': 'CH-MIDDLE',
            'partyName': 'PARTY C',
            'finalAmount': 3000.0,
          },
        ]
      });

      await provider.importBackupWithStrategy(
        jsonString: multiDateBackup,
        mode: BackupImportMode.replace,
      );

      final list = provider.filteredChallans;
      expect(list.length, equals(3));
      expect(list[0].challanNo, equals('CH-NEWEST')); // Newest first
      expect(list[1].challanNo, equals('CH-MIDDLE'));
      expect(list[2].challanNo, equals('CH-OLD')); // Oldest last
    });
  });

  group('Filter Verification on Imported & Merged Data Tests', () {
    setUp(() async {
      final dataset = jsonEncode({
        'challans': [
          {
            'id': 'c_filter_1',
            'date': '2026-11-18T10:00:00.000',
            'challanNo': 'CH-ALPHA',
            'partyId': 'party_filter_a',
            'partyName': 'MANAV FAB',
            'finalAmount': 20000.0,
            'paymentOption': 'cash',
            'isCashPaid': false, // Unpaid warning
          },
          {
            'id': 'c_filter_2',
            'date': '2026-11-17T10:00:00.000',
            'challanNo': 'CH-BETA',
            'partyId': 'party_filter_b',
            'partyName': 'SWASTIK CREATION',
            'finalAmount': 40000.0,
            'paymentOption': 'cheque',
            'chequeDetails': {
              'chequeNo': 'CHQ-888999',
              'bankName': 'HDFC BANK',
              'status': 'cleared',
            },
          },
        ],
        'parties': [
          {'id': 'party_filter_a', 'name': 'MANAV FAB'},
          {'id': 'party_filter_b', 'name': 'SWASTIK CREATION'},
        ]
      });

      await provider.importBackupWithStrategy(
        jsonString: dataset,
        mode: BackupImportMode.replace,
      );
    });

    test('Search filter properly matches imported Challan No, Party, and Cheque No', () {
      provider.setSearchQuery('CH-ALPHA');
      expect(provider.filteredChallans.length, equals(1));
      expect(provider.filteredChallans.first.partyName, equals('MANAV FAB'));

      provider.setSearchQuery('HDFC');
      expect(provider.filteredChallans.length, equals(1));
      expect(provider.filteredChallans.first.challanNo, equals('CH-BETA'));

      provider.resetFilters();
      expect(provider.filteredChallans.length, equals(2));
    });

    test('Payment option and status filters work cleanly on imported records', () {
      // 1. Cash Only Filter
      provider.setPaymentOptionFilter(PaymentOption.cash);
      expect(provider.filteredChallans.length, equals(1));
      expect(provider.filteredChallans.first.challanNo, equals('CH-ALPHA'));

      // 2. Unpaid Warning Filter
      provider.setStatusFilter('unpaid');
      expect(provider.filteredChallans.length, equals(1));
      expect(provider.filteredChallans.first.hasWarning, isTrue);

      // 3. Paid Filter
      provider.resetFilters();
      provider.setStatusFilter('paid');
      expect(provider.filteredChallans.length, equals(1));
      expect(provider.filteredChallans.first.challanNo, equals('CH-BETA'));
    });
  });

  group('Database Schema Evolution & Flexible Import Tests', () {
    test('Correctly imports database with commas, currency symbols, and computed finalAmount', () async {
      final dataset = jsonEncode({
        'challans': [
          {
            'referenceNo': '168',
            'customerName': 'KAMDAR SILK MILLS',
            'challanAmount': '₹ 57,200',
            'discount': '1,200',
            'gst': '0',
            // finalAmount omitted -> should auto-compute: 57200 - 1200 = 56000
            'paymentStatus': 'unpaid',
            'date': '24/11/2026',
            'due_date': '30/11/2026',
            'note': 'Urgent delivery note',
          },
        ],
      });

      final summary = await provider.importBackupWithStrategy(
        jsonString: dataset,
        mode: BackupImportMode.replace,
      );

      expect(summary.success, isTrue);
      expect(provider.challans.length, equals(1));
      final c = provider.challans.first;
      expect(c.challanNo, equals('168'));
      expect(c.partyName, equals('KAMDAR SILK MILLS'));
      expect(c.challanAmount, equals(57200.0));
      expect(c.discountAmount, equals(1200.0));
      expect(c.finalAmount, equals(56000.0));
      expect(c.isCashPaid, isFalse); // unpaid properly preserved
      expect(c.paidAmount, equals(0.0));
      expect(c.hasWarning, isTrue);
      expect(c.notes, equals('Urgent delivery note'));
      expect(c.paymentDueDate, isNotNull);
      expect(c.paymentDueDate!.day, equals(30));
      expect(c.paymentDueDate!.month, equals(11));
      expect(c.paymentDueDate!.year, equals(2026));
      // Party was auto-created
      expect(provider.parties.any((p) => p.name == 'KAMDAR SILK MILLS'), isTrue);
    });

    test('Correctly handles income & expense entries with varied schema during import', () async {
      final dataset = jsonEncode({
        'dayEntries': [
          {
            'id': 'exp_1',
            'type': 'expense',
            'description': 'SALARY BEADS',
            'amount': '2,70,000',
            'date': '01-10-2026',
            'group': 'Salary',
            'remarks': 'BEADS=571140/400=370598/250=299119',
          },
        ],
      });

      final summary = await provider.importBackupWithStrategy(
        jsonString: dataset,
        mode: BackupImportMode.replace,
      );

      expect(summary.success, isTrue);
      expect(provider.incomeExpenseEntries.length, equals(1));
      final entry = provider.incomeExpenseEntries.first;
      expect(entry.particular, equals('SALARY BEADS'));
      expect(entry.amount, equals(270000.0));
      expect(entry.notes, contains('BEADS=571140'));
      expect(entry.category, equals('Salary'));
    });

    test('Old version v1.0.0 backup without category items or expense entries imports without errors and preserves presets', () async {
      // Legacy backup format from older version: only parties and legacy transactions
      final legacyBackupJson = jsonEncode({
        'version': '1.0.0',
        'parties': [
          {'id': 'p_old_1', 'name': 'SHREE RAM TEXTILES', 'createdAt': '2025-01-01T10:00:00.000'},
        ],
        'transactions': [
          {
            'id': 'tx_old_1',
            'referenceNo': 'CH-OLD-88',
            'partyId': 'p_old_1',
            'partyName': 'SHREE RAM TEXTILES',
            'amount': '12,500',
            'date': '2025-01-05T10:00:00.000',
            'description': 'Old delivery order',
          }
        ]
      });

      // Analyze legacy backup
      final analysis = provider.analyzeBackupJson(legacyBackupJson);
      expect(analysis.isValid, isTrue);
      expect(analysis.totalChallans, equals(1));
      expect(analysis.totalParties, equals(1));

      // Import in Replace Mode
      final replaceSummary = await provider.importBackupWithStrategy(
        jsonString: legacyBackupJson,
        mode: BackupImportMode.replace,
      );
      expect(replaceSummary.success, isTrue);
      expect(provider.challans.length, equals(1));
      expect(provider.challans.first.challanNo, equals('CH-OLD-88'));
      expect(provider.challans.first.finalAmount, equals(12500.0));
      // Presets are guaranteed not empty
      expect(provider.ledgerCategoryItems.isNotEmpty, isTrue);
      expect(provider.expenseCategoryItems.any((e) => e.name == 'Electricity Bill'), isTrue);

      // Import in Merge Mode
      final mergeSummary = await provider.importBackupWithStrategy(
        jsonString: legacyBackupJson,
        mode: BackupImportMode.merge,
      );
      expect(mergeSummary.success, isTrue);
      expect(provider.ledgerCategoryItems.isNotEmpty, isTrue);
    });
  });
}

