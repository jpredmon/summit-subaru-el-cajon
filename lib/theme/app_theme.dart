import 'package:flutter/material.dart';

/// Shared corner radius for every interactive rectangle (buttons, selects, cards).
const double kCardRadius = 12.0;

/// "Certified" badge accent (emerald) — outside the amber/slate palette scale.
const Color kCertifiedColor = Color(0xFF10B981);

/// Material 3's default font family -- explicitly named so [tabularNumsStyle]
/// can force numeric displays back onto it, undoing the header/title font
/// (Anton) some numbers would otherwise inherit from a `titleMedium`/
/// `titleLarge` base style.
const String _kDefaultFontFamily = 'Roboto';

/// Applies tabular-figure alignment for numeric displays (prices, mileage,
/// mpg, counters). Also forces the font back to [_kDefaultFontFamily]
/// regardless of the base style's own font -- Anton (the header/title font)
/// has condensed numeral glyphs that look scrunched once stretched to
/// tabular-figure fixed-width, so numeric displays opt out of it even when
/// their base style (e.g. a bold price using `titleMedium`) is Anton.
TextStyle tabularNumsStyle(TextStyle base) {
  return base.copyWith(
    fontFamily: _kDefaultFontFamily,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
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
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
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
      // Matches the "SUMMIT SUBARU" lettering in the header logo (bold
      // condensed display face) -- applied only to headline/title roles,
      // not body/label text: a display font like this hurts readability
      // in dense areas (prices, descriptions, spec tables), so it's scoped
      // to short, prominent text (vehicle titles, section headers) via
      // Flutter's own TextTheme roles rather than touching individual
      // widgets.
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontFamily: 'Anton'),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontFamily: 'Anton'),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontFamily: 'Anton'),
      ),
    );
  }
}
