import 'package:flutter/material.dart';

/// Shared corner radius for every interactive rectangle (buttons, selects, cards).
const double kCardRadius = 12.0;

/// "Certified" badge accent (emerald) — outside the amber/slate palette scale.
const Color kCertifiedColor = Color(0xFF10B981);

/// Applies tabular-figure alignment for numeric displays (prices, mileage, mpg, counters).
TextStyle tabularNumsStyle(TextStyle base) {
  return base.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFF59E0B),
          brightness: Brightness.light,
        ).copyWith(primary: const Color(0xFFB45309)),
      );

  static ThemeData dark() => _base(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFF59E0B),
          brightness: Brightness.dark,
        ),
      );

  static ThemeData _base(ColorScheme scheme) {
    final radius = BorderRadius.circular(kCardRadius);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      cardTheme: CardThemeData(shape: RoundedRectangleBorder(borderRadius: radius)),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: radius)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
      ),
    );
  }
}
