import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color creme = Color(0xFFF7F2E9);
const Color terracotta = Color(0xFFC97B5A);
const Color sauge = Color(0xFF7A8B6F);
const Color vertProfond = Color(0xFF3D4A35);

abstract final class AppTheme {
  static TextStyle get _titleFont => GoogleFonts.fraunces(
        color: vertProfond,
        letterSpacing: -0.4,
      );

  static TextStyle get _bodyFont => GoogleFonts.dmSans(
        color: vertProfond,
      );

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: terracotta,
        primary: terracotta,
        secondary: sauge,
        surface: creme,
        onSurface: vertProfond,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: creme,
        foregroundColor: vertProfond,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _titleFont.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: _bodyFont.copyWith(color: vertProfond.withValues(alpha: 0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: terracotta,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _bodyFont.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: _titleFont.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 28,
          height: 1.2,
        ),
        titleLarge: _titleFont.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        titleMedium: _bodyFont.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyLarge: _bodyFont.copyWith(fontSize: 16),
        bodyMedium: _bodyFont.copyWith(fontSize: 14),
      ),
    );
  }
}
