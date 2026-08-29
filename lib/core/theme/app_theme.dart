import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Parent Palette: Deep Trust & Mindful Analytical
  static const Color parentPrimary = Color(0xFF1E3A8A); // Deep Indigo
  static const Color parentSecondary = Color(0xFF0D9488); // Teal
  static const Color parentAccent = Color(0xFF6366F1); // Soft Iris
  static const Color parentSurface = Color(0xFFF8FAFC); // Slate 50
  static const Color parentCard = Color(0xFFFFFFFF);
  static const Color parentTextDark = Color(0xFF0F172A);

  // Child Palette: Positive, Friendly, Wellbeing & Encouragement
  static const Color childPrimary = Color(0xFF4F46E5); // Vibrant Indigo
  static const Color childSecondary = Color(0xFF10B981); // Emerald Green
  static const Color childAccent = Color(0xFFF59E0B); // Amber Glow
  static const Color childSurface = Color(0xFFF0FDF4); // Gentle Mint
  static const Color childCard = Color(0xFFFFFFFF);
  static const Color childTextDark = Color(0xFF1E293B);

  // Shared
  static const Color neutralMuted = Color(0xFF64748B);
  static const Color neutralBorder = Color(0xFFE2E8F0);
  static const Color successGreen = Color(0xFF22C55E);
  static const Color warningOrange = Color(0xFFF97316);
  static const Color errorRed = Color(0xFFEF4444);

  static ThemeData lightTheme({bool isChildTheme = false}) {
    final primary = isChildTheme ? childPrimary : parentPrimary;
    final secondary = isChildTheme ? childSecondary : parentSecondary;
    final surface = isChildTheme ? childSurface : parentSurface;

    final baseTextTheme = isChildTheme
        ? GoogleFonts.outfitTextTheme()
        : GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: surface,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: parentTextDark,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: parentTextDark,
          letterSpacing: -0.5,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: parentTextDark,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: parentTextDark,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: parentTextDark,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: parentTextDark,
          fontSize: 16,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: neutralMuted,
          fontSize: 14,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: parentTextDark,
        centerTitle: false,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: parentTextDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: neutralBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(
              color: primary.withAlpha((0.5 * 255).round()), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: baseTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neutralBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: neutralBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        labelStyle: TextStyle(color: neutralMuted),
        hintStyle:
            TextStyle(color: neutralMuted.withAlpha((0.7 * 255).round())),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primary,
        unselectedItemColor: neutralMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
      ),
    );
  }
}
