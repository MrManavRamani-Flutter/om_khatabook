import 'package:flutter_test/flutter_test.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:om_khatabook/utils/formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Natural Alphanumeric Sorting Tests (Formatters)', () {
    test('Correctly orders numeric challan numbers (natural order: 2 before 10)', () {
      final list = ['160', '2', '1', '10', '20', '100'];
      list.sort((a, b) => Formatters.compareChallanNumbers(a, b, ascending: true));
      expect(list, ['1', '2', '10', '20', '100', '160']);

      list.sort((a, b) => Formatters.compareChallanNumbers(a, b, ascending: false));
      expect(list, ['160', '100', '20', '10', '2', '1']);
    });

    test('Correctly orders prefixed alphanumeric challans (CH-2 before CH-10)', () {
      final list = ['CH-100', 'CH-1', 'CH-20', 'CH-2', 'CH-10'];
      list.sort((a, b) => Formatters.compareChallanNumbers(a, b, ascending: true));
      expect(list, ['CH-1', 'CH-2', 'CH-10', 'CH-20', 'CH-100']);

      list.sort((a, b) => Formatters.compareChallanNumbers(a, b, ascending: false));
      expect(list, ['CH-100', 'CH-20', 'CH-10', 'CH-2', 'CH-1']);
    });
  });

  group('ChallanProvider Sort & Filter Integration Tests', () {
    late StorageService storage;
    late ChallanProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
      provider = ChallanProvider(storage);
      await provider.initialize();

      // Clear any default sample challans for predictable sorting assertions
      for (final c in List.of(provider.challans)) {
        await provider.deleteChallan(c.id);
      }
    });

    test('Sorts challans by Date (Newest first & Oldest first)', () async {
      final p = provider.parties.first;

      await provider.addChallan(
        date: DateTime(2026, 11, 1),
        challanNo: '10',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 1000,
        finalAmount: 1000,
      );
      await provider.addChallan(
        date: DateTime(2026, 11, 15),
        challanNo: '2',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 2000,
        finalAmount: 2000,
      );
      await provider.addChallan(
        date: DateTime(2026, 11, 5),
        challanNo: '1',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 3000,
        finalAmount: 3000,
      );

      // Default is Date Newest First (descending)
      expect(provider.sortField, ChallanSortField.date);
      expect(provider.sortAscending, false);
      expect(
        provider.filteredChallans.map((c) => c.challanNo).toList(),
        ['2', '1', '10'], // 15 Nov, 5 Nov, 1 Nov
      );
      expect(provider.activeFilterSummary, contains('Sort: Date (Newest First (Desc))'));

      // Toggle Date sort to Oldest First (ascending)
      provider.toggleSortOrder();
      expect(provider.sortAscending, true);
      expect(
        provider.filteredChallans.map((c) => c.challanNo).toList(),
        ['10', '1', '2'], // 1 Nov, 5 Nov, 15 Nov
      );
      expect(provider.activeFilterSummary, contains('Sort: Date (Oldest First (Asc))'));
    });

    test('Sorts challans by Challan Number (Ascending 1->N & Descending N->1)', () async {
      final p = provider.parties.first;

      await provider.addChallan(
        date: DateTime(2026, 11, 10),
        challanNo: '160',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 1000,
        finalAmount: 1000,
      );
      await provider.addChallan(
        date: DateTime(2026, 11, 1),
        challanNo: '2',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 2000,
        finalAmount: 2000,
      );
      await provider.addChallan(
        date: DateTime(2026, 11, 20),
        challanNo: '10',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 3000,
        finalAmount: 3000,
      );
      await provider.addChallan(
        date: DateTime(2026, 11, 15),
        challanNo: '1',
        partyId: p.id,
        partyName: p.name,
        challanAmount: 4000,
        finalAmount: 4000,
      );

      // Switch to Challan Number sorting (defaults to Ascending 1 to N)
      provider.setSortField(ChallanSortField.challanNo);
      expect(provider.sortField, ChallanSortField.challanNo);
      expect(provider.sortAscending, true);
      expect(
        provider.filteredChallans.map((c) => c.challanNo).toList(),
        ['1', '2', '10', '160'],
      );
      expect(provider.activeFilterSummary, contains('Sort: Challan # (1 → 9 (Asc))'));

      // Toggle to Descending N to 1
      provider.setSortField(ChallanSortField.challanNo);
      expect(provider.sortAscending, false);
      expect(
        provider.filteredChallans.map((c) => c.challanNo).toList(),
        ['160', '10', '2', '1'],
      );
      expect(provider.activeFilterSummary, contains('Sort: Challan # (9 → 1 (Desc))'));

      // Reset filters restores Date Newest First
      provider.resetFilters();
      expect(provider.sortField, ChallanSortField.date);
      expect(provider.sortAscending, false);
      expect(provider.activeFilterSummary, contains('Sort: Date (Newest First (Desc))'));
    });
  });
}
