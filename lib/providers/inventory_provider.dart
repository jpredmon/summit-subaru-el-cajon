import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dealer_name.dart';
import '../models/filter_vehicles.dart';
import '../models/inventory.dart';
import '../services/inventory_repository.dart';
import '../services/static_inventory_data_source.dart';

/// The bundled-asset inventory data source. Unlike the historical
/// `inventoryApiClientProvider` it replaces, this has a real default and
/// needs no app-root override — there's no build-time configuration left
/// (see docs/superpowers/specs/2026-07-20-static-inventory-snapshot-design.md).
final staticInventoryDataSourceProvider = Provider<StaticInventoryDataSource>((ref) {
  return StaticInventoryDataSource();
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(staticInventoryDataSourceProvider));
});

/// The single source of inventory for the session. A [FutureProvider] computes
/// its body once and caches the result, so SRP and VDP share one fetch — never
/// two.
final inventoryProvider = FutureProvider<Inventory>((ref) {
  return ref.watch(inventoryRepositoryProvider).getInventory();
});

/// The loaded dealer name, or the generic fallback while loading or on error.
/// Derived once here (mirrors the web app's `useDealerName()`) so callers never
/// re-derive `data?.dealerName ?? fallback` by hand.
final dealerNameProvider = Provider<String>((ref) {
  // AsyncValue.value is null (not a rethrow) during loading and on error, so
  // this yields the fallback until real data arrives. requireValue would throw.
  return ref.watch(inventoryProvider).value?.dealerName ?? kFallbackDealerName;
});

/// The SRP filter dropdowns' option sets, derived once per inventory load.
/// Watching only [inventoryProvider] (not `srpStateProvider`) means Riverpod
/// caches this and skips recomputing `getFilterOptions`'s two O(n) passes on
/// every filter/page change -- it only ever depends on which vehicles are
/// loaded, never on the active filter/page selection.
final filterOptionsProvider = Provider<FilterOptions>((ref) {
  final vehicles = ref.watch(inventoryProvider).value?.vehicles ?? const [];
  return getFilterOptions(vehicles);
});
