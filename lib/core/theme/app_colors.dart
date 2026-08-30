import 'package:flutter/material.dart';

/// Centralized semantic color tokens for ClearTime.
///
/// Designed with a calm, trustworthy slate/indigo/teal palette for parents
/// and an encouraging, vibrant indigo/emerald/amber palette for children.
class AppColors {
  AppColors._();

  // ─── Parent Palette (Deep Trust, Mindful & Analytical) ───
  static const Color parentPrimary = Color(0xFF1E3A8A); // Deep Indigo
  static const Color parentPrimaryLight = Color(0xFF3B82F6);
  static const Color parentPrimaryDark = Color(0xFF172554);
  static const Color parentPrimaryContainer = Color(0xFFEFF6FF);
  
  static const Color parentSecondary = Color(0xFF0D9488); // Teal
  static const Color parentSecondaryContainer = Color(0xFFF0FDFA);
  
  static const Color parentAccent = Color(0xFF6366F1); // Soft Iris
  static const Color parentSurface = Color(0xFFF8FAFC); // Slate 50
  static const Color parentCard = Color(0xFFFFFFFF);
  static const Color parentTextDark = Color(0xFF0F172A); // Slate 900
  static const Color parentTextSecondary = Color(0xFF475569); // Slate 600

  // ─── Child Palette (Encouraging, Friendly & Gamified) ───
  static const Color childPrimary = Color(0xFF4F46E5); // Vibrant Indigo
  static const Color childPrimaryLight = Color(0xFF818CF8);
  static const Color childPrimaryDark = Color(0xFF3730A3);
  static const Color childPrimaryContainer = Color(0xFFEEF2FF);

  static const Color childSecondary = Color(0xFF10B981); // Emerald Green
  static const Color childSecondaryContainer = Color(0xFFECFDF5);

  static const Color childAccent = Color(0xFFF59E0B); // Amber Glow
  static const Color childAccentContainer = Color(0xFFFFFBEB);

  static const Color childSurface = Color(0xFFF0FDF4); // Gentle Mint
  static const Color childCard = Color(0xFFFFFFFF);
  static const Color childTextDark = Color(0xFF1E293B); // Slate 800
  static const Color childTextSecondary = Color(0xFF64748B); // Slate 500

  // ─── Neutral Palette ───
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral300 = Color(0xFFCBD5E1);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral700 = Color(0xFF334155);
  static const Color neutral800 = Color(0xFF1E293B);
  static const Color neutral900 = Color(0xFF0F172A);

  static const Color neutralMuted = Color(0xFF64748B);
  static const Color neutralBorder = Color(0xFFE2E8F0);
  static const Color neutralBg = Color(0xFFF8FAFC);
  static const Color neutralCard = Color(0xFFFFFFFF);

  // ─── Semantic Feedback ───
  static const Color successGreen = Color(0xFF16A34A);
  static const Color successGreenLight = Color(0xFFDCFCE7);
  
  static const Color warningOrange = Color(0xFFEA580C);
  static const Color warningOrangeLight = Color(0xFFFFEDD5);

  static const Color errorRed = Color(0xFFDC2626);
  static const Color errorRedLight = Color(0xFFFEE2E2);

  static const Color infoBlue = Color(0xFF2563EB);
  static const Color infoBlueLight = Color(0xFFDBEAFE);

  static const Color alertRed = Color(0xFFEF4444);
}
