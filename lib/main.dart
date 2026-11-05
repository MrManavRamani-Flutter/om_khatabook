import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/challan_provider.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'views/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ChallanProvider(storageService)..initialize(),
        ),
      ],
      child: const OmKhataBookApp(),
    ),
  );
}

class OmKhataBookApp extends StatelessWidget {
  const OmKhataBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ChallanProvider, bool>((p) => p.isDarkMode);

    return MaterialApp(
      title: 'OM Mavtar Group Khata Book',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const MainLayout(),
    );
  }
}
