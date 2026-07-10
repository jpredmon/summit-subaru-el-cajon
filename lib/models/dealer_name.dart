import 'raw_vehicle.dart';

/// Shown when the response carries no usable dealer name. VINCUE is the
/// platform vendor, not the dealership, so a generic label is used rather than
/// anything hardcoded.
const String kFallbackDealerName = 'Vehicle Inventory';

/// Derives the dealer name from the inventory response — the first record's
/// name (consistent across all records for a single dealer), trimmed, falling
/// back to [kFallbackDealerName] when empty or absent.
String getDealerName(List<RawVehicle> records) {
  if (records.isEmpty) return kFallbackDealerName;
  final name = records.first.dealerName.trim();
  return name.isNotEmpty ? name : kFallbackDealerName;
}
