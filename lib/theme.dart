import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_profiles.dart';

/// Colour accessors resolve to the currently-active [ColorProfile], so the
/// whole app re-skins when the profile changes (the app root rebuilds the
/// MaterialApp from [theme], and every `AppTheme.x` reference re-reads here).
class AppTheme {
  static Color get background => activeProfile.background;
  static Color get surface => activeProfile.surface;
  static Color get surfaceElevated => activeProfile.surfaceElevated;
  static Color get accent => activeProfile.accent;
  static Color get ink => activeProfile.ink;
  static Color get textPrimary => activeProfile.textPrimary;
  static Color get textSecondary => activeProfile.textSecondary;
  static Color get textTertiary => activeProfile.textTertiary;
  static Color get divider => activeProfile.divider;

  // ---- Typefaces (cute, but grown-up) ----
  // Body: Zen Maru Gothic — a soft rounded gothic that reads cute yet refined.
  // Display: Klee One — a pen-handwriting face that ties into the sketchbook look.
  static TextStyle body([TextStyle? s]) => GoogleFonts.zenMaruGothic(textStyle: s);
  static TextStyle display([TextStyle? s]) => GoogleFonts.kleeOne(textStyle: s);
  static String get bodyFamily => GoogleFonts.zenMaruGothic().fontFamily!;

  static ThemeData get theme {
    final p = activeProfile;
    final base = ThemeData(brightness: p.brightness);
    return ThemeData(
      brightness: p.brightness,
      fontFamily: bodyFamily,
      textTheme: GoogleFonts.zenMaruGothicTextTheme(base.textTheme)
          .apply(bodyColor: p.textPrimary, displayColor: p.textPrimary),
      scaffoldBackgroundColor: p.background,
      colorScheme: ColorScheme(
        brightness: p.brightness,
        primary: p.accent,
        onPrimary: p.brightness == Brightness.dark
            ? const Color(0xFF1B1A2A)
            : Colors.white,
        secondary: p.accent,
        onSecondary: Colors.white,
        surface: p.surface,
        onSurface: p.textPrimary,
        error: const Color(0xFFD64550),
        onError: Colors.white,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.accent,
        unselectedItemColor: p.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.zenMaruGothic(
          color: p.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: p.accent,
        labelColor: p.accent,
        unselectedLabelColor: p.textTertiary,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        thumbColor: p.accent,
        inactiveTrackColor: p.divider,
        overlayColor: p.accent.withValues(alpha: 0.12),
        trackHeight: 1.5,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accent,
        labelStyle: TextStyle(color: p.textPrimary, fontSize: 11),
        side: BorderSide(color: p.textTertiary.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.accent, width: 1),
        ),
        labelStyle: TextStyle(color: p.textSecondary, fontSize: 12),
        hintStyle: TextStyle(color: p.textTertiary.withValues(alpha: 0.7)),
      ),
    );
  }
}
