import 'package:flutter/material.dart';

/// Brand palette — energetic orange on dark, with a matching light scheme.
abstract final class AppColors {
  static const Color accent = Color(0xFFFF5A1F);
  static const Color accentSoft = Color(0xFFFF8A5B);
  static const Color success = Color(0xFF3DDC97);
  static const Color warning = Color(0xFFFFC857);
  static const Color gold = Color(0xFFFFD166);
  static const Color silver = Color(0xFFC0C7D1);
  static const Color bronze = Color(0xFFD4A373);

  static const Color darkBg = Color(0xFF0E1116);
  static const Color darkSurface = Color(0xFF181C23);
  static const Color darkSurfaceAlt = Color(0xFF222831);
  static const Color darkBorder = Color(0xFF2C3340);
  static const Color darkText = Color(0xFFF4F6F8);
  static const Color darkMuted = Color(0xFF9AA3B2);

  static const Color lightBg = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEEF1F5);
  static const Color lightBorder = Color(0xFFE3E7EE);
  static const Color lightText = Color(0xFF12151A);
  static const Color lightMuted = Color(0xFF6B7380);
  static const Color avatarBlue = Color(0xFF4C8DFF);
  static const Color avatarPurple = Color(0xFF9B6DFF);
  static const Color avatarTeal = Color(0xFF2EC4B6);

  static const List<Color> avatarSwatches = [
    accent,
    accentSoft,
    success,
    warning,
    gold,
    bronze,
    avatarBlue,
    avatarPurple,
  ];

  /// Parses `#RRGGBB` (optional leading `#`). Returns null if invalid.
  static Color? tryParseHex(String? hex) {
    if (hex == null) return null;
    var value = hex.trim();
    if (value.startsWith('#')) value = value.substring(1);
    if (value.length != 6) return null;
    final n = int.tryParse(value, radix: 16);
    if (n == null) return null;
    return Color(0xFF000000 | n);
  }

  static String toHex(Color color) {
    int channel(double component) => (component * 255).round().clamp(0, 255);
    final r = channel(color.r).toRadixString(16).padLeft(2, '0');
    final g = channel(color.g).toRadixString(16).padLeft(2, '0');
    final b = channel(color.b).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}
