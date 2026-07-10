/// The raw inventory record exactly as VINCUE's `ActiveInventory` endpoint
/// returns it — narrowed to the fields this app consumes. Numeric-looking
/// values arrive as strings and are left untouched here; the [Vehicle]
/// transform (see `transform_vehicle.dart`) owns all parsing and business
/// rules. Field names mirror the JSON keys verbatim.
class RawVehicle {
  const RawVehicle({
    required this.inventoryID,
    required this.vin,
    required this.stock,
    required this.newUsed,
    required this.year,
    required this.make,
    required this.model,
    required this.trim,
    required this.body,
    required this.transmission,
    required this.engine,
    required this.drivetrain,
    required this.extColor,
    required this.intColor,
    required this.miles,
    required this.sellingPrice,
    required this.certified,
    required this.mpgCity,
    required this.mpgHwy,
    required this.vehiclePhotos,
    required this.photoCount,
    required this.features,
    required this.description,
    required this.vdpUrl,
    required this.dealerName,
  });

  final int inventoryID;
  final String vin;
  final String stock;
  final String newUsed; // 'N' | 'U'
  final String year; // numeric string
  final String make;
  final String model;
  final String trim;
  final String body; // inconsistent; normalized during transform
  final String transmission;
  final String engine;
  final String drivetrain;
  final String extColor;
  final String intColor;
  final String miles; // numeric string
  final String sellingPrice; // numeric string, sometimes "0.00" or ""
  final String certified; // 'Y' | 'N'
  final String mpgCity; // numeric string
  final String mpgHwy; // numeric string
  final List<String> vehiclePhotos; // frequently empty; matches photoCount
  final int photoCount;
  final List<String> features; // long, noisy, inconsistent
  final String description; // raw HTML entities, marketing copy
  final String? vdpUrl;
  final String dealerName;

  factory RawVehicle.fromJson(Map<String, dynamic> json) {
    return RawVehicle(
      inventoryID: json['inventoryID'] as int,
      vin: json['vin'] as String,
      stock: json['stock'] as String,
      newUsed: json['newUsed'] as String,
      year: json['year'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      trim: json['trim'] as String,
      body: json['body'] as String,
      transmission: json['transmission'] as String,
      engine: json['engine'] as String,
      drivetrain: json['drivetrain'] as String,
      extColor: json['extColor'] as String,
      intColor: json['intColor'] as String,
      miles: json['miles'] as String,
      sellingPrice: json['sellingPrice'] as String,
      certified: json['certified'] as String,
      mpgCity: json['mpgCity'] as String,
      mpgHwy: json['mpgHwy'] as String,
      vehiclePhotos: (json['vehiclePhotos'] as List<dynamic>).cast<String>(),
      photoCount: json['photoCount'] as int,
      features: (json['features'] as List<dynamic>).cast<String>(),
      description: json['description'] as String,
      vdpUrl: json['vdpUrl'] as String?,
      dealerName: json['dealerName'] as String,
    );
  }
}
