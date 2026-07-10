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
