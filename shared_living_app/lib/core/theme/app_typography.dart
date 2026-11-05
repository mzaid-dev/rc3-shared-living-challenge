import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography Scale with Tabular Numeral Support & Hisab Visual Hierarchy
class AppTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 29,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    color: AppColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 21,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: AppColors.slate,
  );

  static const TextStyle labelBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.faint,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: AppColors.slate,
  );

  /// Tabular currency figures
  static const TextStyle currencyHero = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle currencyBody = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
