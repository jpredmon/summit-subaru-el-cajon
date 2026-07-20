import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vincue_mobile/services/inventory_repository.dart';
import 'package:vincue_mobile/services/inventory_response_parser.dart';
import 'package:vincue_mobile/services/static_inventory_data_source.dart';

import '../support/raw_vehicle_factory.dart';

class _MockDataSource extends Mock implements StaticInventoryDataSource {}

void main() {
  late _MockDataSource dataSource;

  setUp(() => dataSource = _MockDataSource());

  test('maps raw records through the transform and passes dealerName', () async {
    when(() => dataSource.loadInventory()).thenAnswer(
      (_) async => RawInventory(
        records: [
          rawVehicle(sellingPrice: '0.00'), // -> price null via transform
          rawVehicle(sellingPrice: '25000.00'),
        ],
        dealerName: 'Summit Subaru El Cajon',
      ),
    );

    final inventory = await InventoryRepository(dataSource).getInventory();

    expect(inventory.vehicles, hasLength(2));
    expect(inventory.vehicles.first.price, isNull);
    expect(inventory.vehicles[1].price, 25000.0);
    expect(inventory.dealerName, 'Summit Subaru El Cajon');
  });

  test('propagates data source errors', () {
    when(() => dataSource.loadInventory()).thenThrow(const InventoryApiException('boom'));

    expect(
      InventoryRepository(dataSource).getInventory(),
      throwsA(isA<InventoryApiException>()),
    );
  });
}
