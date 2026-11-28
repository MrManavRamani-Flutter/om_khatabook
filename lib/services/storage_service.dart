import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/app_user.dart';
import '../models/audit_log_entry.dart';
import '../models/challan_entry.dart';
import '../models/income_expense_entry.dart';
import '../models/party.dart';

class StorageService {
  static const String _keyParties = 'om_parties_v2';
  static const String _keyChallans = 'om_challans_v2';
  static const String _keyThemeMode = 'om_theme_mode_v2';
  static const String _keyFirstRun = 'om_first_run_v2';
  static const String _keyLedgerViewMode = 'om_ledger_view_mode_v2';
  static const String _keyPartyViewMode = 'om_party_view_mode_v2';
  static const String _keyTextCasingRule = 'om_text_casing_rule_v2';
  static const String _keyCleanMigration = 'om_clean_parties_v3';
  static const String _keyAppLogoBase64 = 'om_app_logo_base64_v2';
  static const String _keyProfileLogoBase64 = 'om_profile_logo_base64_v2';
  static const String _keyCompanyName = 'om_company_name_v2';
  static const String _keyCompanyTagline = 'om_company_tagline_v2';
  static const String _keyAdminName = 'om_admin_name_v2';
  static const String _keyAdminRole = 'om_admin_role_v2';
  static const String _keySidebarCollapsed = 'om_sidebar_collapsed_v2';
  static const String _keyUsers = 'om_users_v2';
  static const String _keyActiveSession = 'om_active_session_v2';
  static const String _keyAuditLogs = 'om_audit_logs_v2';
  static const String _keyRolePermissions = 'om_role_permissions_v2';
  static const String _keyCustomRoles = 'om_custom_roles_v2';
  static const String _keyIncomeExpenseEntries = 'om_income_expense_entries_v1';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await migrateDatabase();
  }

  /// Automatically discovers and upgrades database schemas, legacy keys,
  /// and missing fields when installing or updating across systems.
  Future<void> migrateDatabase() async {
    try {
      // 1. Migrate legacy party keys (e.g. from v1.0.0 or pre-v2 builds)
      final currentPartiesStr = _prefs.getString(_keyParties);
      if (currentPartiesStr == null || currentPartiesStr.trim() == '[]' || currentPartiesStr.isEmpty) {
        final legacyPartiesStr = _prefs.getString('om_parties') ?? _prefs.getString('om_parties_data');
        if (legacyPartiesStr != null && legacyPartiesStr.isNotEmpty && legacyPartiesStr.trim() != '[]') {
          await _prefs.setString(_keyParties, legacyPartiesStr);
          debugPrint('Successfully migrated legacy parties into $_keyParties');
        }
      }

      // 2. Migrate legacy challans or transactions
      final currentChallansStr = _prefs.getString(_keyChallans);
      if (currentChallansStr == null || currentChallansStr.trim() == '[]' || currentChallansStr.isEmpty) {
        final legacyChallansStr = _prefs.getString('om_challans');
        if (legacyChallansStr != null && legacyChallansStr.isNotEmpty && legacyChallansStr.trim() != '[]') {
          await _prefs.setString(_keyChallans, legacyChallansStr);
          debugPrint('Successfully migrated legacy challans into $_keyChallans');
        } else {
          final legacyTxStr = _prefs.getString('om_transactions_data');
          if (legacyTxStr != null && legacyTxStr.isNotEmpty && legacyTxStr.trim() != '[]') {
            try {
              final List txList = jsonDecode(legacyTxStr) as List;
              final converted = txList.map((tx) {
                if (tx is Map) {
                  final m = Map<String, dynamic>.from(tx);
                  final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
                  return {
                    'id': m['id'] ?? 'migrated_${DateTime.now().millisecondsSinceEpoch}',
                    'challanNo': m['referenceNo'] ?? m['id'] ?? 'CH-LEGACY',
                    'partyId': m['partyId'] ?? '',
                    'partyName': m['partyName'] ?? 'Legacy Party',
                    'date': m['date'] ?? DateTime.now().toIso8601String(),
                    'challanAmount': amt,
                    'hasGstBill': false,
                    'gstRate': 0.0,
                    'gstAmount': 0.0,
                    'finalAmount': amt,
                    'paidAmount': amt,
                    'paymentOption': 'cash',
                    'paymentStatus': 'paid',
                    'notes': m['description'] ?? 'Migrated legacy transaction',
                    'createdAt': m['createdAt'] ?? DateTime.now().toIso8601String(),
                    'createdBy': 'OM MAVTAR',
                  };
                }
                return tx;
              }).toList();
              await _prefs.setString(_keyChallans, jsonEncode(converted));
              debugPrint('Successfully converted legacy transactions into $_keyChallans');
            } catch (e) {
              debugPrint('Error converting legacy transactions: $e');
            }
          }
        }
      }

      // 2b. Auto-discover exported backup file if active database has 0 challans
      // Only run in live app environment, skip during unit test execution
      final isTestEnv = Platform.environment.containsKey('FLUTTER_TEST');
      if (!isTestEnv) {
        final challansCheck = _prefs.getString(_keyChallans);
        if (challansCheck == null || challansCheck.trim() == '[]' || challansCheck.isEmpty) {
          final recentBackups = await getRecentBackupFiles();
          for (final backupFile in recentBackups) {
            try {
              if (await backupFile.exists()) {
                final content = await backupFile.readAsString();
                final dynamic decoded = jsonDecode(content);
                if (decoded is Map<String, dynamic>) {
                  final cList = decoded['challans'];
                  final pList = decoded['parties'];
                  if (cList is List && cList.isNotEmpty) {
                    await _prefs.setString(_keyChallans, jsonEncode(cList));
                    if (pList is List && pList.isNotEmpty) {
                      await _prefs.setString(_keyParties, jsonEncode(pList));
                    }
                    debugPrint('Auto-restored ${cList.length} challans and ${(pList as List?)?.length ?? 0} parties from backup: ${backupFile.path}');
                    break;
                  }
                }
              }
            } catch (e) {
              debugPrint('Error inspecting backup file ${backupFile.path}: $e');
            }
          }
        }
      }

      // 3. Upgrade existing challans schema (ensure paidAmount & createdBy = OM MAVTAR)
      final existingChallansJson = _prefs.getString(_keyChallans);
      if (existingChallansJson != null && existingChallansJson.isNotEmpty) {
        try {
          final List list = jsonDecode(existingChallansJson) as List;
          bool modified = false;
          final upgraded = list.map((item) {
            if (item is Map) {
              final m = Map<String, dynamic>.from(item);
              // Ensure discountAmount
              if (!m.containsKey('discountAmount') || m['discountAmount'] == null) {
                final disc = (m['discount'] as num?)?.toDouble() ?? 0.0;
                m['discountAmount'] = disc;
                modified = true;
              }
              // Ensure notes
              if (!m.containsKey('notes') || m['notes'] == null) {
                m['notes'] = m['note'] ?? m['remarks'] ?? m['description'] ?? '';
                modified = true;
              }
              // Ensure paymentDueDate from dueDate if present
              if (!m.containsKey('paymentDueDate') && m.containsKey('dueDate')) {
                m['paymentDueDate'] = m['dueDate'];
                modified = true;
              }
              if (!m.containsKey('paidAmount') || m['paidAmount'] == null) {
                final status = (m['paymentStatus'] as String?)?.toLowerCase();
                final finalAmt = (m['finalAmount'] as num?)?.toDouble() ??
                    (m['challanAmount'] as num?)?.toDouble() ??
                    0.0;
                if (status == 'paid') {
                  m['paidAmount'] = finalAmt;
                } else if (status == 'pending' || status == 'unpaid' || status == 'warning') {
                  m['paidAmount'] = 0.0;
                } else {
                  m['paidAmount'] = finalAmt;
                }
                modified = true;
              }
              if (m['createdBy'] == null ||
                  m['createdBy'] == 'system' ||
                  m['createdBy'] == 'developer' ||
                  m['createdBy'] == 'admin') {
                m['createdBy'] = 'OM MAVTAR';
                modified = true;
              }
              return m;
            }
            return item;
          }).toList();
          if (modified) {
            await _prefs.setString(_keyChallans, jsonEncode(upgraded));
            debugPrint('Upgraded existing challan entries schema (paidAmount & createdBy).');
          }
        } catch (e) {
          debugPrint('Error upgrading existing challans: $e');
        }
      }

      // 4. Migrate legacy users if needed
      final currentUsersStr = _prefs.getString(_keyUsers);
      if (currentUsersStr == null || currentUsersStr.trim() == '[]') {
        final legacyUsers = _prefs.getString('om_users');
        if (legacyUsers != null && legacyUsers.isNotEmpty) {
          await _prefs.setString(_keyUsers, legacyUsers);
        }
      }

      // 5. Migrate active session: normalize any developer/admin to OMMAVTAR36
      final sessionStr = _prefs.getString(_keyActiveSession) ?? _prefs.getString('om_active_session');
      if (sessionStr != null && sessionStr.isNotEmpty) {
        try {
          final sessionMap = jsonDecode(sessionStr) as Map<String, dynamic>;
          sessionMap['id'] = 'user_ommavtar36';
          sessionMap['username'] = 'OMMAVTAR36';
          sessionMap['displayName'] = 'OM MAVTAR';
          sessionMap['password'] = 'OMMAVTAR36';
          sessionMap['role'] = 'admin';
          sessionMap['roleId'] = 'admin';
          sessionMap['createdAt'] = sessionMap['createdAt'] ?? DateTime.now().toIso8601String();
          sessionMap['createdBy'] = 'system';
          await _prefs.setString(_keyActiveSession, jsonEncode(sessionMap));
        } catch (_) {}
      }

      // 6. Migrate branding settings if existing in old non-v2 keys
      if (_prefs.getString(_keyCompanyName) == null) {
        final oldName = _prefs.getString('om_company_name');
        if (oldName != null) await _prefs.setString(_keyCompanyName, oldName);
      }
      if (_prefs.getString(_keyCompanyTagline) == null) {
        final oldTagline = _prefs.getString('om_company_tagline');
        if (oldTagline != null) await _prefs.setString(_keyCompanyTagline, oldTagline);
      }
      if (_prefs.getString(_keyAppLogoBase64) == null) {
        final oldLogo = _prefs.getString('om_app_logo_base64');
        if (oldLogo != null) await _prefs.setString(_keyAppLogoBase64, oldLogo);
      }
      if (_prefs.getString(_keyProfileLogoBase64) == null) {
        final oldProfileLogo = _prefs.getString('om_profile_logo_base64');
        if (oldProfileLogo != null) await _prefs.setString(_keyProfileLogoBase64, oldProfileLogo);
      }

      // 7. Stamp current database schema version
      await _prefs.setString('om_database_version', '2.1.0');
    } catch (e) {
      debugPrint('Database migration error: $e');
    }
  }

  bool get isFirstRun => !(_prefs.getBool(_keyFirstRun) ?? false);

  Future<void> markFirstRunComplete() async {
    await _prefs.setBool(_keyFirstRun, true);
  }

  bool get isCleanDataMigrated => _prefs.getBool(_keyCleanMigration) ?? false;

  Future<void> markCleanDataMigrated() async {
    await _prefs.setBool(_keyCleanMigration, true);
  }

  // --- THEME ---
  bool get isDarkMode => _prefs.getBool(_keyThemeMode) ?? false;
  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_keyThemeMode, value);
  }

  // --- VIEW MODE (TABLE / CARDS / COMPACT) ---
  String get ledgerViewMode => _prefs.getString(_keyLedgerViewMode) ?? 'table';
  Future<void> setLedgerViewMode(String mode) async {
    await _prefs.setString(_keyLedgerViewMode, mode);
  }

  String get partyViewMode => _prefs.getString(_keyPartyViewMode) ?? 'table';
  Future<void> setPartyViewMode(String mode) async {
    await _prefs.setString(_keyPartyViewMode, mode);
  }

  // --- COLLAPSIBLE SIDEBAR ---
  bool get isSidebarCollapsed => _prefs.getBool(_keySidebarCollapsed) ?? false;
  Future<void> setSidebarCollapsed(bool value) async {
    await _prefs.setBool(_keySidebarCollapsed, value);
  }

  // --- TEXT CASING PREFERENCE (UPPERCASE DEFAULT) ---
  String get textCasingStyle => _prefs.getString(_keyTextCasingRule) ?? 'uppercase';
  Future<void> setTextCasingStyle(String style) async {
    await _prefs.setString(_keyTextCasingRule, style);
  }

  // --- BRANDING & LOGOS (SIDEBAR & PROFILE) ---
  String get appLogoBase64 => _prefs.getString(_keyAppLogoBase64) ?? '';
  Future<void> setAppLogoBase64(String base64) async {
    await _prefs.setString(_keyAppLogoBase64, base64);
  }

  String get profileLogoBase64 => _prefs.getString(_keyProfileLogoBase64) ?? '';
  Future<void> setProfileLogoBase64(String base64) async {
    await _prefs.setString(_keyProfileLogoBase64, base64);
  }

  String get companyName => _prefs.getString(_keyCompanyName) ?? 'OM Mavtar Group';
  Future<void> setCompanyName(String name) async {
    await _prefs.setString(_keyCompanyName, name);
  }

  String get companyTagline => _prefs.getString(_keyCompanyTagline) ?? 'Khata Book Desktop';
  Future<void> setCompanyTagline(String tagline) async {
    await _prefs.setString(_keyCompanyTagline, tagline);
  }

  String get adminName => _prefs.getString(_keyAdminName) ?? 'OM Mavtar Admin';
  Future<void> setAdminName(String name) async {
    await _prefs.setString(_keyAdminName, name);
  }

  String get adminRole => _prefs.getString(_keyAdminRole) ?? 'Administrator';
  Future<void> setAdminRole(String role) async {
    await _prefs.setString(_keyAdminRole, role);
  }

  // --- GENERIC INT PREFERENCE (for session timeout, custom days, etc.) ---
  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  // --- THEME & STATUS COLORS ---
  int? get themePrimaryColorValue => _prefs.getInt('om_theme_primary_color');
  Future<void> setThemePrimaryColorValue(int value) => _prefs.setInt('om_theme_primary_color', value);

  int? get statusSuccessColorValue => _prefs.getInt('om_status_success_color');
  Future<void> setStatusSuccessColorValue(int value) => _prefs.setInt('om_status_success_color', value);

  int? get statusPartialColorValue => _prefs.getInt('om_status_partial_color');
  Future<void> setStatusPartialColorValue(int value) => _prefs.setInt('om_status_partial_color', value);

  int? get statusWarningColorValue => _prefs.getInt('om_status_warning_color');
  Future<void> setStatusWarningColorValue(int value) => _prefs.setInt('om_status_warning_color', value);

  bool get isHighContrast => _prefs.getBool('om_high_contrast_text') ?? true;
  Future<void> setHighContrast(bool value) => _prefs.setBool('om_high_contrast_text', value);

  String get themePresetName => _prefs.getString('om_theme_preset') ?? 'Teal';
  Future<void> setThemePresetName(String name) => _prefs.setString('om_theme_preset', name);

  // --- PARTIES ---
  Future<List<Party>> loadParties() async {
    final str = _prefs.getString(_keyParties);
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List<dynamic>;
        return list
            .map((e) => Party.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading parties: $e');
      }
    }
    return [];
  }

  Future<void> saveParties(List<Party> parties) async {
    final list = parties.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyParties, jsonEncode(list));
  }

  // --- CHALLAN ENTRIES ---
  Future<List<ChallanEntry>> loadChallans() async {
    final str = _prefs.getString(_keyChallans);
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List<dynamic>;
        return list
            .map((e) => ChallanEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading challan entries: $e');
      }
    }
    return [];
  }

  Future<void> saveChallans(List<ChallanEntry> challans) async {
    final list = challans.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyChallans, jsonEncode(list));
  }

  // --- USERS & AUTHENTICATION (RBAC) ---
  Future<List<AppUser>> loadUsers() async {
    final str = _prefs.getString(_keyUsers);
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List<dynamic>;
        return list
            .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading users: $e');
      }
    }
    return [];
  }

  Future<void> saveUsers(List<AppUser> users) async {
    final list = users.map((u) => u.toJson()).toList();
    await _prefs.setString(_keyUsers, jsonEncode(list));
  }

  Future<AppUser?> loadActiveSessionUser() async {
    final str = _prefs.getString(_keyActiveSession);
    if (str != null && str.isNotEmpty) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return AppUser.fromJson(map);
      } catch (e) {
        debugPrint('Error loading active session user: $e');
        try {
          final map = jsonDecode(str) as Map<String, dynamic>;
          if (map.containsKey('username')) {
            return AppUser(
              id: map['id'] ?? 'user_ommavtar36',
              username: map['username'] ?? 'OMMAVTAR36',
              password: map['password'] ?? 'OMMAVTAR36',
              displayName: map['displayName'] ?? 'OM MAVTAR',
              roleId: map['roleId'] ?? 'admin',
              role: UserRole.admin,
              createdAt: DateTime.now(),
              createdBy: 'system',
            );
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> saveActiveSessionUser(AppUser? user) async {
    if (user == null) {
      await _prefs.remove(_keyActiveSession);
    } else {
      await _prefs.setString(_keyActiveSession, jsonEncode(user.toJson()));
    }
  }

  // --- CUSTOM ROLES & DYNAMIC ROLE PERMISSIONS (RBAC) ---
  Future<List<AppRole>> loadCustomRoles() async {
    final str = _prefs.getString(_keyCustomRoles);
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List<dynamic>;
        return list
            .map((e) => AppRole.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading custom roles: $e');
      }
    }
    return [];
  }

  Future<void> saveCustomRoles(List<AppRole> roles) async {
    final list = roles.map((r) => r.toJson()).toList();
    await _prefs.setString(_keyCustomRoles, jsonEncode(list));
  }

  Future<Map<String, RolePermissions>> loadRolePermissions() async {
    final str = _prefs.getString(_keyRolePermissions);
    if (str != null && str.isNotEmpty) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        final result = <String, RolePermissions>{};
        for (final entry in map.entries) {
          result[entry.key] =
              RolePermissions.fromJson(entry.value as Map<String, dynamic>);
        }
        return result;
      } catch (e) {
        debugPrint('Error loading role permissions: $e');
      }
    }
    return {};
  }

  Future<void> saveRolePermissions(
      Map<String, RolePermissions> permissions) async {
    final map = <String, dynamic>{};
    for (final entry in permissions.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await _prefs.setString(_keyRolePermissions, jsonEncode(map));
  }

  // --- AUDIT TRAIL & HISTORY LOGS ---
  Future<List<AuditLogEntry>> loadAuditLogs() async {
    final str = _prefs.getString(_keyAuditLogs);
    List<AuditLogEntry> logs = [];
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List<dynamic>;
        logs = list
            .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading audit logs: $e');
      }
    }

    // Normalize any legacy/default entries to the single master operator OM MAVTAR [MASTER]
    bool needsResave = false;
    final normalized = <AuditLogEntry>[];
    for (final entry in logs) {
      if (entry.performedBy != 'OM MAVTAR' || entry.userRole != 'MASTER') {
        needsResave = true;
        normalized.add(entry.copyWith(
          performedBy: 'OM MAVTAR',
          userRole: 'MASTER',
        ));
      } else {
        normalized.add(entry);
      }
    }

    // If completely empty, seed an initial master session log
    if (normalized.isEmpty) {
      normalized.add(AuditLogEntry(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        action: AuditAction.login,
        entityType: AuditEntityType.auth,
        entityId: 'OM_MAVTAR',
        entityTitle: 'Master System Session',
        performedBy: 'OM MAVTAR',
        userRole: 'MASTER',
        description: 'Master operator OM MAVTAR session initialized',
      ));
      needsResave = true;
    }

    if (needsResave) {
      await saveAuditLogs(normalized);
    }

    return normalized;
  }

  Future<void> saveAuditLogs(List<AuditLogEntry> logs) async {
    // Keep up to 2000 most recent logs
    final trimmed = logs.length > 2000 ? logs.sublist(0, 2000) : logs;
    final list = trimmed.map((l) => l.toJson()).toList();
    await _prefs.setString(_keyAuditLogs, jsonEncode(list));
  }

  // --- INCOME & EXPENSE LEDGER ENTRIES (PROFIT & LOSS) ---
  Future<List<IncomeExpenseEntry>> loadIncomeExpenseEntries() async {
    final str = _prefs.getString(_keyIncomeExpenseEntries);
    if (str == null || str.isEmpty) {
      // Seed default sample entries:
      // Expenses: Electricity Bill (50), Staff Salary (50)
      // Income: Om Kiran (10), Pradip (20)
      final now = DateTime.now();
      return [
        IncomeExpenseEntry(
          id: 'exp_default_1',
          type: EntryType.expense,
          date: now,
          particular: 'Electricity Bill (Light Bill)',
          amount: 50.0,
          category: 'Utility & Bills',
          paymentMode: 'Cash',
          createdAt: now,
          createdBy: 'OM MAVTAR',
        ),
        IncomeExpenseEntry(
          id: 'exp_default_2',
          type: EntryType.expense,
          date: now,
          particular: 'Staff Salary (Monthly Wages)',
          amount: 50.0,
          category: 'Salary & Wages',
          paymentMode: 'Cash',
          createdAt: now,
          createdBy: 'OM MAVTAR',
        ),
        IncomeExpenseEntry(
          id: 'inc_default_1',
          type: EntryType.income,
          date: now,
          particular: 'Om Kiran (Sales Income)',
          amount: 10.0,
          category: 'Party Sales',
          paymentMode: 'Cash',
          createdAt: now,
          createdBy: 'OM MAVTAR',
        ),
        IncomeExpenseEntry(
          id: 'inc_default_2',
          type: EntryType.income,
          date: now,
          particular: 'Pradip (Sales Income)',
          amount: 20.0,
          category: 'Party Sales',
          paymentMode: 'Cash',
          createdAt: now,
          createdBy: 'OM MAVTAR',
        ),
      ];
    }
    try {
      final List decoded = jsonDecode(str) as List;
      return decoded
          .map((e) => IncomeExpenseEntry.fromJson(e as Map<String, dynamic>))
          .where((e) => !e.isDeleted)
          .toList();
    } catch (e) {
      debugPrint('Error loading income/expense entries: $e');
      return [];
    }
  }

  Future<void> saveIncomeExpenseEntries(List<IncomeExpenseEntry> entries) async {
    final list = entries.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyIncomeExpenseEntries, jsonEncode(list));
  }

  // --- BACKUP & RESTORE ---
  Future<String> exportBackupJson() async {
    final partiesStr = _prefs.getString(_keyParties) ?? '[]';
    final challansStr = _prefs.getString(_keyChallans) ?? '[]';
    final usersStr = _prefs.getString(_keyUsers) ?? '[]';
    final auditStr = _prefs.getString(_keyAuditLogs) ?? '[]';
    final permissionsStr = _prefs.getString(_keyRolePermissions) ?? '{}';
    final customRolesStr = _prefs.getString(_keyCustomRoles) ?? '[]';
    final entriesStr = _prefs.getString(_keyIncomeExpenseEntries) ?? '[]';

    final data = {
      'app': 'OM Mavtar Group Khata Book',
      'version': '2.1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'parties': jsonDecode(partiesStr),
      'challans': jsonDecode(challansStr),
      'users': jsonDecode(usersStr),
      'auditLogs': jsonDecode(auditStr),
      'rolePermissions': jsonDecode(permissionsStr),
      'customRoles': jsonDecode(customRolesStr),
      'incomeExpenseEntries': jsonDecode(entriesStr),
      'branding': {
        'companyName': companyName,
        'companyTagline': companyTagline,
        'adminName': adminName,
        'adminRole': adminRole,
        'appLogoBase64': appLogoBase64,
        'profileLogoBase64': profileLogoBase64,
        'textCasingStyle': textCasingStyle,
        'ledgerViewMode': ledgerViewMode,
        'partyViewMode': partyViewMode,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String> saveBackupToDocuments() async {
    final jsonStr = await exportBackupJson();
    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'OM_Mavtar_ChallanLedger_Backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(jsonStr);
    return file.path;
  }

  Future<List<File>> getRecentBackupFiles() async {
    final files = <File>[];
    final seenPaths = <String>{};

    void scanDir(Directory dir) {
      try {
        if (!dir.existsSync()) return;
        final entities = dir.listSync();
        for (final e in entities) {
          if (e is File) {
            final name = e.uri.pathSegments.last;
            if ((name.startsWith('OM_Mavtar_') || name.startsWith('OM_Khatabook_')) &&
                name.endsWith('.json')) {
              if (seenPaths.add(e.path)) {
                files.add(e);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error scanning dir ${dir.path}: $e');
      }
    }

    try {
      final docDir = await getApplicationDocumentsDirectory();
      scanDir(docDir);

      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        scanDir(Directory('$home/Downloads'));
        scanDir(Directory('$home/Documents'));
        scanDir(Directory('$home/Desktop'));
      }
    } catch (e) {
      debugPrint('Error listing backup files: $e');
    }

    files.sort((a, b) {
      try {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });

    return files;
  }

  Future<bool> importBackupJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (data.containsKey('parties')) {
        await _prefs.setString(_keyParties, jsonEncode(data['parties']));
      }
      if (data.containsKey('challans')) {
        await _prefs.setString(_keyChallans, jsonEncode(data['challans']));
      } else if (data.containsKey('transactions')) {
        final txList = data['transactions'] as List;
        final converted = txList.map((tx) {
          if (tx is Map) {
            final m = Map<String, dynamic>.from(tx);
            final rawAmt = m['amount'];
            double amt = 0.0;
            if (rawAmt is num) {
              amt = rawAmt.toDouble();
            } else if (rawAmt != null) {
              final clean = rawAmt.toString().replaceAll('₹', '').replaceAll(',', '').replaceAll('Rs.', '').replaceAll(' ', '').trim();
              amt = double.tryParse(clean) ?? 0.0;
            }
            return {
              'id': m['id'] ?? 'migrated_${DateTime.now().millisecondsSinceEpoch}',
              'challanNo': m['referenceNo'] ?? m['id'] ?? 'CH-LEGACY',
              'partyId': m['partyId'] ?? '',
              'partyName': m['partyName'] ?? 'Legacy Party',
              'date': m['date'] ?? DateTime.now().toIso8601String(),
              'challanAmount': amt,
              'discountAmount': 0.0,
              'hasGstBill': false,
              'gstRate': 0.0,
              'gstAmount': 0.0,
              'finalAmount': amt,
              'paidAmount': amt,
              'paymentOption': 'cash',
              'paymentStatus': 'paid',
              'notes': m['description'] ?? m['notes'] ?? m['remarks'] ?? 'Migrated from legacy backup',
              'createdAt': m['createdAt'] ?? DateTime.now().toIso8601String(),
              'createdBy': 'OM MAVTAR',
            };
          }
          return tx;
        }).toList();
        await _prefs.setString(_keyChallans, jsonEncode(converted));
      }

      if (data.containsKey('users')) {
        await _prefs.setString(_keyUsers, jsonEncode(data['users']));
      }
      if (data.containsKey('auditLogs')) {
        await _prefs.setString(_keyAuditLogs, jsonEncode(data['auditLogs']));
      }
      if (data.containsKey('rolePermissions')) {
        await _prefs.setString(_keyRolePermissions, jsonEncode(data['rolePermissions']));
      }
      if (data.containsKey('customRoles')) {
        await _prefs.setString(_keyCustomRoles, jsonEncode(data['customRoles']));
      }
      if (data.containsKey('incomeExpenseEntries')) {
        await _prefs.setString(_keyIncomeExpenseEntries, jsonEncode(data['incomeExpenseEntries']));
      } else if (data.containsKey('dayEntries')) {
        final deList = data['dayEntries'] as List;
        final converted = deList.map((de) {
          if (de is Map) {
            final m = Map<String, dynamic>.from(de);
            final typeStr = (m['type'] as String?)?.toLowerCase() ?? 'expense';
            final rawAmt = m['amount'];
            double amt = 0.0;
            if (rawAmt is num) {
              amt = rawAmt.toDouble();
            } else if (rawAmt != null) {
              final clean = rawAmt.toString().replaceAll('₹', '').replaceAll(',', '').replaceAll('Rs.', '').replaceAll(' ', '').trim();
              amt = double.tryParse(clean) ?? 0.0;
            }
            return {
              'id': m['id'] ?? 'de_${DateTime.now().millisecondsSinceEpoch}',
              'type': typeStr == 'income' ? 'income' : 'expense',
              'date': m['date'] ?? DateTime.now().toIso8601String(),
              'particular': m['description'] ?? m['particular'] ?? '',
              'amount': amt,
              'category': m['category'] ?? m['group'] ?? (typeStr == 'income' ? 'Income' : 'Expense'),
              'paymentMode': m['paymentMode'] ?? m['mode'] ?? 'Cash',
              'notes': m['remarks'] ?? m['remark'] ?? m['notes'] ?? m['note'] ?? '',
              'createdAt': m['createdAt'] ?? DateTime.now().toIso8601String(),
              'createdBy': 'OM MAVTAR',
            };
          }
          return de;
        }).toList();
        await _prefs.setString(_keyIncomeExpenseEntries, jsonEncode(converted));
      }

      if (data.containsKey('branding') &&
          data['branding'] is Map<String, dynamic>) {
        final b = data['branding'] as Map<String, dynamic>;
        if (b['companyName'] != null) await setCompanyName(b['companyName'] as String);
        if (b['companyTagline'] != null) await setCompanyTagline(b['companyTagline'] as String);
        if (b['adminName'] != null) await setAdminName(b['adminName'] as String);
        if (b['adminRole'] != null) await setAdminRole(b['adminRole'] as String);
        if (b['appLogoBase64'] != null) await setAppLogoBase64(b['appLogoBase64'] as String);
        if (b['profileLogoBase64'] != null) await setProfileLogoBase64(b['profileLogoBase64'] as String);
        if (b['textCasingStyle'] != null) await setTextCasingStyle(b['textCasingStyle'] as String);
        if (b['ledgerViewMode'] != null) await setLedgerViewMode(b['ledgerViewMode'] as String);
        if (b['partyViewMode'] != null) await setPartyViewMode(b['partyViewMode'] as String);
      }
      if (data.containsKey('appLogoBase64')) {
        await setAppLogoBase64(data['appLogoBase64'] as String);
      }
      if (data.containsKey('profileLogoBase64')) {
        await setProfileLogoBase64(data['profileLogoBase64'] as String);
      }
      return true;
    } catch (e) {
      debugPrint('Import backup failed: $e');
      return false;
    }
  }

  Future<void> clearAllData() async {
    await _prefs.remove(_keyParties);
    await _prefs.remove(_keyChallans);
    await _prefs.remove(_keyFirstRun);
    await _prefs.remove(_keyUsers);
    await _prefs.remove(_keyActiveSession);
    await _prefs.remove(_keyAuditLogs);
    await _prefs.remove(_keyRolePermissions);
    await _prefs.remove(_keyCustomRoles);
    await _prefs.remove(_keyIncomeExpenseEntries);
  }
}
