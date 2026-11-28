import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/challan_provider.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';
import 'views/login_view.dart';
import 'views/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final challanProvider = ChallanProvider(storageService)..initialize();
  final authProvider = AuthProvider(storageService);

  // Wire audit logs from AuthProvider to ChallanProvider
  authProvider.onAuditLog = (entry) => challanProvider.addAuditLog(entry);
  await authProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<ChallanProvider>.value(value: challanProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: const OmKhataBookApp(),
    ),
  );
}

class OmKhataBookApp extends StatelessWidget {
  const OmKhataBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallanProvider>();
    final isDark = provider.isDarkMode;

    return MaterialApp(
      theme: AppTheme.buildTheme(
        isDark: false,
        primary: provider.primaryColor,
        success: provider.successColor,
        warning: provider.warningColor,
        partial: provider.partialColor,
      ),
      darkTheme: AppTheme.buildTheme(
        isDark: true,
        primary: provider.primaryColor,
        success: provider.successColor,
        warning: provider.warningColor,
        partial: provider.partialColor,
      ),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isAuthenticated) {
            return const LoginView();
          }
          return const MainLayout();
        },
      ),
    );
  }
}
