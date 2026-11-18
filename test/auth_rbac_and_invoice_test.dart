import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:om_khatabook/models/audit_log_entry.dart';
import 'package:om_khatabook/models/challan_entry.dart';
import 'package:om_khatabook/models/party.dart';
import 'package:om_khatabook/providers/auth_provider.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/export_service.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:om_khatabook/utils/formatters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Master User Login & Unrestricted Permissions Tests', () {
    late StorageService storage;
    late AuthProvider auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      auth = AuthProvider(storage);
      await auth.initialize();
    });

    test('Initial unauthenticated state requires master login', () {
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('Login with invalid credentials fails and stays unauthenticated', () async {
      final success = await auth.login('wrong_user', 'wrong_pass');
      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
    });

    test('Login with OMMAVTAR36 / OMMAVTAR36 grants full master access', () async {
      final success = await auth.login('OMMAVTAR36', 'OMMAVTAR36');
      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser?.username, equals('OMMAVTAR36'));
      expect(auth.isDeveloper, isTrue);
      expect(auth.isAdmin, isTrue);
      expect(auth.canCreateChallan, isTrue);
      expect(auth.canEditChallan, isTrue);
      expect(auth.canDelete, isTrue);
      expect(auth.canDeleteChallan, isTrue);
      expect(auth.canRestoreFromBin, isTrue);
      expect(auth.canPurgeRecycleBin, isTrue);
      expect(auth.canManageParties, isTrue);
      expect(auth.canExportReports, isTrue);
      expect(auth.canPrintInvoice, isTrue);
      expect(auth.canViewAuditLogs, isTrue);
      expect(auth.canManageSettings, isTrue);
    });
  });

  group('Audit Trail Integrity Tests', () {
    late StorageService storage;
    late ChallanProvider provider;
    late AuthProvider auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      provider = ChallanProvider(storage);
      await provider.initialize();
      auth = AuthProvider(storage);
      auth.onAuditLog = (entry) => provider.addAuditLog(entry);
      await auth.initialize();
    });

    test('Adding a challan creates AuditAction.create log', () async {
      final entry = await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-999',
        partyId: 'party_1',
        partyName: 'MANAV FAB',
        challanAmount: 10000,
        finalAmount: 10000,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        performedBy: 'admin',
      );

      final createLogs = provider.auditLogs.where((l) => l.action == AuditAction.create && l.entityId == entry.id);
      expect(createLogs.isNotEmpty, isTrue);
      expect(createLogs.first.entityType, equals(AuditEntityType.challan));
      expect(createLogs.first.entityTitle, contains('CH-999'));
      expect(createLogs.first.performedBy, equals('OMMAVTAR36'));
      expect(createLogs.first.userRole, equals('MASTER'));
    });

    test('Audit history strictly normalizes legacy user references to single master operator OMMAVTAR36', () async {
      // Test 1: fromJson with legacy usernames
      final legacyJson = {
        'id': 'legacy_1',
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'create',
        'entityType': 'party',
        'entityId': 'p_1',
        'entityTitle': 'TEST PARTY',
        'performedBy': 'developer',
        'userRole': 'DEVELOPER',
        'description': 'Old developer action',
      };
      final parsed = AuditLogEntry.fromJson(legacyJson);
      expect(parsed.performedBy, equals('OMMAVTAR36'));
      expect(parsed.userRole, equals('MASTER'));

      // Test 2: Provider actions default to OMMAVTAR36 and MASTER
      final party = await provider.addParty(name: 'MASTER AUDIT TEST PARTY');
      final partyLogs = provider.auditLogs.where((l) => l.entityId == party.id);
      expect(partyLogs.isNotEmpty, isTrue);
      expect(partyLogs.first.performedBy, equals('OMMAVTAR36'));
      expect(partyLogs.first.userRole, equals('MASTER'));

      // Test 3: StorageService loadAuditLogs normalizes storage
      final loadedLogs = await storage.loadAuditLogs();
      for (final log in loadedLogs) {
        expect(log.performedBy, equals('OMMAVTAR36'));
        expect(log.userRole, equals('MASTER'));
      }
    });

    test('Editing and soft deleting a challan appends to audit trail', () async {
      final entry = await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-888',
        partyId: 'party_1',
        partyName: 'MANAV FAB',
        challanAmount: 20000,
        finalAmount: 20000,
        paymentOption: PaymentOption.cash,
        isCashPaid: true,
        performedBy: 'admin',
      );

      final updated = entry.copyWith(challanAmount: 55000);
      await provider.updateChallan(updated, performedBy: 'admin');

      final updateLogs = provider.auditLogs.where((l) => l.action == AuditAction.update && l.entityId == entry.id);
      expect(updateLogs.isNotEmpty, isTrue);

      await provider.moveToBinChallan(entry.id, performedBy: 'admin');
      final deleteLogs = provider.auditLogs.where((l) => l.action == AuditAction.softDelete && l.entityId == entry.id);
      expect(deleteLogs.isNotEmpty, isTrue);
    });
  });

  group('Single-Page GST Tax Invoice & NumberToWords Tests', () {
    test('Formatters.currencyPdf uses ASCII Rs. prefix for safe, warning-free PDF rendering', () {
      expect(Formatters.currencyPdf(500), equals('Rs. 500'));
      expect(Formatters.currencyPdf(15420.50), equals('Rs. 15,420.50'));
      expect(Formatters.currencyPdf(0), equals('Rs. 0'));
      // Standard Formatters.currency uses ₹ for screen UI
      expect(Formatters.currency(500), contains('₹'));
    });

    test('Formatters.numberToWords correctly formats Indian currency', () {
      expect(Formatters.numberToWords(0), equals('Rupees Zero Only'));
      expect(Formatters.numberToWords(500), equals('Rupees Five Hundred Only'));
      expect(Formatters.numberToWords(15420), equals('Rupees Fifteen Thousand Four Hundred Twenty Only'));
      expect(Formatters.numberToWords(125000), equals('Rupees One Lakh Twenty Five Thousand Only'));
      expect(Formatters.numberToWords(10000000), equals('Rupees One Crore Only'));
      expect(Formatters.numberToWords(250.50), equals('Rupees Two Hundred Fifty and Fifty Paise Only'));
    });

    test('generateSingleInvoicePdfData generates non-empty A4 and A5 bytes', () async {
      final challan = ChallanEntry(
        id: 'TEST-INV-1',
        challanNo: '101',
        date: DateTime(2026, 11, 6),
        partyId: 'p1',
        partyName: 'MANAV FAB',
        challanAmount: 20000,
        finalAmount: 25000,
        gstBillNo: 'JK-8899',
        gstAmount: 1250,
        paymentOption: PaymentOption.cheque,
        chequeDetails: ChequeDetails(
          chequeNo: '001245',
          bankName: 'HDFC Bank',
          chequeAmount: 25000,
          chequeDate: DateTime(2026, 11, 6),
          status: ChequeStatus.pending,
        ),
        createdAt: DateTime(2026, 11, 6),
      );

      final party = Party(
        id: 'p1',
        name: 'MANAV FAB',
        phone: '9876543210',
        address: 'Ring Road, Surat, Gujarat',
        gstNumber: '24AAAAA0000A1Z5',
        createdAt: DateTime(2026, 11, 6),
      );

      // A4 Test
      final a4Bytes = await ExportService.generateSingleInvoicePdfData(
        entry: challan,
        party: party,
        pageFormat: PdfPageFormat.a4,
        companyName: 'OM Mavtar Group',
        companyTagline: 'Textile Trading & Commercial Challan Management',
        companyAddress: 'Surat Textile Market, Surat, Gujarat - 395002',
        companyPhone: '+91 98250 12345',
        companyGstin: '24AAFCO9080P1ZT',
      );
      expect(a4Bytes, isNotEmpty);
      expect(a4Bytes.length, greaterThan(1000));

      // A5 Test
      final a5Bytes = await ExportService.generateSingleInvoicePdfData(
        entry: challan,
        party: party,
        pageFormat: PdfPageFormat.a5,
        companyName: 'OM Mavtar Group',
        companyTagline: 'Textile Trading & Commercial Challan Management',
        companyAddress: 'Surat Textile Market, Surat, Gujarat - 395002',
        companyPhone: '+91 98250 12345',
        companyGstin: '24AAFCO9080P1ZT',
      );
      expect(a5Bytes, isNotEmpty);
      expect(a5Bytes.length, greaterThan(1000));
    });
  });

  group('Data Audit Stamps Tests', () {
    late StorageService storage;
    late ChallanProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      provider = ChallanProvider(storage);
      await provider.initialize();
    });

    test('Challan entries track createdBy, lastModifiedBy, and lastModifiedAt stamps', () async {
      final entry = await provider.addChallan(
        date: DateTime.now(),
        challanNo: 'CH-STAMP-01',
        partyId: 'party_stamp_1',
        partyName: 'RAMESH CLOTH',
        challanAmount: 15000,
        finalAmount: 15000,
        paymentOption: PaymentOption.cash,
        isCashPaid: false,
        performedBy: 'admin',
      );

      expect(entry.createdBy, equals('admin'));
      expect(entry.lastModifiedBy, isNull);

      final updated = entry.copyWith(finalAmount: 16500, notes: 'Discount revised');
      await provider.updateChallan(updated, performedBy: 'admin');

      final fetched = provider.challans.firstWhere((c) => c.id == entry.id);
      expect(fetched.createdBy, equals('admin'));
      expect(fetched.lastModifiedBy, equals('admin'));
      expect(fetched.lastModifiedAt, isNotNull);
    });

    test('Party counterparty directory tracks createdBy and lastModifiedBy stamps', () async {
      final party = await provider.addParty(
        name: 'GUJARAT TEXTILE MILLS',
        phone: '9898012345',
        address: 'GIDC Pandesara, Surat',
        gstNumber: '24AAACT1234F1Z9',
        performedBy: 'admin',
      );

      expect(party.createdBy, equals('admin'));
      expect(party.lastModifiedBy, isNull);

      final updatedParty = party.copyWith(phone: '9898099999');
      await provider.updateParty(updatedParty, performedBy: 'admin');

      final fetchedParty = provider.parties.firstWhere((p) => p.id == party.id);
      expect(fetchedParty.createdBy, equals('admin'));
      expect(fetchedParty.lastModifiedBy, equals('admin'));
      expect(fetchedParty.lastModifiedAt, isNotNull);
    });
  });
}
