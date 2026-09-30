import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- SIGNATURE BRAND PALETTE (From Logo.png) ---
  // Background: Deep Forest Pine / Moss Green
  static const Color brandDeepGreen = Color(0xFF2A3B19);
  // Quadrant Z: Cream Ivory
  static const Color brandIvory = Color(0xFFFFF5EB);
  // Quadrant I: Sunburst Gold Yellow
  static const Color brandSunYellow = Color(0xFFFFDE59);
  // Quadrant P: Sunset Tangerine Orange
  static const Color brandSunsetOrange = Color(0xFFFF914D);
  // Quadrant R: Spring Leaf Emerald
  static const Color brandLeafGreen = Color(0xFF7ED957);

  // --- DARK PALETTE (Deep Forest Moss & Botanical Essence) ---
  static const Color darkBg = Color(0xFF1B2714);
  static const Color darkSurface = Color(0xFF253519);
  static const Color darkSurfaceElev = Color(0xFF314322);
  static const Color darkBorder = Color(0xFF3D522B);
  static const Color darkBorderLight = Color(0xFF4E6838);
  static const Color darkPrimary = Color(0xFF7ED957);
  static const Color darkSecondary = Color(0xFFFFDE59);
  static const Color darkAccentOrange = Color(0xFFFF914D);
  static const Color darkAccentIvory = Color(0xFFFFF5EB);
  static const Color darkTextPrimary = Color(0xFFFFF5EB);
  static const Color darkTextSecondary = Color(0xFFC7D6BD);
  static const Color darkTextMuted = Color(0xFF8DA082);
  static const Color darkSuccess = Color(0xFF7ED957);
  static const Color darkError = Color(0xFFFF6B6B);

  // --- LIGHT PALETTE (Warm Linen Ivory & Executive Pine Essence) ---
  static const Color lightBg = Color(0xFFF7F5EE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElev = Color(0xFFECE7DA);
  static const Color lightBorder = Color(0xFFDBD4C1);
  static const Color lightBorderLight = Color(0xFFC8BFAB);
  static const Color lightPrimary = Color(0xFF2A3B19);
  static const Color lightSecondary = Color(0xFF4A6830);
  static const Color lightAccentGreen = Color(0xFF4E9C2B);
  static const Color lightAccentOrange = Color(0xFFE27329);
  static const Color lightAccentYellow = Color(0xFFD6AB1A);
  static const Color lightTextPrimary = Color(0xFF1B2610);
  static const Color lightTextSecondary = Color(0xFF48583B);
  static const Color lightTextMuted = Color(0xFF78886B);
  static const Color lightSuccess = Color(0xFF3B8721);
  static const Color lightError = Color(0xFFD32F2F);

  // --- CONVENIENCE GETTERS ---
  static Color primary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkPrimary : lightPrimary;
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;
  }

  static Color border(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkBorder : lightBorder;
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        surface: darkSurface,
        surfaceContainerHighest: darkSurfaceElev,
        error: darkError,
        onPrimary: Color(0xFF1B2714),
        onSurface: darkTextPrimary,
        outline: darkBorder,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).apply(
        bodyColor: darkTextPrimary,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF202F18),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: darkBg,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: const Color(0xFF1B2714),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E2D17),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkPrimary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: darkTextMuted, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightSecondary,
        surface: lightSurface,
        surfaceContainerHighest: lightSurfaceElev,
        error: lightError,
        onPrimary: Colors.white,
        onSurface: lightTextPrimary,
        outline: lightBorder,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: Brightness.light).textTheme,
      ).apply(
        bodyColor: lightTextPrimary,
        displayColor: lightTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: lightBg,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 2,
        shadowColor: const Color(0xFF2A3B19).withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurface,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceElev,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightPrimary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 13),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
