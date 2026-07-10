import 'vehicle.dart';

/// The session's inventory: transformed vehicles plus the derived dealer name.
/// Same shape as the web app's `useInventory()` return — SRP and VDP both read
/// from this one cached value.
class Inventory {
  const Inventory({required this.vehicles, required this.dealerName});

  final List<Vehicle> vehicles;
  final String dealerName;
}
