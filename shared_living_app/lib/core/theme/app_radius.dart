import 'package:flutter/material.dart';

/// Corner Radius Tokens according to Hisab Design System Spec
class AppRadius {
  static const double tag = 6.0;
  static const double chip = 9.0;
  static const double field = 14.0;
  static const double card = 20.0;
  static const double hero = 20.0;
  static const double sheet = 28.0;
  static const double full = 999.0;

  // General sizing aliases
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 14.0;
  static const double lg = 20.0;
  static const double xl = 28.0;

  static const BorderRadius radiusTag = BorderRadius.all(Radius.circular(tag));
  static const BorderRadius radiusChip = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius radiusField = BorderRadius.all(Radius.circular(field));
  static const BorderRadius radiusCard = BorderRadius.all(Radius.circular(card));
  static const BorderRadius radiusHero = BorderRadius.all(Radius.circular(hero));
  static const BorderRadius radiusSheetTop = BorderRadius.vertical(top: Radius.circular(sheet));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(full));

  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
}
