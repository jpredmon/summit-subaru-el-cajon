import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/raw_vehicle.dart';
import 'package:vincue_mobile/models/transform_vehicle.dart';

List<RawVehicle> _load(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return (decoded['result'] as List<dynamic>)
      .map((e) => RawVehicle.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// A synthetic raw record with valid defaults; override only the field under
/// test. Used where the sample has no record that exercises a branch (mpg
/// gating, parse-failure fallback, feature dedupe).
RawVehicle _raw({
  String year = '2020',
  String miles = '10000',
  String sellingPrice = '20000.00',
  String body = 'Sedan',
  String certified = 'N',
  String newUsed = 'U',
  String mpgCity = '25',
  String mpgHwy = '32',
  List<String> features = const ['Bluetooth'],
  String description = 'Clean car.',
  List<String> vehiclePhotos = const [],
}) {
  return RawVehicle(
    inventoryID: 1,
    vin: 'VIN1',
    stock: 'S1',
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
    dealerName: 'Dealer',
  );
}

void main() {
  late List<RawVehicle> records;
  late Map<int, RawVehicle> edge;

  setUpAll(() {
    records = _load('test/fixtures/active_inventory_response.json');
    edge = {
      for (final r in _load('test/fixtures/edge_case_vehicles.json')) r.inventoryID: r,
    };
  });

  RawVehicle find(bool Function(RawVehicle) test) =>
      records.firstWhere(test, orElse: () => throw StateError('no matching record'));

  group('price (\$500 floor + placeholder sentinels)', () {
    test('nulls an empty-string selling price', () {
      expect(transformVehicle(edge[358370223]!).price, isNull);
    });

    test('nulls a "0.00" selling price', () {
      expect(transformVehicle(edge[367449581]!).price, isNull);
    });

    test('nulls the \$1 Porsche placeholder (>0 but below the floor)', () {
      expect(transformVehicle(edge[378880968]!).price, isNull);
    });

    test('parses a genuine price at/above the floor', () {
      final raw = edge[174507806]!; // BMW M5, "74100.00"
      expect(transformVehicle(raw).price, 74100.0);
    });
  });

  group('body normalization', () {
    test('buckets a drivetrain-string body into other', () {
      final raw = find((r) => r.body == 'S-AWC');
      expect(transformVehicle(raw).bodyStyle, BodyCategory.other);
    });

    test('maps a clean "Sedan" to sedan', () {
      final raw = find((r) => r.body == 'Sedan');
      expect(transformVehicle(raw).bodyStyle, BodyCategory.sedan);
    });

    test('maps a crew/cab variant to truck', () {
      final raw = find((r) => r.body.toLowerCase().contains('crew'));
      expect(transformVehicle(raw).bodyStyle, BodyCategory.truck);
    });

    test('does not misclassify "Cabriolet" as truck (cab substring)', () {
      expect(normalizeBodyStyle('Cabriolet'), BodyCategory.convertible);
    });

    test('empty body is other', () {
      expect(normalizeBodyStyle(''), BodyCategory.other);
    });
  });

  group('mpg gating', () {
    test('nulls mpg when <= 0 or unparseable, keeps positive values', () {
      expect(transformVehicle(_raw(mpgCity: '0')).mpgCity, isNull);
      expect(transformVehicle(_raw(mpgHwy: '')).mpgHwy, isNull);
      expect(transformVehicle(_raw(mpgCity: 'n/a')).mpgCity, isNull);
      expect(transformVehicle(_raw(mpgCity: '28')).mpgCity, 28.0);
    });
  });

  group('year/mileage parse-failure fallback', () {
    test('falls back to 0 (not null) on unparseable year/mileage', () {
      expect(transformVehicle(_raw(year: '')).year, 0);
      expect(transformVehicle(_raw(miles: 'abc')).mileage, 0);
    });

    test('parses valid year/mileage', () {
      final v = transformVehicle(_raw(year: '2020', miles: '10000'));
      expect(v.year, 2020);
      expect(v.mileage, 10000);
    });
  });

  group('boolean flags', () {
    test('isCertified is true only for "Y"', () {
      expect(transformVehicle(_raw(certified: 'Y')).isCertified, isTrue);
      expect(transformVehicle(_raw(certified: 'N')).isCertified, isFalse);
    });

    test('isNew is true only for newUsed "N"', () {
      expect(transformVehicle(_raw(newUsed: 'N')).isNew, isTrue);
      expect(transformVehicle(_raw(newUsed: 'U')).isNew, isFalse);
    });
  });

  group('features', () {
    test('trims, drops empty-after-trim, and dedupes order-preservingly', () {
      final v = transformVehicle(_raw(features: const [
        'Cruise Control',
        '  Cruise Control  ',
        '   ',
        'Heated Seats',
        'Cruise Control',
      ]));
      expect(v.features, ['Cruise Control', 'Heated Seats']);
    });
  });

  group('description sanitization', () {
    test('strips tags and literal backslash-n from a real description', () {
      final cleaned = transformVehicle(edge[174507784]!).description;
      expect(cleaned, isNotEmpty);
      expect(cleaned.contains('<'), isFalse);
      expect(cleaned.contains(r'\n'), isFalse);
    });

    test('decodes HTML entities present in real descriptions', () {
      final raw = find((r) => RegExp(r'&[a-zA-Z]+;').hasMatch(r.description));
      final cleaned = transformVehicle(raw).description;
      expect(RegExp(r'&[a-zA-Z]+;').hasMatch(cleaned), isFalse);
    });

    test('collapses whitespace and trims', () {
      final v = transformVehicle(_raw(description: '  a   b  '));
      expect(v.description, 'a b');
    });
  });

  group('photos passthrough', () {
    test('empty stays empty; non-empty passes through unchanged', () {
      expect(transformVehicle(edge[174507784]!).photos, isEmpty);
      final withPhotos = edge[174507806]!;
      expect(transformVehicle(withPhotos).photos, withPhotos.vehiclePhotos);
    });
  });

  // Regression guard: the whole sample must transform without throwing
  // (notably the html parser over every real description) and every output
  // must satisfy the documented invariants.
  group('transforms the full captured response', () {
    test('all 141 records transform and hold their invariants', () {
      for (final raw in records) {
        final v = transformVehicle(raw);
        expect(v.price == null || v.price! >= 500, isTrue);
        expect(v.mpgCity == null || v.mpgCity! > 0, isTrue);
        expect(v.mpgHwy == null || v.mpgHwy! > 0, isTrue);
        expect(v.year >= 0, isTrue);
        expect(v.mileage >= 0, isTrue);
        expect(v.features.every((f) => f.trim().isNotEmpty), isTrue);
        expect(v.description.contains(r'\n'), isFalse);
      }
    });
  });
}
