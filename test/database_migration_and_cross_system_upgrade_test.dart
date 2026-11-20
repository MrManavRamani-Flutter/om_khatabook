import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/providers/auth_provider.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cross-System Installation & Database Auto-Upgrade Tests', () {
    test('Automatically migrates legacy parties and legacy challans to v2 keys', () async {
      SharedPreferences.setMockInitialValues({
        'om_parties': jsonEncode([
          {'id': 'p_old_1', 'name': 'RAMESH TEXTILES', 'phone': '9898012345', 'createdAt': '2026-01-01T10:00:00.000'},
        ]),
        'om_challans': jsonEncode([
          {
            'id': 'c_old_1',
            'challanNo': 'CH-OLD-01',
            'partyId': 'p_old_1',
            'partyName': 'RAMESH TEXTILES',
            'date': '2026-01-02T10:00:00.000',
            'challanAmount': 5000.0,
            'hasGstBill': false,
            'finalAmount': 5000.0,
            'paymentOption': 'cash',
            'paymentStatus': 'paid',
            // Missing paidAmount & createdBy is 'developer'
            'createdBy': 'developer',
            'createdAt': '2026-01-02T10:00:00.000',
          }
        ]),
        'om_active_session_v2': jsonEncode({
          'id': 'user_developer_default',
          'username': 'developer',
          'displayName': 'System Developer',
        }),
      });

      final storage = StorageService();
      await storage.init();

      // Verify parties migrated
      final parties = await storage.loadParties();
      expect(parties.length, 1);
      expect(parties.first.name, 'RAMESH TEXTILES');

      // Verify challans migrated and schema upgraded
      final challans = await storage.loadChallans();
      expect(challans.length, 1);
      expect(challans.first.challanNo, 'CH-OLD-01');
      expect(challans.first.paidAmount, 5000.0);
      expect(challans.first.createdBy, 'OM MAVTAR');

      // Verify AuthProvider initializes with OMMAVTAR36 (OM MAVTAR)
      final auth = AuthProvider(storage);
      await auth.initialize();
      expect(auth.currentUser?.username, 'OMMAVTAR36');
      expect(auth.currentUser?.displayName, 'OM MAVTAR');
    });

    test('Loads legacy v1.0.0 transactions and converts them seamlessly', () async {
      SharedPreferences.setMockInitialValues({
        'om_parties_data': jsonEncode([
          {'id': 'p_v1_1', 'name': 'MAHAVIR ENTERPRISE', 'createdAt': '2026-01-01T10:00:00.000'},
        ]),
        'om_transactions_data': jsonEncode([
          {
            'id': 'tx_v1_1',
            'referenceNo': 'TX-V1-100',
            'partyId': 'p_v1_1',
            'partyName': 'MAHAVIR ENTERPRISE',
            'date': '2026-01-03T10:00:00.000',
            'amount': 12000.0,
            'description': 'Legacy opening balance bill',
            'createdAt': '2026-01-03T10:00:00.000',
          }
        ]),
      });

      final storage = StorageService();
      await storage.init();

      final challans = await storage.loadChallans();
      expect(challans.length, 1);
      expect(challans.first.challanNo, 'TX-V1-100');
      expect(challans.first.finalAmount, 12000.0);
      expect(challans.first.paidAmount, 12000.0);
      expect(challans.first.createdBy, 'OM MAVTAR');

      final parties = await storage.loadParties();
      expect(parties.length, 1);
      expect(parties.first.name, 'MAHAVIR ENTERPRISE');
    });

    test('analyzeBackupJson parses both legacy v1.0.0 and v2.1.0 backups correctly', () {
      final storage = StorageService();
      final provider = ChallanProvider(storage);

      // Legacy v1.0.0 backup string
      final legacyBackup = jsonEncode({
        'app': 'OM Mavtar Group Khata Book',
        'version': '1.0.0',
        'parties': [
          {'id': 'p1', 'name': 'LEGACY PARTY A', 'createdAt': '2026-01-01T10:00:00.000'}
        ],
        'transactions': [
          {
            'id': 't1',
            'referenceNo': 'BILL-001',
            'partyId': 'p1',
            'partyName': 'LEGACY PARTY A',
            'amount': 3500.0,
            'date': '2026-01-02T10:00:00.000',
          }
        ],
        'dayEntries': [
          {
            'id': 'd1',
            'type': 'expense',
            'description': 'Chai Pani',
            'amount': 120.0,
            'date': '2026-01-02T10:00:00.000',
          }
        ]
      });

      final analysis = provider.analyzeBackupJson(legacyBackup);
      expect(analysis.isValid, isTrue);
      expect(analysis.parties.length, 1);
      expect(analysis.parties.first.name, 'LEGACY PARTY A');
      expect(analysis.challans.length, 1);
      expect(analysis.challans.first.challanNo, 'BILL-001');
      expect(analysis.challans.first.finalAmount, 3500.0);
      expect(analysis.challans.first.paidAmount, 3500.0);
      expect(analysis.incomeExpenseEntries.length, 1);
      expect(analysis.incomeExpenseEntries.first.particular, 'Chai Pani');
    });
  });
}
