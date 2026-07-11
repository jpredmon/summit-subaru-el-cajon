import 'vehicle.dart';

/// Finds the vehicle whose `id` matches, or `null` if none does. VDP's local
/// lookup into the SRP's already-cached inventory -- never a second fetch.
Vehicle? findVehicleById(List<Vehicle> vehicles, int id) {
  for (final vehicle in vehicles) {
    if (vehicle.id == id) return vehicle;
  }
  return null;
}
