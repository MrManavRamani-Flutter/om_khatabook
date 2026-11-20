import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Validates and imports Desktop backup JSON file successfully (Replace Mode)', () async {
    const backupPath = '/Users/manavramani/Desktop/OM_Mavtar_ChallanLedger_Backup_1795153908762.json';
    final backupFile = File(backupPath);
    if (!backupFile.existsSync()) {
      return;
    }

    final jsonContent = backupFile.readAsStringSync();
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final provider = ChallanProvider(storage);
    await provider.initialize();

    final analysis = provider.analyzeBackupJson(jsonContent);
    expect(analysis.isValid, isTrue);
    expect(analysis.totalChallans, equals(70));
    expect(analysis.totalParties, equals(19));

    final result = await provider.importBackupWithStrategy(
      jsonString: jsonContent,
      mode: BackupImportMode.replace,
    );

    expect(result.success, isTrue);
    expect(provider.challans.length, equals(70));
    expect(provider.parties.length, equals(19));

    // Verify all party names match
    expect(provider.parties.any((p) => p.name == 'Manav Fab'), isTrue);
    expect(provider.parties.any((p) => p.name == 'Swastik Creation'), isTrue);
    expect(provider.parties.any((p) => p.name == 'Kamdar Silk Mills'), isTrue);
  });

  test('Validates and imports Desktop backup JSON file successfully (Merge Mode)', () async {
    const backupPath = '/Users/manavramani/Desktop/OM_Mavtar_ChallanLedger_Backup_1795153908762.json';
    final backupFile = File(backupPath);
    if (!backupFile.existsSync()) {
      return;
    }

    final jsonContent = backupFile.readAsStringSync();
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    final provider = ChallanProvider(storage);
    await provider.initialize();

    final result = await provider.importBackupWithStrategy(
      jsonString: jsonContent,
      mode: BackupImportMode.merge,
    );

    expect(result.success, isTrue);
    expect(provider.challans.length, equals(70));
    // The initial seed had 16 parties; the backup has 19 parties. 16 overlap by name.
    expect(provider.parties.length, greaterThanOrEqualTo(19));
  });
}
