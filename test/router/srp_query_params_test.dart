import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/body_category.dart';
import 'package:vincue_mobile/models/filter_vehicles.dart';
import 'package:vincue_mobile/providers/srp_state_provider.dart';
import 'package:vincue_mobile/router/srp_query_params.dart';

void main() {
  group('parseSrpQueryParams', () {
    test('returns default (no filters, page 1) for empty query parameters', () {
      final state = parseSrpQueryParams(const {});

      expect(state.filters.make, isNull);
      expect(state.filters.body, isNull);
      expect(state.filters.minPrice, isNull);
      expect(state.filters.maxPrice, isNull);
      expect(state.page, 1);
    });

    test('parses make directly', () {
      final state = parseSrpQueryParams(const {'make': 'Honda'});
      expect(state.filters.make, 'Honda');
    });

    test('parses a valid body category', () {
      final state = parseSrpQueryParams(const {'body': 'SUV'});
      expect(state.filters.body, BodyCategory.suv);
    });

    test('ignores an unrecognized body category value', () {
      final state = parseSrpQueryParams(const {'body': 'Spaceship'});
      expect(state.filters.body, isNull);
    });

    test('parses minPrice and maxPrice as numbers', () {
      final state = parseSrpQueryParams(const {'minPrice': '10000', 'maxPrice': '20000'});
      expect(state.filters.minPrice, 10000);
      expect(state.filters.maxPrice, 20000);
    });

    test('ignores a non-numeric price value', () {
      final state = parseSrpQueryParams(const {'minPrice': 'not-a-number'});
      expect(state.filters.minPrice, isNull);
    });

    test('ignores non-finite price values (Infinity/-Infinity/NaN parse successfully in Dart '
        'but are not real prices)', () {
      expect(parseSrpQueryParams(const {'minPrice': 'Infinity'}).filters.minPrice, isNull);
      expect(parseSrpQueryParams(const {'minPrice': '-Infinity'}).filters.minPrice, isNull);
      expect(parseSrpQueryParams(const {'maxPrice': 'NaN'}).filters.maxPrice, isNull);
    });

    test('parses a page number', () {
      final state = parseSrpQueryParams(const {'page': '3'});
      expect(state.page, 3);
    });

    test('defaults to page 1 for a missing, non-numeric, or sub-1 page value', () {
      expect(parseSrpQueryParams(const {}).page, 1);
      expect(parseSrpQueryParams(const {'page': 'abc'}).page, 1);
      expect(parseSrpQueryParams(const {'page': '0'}).page, 1);
      expect(parseSrpQueryParams(const {'page': '-5'}).page, 1);
    });

    test('floors a fractional page value', () {
      expect(parseSrpQueryParams(const {'page': '2.9'}).page, 2);
    });
  });

  group('srpStateToQueryParams', () {
    test('returns an empty map for default state (no filters, page 1)', () {
      expect(srpStateToQueryParams(const SrpFilterState()), isEmpty);
    });

    test('includes only the active filter dimensions', () {
      final params = srpStateToQueryParams(
        const SrpFilterState(filters: VehicleFilters(make: 'Honda')),
      );
      expect(params, {'make': 'Honda'});
    });

    test('encodes body as its display-name string', () {
      final params = srpStateToQueryParams(
        const SrpFilterState(filters: VehicleFilters(body: BodyCategory.suv)),
      );
      expect(params, {'body': 'SUV'});
    });

    test('encodes minPrice/maxPrice as plain numeric strings', () {
      final params = srpStateToQueryParams(
        const SrpFilterState(filters: VehicleFilters(minPrice: 10000, maxPrice: 20000)),
      );
      expect(params, {'minPrice': '10000', 'maxPrice': '20000'});
    });

    test('omits page from the map at page 1', () {
      final params = srpStateToQueryParams(const SrpFilterState(page: 1));
      expect(params.containsKey('page'), isFalse);
    });

    test('includes page when greater than 1', () {
      final params = srpStateToQueryParams(const SrpFilterState(page: 3));
      expect(params['page'], '3');
    });

    test('round-trips through parseSrpQueryParams', () {
      const original = SrpFilterState(
        filters: VehicleFilters(make: 'Toyota', body: BodyCategory.truck, minPrice: 15000, maxPrice: 40000),
        page: 4,
      );

      final restored = parseSrpQueryParams(srpStateToQueryParams(original));

      expect(restored.filters.make, original.filters.make);
      expect(restored.filters.body, original.filters.body);
      expect(restored.filters.minPrice, original.filters.minPrice);
      expect(restored.filters.maxPrice, original.filters.maxPrice);
      expect(restored.page, original.page);
    });
  });
}
