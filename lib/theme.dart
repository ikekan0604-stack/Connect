import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF080808);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF1A1A1A);
  static const Color accent = Color(0xFFE5E5E5);
  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFF8E8E8E);
  static const Color textTertiary = Color(0xFF5C5C5C);
  static const Color divider = Color(0xFF1F1F1F);

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: surface,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0A0A0A),
          selectedItemColor: textPrimary,
          unselectedItemColor: textTertiary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: textPrimary,
          thumbColor: textPrimary,
          inactiveTrackColor: const Color(0xFF2A2A2A),
          overlayColor: textPrimary.withValues(alpha: 0.08),
          trackHeight: 1.5,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surface,
          selectedColor: textPrimary,
          labelStyle: const TextStyle(color: textPrimary, fontSize: 11),
          side: BorderSide(color: textTertiary.withValues(alpha: 0.3)),
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
            borderSide: const BorderSide(color: textPrimary, width: 1),
          ),
          labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
          hintStyle: TextStyle(color: textTertiary.withValues(alpha: 0.7)),
        ),
      );
}
