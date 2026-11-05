import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:om_khatabook/main.dart';
import 'package:om_khatabook/providers/challan_provider.dart';
import 'package:om_khatabook/services/storage_service.dart';

void main() {
  testWidgets('OM Mavtar Group Challan & Billing smoke test', (WidgetTester tester) async {
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

    expect(find.textContaining('OM Mavtar Group'), findsWidgets);
    expect(find.text('Challan & Billing Ledger'), findsOneWidget);
    expect(find.text('Parties Directory'), findsWidgets);
    expect(find.text('Financial Reports'), findsOneWidget);
    expect(find.textContaining('UNPAID CASH'), findsWidgets);
  });
}
