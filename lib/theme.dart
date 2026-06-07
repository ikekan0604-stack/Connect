import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Sketchbook palette: near-white paper + deep-indigo pen ink + pink accent.
  static const Color background = Color(0xFFFBF9F4); // whiter paper
  static const Color surface = Color(0xFFFFFDFA); // card on paper
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFE85C8A); // pen pink
  static const Color ink = Color(0xFF2A2740); // primary pen ink (near-black indigo)
  static const Color textPrimary = Color(0xFF34304A);
  static const Color textSecondary = Color(0xFF6E6884);
  static const Color textTertiary = Color(0xFFA9A2B8);
  static const Color divider = Color(0xFFE2DAC8);

  // ---- Typefaces (cute, but grown-up) ----
  // Body: Zen Maru Gothic — a soft rounded gothic that reads cute yet refined.
  // Display: Klee One — a pen-handwriting face that ties into the sketchbook look.
  static TextStyle body([TextStyle? s]) => GoogleFonts.zenMaruGothic(textStyle: s);
  static TextStyle display([TextStyle? s]) => GoogleFonts.kleeOne(textStyle: s);
  static String get bodyFamily => GoogleFonts.zenMaruGothic().fontFamily!;

  static ThemeData get theme {
    final base = ThemeData(brightness: Brightness.light);
    return ThemeData(
        brightness: Brightness.light,
        fontFamily: bodyFamily,
        textTheme: GoogleFonts.zenMaruGothicTextTheme(base.textTheme)
            .apply(bodyColor: textPrimary, displayColor: textPrimary),
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.light(
          primary: accent,
          surface: surface,
          onSurface: textPrimary,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: accent,
          unselectedItemColor: textTertiary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.zenMaruGothic(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: textTertiary,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: accent,
          thumbColor: accent,
          inactiveTrackColor: const Color(0xFFDED6C4),
          overlayColor: accent.withValues(alpha: 0.12),
          trackHeight: 1.5,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surface,
          selectedColor: accent,
          labelStyle: const TextStyle(color: textPrimary, fontSize: 11),
          side: BorderSide(color: textTertiary.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: accent, width: 1),
          ),
          labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
          hintStyle: TextStyle(color: textTertiary.withValues(alpha: 0.7)),
        ),
      );
  }
}
