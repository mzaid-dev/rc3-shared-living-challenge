import 'package:flutter/material.dart';

/// Hisab Design System — Complete Token Foundations
/// Based on GLM 5.3 Design System Spec for RC3 Shared Living Challenge
class AppColors {
  // Jade Core Foundations
  static const Color jade900 = Color(0xFF092A20);
  static const Color jade800 = Color(0xFF0C3A2C);
  static const Color jade700 = Color(0xFF0F4A37);
  static const Color jade600 = Color(0xFF136049); // Primary interactive brand jade
  static const Color jade500 = Color(0xFF1A7D5C); // Accent brand dot
  static const Color jade400 = Color(0xFF3FA57D);
  static const Color jade200 = Color(0xFFBFE3D2);
  static const Color jade100 = Color(0xFFDCF0E6);
  static const Color jade50  = Color(0xFFEFF8F3); // Pale mint-sage surface & badge bg

  // Canvas & Surfaces
  static const Color canvas  = Color(0xFFF4F8F5); // Screen background (warm sage canvas)
  static const Color surface = Color(0xFFFFFFFF); // Card & modal background
  static const Color surfaceMuted = Color(0xFFF9FBFA);

  // Semantics: Amber (Budget Alert & Pending Status)
  static const Color amber700 = Color(0xFF8A5A1B);
  static const Color amber600 = Color(0xFFB9791B);
  static const Color amber500 = Color(0xFFE8A33D); // Warning pill & Near Limit 84%
  static const Color amber100 = Color(0xFFF7E8CC);
  static const Color amber50  = Color(0xFFFCF6EA); // Pending badge background

  // Semantics: Coral (Debts, Negative Balances, Errors)
  static const Color coral700 = Color(0xFF93362D);
  static const Color coral600 = Color(0xFFB23F35); // Negative balance text (-450.00)
  static const Color coral500 = Color(0xFFCB5A4E); // Owes badge & error
  static const Color coral100 = Color(0xFFF7E2DE);
  static const Color coral50  = Color(0xFFFBF0ED);

  // Typography & Hairlines
  static const Color ink      = Color(0xFF16241D); // Primary text (deep forest black)
  static const Color slate    = Color(0xFF5F6F66); // Secondary body text
  static const Color faint    = Color(0xFF94A39B); // Tertiary captions & placeholders
  static const Color line     = Color(0xFFE2EAE4); // Hairline borders (1px)
  static const Color lineSoft = Color(0xFFECF2EE); // Divider lines inside cards

  // Roommate Color Accents
  static const Color avatarAli = Color(0xFF136049);    // Jade
  static const Color avatarAyesha = Color(0xFFE8A33D); // Amber
  static const Color avatarBilal = Color(0xFFCB5A4E);  // Coral

  // Category Icon Tint Colors
  static const Color catUtilitiesBg = Color(0xFFFCF6EA);
  static const Color catUtilitiesFg = Color(0xFFB9791B);
  static const Color catGroceriesBg = Color(0xFFEFF8F3);
  static const Color catGroceriesFg = Color(0xFF136049);
  static const Color catCleaningBg  = Color(0xFFEFF8F3);
  static const Color catCleaningFg  = Color(0xFF1A7D5C);
  static const Color catDiningBg    = Color(0xFFFBF0ED);
  static const Color catDiningFg    = Color(0xFFCB5A4E);

  // Backward-compatible semantic aliases
  static const Color primaryPine = jade700;
  static const Color accentEmerald = jade600;
  static const Color accentEmeraldDark = jade700;
  static const Color backgroundSlate = canvas;
  static const Color surfaceContainer = surface;
  static const Color surfaceElevated = jade50;

  static const Color balanceReceivable = jade600;
  static const Color balanceOwed = coral600;
  static const Color budgetWarning = amber500;
  static const Color budgetOnTrack = jade600;
  static const Color budgetOverLimit = coral600;

  static const Color textPrimary = ink;
  static const Color textSecondary = slate;
  static const Color textMuted = faint;

  static const Color borderSubtle = line;
  static const Color borderCard = line;

  static const Color lightBackground = canvas;
  static const Color lightSurface = surface;
  static const Color lightSurfaceContainer = jade50;
  static const Color lightTextPrimary = ink;
  static const Color lightTextSecondary = slate;
  static const Color lightBorder = line;
}
