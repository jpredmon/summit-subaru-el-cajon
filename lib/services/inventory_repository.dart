import '../models/inventory.dart';
import '../models/transform_vehicle.dart';
import 'static_inventory_data_source.dart';

/// Bridges the [StaticInventoryDataSource] to the domain layer: loads the
/// bundled inventory snapshot and maps its records through
/// `transformVehicle`, yielding the cleaned [Inventory] the UI consumes.
class InventoryRepository {
  InventoryRepository(this._dataSource);

  final StaticInventoryDataSource _dataSource;

  Future<Inventory> getInventory() async {
    final raw = await _dataSource.loadInventory();
    return Inventory(
      vehicles: raw.records.map(transformVehicle).toList(),
      dealerName: raw.dealerName,
    );
  }
}
