import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dealer_name.dart';
import '../models/inventory.dart';
import '../services/inventory_api_client.dart';
import '../services/inventory_repository.dart';

/// Supplies the configured API client. Has no usable default — the base URL
/// and key are build-time inputs — so it must be overridden at the app root
/// (build config, Task 15) and in tests.
final inventoryApiClientProvider = Provider<InventoryApiClient>((ref) {
  throw UnimplementedError(
    'inventoryApiClientProvider must be overridden at the app root (Task 15).',
  );
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(inventoryApiClientProvider));
});

/// The single source of inventory for the session. A [FutureProvider] computes
/// its body once and caches the result, so SRP and VDP share one fetch — never
/// two — keeping well inside the 5000/hr rate limit regardless of navigation.
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
