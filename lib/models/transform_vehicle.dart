import 'package:html/parser.dart' as html;

import 'body_category.dart';
import 'raw_vehicle.dart';
import 'vehicle.dart';

/// The second-lowest real selling price in the sample is ~$8,994. A $1 record
/// exists (2025 Porsche 911, wholesalePrice 413035) as a "not yet priced"
/// placeholder — same intent as "0.00"/"". A $500 floor cleanly separates
/// placeholder prices from any genuine low price.
const double _minPlausiblePrice = 500;

/// Parses a numeric string, returning null for empty/whitespace, non-numeric,
/// or non-finite input. Dart's [double.tryParse] does not trim, so trim first
/// to match the source app's `Number()` whitespace tolerance.
double? _parseNumberOrNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed);
  if (parsed == null || !parsed.isFinite) return null;
  return parsed;
}

/// Normalizes the inconsistent raw `body` string into one [BodyCategory].
/// Order matters: convertible is checked before truck so "Cabriolet" isn't
/// caught by the "cab" substring.
BodyCategory normalizeBodyStyle(String raw) {
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return BodyCategory.other;
  if (lower == '4dr car' || lower.contains('sedan')) return BodyCategory.sedan;
  if (lower.contains('sport utility') || lower.contains('suv')) {
    return BodyCategory.suv;
  }
  if (lower.contains('convertible') || lower.contains('cabriolet')) {
    return BodyCategory.convertible;
  }
  if (lower.contains('truck') ||
      lower.contains('pickup') ||
      lower.contains('cab') ||
      lower.contains('crew')) {
    return BodyCategory.truck;
  }
  if (lower.contains('coupe')) return BodyCategory.coupe;
  if (lower.contains('van')) return BodyCategory.van;
  if (lower.contains('hatchback')) return BodyCategory.hatchback;
  return BodyCategory.other;
}

/// Sanitizes a raw marketing description for plain-text display: strip the
/// literal two-character `\n` sequences the API embeds, parse the remaining
/// HTML to text (decoding entities), then collapse whitespace.
String stripDescription(String raw) {
  final withoutEscapedNewlines = raw.replaceAll(r'\n', ' ');
  final text = html.parse(withoutEscapedNewlines).body?.text ?? '';
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Trims each feature, drops entries empty after trimming, and dedupes
/// while preserving first-seen order.
List<String> _dedupeFeatures(List<String> features) {
  final seen = <String>{};
  final result = <String>[];
  for (final feature in features) {
    final trimmed = feature.trim();
    if (trimmed.isNotEmpty && seen.add(trimmed)) {
      result.add(trimmed);
    }
  }
  return result;
}

/// Transforms a [RawVehicle] into the cleaned [Vehicle] the UI consumes,
/// applying all business rules (price floor, body normalization, mpg gating,
/// parse-failure fallbacks, feature cleanup, description sanitization).
Vehicle transformVehicle(RawVehicle raw) {
  final price = _parseNumberOrNull(raw.sellingPrice);
  final mpgCity = _parseNumberOrNull(raw.mpgCity);
  final mpgHwy = _parseNumberOrNull(raw.mpgHwy);

  return Vehicle(
    id: raw.inventoryID,
    vin: raw.vin,
    stock: raw.stock,
    year: _parseNumberOrNull(raw.year)?.toInt() ?? 0,
    make: raw.make,
    model: raw.model,
    trim: raw.trim,
    bodyStyle: normalizeBodyStyle(raw.body),
    engine: raw.engine,
    transmission: raw.transmission,
    drivetrain: raw.drivetrain,
    exteriorColor: raw.extColor,
    interiorColor: raw.intColor,
    mileage: _parseNumberOrNull(raw.miles)?.toInt() ?? 0,
    price: price != null && price >= _minPlausiblePrice ? price : null,
    isCertified: raw.certified == 'Y',
    mpgCity: mpgCity != null && mpgCity > 0 ? mpgCity : null,
    mpgHwy: mpgHwy != null && mpgHwy > 0 ? mpgHwy : null,
    photos: raw.vehiclePhotos,
    features: _dedupeFeatures(raw.features),
    description: stripDescription(raw.description),
    isNew: raw.newUsed == 'N',
  );
}
