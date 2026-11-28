import 'package:flutter/material.dart';

class AppColors {
  // Brand & Slate Primary
  static const Color primary = Color(0xFF0F766E); // Teal 700
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color primaryDark = Color(0xFF115E59); // Teal 800

  // Warning Highlight (Light Red for Unpaid Cash / Bounced Cheques)
  static const Color warningBgLight = Color(0xFFFFF1F2); // Rose/Red 50
  static const Color warningBgDark = Color(0xFF3B1219);
  static const Color warningBorder = Color(0xFFFDA4AF); // Rose 300
  static const Color warningBorderDark = Color(0xFF9F1239);
  static const Color warningText = Color(0xFFBE123C); // Rose 700

  // Success Highlight (Paid / Cleared)
  static const Color successBgLight = Color(0xFFF0FDF4); // Green 50
  static const Color successBgDark = Color(0xFF062E1A);
  static const Color successBorder = Color(0xFF86EFAC);
  static const Color successText = Color(0xFF15803D);
  static const Color successTextDark = Color(0xFF86EFAC);

  // Cheque Pending / Partially Paid
  static const Color pendingBgLight = Color(0xFFFFFBEB); // Amber 50
  static const Color pendingBgDark = Color(0xFF291E05);
  static const Color pendingBorder = Color(0xFFFCD34D);
  static const Color pendingText = Color(0xFFB45309);
  static const Color pendingTextDark = Color(0xFFFDE68A);

  // High-contrast warning for Dark theme
  static const Color warningTextDark = Color(0xFFFDA4AF);

  // Neutrals
  static const Color slate = Color(0xFF334155);

  // Financial Indicators
  static const Color incomeGreen = Color(0xFF10B981);
  static const Color incomeGreenLight = Color(0xFFD1FAE5);
  static const Color incomeGreenDark = Color(0xFF064E3B);
  static const Color expenseRed = Color(0xFFEF4444);
  static const Color expenseRedLight = Color(0xFFFEE2E2);
  static const Color expenseRedDark = Color(0xFF7F1D1D);

  // Social & Export Brands
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF128C7E);
  static const Color whatsappBorder = Color(0xFF16A34A);
  static const Color excel = Color(0xFF107C41);
  static const Color pdf = Color(0xFFD32F2F);

  // Design Tag & Accents
  static const Color designBlue = Color(0xFF0284C7);
  static const Color designBlueDark = Color(0xFF38BDF8);
  static const Color designBlueBg = Color(0xFFE0F2FE);

  // Background Surfaces & Borders
  static const Color darkScaffold = Color(0xFF0F172A);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkMutedText = Color(0xFF64748B);

  /// Helper to derive high-contrast color for dark theme
  static Color getHighContrast(Color color, bool isDark) {
    if (!isDark) return color;
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness < 0.65) {
      return hsl.withLightness(0.72).toColor();
    }
    return color;
  }
}

class AppTheme {
  static ThemeData buildTheme({
    required bool isDark,
    required Color primary,
    Color? success,
    Color? warning,
    Color? partial,
  }) {
    final hsl = HSLColor.fromColor(primary);
    final primaryLight = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();

    if (isDark) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primaryLight,
          secondary: primary,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E293B),
        ),
        primaryColor: primary,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF334155), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF475569)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primaryLight, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryLight,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: primaryLight,
        brightness: Brightness.light,
        surface: const Color(0xFFF8FAFC),
      ),
      primaryColor: primary,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  static ThemeData lightTheme = buildTheme(isDark: false, primary: AppColors.primary);
  static ThemeData darkTheme = buildTheme(isDark: true, primary: AppColors.primary);
}
