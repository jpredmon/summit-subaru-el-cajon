import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/dealer_name.dart';
import 'package:vincue_mobile/models/raw_vehicle.dart';

RawVehicle _raw({required String dealerName}) => RawVehicle(
      inventoryID: 1,
      vin: 'V',
      stock: 'S',
      newUsed: 'U',
      year: '2020',
      make: 'Make',
      model: 'Model',
      trim: 'Trim',
      body: 'Sedan',
      transmission: 'Automatic',
      engine: 'V6',
      drivetrain: 'FWD',
      extColor: 'Black',
      intColor: 'Gray',
      miles: '1000',
      sellingPrice: '20000.00',
      certified: 'N',
      mpgCity: '25',
      mpgHwy: '30',
      vehiclePhotos: const [],
      photoCount: 0,
      features: const [],
      description: '',
      vdpUrl: null,
      dealerName: dealerName,
    );

void main() {
  group('getDealerName', () {
    test("returns the first record's dealer name", () {
      expect(
        getDealerName([_raw(dealerName: 'Summit Subaru El Cajon')]),
        'Summit Subaru El Cajon',
      );
    });

    test('trims surrounding whitespace', () {
      expect(getDealerName([_raw(dealerName: '  Summit  ')]), 'Summit');
    });

    test('falls back when the name is empty', () {
      expect(getDealerName([_raw(dealerName: '')]), kFallbackDealerName);
    });

    test('falls back when the name is only whitespace', () {
      expect(getDealerName([_raw(dealerName: '   ')]), kFallbackDealerName);
    });

    test('falls back on an empty list', () {
      expect(getDealerName(const []), kFallbackDealerName);
    });

    test('fallback constant is the generic label', () {
      expect(kFallbackDealerName, 'Vehicle Inventory');
    });
  });
}
