import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/raw_vehicle.dart';

/// Round-trips [map] through JSON encode/decode so the value handed to
/// [RawVehicle.fromJson] has the same dynamic types the real `http` response
/// produces (e.g. arrays as `List<dynamic>`, not `List<String>`). This catches
/// over-narrow casts that would pass against a hand-built typed map but crash
/// on live data.
RawVehicle _parse(Map<String, dynamic> map) =>
    RawVehicle.fromJson(jsonDecode(jsonEncode(map)) as Map<String, dynamic>);

Map<String, dynamic> _record({
  String sellingPrice = '18905.00',
  List<String> vehiclePhotos = const [
    'https://example.com/1.jpg',
    'https://example.com/2.jpg',
  ],
  Object? vdpUrl = 'https://pro.vincue.com/vdp/123',
}) {
  return {
    'inventoryID': 174507784,
    'vin': '1N4AL3AP8HC270506',
    'stock': 'P720',
    'newUsed': 'U',
    'year': '2017',
    'make': 'Nissan',
    'model': 'Altima',
    'trim': '2.5 SR',
    'body': 'Sedan',
    'transmission': 'CVT',
    'engine': '4 Cylinder Engine',
    'drivetrain': 'Front Wheel Drive',
    'extColor': 'Super Black',
    'intColor': 'Sport Interior',
    'miles': '41900',
    'sellingPrice': sellingPrice,
    'certified': 'N',
    'mpgCity': '27',
    'mpgHwy': '39',
    'vehiclePhotos': vehiclePhotos,
    'photoCount': vehiclePhotos.length,
    'features': const ['Bluetooth', 'Backup Camera'],
    'description': 'The 2017 Nissan Altima 2.5 SR is a stylish sedan.',
    'vdpUrl': vdpUrl,
    'dealerName': 'Summit Subaru El Cajon',
  };
}

void main() {
  group('RawVehicle.fromJson', () {
    test('maps every field of a fully populated record', () {
      final raw = _parse(_record());

      expect(raw.inventoryID, 174507784);
      expect(raw.vin, '1N4AL3AP8HC270506');
      expect(raw.stock, 'P720');
      expect(raw.newUsed, 'U');
      expect(raw.year, '2017');
      expect(raw.make, 'Nissan');
      expect(raw.model, 'Altima');
      expect(raw.trim, '2.5 SR');
      expect(raw.body, 'Sedan');
      expect(raw.transmission, 'CVT');
      expect(raw.engine, '4 Cylinder Engine');
      expect(raw.drivetrain, 'Front Wheel Drive');
      expect(raw.extColor, 'Super Black');
      expect(raw.intColor, 'Sport Interior');
      expect(raw.miles, '41900');
      expect(raw.sellingPrice, '18905.00');
      expect(raw.certified, 'N');
      expect(raw.mpgCity, '27');
      expect(raw.mpgHwy, '39');
      expect(raw.vehiclePhotos, [
        'https://example.com/1.jpg',
        'https://example.com/2.jpg',
      ]);
      expect(raw.photoCount, 2);
      expect(raw.features, ['Bluetooth', 'Backup Camera']);
      expect(raw.description, contains('Nissan Altima'));
      expect(raw.vdpUrl, 'https://pro.vincue.com/vdp/123');
      expect(raw.dealerName, 'Summit Subaru El Cajon');
    });

    test('preserves an empty sellingPrice as an empty string', () {
      final raw = _parse(_record(sellingPrice: ''));
      expect(raw.sellingPrice, '');
    });

    test('parses an empty vehiclePhotos array as an empty list', () {
      final raw = _parse(_record(vehiclePhotos: const []));
      expect(raw.vehiclePhotos, isEmpty);
    });

    test('typed list fields are List<String>, not List<dynamic>', () {
      final raw = _parse(_record());
      expect(raw.vehiclePhotos, isA<List<String>>());
      expect(raw.features, isA<List<String>>());
    });

    test('parses a null vdpUrl as null', () {
      final raw = _parse(_record(vdpUrl: null));
      expect(raw.vdpUrl, isNull);
    });
  });
}
