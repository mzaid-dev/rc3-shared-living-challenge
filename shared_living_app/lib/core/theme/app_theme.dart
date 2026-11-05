import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.canvas,
      colorScheme: const ColorScheme.light(
        primary: AppColors.jade600,
        onPrimary: Colors.white,
        secondary: AppColors.jade700,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.coral600,
        onError: Colors.white,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusCard,
          side: BorderSide(color: AppColors.line, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge,
        iconTheme: IconThemeData(color: AppColors.ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusField,
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusField,
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusField,
          borderSide: const BorderSide(color: AppColors.jade500, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusField,
          borderSide: const BorderSide(color: AppColors.coral500, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusField,
          borderSide: const BorderSide(color: AppColors.coral600, width: 1.8),
        ),
        labelStyle: AppTypography.caption,
        hintStyle: AppTypography.bodyMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.jade600,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: AppTypography.titleSmall.copyWith(color: Colors.white),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusField),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.jade600,
        unselectedItemColor: AppColors.faint,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // Provide darkTheme as alias or default to lightTheme to match Hisab
  static ThemeData get darkTheme => lightTheme;
}
