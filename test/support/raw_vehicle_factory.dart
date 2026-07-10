import 'package:vincue_mobile/models/raw_vehicle.dart';

/// Builds a raw record with valid defaults; override only the fields a test
/// cares about. Shared across the model/service/provider tests.
RawVehicle rawVehicle({
  int inventoryID = 1,
  String year = '2020',
  String miles = '10000',
  String sellingPrice = '20000.00',
  String body = 'Sedan',
  String certified = 'N',
  String newUsed = 'U',
  String mpgCity = '25',
  String mpgHwy = '32',
  List<String> vehiclePhotos = const [],
  List<String> features = const ['Bluetooth'],
  String description = 'Clean car.',
  String dealerName = 'Summit Subaru El Cajon',
}) {
  return RawVehicle(
    inventoryID: inventoryID,
    vin: 'VIN$inventoryID',
    stock: 'S$inventoryID',
    newUsed: newUsed,
    year: year,
    make: 'Make',
    model: 'Model',
    trim: 'Trim',
    body: body,
    transmission: 'Automatic',
    engine: 'V6',
    drivetrain: 'FWD',
    extColor: 'Black',
    intColor: 'Gray',
    miles: miles,
    sellingPrice: sellingPrice,
    certified: certified,
    mpgCity: mpgCity,
    mpgHwy: mpgHwy,
    vehiclePhotos: vehiclePhotos,
    photoCount: vehiclePhotos.length,
    features: features,
    description: description,
    vdpUrl: null,
    dealerName: dealerName,
  );
}
