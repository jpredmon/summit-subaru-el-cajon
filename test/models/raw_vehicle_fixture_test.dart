import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/raw_vehicle.dart';

/// Reads a `{ result: [...] }` fixture and returns the raw record list.
/// The working directory for `flutter test` is the package root, so these
/// relative paths resolve.
List<dynamic> _loadResult(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return decoded['result'] as List<dynamic>;
}

void main() {
  // Regression guard: parse the full, real API response captured from the
  // live endpoint. If VINCUE's contract ever drifts (a field goes null, a
  // number arrives as a string), fromJson throws here instead of at runtime.
  group('RawVehicle.fromJson against the real captured response', () {
    late List<RawVehicle> vehicles;

    setUpAll(() {
      final result = _loadResult('test/fixtures/active_inventory_response.json');
      vehicles = result
          .map((e) => RawVehicle.fromJson(e as Map<String, dynamic>))
          .toList();
    });

    test('parses every record in the captured response without throwing', () {
      expect(vehicles, hasLength(141));
    });

    test('typed list fields are List<String> across all records', () {
      for (final v in vehicles) {
        expect(v.vehiclePhotos, isA<List<String>>());
        expect(v.features, isA<List<String>>());
      }
    });

    test('nullable vdpUrl holds — null on the majority of records', () {
      final nullCount = vehicles.where((v) => v.vdpUrl == null).length;
      expect(nullCount, greaterThan(0));
    });
  });

  // Curated real records covering the transform's tricky inputs (Task 3
  // reuses this fixture). Asserting the raw values here documents exactly
  // which quirk each record represents.
  group('curated edge-case fixture', () {
    late Map<int, RawVehicle> byId;

    setUpAll(() {
      final result = _loadResult('test/fixtures/edge_case_vehicles.json');
      byId = {
        for (final e in result)
          (e as Map<String, dynamic>)['inventoryID'] as int:
              RawVehicle.fromJson(e),
      };
    });

    test('empty-sellingPrice record parses with an empty-string price', () {
      expect(byId[358370223]!.sellingPrice, '');
    });

    test('zero-sellingPrice record parses as "0.00"', () {
      expect(byId[367449581]!.sellingPrice, '0.00');
    });

    test(r'the $1 Porsche sentinel parses as "1.00"', () {
      expect(byId[378880968]!.make, 'Porsche');
      expect(byId[378880968]!.sellingPrice, '1.00');
    });

    test('no-photos record parses with an empty photo list', () {
      expect(byId[174507784]!.vehiclePhotos, isEmpty);
    });

    test('with-photos record parses with a non-empty photo list', () {
      expect(byId[174507806]!.vehiclePhotos, isNotEmpty);
    });
  });
}
