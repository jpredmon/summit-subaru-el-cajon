import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vincue_mobile/models/dealer_name.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/services/inventory_api_client.dart';

import '../support/raw_vehicle_factory.dart';

class _MockClient extends Mock implements InventoryApiClient {}

void main() {
  late _MockClient client;

  setUp(() => client = _MockClient());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [inventoryApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('fetches once per session even when read multiple times', () async {
    when(() => client.fetchInventory()).thenAnswer(
      (_) async => RawInventory(records: [rawVehicle()], dealerName: 'Dealer'),
    );

    final c = container();
    await c.read(inventoryProvider.future);
    await c.read(inventoryProvider.future);
    c.read(inventoryProvider);

    verify(() => client.fetchInventory()).called(1);
  });

  test('exposes transformed vehicles and the dealer name', () async {
    when(() => client.fetchInventory()).thenAnswer(
      (_) async => RawInventory(
        records: [rawVehicle(sellingPrice: '0.00'), rawVehicle(sellingPrice: '25000.00')],
        dealerName: 'Summit Subaru El Cajon',
      ),
    );

    final inventory = await container().read(inventoryProvider.future);

    expect(inventory.vehicles, hasLength(2));
    expect(inventory.vehicles.first.price, isNull);
    expect(inventory.dealerName, 'Summit Subaru El Cajon');
  });

  test('propagates a client error through the provider', () async {
    when(() => client.fetchInventory())
        .thenAnswer((_) => Future.error(const InventoryApiException('boom')));

    final c = container();
    // Keep the provider alive and drain the async work before asserting.
    c.listen(inventoryProvider, (_, _) {}, onError: (_, _) {});
    await pumpEventQueue();

    final state = c.read(inventoryProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<InventoryApiException>());
  });

  group('dealerNameProvider', () {
    test('returns the fallback while inventory is still loading', () {
      final pending = Completer<RawInventory>();
      when(() => client.fetchInventory()).thenAnswer((_) => pending.future);

      expect(container().read(dealerNameProvider), kFallbackDealerName);
    });

    test('returns the loaded dealer name once available', () async {
      when(() => client.fetchInventory()).thenAnswer(
        (_) async => RawInventory(
          records: [rawVehicle()],
          dealerName: 'Summit Subaru El Cajon',
        ),
      );

      final c = container();
      await c.read(inventoryProvider.future);

      expect(c.read(dealerNameProvider), 'Summit Subaru El Cajon');
    });
  });
}
