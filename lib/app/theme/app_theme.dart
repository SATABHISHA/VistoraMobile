import 'package:flutter/material.dart';

abstract final class VistoraColors {
  static const background = Color(0xFF07091A);
  static const surface = Color(0xFF0D1226);
  static const surfaceRaised = Color(0xFF151C35);
  static const orange = Color(0xFFFF6A00);
  static const amber = Color(0xFFFFAA00);
  static const pink = Color(0xFFFF2D78);
  static const cyan = Color(0xFF00D2FF);
  static const green = Color(0xFF00E676);
  static const text = Color(0xFFE8EEFF);
  static const muted = Color(0xFF91A2C8);
}

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: VistoraColors.orange,
      secondary: VistoraColors.pink,
      tertiary: VistoraColors.cyan,
      surface: VistoraColors.surface,
      error: Color(0xFFFF6B7A),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: VistoraColors.text,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF303A56)),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: VistoraColors.background,
      fontFamily: 'sans-serif',
      appBarTheme: const AppBarTheme(
        backgroundColor: VistoraColors.background,
        foregroundColor: VistoraColors.text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: VistoraColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF171D32),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: VistoraColors.orange, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF6B7A)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VistoraColors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: VistoraColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: VistoraColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: VistoraColors.surface,
        indicatorColor: Color(0x33FF6A00),
      ),
      dividerColor: const Color(0x1AFFFFFF),
    );
  }
}
