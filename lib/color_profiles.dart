import 'package:flutter/material.dart';

/// A complete UI colour profile for the sketchbook theme. Every screen and the
/// node-graph painter read their colours from the currently-active profile, so
/// switching one re-skins the whole app.
class ColorProfile {
  final String name;
  final Brightness brightness;
  final Color background; // paper
  final Color paperLow; // paper's lower-gradient edge
  final Color surface; // cards on paper
  final Color surfaceElevated;
  final Color accent; // pen accent (self node, selections)
  final Color ink; // soft pen ink (faint marks, doodles, dot grid, text body)
  final Color inkLine; // strong pen line (node rings)
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color divider;

  const ColorProfile({
    required this.name,
    required this.brightness,
    required this.background,
    required this.paperLow,
    required this.surface,
    required this.surfaceElevated,
    required this.accent,
    required this.ink,
    required this.inkLine,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.divider,
  });

  /// Three-colour preview shown in the picker chips.
  List<Color> get swatch => [background, accent, inkLine];
}

/// Curated brand-style palettes (in the spirit of huemint's brand-intersection
/// presets: Default / Pastel / Bright&Light / Vibrant / Dark).
const List<ColorProfile> kColorProfiles = [
  // 0 — Sketchbook (default): warm cream + indigo ink + pink.
  ColorProfile(
    name: 'スケッチ',
    brightness: Brightness.light,
    background: Color(0xFFFBF9F4),
    paperLow: Color(0xFFF3EFE6),
    surface: Color(0xFFFFFDFA),
    surfaceElevated: Color(0xFFFFFFFF),
    accent: Color(0xFFE85C8A),
    ink: Color(0xFF2A2740),
    inkLine: Color(0xFF201D33),
    textPrimary: Color(0xFF34304A),
    textSecondary: Color(0xFF6E6884),
    textTertiary: Color(0xFFA9A2B8),
    divider: Color(0xFFE2DAC8),
  ),
  // 1 — Mint: soft sage paper + deep teal ink + coral.
  ColorProfile(
    name: 'ミント',
    brightness: Brightness.light,
    background: Color(0xFFEAF3EC),
    paperLow: Color(0xFFDBEADF),
    surface: Color(0xFFF4FAF5),
    surfaceElevated: Color(0xFFFFFFFF),
    accent: Color(0xFFF2785C),
    ink: Color(0xFF1E3A34),
    inkLine: Color(0xFF15302A),
    textPrimary: Color(0xFF21413A),
    textSecondary: Color(0xFF5A726B),
    textTertiary: Color(0xFF9DB0AA),
    divider: Color(0xFFCFE0D5),
  ),
  // 2 — Butter: pale warm yellow + espresso ink + vermilion.
  ColorProfile(
    name: 'バター',
    brightness: Brightness.light,
    background: Color(0xFFFBF6E9),
    paperLow: Color(0xFFF2E9D3),
    surface: Color(0xFFFEFBF2),
    surfaceElevated: Color(0xFFFFFFFF),
    accent: Color(0xFFE0533A),
    ink: Color(0xFF3B2F22),
    inkLine: Color(0xFF2E2418),
    textPrimary: Color(0xFF3B2F22),
    textSecondary: Color(0xFF7A6A56),
    textTertiary: Color(0xFFB8A991),
    divider: Color(0xFFE8DDC4),
  ),
  // 3 — Sky: cool pale blue + navy ink + amber.
  ColorProfile(
    name: 'スカイ',
    brightness: Brightness.light,
    background: Color(0xFFEEF3FA),
    paperLow: Color(0xFFDCE7F3),
    surface: Color(0xFFF6F9FD),
    surfaceElevated: Color(0xFFFFFFFF),
    accent: Color(0xFFEFA23C),
    ink: Color(0xFF1B2A44),
    inkLine: Color(0xFF14213A),
    textPrimary: Color(0xFF1B2A44),
    textSecondary: Color(0xFF5C6A82),
    textTertiary: Color(0xFFA2AEC2),
    divider: Color(0xFFD4DEEC),
  ),
  // 4 — Ink (dark): deep indigo paper + off-white ink + bright pink.
  ColorProfile(
    name: 'インク',
    brightness: Brightness.dark,
    background: Color(0xFF1B1A2A),
    paperLow: Color(0xFF15141F),
    surface: Color(0xFF232234),
    surfaceElevated: Color(0xFF2B2942),
    accent: Color(0xFFFF6FA5),
    ink: Color(0xFFECEAF4),
    inkLine: Color(0xFFF4F2FB),
    textPrimary: Color(0xFFECEAF4),
    textSecondary: Color(0xFFA7A3C0),
    textTertiary: Color(0xFF6E6A88),
    divider: Color(0xFF34324A),
  ),
];

/// Index of the active profile. Listened to by the app root (re-themes
/// everything) and by the node graph (rebuilds its cached ink colours).
final ValueNotifier<int> activeProfileIndex = ValueNotifier<int>(0);

ColorProfile get activeProfile =>
    kColorProfiles[activeProfileIndex.value.clamp(0, kColorProfiles.length - 1)];
