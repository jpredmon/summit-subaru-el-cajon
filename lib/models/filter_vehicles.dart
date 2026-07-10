import 'body_category.dart';
import 'vehicle.dart';

/// Active SRP filter selections. A `null` field means "no constraint on this
/// dimension" — distinct from a value that happens to match everything.
class VehicleFilters {
  final String? make;
  final BodyCategory? body;
  final double? minPrice;
  final double? maxPrice;

  const VehicleFilters({this.make, this.body, this.minPrice, this.maxPrice});
}

/// Filters [vehicles] against every active dimension in [filters] (AND, not
/// OR). Vehicles with a `null` price ("Call for price") are excluded
/// whenever *either* price bound is active — a real UX rule, not an
/// incidental gap, since a null price can't be meaningfully compared.
List<Vehicle> filterVehicles(List<Vehicle> vehicles, VehicleFilters filters) {
  return vehicles.where((vehicle) {
    if (filters.make != null && vehicle.make != filters.make) return false;
    if (filters.body != null && vehicle.bodyStyle != filters.body) return false;

    if (filters.minPrice != null || filters.maxPrice != null) {
      final price = vehicle.price;
      if (price == null) return false;
      if (filters.minPrice != null && price < filters.minPrice!) return false;
      if (filters.maxPrice != null && price > filters.maxPrice!) return false;
    }

    return true;
  }).toList();
}

/// Grounded in the real price distribution (see docs/SPEC.md): min $8,994,
/// p25 $17,988, p50 $23,946, p75 $31,888, p90 $44,500, max $159,500. Shared
/// by both the min-price and max-price selects.
const List<double> priceThresholds = [
  10000,
  15000,
  20000,
  25000,
  30000,
  40000,
  50000,
  75000,
  100000,
];

/// Options for the min-price select, pruned so it never offers a value above
/// the currently selected [maxPrice] — the two selects constrain each other.
List<double> minPriceOptions(double? maxPrice) {
  if (maxPrice == null) return priceThresholds;
  return priceThresholds.where((threshold) => threshold <= maxPrice).toList();
}

/// Options for the max-price select, pruned so it never offers a value below
/// the currently selected [minPrice].
List<double> maxPriceOptions(double? minPrice) {
  if (minPrice == null) return priceThresholds;
  return priceThresholds.where((threshold) => threshold >= minPrice).toList();
}

/// The dropdown option sets derivable from the current vehicle list: every
/// distinct make (sorted), and every [BodyCategory] actually present in the
/// data (in the enum's canonical order, not insertion order).
class FilterOptions {
  final List<String> makes;
  final List<BodyCategory> bodyStyles;

  const FilterOptions({required this.makes, required this.bodyStyles});
}

FilterOptions getFilterOptions(List<Vehicle> vehicles) {
  final makes = {for (final v in vehicles) v.make}.toList()..sort();
  final present = {for (final v in vehicles) v.bodyStyle};
  final bodyStyles = BodyCategory.values.where(present.contains).toList();
  return FilterOptions(makes: makes, bodyStyles: bodyStyles);
}
