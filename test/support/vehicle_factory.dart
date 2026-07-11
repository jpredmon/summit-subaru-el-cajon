import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/vehicle.dart';

/// Builds a transformed [Vehicle] with valid defaults; override only the
/// fields a test cares about. Shared across widget/screen tests that need a
/// ready-to-render [Vehicle] without going through [RawVehicle]/transform.
Vehicle vehicle({
  int id = 1,
  String make = 'Honda',
  String model = 'Accord',
  String trim = 'EX-L',
  int year = 2020,
  BodyCategory bodyStyle = BodyCategory.sedan,
  int mileage = 45231,
  double? price = 20000,
  List<String> photos = const [],
}) {
  return Vehicle(
    id: id,
    vin: 'VIN$id',
    stock: 'S$id',
    year: year,
    make: make,
    model: model,
    trim: trim,
    bodyStyle: bodyStyle,
    engine: 'V6',
    transmission: 'Automatic',
    drivetrain: 'FWD',
    exteriorColor: 'Black',
    interiorColor: 'Gray',
    mileage: mileage,
    price: price,
    isCertified: false,
    mpgCity: 25,
    mpgHwy: 32,
    photos: photos,
    features: const ['Bluetooth'],
    description: 'Clean car.',
    isNew: false,
  );
}
