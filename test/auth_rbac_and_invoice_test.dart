import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:om_khatabook/models/app_user.dart';
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

  group('Authentication & RBAC Tests', () {
    late StorageService storage;
    late AuthProvider auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      auth = AuthProvider(storage);
      await auth.initialize();
    });

    test('Initial seeded accounts are developer, admin, manager, and clerk', () {
      expect(auth.users.length, equals(4));
      final usernames = auth.users.map((u) => u.username).toList();
      expect(usernames, containsAll(['developer', 'admin', 'manager', 'clerk']));
    });

    test('Developer login succeeds and grants full developer & system permissions', () async {
      final success = await auth.login('developer', 'developer123');
      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isDeveloper, isTrue);
      expect(auth.isAdmin, isTrue);
      expect(auth.currentUser?.role, equals(UserRole.developer));

      // RBAC Permission checks for Developer
      expect(auth.canCreateChallan, isTrue);
      expect(auth.canEditChallan, isTrue);
      expect(auth.canDelete, isTrue);
      expect(auth.canRestoreFromBin, isTrue);
      expect(auth.canPurgeRecycleBin, isTrue);
      expect(auth.canManageParties, isTrue);
      expect(auth.canExportReports, isTrue);
      expect(auth.canPrintInvoice, isTrue);
      expect(auth.canViewAuditLogs, isTrue);
      expect(auth.canClearAuditLogs, isTrue);
      expect(auth.canManageUsers, isTrue);
      expect(auth.canManageSettings, isTrue);
    });

    test('Default login with admin/admin123 succeeds and grants full admin permissions', () async {
      final success = await auth.login('admin', 'admin123');
      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isDeveloper, isFalse);
      expect(auth.isAdmin, isTrue);
      expect(auth.currentUser?.role, equals(UserRole.admin));

      // RBAC Permission checks for Admin
      expect(auth.canDelete, isTrue);
      expect(auth.canPurgeRecycleBin, isTrue);
      expect(auth.canManageUsers, isTrue);
      expect(auth.canManageSettings, isTrue);
      expect(auth.canViewAuditLogs, isTrue);
      expect(auth.canClearAuditLogs, isTrue);
    });

    test('Manager role permissions allow edits & exports but prevent user management or log clearing', () async {
      final success = await auth.login('manager', 'manager123');
      expect(success, isTrue);
      expect(auth.currentUser?.role, equals(UserRole.manager));

      expect(auth.canDelete, isTrue);
      expect(auth.canViewAuditLogs, isTrue);
      expect(auth.canPurgeRecycleBin, isFalse);
      expect(auth.canClearAuditLogs, isFalse);
      expect(auth.canManageUsers, isFalse);
      expect(auth.canManageSettings, isFalse);
    });

    test('Clerk role permissions allow entry/view only (no deletions, no user management)', () async {
      final success = await auth.login('clerk', 'clerk123');
      expect(success, isTrue);
      expect(auth.currentUser?.role, equals(UserRole.clerk));

      expect(auth.canDelete, isFalse);
      expect(auth.canPurgeRecycleBin, isFalse);
      expect(auth.canViewAuditLogs, isFalse);
      expect(auth.canClearAuditLogs, isFalse);
      expect(auth.canManageUsers, isFalse);
      expect(auth.canManageSettings, isFalse);
    });

    test('Invalid login fails with false', () async {
      final success = await auth.login('admin', 'wrong_pass');
      expect(success, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('Logout clears session', () async {
      await auth.login('admin', 'admin123');
      expect(auth.isAuthenticated, isTrue);

      await auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    });
  });

  group('Dynamic Role Permissions & Database Persistence Tests', () {
    late StorageService storage;
    late AuthProvider auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      auth = AuthProvider(storage);
      await auth.initialize();
    });

    test('Admin dynamically grants new permissions to Clerk and it persists across app restart', () async {
      // 1. Initial Clerk permissions
      await auth.login('clerk', 'clerk123');
      expect(auth.canManageParties, isFalse);
      expect(auth.canDelete, isFalse);

      // 2. Admin logs in and dynamically updates Clerk permissions
      await auth.login('admin', 'admin123');
      final currentClerkPerms = auth.permissionsFor(UserRole.clerk);
      final updatedClerkPerms = currentClerkPerms.copyWith(
        canManageParties: true,
        canDeleteChallan: true,
      );

      await auth.updateRolePermissions(UserRole.clerk, updatedClerkPerms);

      // 3. Verify in current session
      expect(auth.permissionsFor(UserRole.clerk).canManageParties, isTrue);
      expect(auth.permissionsFor(UserRole.clerk).canDeleteChallan, isTrue);

      // 4. Simulate app restart: re-initialize AuthProvider from database storage
      final newAuthProvider = AuthProvider(storage);
      await newAuthProvider.initialize();
      await newAuthProvider.login('clerk', 'clerk123');

      // 5. Verify dynamic permissions survived persistence in database
      expect(newAuthProvider.canManageParties, isTrue);
      expect(newAuthProvider.canDelete, isTrue);
    });

    test('Admin role safety lock prevents revoking canManageUsers on Admin account', () async {
      await auth.login('admin', 'admin123');
      final adminPerms = auth.permissionsFor(UserRole.admin);

      // Attempt to revoke user management on admin
      await auth.updateRolePermissions(
        UserRole.admin,
        adminPerms.copyWith(canManageUsers: false),
      );

      // Verify safety lock enforced
      expect(auth.permissionsFor(UserRole.admin).canManageUsers, isTrue);
      expect(auth.canManageUsers, isTrue);
    });

    test('Reset permissions restores factory defaults in database', () async {
      // Modify Clerk permission
      await auth.login('admin', 'admin123');
      final current = auth.permissionsFor(UserRole.clerk);
      await auth.updateRolePermissions(
        UserRole.clerk,
        current.copyWith(canManageParties: true),
      );
      expect(auth.permissionsFor(UserRole.clerk).canManageParties, isTrue);

      // Reset to defaults
      await auth.resetRolePermissions(UserRole.clerk);
      expect(auth.permissionsFor(UserRole.clerk).canManageParties, isFalse);

      // Check database persistence
      final savedInDb = await storage.loadRolePermissions();
      expect(savedInDb['clerk']?.canManageParties, isFalse);
    });

    test('Visibility rule: Admin CANNOT view Developer role or Developer users', () async {
      await auth.login('admin', 'admin123');

      // Admin visible roles must NOT contain Developer
      final visibleRoles = auth.visibleRoles;
      final roleIds = visibleRoles.map((r) => r.id).toList();
      expect(roleIds, isNot(contains(AppRole.developerId)));
      expect(roleIds, containsAll([AppRole.adminId, AppRole.managerId, AppRole.clerkId]));

      // Admin visible users must NOT contain Developer
      final visibleUsers = auth.visibleUsers;
      final usernames = visibleUsers.map((u) => u.username).toList();
      expect(usernames, isNot(contains('developer')));
      expect(usernames, containsAll(['admin', 'manager', 'clerk']));
      expect(visibleUsers.length, equals(3));
    });

    test('Visibility rule: Developer CAN view all roles including Developer and all users', () async {
      await auth.login('developer', 'developer123');

      // Developer visible roles must contain all roles including Developer
      final visibleRoles = auth.visibleRoles;
      final roleIds = visibleRoles.map((r) => r.id).toList();
      expect(roleIds, containsAll([AppRole.developerId, AppRole.adminId, AppRole.managerId, AppRole.clerkId]));

      // Developer visible users must contain all users including developer
      final visibleUsers = auth.visibleUsers;
      final usernames = visibleUsers.map((u) => u.username).toList();
      expect(usernames, containsAll(['developer', 'admin', 'manager', 'clerk']));
      expect(visibleUsers.length, equals(4));
    });

    test('Admin and Developer can add a new custom role and assign dynamic permissions', () async {
      await auth.login('admin', 'admin123');

      // Add a custom role "Accountant"
      final newRole = await auth.createCustomRole(
        name: 'Accountant',
        description: 'Manages ledger and tax invoices',
        copyFromRoleId: AppRole.clerkId,
      );

      expect(newRole.name, equals('Accountant'));
      expect(newRole.isBuiltIn, isFalse);

      // Verify custom role is in visible roles
      expect(auth.visibleRoles.any((r) => r.id == newRole.id), isTrue);

      // Verify default permissions copied from clerk
      expect(auth.permissionsForId(newRole.id).canCreateChallan, isTrue);
      expect(auth.permissionsForId(newRole.id).canDeleteChallan, isFalse);

      // Admin updates Accountant permissions to allow deleting challans
      final currentPerms = auth.permissionsForId(newRole.id);
      await auth.updateRolePermissionsForId(
        newRole.id,
        currentPerms.copyWith(canDeleteChallan: true),
      );
      expect(auth.permissionsForId(newRole.id).canDeleteChallan, isTrue);

      // Create a user assigned to this custom role
      final userCreated = await auth.addUser(
        username: 'ramesh_acc',
        password: 'password123',
        displayName: 'Ramesh (Accountant)',
        roleId: newRole.id,
      );
      expect(userCreated, isTrue);

      // Login as the custom role user and verify permissions
      await auth.login('ramesh_acc', 'password123');
      expect(auth.currentRoleId, equals(newRole.id));
      expect(auth.canCreateChallan, isTrue);
      expect(auth.canDeleteChallan, isTrue);
      expect(auth.canPurgeRecycleBin, isFalse);
    });

    test('Dynamic role permissions and custom roles are preserved in backup JSON export/import', () async {
      await auth.login('developer', 'developer123');

      // Create custom role
      final customRole = await auth.createCustomRole(
        name: 'Store Supervisor',
        description: 'Warehouse supervisor',
        copyFromRoleId: AppRole.managerId,
      );

      final current = auth.permissionsFor(UserRole.manager);
      await auth.updateRolePermissions(
        UserRole.manager,
        current.copyWith(canPurgeRecycleBin: true),
      );

      // Export JSON
      final backupJson = await storage.exportBackupJson();
      expect(backupJson, contains('rolePermissions'));
      expect(backupJson, contains('customRoles'));
      expect(backupJson, contains('Store Supervisor'));
      expect(backupJson, contains('"canPurgeRecycleBin": true'));

      // Clear all data
      await storage.clearAllData();
      final blankPermissions = await storage.loadRolePermissions();
      expect(blankPermissions.isEmpty, isTrue);
      final blankRoles = await storage.loadCustomRoles();
      expect(blankRoles.isEmpty, isTrue);

      // Import backup JSON
      final importSuccess = await storage.importBackupJson(backupJson);
      expect(importSuccess, isTrue);

      final restoredPerms = await storage.loadRolePermissions();
      expect(restoredPerms['manager']?.canPurgeRecycleBin, isTrue);
      expect(restoredPerms[customRole.id]?.canCreateChallan, isTrue);

      final restoredRoles = await storage.loadCustomRoles();
      expect(restoredRoles.any((r) => r.name == 'Store Supervisor'), isTrue);
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
      await auth.login('admin', 'admin123');
    });

    test('Login generates AuditAction.login entry', () {
      final loginLogs = provider.auditLogs.where((l) => l.action == AuditAction.login);
      expect(loginLogs.isNotEmpty, isTrue);
      expect(loginLogs.first.performedBy, equals('admin'));
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
}
