import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:om_khatabook/main.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';
import 'package:om_khatabook/views/party_ledger_detail_view.dart';

void main() {
  testWidgets('Clicking a party card opens PartyLedgerDetailView with only that party records', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    final storageService = StorageService();
    await storageService.init();

    final provider = ChallanProvider(storageService);
    await provider.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChallanProvider>.value(value: provider),
        ],
        child: const OmKhataBookApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Navigate to Parties Directory tab in sidebar
    await tester.tap(find.text('Parties Directory').first);
    await tester.pumpAndSettle();

    // 2. Verify registered parties are shown in Directory
    expect(find.text('Manav Fab'), findsOneWidget);
    expect(find.text('Swastik Creation'), findsOneWidget);
    expect(find.text('Kamdar Silk Mills'), findsOneWidget);

    // 3. Click on "Manav Fab" card
    await tester.tap(find.text('Manav Fab'));
    await tester.pumpAndSettle();

    // 4. Verify PartyLedgerDetailView is opened
    expect(find.byType(PartyLedgerDetailView), findsOneWidget);
    expect(find.textContaining('Party Ledger'), findsWidgets);

    // 5. Verify ONLY Manav Fab records view is active
    expect(find.text('Manav Fab'), findsWidgets);
    expect(find.text('Swastik Creation'), findsNothing);
    expect(find.text('Kamdar Silk Mills'), findsNothing);

    // 6. Test Back button returns to Parties Directory
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(PartyLedgerDetailView), findsNothing);
    expect(find.text('Manav Fab'), findsOneWidget);
  });
}

