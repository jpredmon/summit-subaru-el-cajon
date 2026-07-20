import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vincue_mobile/models/dealer_name.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/services/inventory_response_parser.dart';
import 'package:vincue_mobile/services/static_inventory_data_source.dart';

import '../support/raw_vehicle_factory.dart';

class _MockDataSource extends Mock implements StaticInventoryDataSource {}

void main() {
  late _MockDataSource dataSource;

  setUp(() => dataSource = _MockDataSource());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [staticInventoryDataSourceProvider.overrideWithValue(dataSource)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('fetches once per session even when read multiple times', () async {
    when(() => dataSource.loadInventory()).thenAnswer(
      (_) async => RawInventory(records: [rawVehicle()], dealerName: 'Dealer'),
    );

    final c = container();
    await c.read(inventoryProvider.future);
    await c.read(inventoryProvider.future);
    c.read(inventoryProvider);

    verify(() => dataSource.loadInventory()).called(1);
  });

  test('exposes transformed vehicles and the dealer name', () async {
    when(() => dataSource.loadInventory()).thenAnswer(
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

  test('propagates a data source error through the provider', () async {
    when(() => dataSource.loadInventory())
        .thenAnswer((_) => Future.error(const InventoryApiException('boom')));

    final c = container();
    c.listen(inventoryProvider, (_, _) {}, onError: (_, _) {});
    await pumpEventQueue();

    final state = c.read(inventoryProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<InventoryApiException>());
  });

  group('dealerNameProvider', () {
    test('returns the fallback while inventory is still loading', () {
      final pending = Completer<RawInventory>();
      when(() => dataSource.loadInventory()).thenAnswer((_) => pending.future);

      expect(container().read(dealerNameProvider), kFallbackDealerName);
    });

    test('returns the loaded dealer name once available', () async {
      when(() => dataSource.loadInventory()).thenAnswer(
        (_) async => RawInventory(records: [rawVehicle()], dealerName: 'Summit Subaru El Cajon'),
      );

      final c = container();
      await c.read(inventoryProvider.future);

      expect(c.read(dealerNameProvider), 'Summit Subaru El Cajon');
    });
  });
}
