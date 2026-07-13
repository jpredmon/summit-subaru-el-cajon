import 'package:flutter/material.dart';

import 'breakpoints.dart';

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

/// Persistent filled background for a link-styled [TextButton] at compact
/// width -- real Android device testing found plain-text `TextButton`s
/// (pagination Next/Previous, Clear filters, etc.) easy to miss at phone
/// widths, since Material 3's default only fills color transiently during
/// the press ripple. `null` above the compact breakpoint, where the plain
/// press-only styling is left as-is. Reuses the theme's own
/// `primaryContainer`/`onPrimaryContainer` pairing (Material 3's own
/// "tonal button" roles) rather than a new hardcoded color.
ButtonStyle? persistentLinkButtonStyle(BuildContext context) {
  if (windowSizeClassOf(MediaQuery.sizeOf(context).width) != WindowSizeClass.compact) {
    return null;
  }
  final scheme = Theme.of(context).colorScheme;
  return TextButton.styleFrom(
    backgroundColor: scheme.primaryContainer,
    foregroundColor: scheme.onPrimaryContainer,
    disabledBackgroundColor: scheme.primaryContainer.withValues(alpha: 0.38),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kCardRadius)),
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFF59E0B),
          brightness: Brightness.light,
          // Matches the "SUMMIT SUBARU" ribbon in the header logo exactly
          // (measured via pixel scan of assets/images/summit_subaru_logo.png:
          // RGB(158,26,28), dominant across 35,199 sampled ribbon pixels).
        ).copyWith(primary: const Color(0xFF9E1A1C)),
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
