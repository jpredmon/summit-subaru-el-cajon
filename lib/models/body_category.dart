/// Normalized body-style buckets. The raw `body` field is inconsistently
/// populated (real styles, stray drivetrain strings, or empty), so the
/// transform maps every record into exactly one of these — anything
/// unrecognized falls through to [BodyCategory.other] to keep the SRP filter
/// dropdown clean.
enum BodyCategory {
  sedan,
  suv,
  truck,
  coupe,
  van,
  hatchback,
  convertible,
  other,
}

/// Human-readable label for each category — matches the web app's
/// `BodyCategory` string union exactly (`'SUV'` all-caps, others capitalized).
extension BodyCategoryDisplay on BodyCategory {
  String get displayName => switch (this) {
        BodyCategory.sedan => 'Sedan',
        BodyCategory.suv => 'SUV',
        BodyCategory.truck => 'Truck',
        BodyCategory.coupe => 'Coupe',
        BodyCategory.van => 'Van',
        BodyCategory.hatchback => 'Hatchback',
        BodyCategory.convertible => 'Convertible',
        BodyCategory.other => 'Other',
      };
}
