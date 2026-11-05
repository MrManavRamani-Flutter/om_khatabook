import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/party.dart';
import '../models/transaction_entry.dart';
import '../models/day_entry.dart';
import '../models/group_profile.dart';

class StorageService {
  static const String _keyParties = 'om_parties_data';
  static const String _keyTransactions = 'om_transactions_data';
  static const String _keyDayEntries = 'om_day_entries_data';
  static const String _keyProfile = 'om_group_profile_data';
  static const String _keyFirstRun = 'om_first_run_done';
  static const String _keyThemeMode = 'om_theme_mode';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isFirstRun => !(_prefs.getBool(_keyFirstRun) ?? false);

  Future<void> markFirstRunComplete() async {
    await _prefs.setBool(_keyFirstRun, true);
  }

  // --- THEME ---
  bool get isDarkMode => _prefs.getBool(_keyThemeMode) ?? false;
  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_keyThemeMode, value);
  }

  // --- PROFILE ---
  Future<GroupProfile> loadProfile() async {
    final str = _prefs.getString(_keyProfile);
    if (str != null && str.isNotEmpty) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        return GroupProfile.fromJson(map);
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }
    return GroupProfile(
      groupName: 'OM Mavtar Group',
      ownerName: 'Manav Ramani',
      currencySymbol: '₹',
    );
  }

  Future<void> saveProfile(GroupProfile profile) async {
    await _prefs.setString(_keyProfile, jsonEncode(profile.toJson()));
  }

  // --- PARTIES ---
  Future<List<Party>> loadParties() async {
    final str = _prefs.getString(_keyParties);
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List<dynamic>;
        return list.map((e) => Party.fromJson(e as Map<String, dynamic>)).toList();
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

  // --- TRANSACTIONS ---
  Future<List<TransactionEntry>> loadTransactions() async {
    final str = _prefs.getString(_keyTransactions);
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List<dynamic>;
        return list
            .map((e) => TransactionEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading transactions: $e');
      }
    }
    return [];
  }

  Future<void> saveTransactions(List<TransactionEntry> transactions) async {
    final list = transactions.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyTransactions, jsonEncode(list));
  }

  // --- DAY ENTRIES (ROJMEL) ---
  Future<List<DayEntry>> loadDayEntries() async {
    final str = _prefs.getString(_keyDayEntries);
    if (str != null && str.isNotEmpty) {
      try {
        final list = jsonDecode(str) as List<dynamic>;
        return list
            .map((e) => DayEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading day entries: $e');
      }
    }
    return [];
  }

  Future<void> saveDayEntries(List<DayEntry> entries) async {
    final list = entries.map((e) => e.toJson()).toList();
    await _prefs.setString(_keyDayEntries, jsonEncode(list));
  }

  // --- BACKUP & RESTORE ---
  Future<String> exportBackupJson() async {
    final data = {
      'app': 'OM Mavtar Group Khata Book',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': jsonDecode(_prefs.getString(_keyProfile) ?? '{}'),
      'parties': jsonDecode(_prefs.getString(_keyParties) ?? '[]'),
      'transactions': jsonDecode(_prefs.getString(_keyTransactions) ?? '[]'),
      'dayEntries': jsonDecode(_prefs.getString(_keyDayEntries) ?? '[]'),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String> saveBackupToDocuments() async {
    final jsonStr = await exportBackupJson();
    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'OM_Mavtar_KhataBook_Backup_${DateTime.now().millisecondsSinceEpoch}.json';
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
      if (data.containsKey('transactions')) {
        await _prefs.setString(
            _keyTransactions, jsonEncode(data['transactions']));
      }
      if (data.containsKey('dayEntries')) {
        await _prefs.setString(_keyDayEntries, jsonEncode(data['dayEntries']));
      }
      if (data.containsKey('profile')) {
        await _prefs.setString(_keyProfile, jsonEncode(data['profile']));
      }
      return true;
    } catch (e) {
      debugPrint('Import backup failed: $e');
      return false;
    }
  }

  Future<void> clearAllData() async {
    await _prefs.remove(_keyParties);
    await _prefs.remove(_keyTransactions);
    await _prefs.remove(_keyDayEntries);
    await _prefs.remove(_keyProfile);
    await _prefs.remove(_keyFirstRun);
  }
}
