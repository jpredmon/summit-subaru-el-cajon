import 'body_category.dart';

/// The cleaned, typed vehicle the UI consumes. Produced from [RawVehicle] by
/// the transform in `transform_vehicle.dart` (Task 3), which owns the price
/// floor, body normalization, mpg gating, and other business rules. This class
/// is a plain immutable holder — no parsing lives here.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.vin,
    required this.stock,
    required this.year,
    required this.make,
    required this.model,
    required this.trim,
    required this.bodyStyle,
    required this.engine,
    required this.transmission,
    required this.drivetrain,
    required this.exteriorColor,
    required this.interiorColor,
    required this.mileage,
    required this.price,
    required this.isCertified,
    required this.mpgCity,
    required this.mpgHwy,
    required this.photos,
    required this.features,
    required this.description,
    required this.isNew,
  });

  final int id;
  final String vin;
  final String stock;
  final int year;
  final String make;
  final String model;
  final String trim;
  final BodyCategory bodyStyle;
  final String engine;
  final String transmission;
  final String drivetrain;
  final String exteriorColor;
  final String interiorColor;
  final int mileage;
  final double? price; // null when unparseable/below floor -> "Call for price"
  final bool isCertified;
  final double? mpgCity; // null when unparseable or <= 0
  final double? mpgHwy; // null when unparseable or <= 0
  final List<String> photos; // may be empty
  final List<String> features; // deduped, trimmed, empty-after-trim dropped
  final String description; // sanitized, VDP supplementary text only
  final bool isNew;
}
