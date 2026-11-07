import 'package:flutter/material.dart';

/// Tixs brand colors and typography constants.
class TixsTheme {
  TixsTheme._();

  // Brand palette
  static const Color primary = Color(0xFF7C3AED); // purple-600
  static const Color primaryDark = Color(0xFF5B21B6); // purple-800
  static const Color surface = Color(0xFF0F0A1A); // near-black background
  static const Color surfaceCard = Color(0xFF1A1030); // card background
  static const Color onPrimary = Colors.white;
  static const Color onSurface = Colors.white;
  static const Color onSurfaceMuted = Color(0xFF9CA3AF); // gray-400
  static const Color divider = Color(0xFF2D2040);
  static const Color error = Color(0xFFEF4444);

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: onSurface,
        error: error,
      ),
      scaffoldBackgroundColor: surface,
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: surfaceCard,
        indicatorColor: Color(0xFF3B1F6E),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      dividerColor: divider,
    );
  }
}
