import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/challan_entry.dart';
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

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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

  // --- BACKUP & RESTORE ---
  Future<String> exportBackupJson() async {
    final partiesStr = _prefs.getString(_keyParties) ?? '[]';
    final challansStr = _prefs.getString(_keyChallans) ?? '[]';

    final data = {
      'app': 'OM Mavtar Group Khata Book',
      'version': '2.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'parties': jsonDecode(partiesStr),
      'challans': jsonDecode(challansStr),
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

  Future<bool> importBackupJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (data.containsKey('parties')) {
        await _prefs.setString(_keyParties, jsonEncode(data['parties']));
      }
      if (data.containsKey('challans')) {
        await _prefs.setString(_keyChallans, jsonEncode(data['challans']));
      }
      if (data.containsKey('branding') && data['branding'] is Map<String, dynamic>) {
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
  }
}
