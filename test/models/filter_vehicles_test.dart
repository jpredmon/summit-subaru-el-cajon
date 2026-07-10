import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/filter_vehicles.dart';
import 'package:vincue_mobile/models/raw_vehicle.dart';
import 'package:vincue_mobile/models/transform_vehicle.dart';
import 'package:vincue_mobile/models/vehicle.dart';

/// A synthetic vehicle with valid defaults; override only the field under
/// test.
Vehicle _vehicle({
  int id = 1,
  String make = 'Honda',
  BodyCategory bodyStyle = BodyCategory.sedan,
  double? price = 20000,
}) {
  return Vehicle(
    id: id,
    vin: 'VIN$id',
    stock: 'S$id',
    year: 2020,
    make: make,
    model: 'Model',
    trim: 'Trim',
    bodyStyle: bodyStyle,
    engine: 'V6',
    transmission: 'Automatic',
    drivetrain: 'FWD',
    exteriorColor: 'Black',
    interiorColor: 'Gray',
    mileage: 10000,
    price: price,
    isCertified: false,
    mpgCity: 25,
    mpgHwy: 32,
    photos: const [],
    features: const ['Bluetooth'],
    description: 'Clean car.',
    isNew: false,
  );
}

void main() {
  late List<Vehicle> fixtureVehicles;

  setUpAll(() {
    final decoded = jsonDecode(
      File('test/fixtures/active_inventory_response.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final raw = (decoded['result'] as List<dynamic>)
        .map((e) => RawVehicle.fromJson(e as Map<String, dynamic>))
        .toList();
    fixtureVehicles = raw.map(transformVehicle).toList();
  });

  group('filterVehicles', () {
    test('returns all vehicles when no filters are set', () {
      final vehicles = [_vehicle(id: 1), _vehicle(id: 2)];
      expect(filterVehicles(vehicles, const VehicleFilters()), hasLength(2));
    });

    test('filters by make', () {
      final vehicles = [
        _vehicle(id: 1, make: 'Honda'),
        _vehicle(id: 2, make: 'Toyota'),
        _vehicle(id: 3, make: 'Honda'),
      ];
      final result = filterVehicles(vehicles, const VehicleFilters(make: 'Honda'));
      expect(result.map((v) => v.id), [1, 3]);
    });

    test('filters by body style', () {
      final vehicles = [
        _vehicle(id: 1, bodyStyle: BodyCategory.sedan),
        _vehicle(id: 2, bodyStyle: BodyCategory.suv),
        _vehicle(id: 3, bodyStyle: BodyCategory.suv),
      ];
      final result = filterVehicles(vehicles, const VehicleFilters(body: BodyCategory.suv));
      expect(result.map((v) => v.id), [2, 3]);
    });

    test('combines make and body filters (AND, not OR)', () {
      final vehicles = [
        _vehicle(id: 1, make: 'Honda', bodyStyle: BodyCategory.sedan),
        _vehicle(id: 2, make: 'Toyota', bodyStyle: BodyCategory.suv),
        _vehicle(id: 3, make: 'Honda', bodyStyle: BodyCategory.suv),
      ];
      final result = filterVehicles(
        vehicles,
        const VehicleFilters(make: 'Honda', body: BodyCategory.suv),
      );
      expect(result.map((v) => v.id), [3]);
    });

    test('filters by minPrice and maxPrice', () {
      final vehicles = [
        _vehicle(id: 1, price: 20000),
        _vehicle(id: 2, price: 30000),
        _vehicle(id: 3, price: 40000),
      ];
      final result = filterVehicles(
        vehicles,
        const VehicleFilters(minPrice: 25000, maxPrice: 35000),
      );
      expect(result.map((v) => v.id), [2]);
    });

    test('excludes vehicles with a null price ("Call for price") when a price filter is active', () {
      final vehicles = [_vehicle(id: 1, price: null), _vehicle(id: 2, price: 20000)];
      final result = filterVehicles(vehicles, const VehicleFilters(minPrice: 0));
      expect(result.map((v) => v.id), [2]);
    });

    test('excludes vehicles with a null price when only maxPrice is active', () {
      final vehicles = [_vehicle(id: 1, price: null), _vehicle(id: 2, price: 20000)];
      final result = filterVehicles(vehicles, const VehicleFilters(maxPrice: 50000));
      expect(result.map((v) => v.id), [2]);
    });

    test('includes null-price vehicles when no price filter is set', () {
      final vehicles = [_vehicle(id: 1, price: null)];
      expect(filterVehicles(vehicles, const VehicleFilters()), hasLength(1));
    });

    test('an inverted range (minPrice > maxPrice) resolves to no matches, not a crash', () {
      // The two selects normally prevent this via mutual pruning, but
      // filter state round-trips through URL query params (Task 10), which
      // a user can hand-edit into an inverted combination.
      final vehicles = [_vehicle(id: 1, price: 20000), _vehicle(id: 2, price: 30000)];
      final result = filterVehicles(
        vehicles,
        const VehicleFilters(minPrice: 100000, maxPrice: 10000),
      );
      expect(result, isEmpty);
    });
  });

  group('priceThresholds', () {
    test('matches the fixed threshold list from the web app', () {
      expect(priceThresholds, [
        10000,
        15000,
        20000,
        25000,
        30000,
        40000,
        50000,
        75000,
        100000,
      ]);
    });
  });

  group('minPriceOptions (pruned by the current maxPrice)', () {
    test('returns the full list when no maxPrice is set', () {
      expect(minPriceOptions(null), priceThresholds);
    });

    test('caps options at or below the current maxPrice', () {
      expect(minPriceOptions(25000), [10000, 15000, 20000, 25000]);
    });

    test('includes a threshold exactly equal to maxPrice (inclusive boundary)', () {
      expect(minPriceOptions(10000), [10000]);
    });
  });

  group('maxPriceOptions (pruned by the current minPrice)', () {
    test('returns the full list when no minPrice is set', () {
      expect(maxPriceOptions(null), priceThresholds);
    });

    test('floors options at or above the current minPrice', () {
      expect(maxPriceOptions(25000), [25000, 30000, 40000, 50000, 75000, 100000]);
    });

    test('includes a threshold exactly equal to minPrice (inclusive boundary)', () {
      expect(maxPriceOptions(100000), [100000]);
    });
  });

  group('pruning self-consistency', () {
    test('a threshold never prunes itself out of the min-price list it belongs to', () {
      for (final threshold in priceThresholds) {
        expect(
          minPriceOptions(threshold),
          contains(threshold),
          reason: 'minPriceOptions($threshold) dropped its own selection',
        );
      }
    });

    test('a threshold never prunes itself out of the max-price list it belongs to', () {
      for (final threshold in priceThresholds) {
        expect(
          maxPriceOptions(threshold),
          contains(threshold),
          reason: 'maxPriceOptions($threshold) dropped its own selection',
        );
      }
    });
  });

  group('getFilterOptions', () {
    test('derives sorted unique makes from the given vehicles', () {
      final vehicles = [
        _vehicle(make: 'Toyota'),
        _vehicle(make: 'Honda'),
        _vehicle(make: 'Honda'),
      ];
      expect(getFilterOptions(vehicles).makes, ['Honda', 'Toyota']);
    });

    test('derives body styles present in the data, in canonical order, with no duplicates', () {
      final vehicles = [
        _vehicle(bodyStyle: BodyCategory.other),
        _vehicle(bodyStyle: BodyCategory.sedan),
        _vehicle(bodyStyle: BodyCategory.sedan),
        _vehicle(bodyStyle: BodyCategory.truck),
      ];
      expect(getFilterOptions(vehicles).bodyStyles, [
        BodyCategory.sedan,
        BodyCategory.truck,
        BodyCategory.other,
      ]);
    });

    test('never includes a body style with zero matching vehicles', () {
      final vehicles = [_vehicle(bodyStyle: BodyCategory.sedan)];
      expect(getFilterOptions(vehicles).bodyStyles, isNot(contains(BodyCategory.suv)));
    });
  });

  group('against the real 141-record fixture', () {
    test('getFilterOptions derives the exact 21-make sorted list, no duplicates', () {
      // Independent oracle computed directly from the fixture JSON (see
      // Task 6's confidence-raising precedent), not by re-running the
      // implementation under test.
      const expectedMakes = [
        'Acura', 'BMW', 'Chevrolet', 'Dodge', 'Ford', 'GMC', 'Honda',
        'Hyundai', 'Jeep', 'Kia', 'Lincoln', 'Mazda', 'Mercedes-Benz',
        'Mitsubishi', 'Nissan', 'Polaris', 'Porsche', 'Subaru', 'Toyota',
        'Volkswagen', 'Volvo',
      ];
      expect(getFilterOptions(fixtureVehicles).makes, expectedMakes);
    });

    test('getFilterOptions body styles are a strictly-ordered, deduped subsequence of BodyCategory.values', () {
      final bodyStyles = getFilterOptions(fixtureVehicles).bodyStyles;
      expect(bodyStyles, isNotEmpty);
      expect(bodyStyles.toSet().length, bodyStyles.length); // no duplicates
      final indices = bodyStyles.map(BodyCategory.values.indexOf).toList();
      expect(indices, List<int>.from(indices)..sort()); // strictly canonical order
    });

    test('filtering by make partitions the fixture with no vehicle double-counted or dropped', () {
      final makes = {for (final v in fixtureVehicles) v.make};
      final totalAcrossMakes = makes
          .map((m) => filterVehicles(fixtureVehicles, VehicleFilters(make: m)).length)
          .fold<int>(0, (sum, count) => sum + count);
      expect(totalAcrossMakes, fixtureVehicles.length);
    });

    test('filtering by minPrice partitions the fixture against an independent price predicate', () {
      const threshold = 25000.0;
      final atOrAbove = filterVehicles(fixtureVehicles, const VehicleFilters(minPrice: threshold)).length;
      // Computed directly against Vehicle.price, not via filterVehicles/paginate.
      final belowThreshold = fixtureVehicles.where((v) => v.price != null && v.price! < threshold).length;
      final nullPriced = fixtureVehicles.where((v) => v.price == null).length;
      expect(atOrAbove + belowThreshold + nullPriced, fixtureVehicles.length);
      expect(atOrAbove, greaterThan(0));
      expect(nullPriced, greaterThan(0)); // the fixture has at least one "Call for price" record
    });
  });
}
