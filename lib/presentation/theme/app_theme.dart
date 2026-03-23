import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bg = Color(0xFF0B1220);       // deep navy
  static const Color panel = Color(0xFF0F1B2D);    // card background
  static const Color panel2 = Color(0xFF0C1626);   // subtle alt
  static const Color border = Color(0x1AFFFFFF);   // white 10%
  static const Color text = Color(0xFFEAF0FF);     // near-white
  static const Color subtext = Color(0xFF9FB0D0);  // muted
  static const Color accent = Color(0xFF6D5EF6);   // purple-ish
  static const Color good = Color(0xFF22C55E);
  static const Color warn = Color(0xFFF59E0B);
  static const Color bad  = Color(0xFFEF4444);
  static const Color info = Color(0xFF38BDF8);
  // ================= Spacing (Abstände wie im Admin-Dashboard) =================
  static const double space2  = 4;
  static const double space4  = 8;
  static const double space8  = 12;
  static const double space12 = 16;
  static const double space16 = 20;
  static const double space24 = 28;

  // ================= Radius (Ecken) =================
  static const double radiusSm = 10;
  static const double radiusMd = 14; // Dashboard-Standard
  static const double radiusLg = 18;

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: text,
        displayColor: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel2,
        hintStyle: const TextStyle(color: subtext),
        labelStyle: const TextStyle(color: subtext),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: text,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }
}
