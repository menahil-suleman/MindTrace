import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── MindTrace design-system colours (ported from Tailwind config) ─────────────
class MindColors {
  MindColors._();

  static const primary = Color(0xFF163422);
  static const primaryContainer = Color(0xFF2D4B37);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFF99BAA1);

  static const surface = Color(0xFFEFFDF0);
  static const surfaceContainerLow = Color(0xFFEAF7EA);
  static const surfaceContainer = Color(0xFFE4F1E4);
  static const surfaceContainerHigh = Color(0xFFDEECDF);
  static const surfaceContainerHighest = Color(0xFFD8E6D9);

  static const onSurface = Color(0xFF131E16);
  static const onSurfaceVariant = Color(0xFF424843);

  static const outline = Color(0xFF727972);
  static const outlineVariant = Color(0xFFC2C8C0);

  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);

  static const secondary = Color(0xFF57615A);
  static const onSecondary = Color(0xFFFFFFFF);

  static const background = Color(0xFFFFFFFF); // pure white page background
  static const onBackground = Color(0xFF131E16);

  // Toggle active pill
  static const toggleActive = Color(0xFF163422);
  static const toggleBg = Color(0xFFE4F1E4);
}

// ── App-wide ThemeData ────────────────────────────────────────────────────────
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: MindColors.primary,
      onPrimary: MindColors.onPrimary,
      primaryContainer: MindColors.primaryContainer,
      onPrimaryContainer: MindColors.onPrimaryContainer,
      secondary: MindColors.secondary,
      onSecondary: MindColors.onSecondary,
      secondaryContainer: Color(0xFFDBE5DD),
      onSecondaryContainer: Color(0xFF5D6760),
      tertiary: Color(0xFF293128),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF3F473E),
      onTertiaryContainer: Color(0xFFADB5A9),
      error: MindColors.error,
      onError: MindColors.onError,
      errorContainer: MindColors.errorContainer,
      onErrorContainer: Color(0xFF93000A),
      surface: Colors.white,
      onSurface: MindColors.onSurface,
      surfaceContainerHighest: MindColors.surfaceContainerHighest,
      onSurfaceVariant: MindColors.onSurfaceVariant,
      outline: MindColors.outline,
      outlineVariant: MindColors.outlineVariant,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF27332B),
      onInverseSurface: Color(0xFFE7F4E7),
      inversePrimary: Color(0xFFADCFB4),
    ),
    scaffoldBackgroundColor: MindColors.background,
  );

  return base.copyWith(
    textTheme: GoogleFonts.manropeTextTheme(base.textTheme).copyWith(
      // headline-xl: 40/48 w700
      displayLarge: GoogleFonts.manrope(
          fontSize: 40, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.8),
      // headline-lg: 32/40 w700
      displayMedium: GoogleFonts.manrope(
          fontSize: 32, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.32),
      // headline-md: 24/32 w600
      displaySmall: GoogleFonts.manrope(
          fontSize: 24, height: 1.33, fontWeight: FontWeight.w600),
      // headline-sm: 20/28 w600
      headlineMedium: GoogleFonts.manrope(
          fontSize: 20, height: 1.4, fontWeight: FontWeight.w600),
      // body-lg: 18/28 w400
      bodyLarge: GoogleFonts.manrope(
          fontSize: 18, height: 1.56, fontWeight: FontWeight.w400),
      // body-md: 16/24 w400
      bodyMedium: GoogleFonts.manrope(
          fontSize: 16, height: 1.5, fontWeight: FontWeight.w400),
      // body-sm: 14/20 w400
      bodySmall: GoogleFonts.manrope(
          fontSize: 14, height: 1.43, fontWeight: FontWeight.w400),
      // label-lg: 14/16 w600
      labelLarge: GoogleFonts.manrope(
          fontSize: 14, height: 1.14, fontWeight: FontWeight.w600, letterSpacing: 0.28),
      // label-md: 12/16 w600
      labelMedium: GoogleFonts.manrope(
          fontSize: 12, height: 1.33, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MindColors.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: MindColors.outline, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: MindColors.outline, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: MindColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: MindColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: const BorderSide(color: MindColors.error, width: 2),
      ),
      hintStyle: GoogleFonts.manrope(
        fontSize: 16,
        color: MindColors.onSurfaceVariant.withValues(alpha: 0.5),
        fontWeight: FontWeight.w400,
      ),
      labelStyle: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: MindColors.onSurface,
        letterSpacing: 0.5,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MindColors.primaryContainer,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.28,
        ),
        elevation: 0,
      ),
    ),
  );
}
