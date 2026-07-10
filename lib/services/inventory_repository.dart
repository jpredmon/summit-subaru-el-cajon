import '../models/inventory.dart';
import '../models/transform_vehicle.dart';
import 'inventory_api_client.dart';

/// Bridges the raw [InventoryApiClient] to the domain layer: fetches the raw
/// records and maps them through `transformVehicle`, yielding the cleaned
/// [Inventory] the UI consumes.
class InventoryRepository {
  InventoryRepository(this._client);

  final InventoryApiClient _client;

  Future<Inventory> getInventory() async {
    final raw = await _client.fetchInventory();
    return Inventory(
      vehicles: raw.records.map(transformVehicle).toList(),
      dealerName: raw.dealerName,
    );
  }
}
