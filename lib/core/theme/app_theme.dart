import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ══════════════════════════════════════════════════════════════
// NEUROSENSE — Design System
// ══════════════════════════════════════════════════════════════
// Style    : Moderne, Épuré, Médical mais Accueillant
// Palette  : Blanc / Bleu (#2196F3) / Glassmorphisme
// Typo     : Poppins (sans-serif)
// ══════════════════════════════════════════════════════════════

// ── Couleurs ─────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Fonds
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundAlt = Color(0xFFF5F9FC);
  static const Color surface = Color(0xFFFFFFFF);

  // Primaire — Bleu
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);

  // Secondaire — Bleu clair
  static const Color secondary = Color(0xFFE3F2FD);
  static const Color secondaryDark = Color(0xFFBBDEFB);

  // Texte
  static const Color textPrimary = Color(0xFF1B2631);
  static const Color textSecondary = Color(0xFF78909C);
  static const Color textOnPrimary = Colors.white;

  // Champs
  static const Color inputFill = Color(0xFFF5F9FC);

  // Utilitaire
  static const Color error = Color(0xFFE53935);
  static const Color divider = Color(0xFFE0E0E0);
}

// ── Décorations de style Glassmorphisme ──────────────────────

class GlassDecoration {
  GlassDecoration._();

  /// Carte avec effet de verre.
  static BoxDecoration card({
    double opacity = 0.80,
    double borderRadius = 20,
    double blurRadius = 24,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: blurRadius,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Barre de navigation inférieure.
  static BoxDecoration navBar() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, -4),
        ),
      ],
    );
  }

  /// Verre teinté bleu pour états actifs.
  static BoxDecoration greenGlass({
    double opacity = 0.15,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: AppColors.primary.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: AppColors.primary.withValues(alpha: 0.2),
        width: 1,
      ),
    );
  }

  /// Chip / badge flottant.
  static BoxDecoration chip() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

// ── Thèmes ──────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  // ── Thème clair ──────────────────────────────────────────

  static ThemeData get light {
    final base = GoogleFonts.poppinsTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primary,

      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),

      textTheme: base.copyWith(
        headlineLarge: base.headlineLarge?.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: base.headlineMedium?.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge: base.titleLarge?.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: base.titleMedium?.copyWith(
            color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: base.bodyLarge?.copyWith(color: AppColors.textPrimary),
        bodyMedium: base.bodyMedium?.copyWith(color: AppColors.textSecondary),
        labelLarge: base.labelLarge?.copyWith(
            color: AppColors.textOnPrimary, fontWeight: FontWeight.w600),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.poppins(
          color: AppColors.textSecondary.withValues(alpha: 0.6),
          fontSize: 14,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
      ),
    );
  }

  // ── Thème sombre ─────────────────────────────────────────

  static ThemeData get dark {
    final base =
        GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);

    const textLight = Color(0xFFE0E0E0);
    const textMuted = Color(0xFF9E9E9E);
    const surfaceDark = Color(0xFF1E1E1E);
    const bgDark = Color(0xFF121212);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: AppColors.primary,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: Color(0xFF1E2D3D),
        onSecondary: Colors.white,
        surface: surfaceDark,
        onSurface: textLight,
        error: AppColors.error,
      ),

      textTheme: base.copyWith(
        headlineLarge: base.headlineLarge?.copyWith(
            color: textLight, fontWeight: FontWeight.w700),
        headlineMedium: base.headlineMedium?.copyWith(
            color: textLight, fontWeight: FontWeight.w600),
        titleLarge: base.titleLarge?.copyWith(
            color: textLight, fontWeight: FontWeight.w600),
        titleMedium: base.titleMedium?.copyWith(
            color: textLight, fontWeight: FontWeight.w500),
        bodyLarge: base.bodyLarge?.copyWith(color: textLight),
        bodyMedium: base.bodyMedium?.copyWith(color: textMuted),
        labelLarge: base.labelLarge?.copyWith(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textLight,
        ),
        iconTheme: const IconThemeData(color: textLight),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: GoogleFonts.poppins(
          color: const Color(0xFF757575),
          fontSize: 14,
        ),
      ),

      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF333333),
        thickness: 0.5,
      ),
    );
  }
}
