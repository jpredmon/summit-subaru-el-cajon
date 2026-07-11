import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/models/find_vehicle.dart';

import '../support/vehicle_factory.dart';

void main() {
  test('returns the vehicle whose id matches', () {
    final vehicles = [vehicle(id: 1), vehicle(id: 2), vehicle(id: 3)];

    expect(findVehicleById(vehicles, 2)?.id, 2);
  });

  test('returns null when no vehicle matches the id', () {
    final vehicles = [vehicle(id: 1), vehicle(id: 2)];

    expect(findVehicleById(vehicles, 99), isNull);
  });

  test('returns null for an empty list', () {
    expect(findVehicleById(const [], 1), isNull);
  });
}
