import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const washbinYellow = Color(0xFFFFC400);
  static const deepNavy = Color(0xFF071B3A);
  static const black = Color(0xFF0B0D10);
  static const offWhite = Color(0xFFF8FAFC);
  static const royalBlue = Color(0xFF1257D6);
  static const lightGrey = Color(0xFFE9EEF5);

  static const red = washbinYellow;
  static const darkRed = deepNavy;
  static const ink = black;
  static const muted = Color(0xFF647084);
  static const canvas = offWhite;
  static const line = lightGrey;

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: washbinYellow,
        primary: washbinYellow,
        secondary: royalBlue,
        surface: offWhite,
        onSurface: ink,
      ),
      fontFamily: 'Roboto',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: muted),
        prefixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: washbinYellow, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: red,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: washbinYellow,
          foregroundColor: ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
