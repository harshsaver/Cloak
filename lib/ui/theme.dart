import 'package:flutter/material.dart';

/// iMessage-inspired palette shared across the app.
class CloakColors {
  static const bubbleBlue = Color(0xFF006BE6);
  static const accent = Color(0xFF0A84FF);

  static Color incomingBubble(Brightness brightness) =>
      brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.055);

  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white;

  static Color canvas(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

  static Color chrome(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF161618) : const Color(0xFFF7F7FA);
}

ThemeData buildTheme(Brightness brightness) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorSchemeSeed: CloakColors.accent,
    fontFamily: '.AppleSystemUIFont',
  );
  return base.copyWith(
    scaffoldBackgroundColor: CloakColors.canvas(brightness),
    dividerTheme: DividerThemeData(
      color: base.colorScheme.outlineVariant.withValues(alpha: 0.5),
      thickness: 0.5,
      space: 0.5,
    ),
    visualDensity: VisualDensity.standard,
  );
}
