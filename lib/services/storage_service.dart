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
  static const String _keyCleanMigration = 'om_clean_parties_v3';

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
