import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vincue_mobile/services/inventory_api_client.dart';
import 'package:vincue_mobile/services/inventory_repository.dart';

import '../support/raw_vehicle_factory.dart';

class _MockClient extends Mock implements InventoryApiClient {}

void main() {
  late _MockClient client;

  setUp(() => client = _MockClient());

  test('maps raw records through the transform and passes dealerName', () async {
    when(() => client.fetchInventory()).thenAnswer(
      (_) async => RawInventory(
        records: [
          rawVehicle(sellingPrice: '0.00'), // -> price null via transform
          rawVehicle(sellingPrice: '25000.00'),
        ],
        dealerName: 'Summit Subaru El Cajon',
      ),
    );

    final inventory = await InventoryRepository(client).getInventory();

    expect(inventory.vehicles, hasLength(2));
    expect(inventory.vehicles.first.price, isNull);
    expect(inventory.vehicles[1].price, 25000.0);
    expect(inventory.dealerName, 'Summit Subaru El Cajon');
  });

  test('propagates client errors', () {
    when(() => client.fetchInventory())
        .thenThrow(const InventoryApiException('boom'));

    expect(
      InventoryRepository(client).getInventory(),
      throwsA(isA<InventoryApiException>()),
    );
  });
}
