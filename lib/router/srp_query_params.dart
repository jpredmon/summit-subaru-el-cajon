import '../models/body_category.dart';
import '../models/filter_vehicles.dart';
import '../providers/srp_state_provider.dart';

/// Restores [SrpFilterState] from the SRP route's query parameters — the
/// inverse of [srpStateToQueryParams]. Matches the web app's `parseFilters`/
/// `parsePage`: any missing, malformed, or unrecognized value is silently
/// dropped rather than erroring, falling back to "no constraint" (or page 1).
SrpFilterState parseSrpQueryParams(Map<String, String> queryParameters) {
  return SrpFilterState(
    filters: VehicleFilters(
      make: queryParameters['make'],
      body: _parseBodyCategory(queryParameters['body']),
      minPrice: _parseDouble(queryParameters['minPrice']),
      maxPrice: _parseDouble(queryParameters['maxPrice']),
    ),
    page: _parsePage(queryParameters['page']),
  );
}

/// Serializes [state] to query parameters — the inverse of
/// [parseSrpQueryParams]. Matches the web app's `filtersToSearchParams`:
/// only active filter dimensions are included, and `page` is omitted at 1.
Map<String, String> srpStateToQueryParams(SrpFilterState state) {
  final filters = state.filters;
  return {
    if (filters.make != null) 'make': filters.make!,
    if (filters.body != null) 'body': filters.body!.displayName,
    if (filters.minPrice != null) 'minPrice': _formatNumber(filters.minPrice!),
    if (filters.maxPrice != null) 'maxPrice': _formatNumber(filters.maxPrice!),
    if (state.page > 1) 'page': state.page.toString(),
  };
}

BodyCategory? _parseBodyCategory(String? raw) {
  if (raw == null) return null;
  for (final category in BodyCategory.values) {
    if (category.displayName == raw) return category;
  }
  return null;
}

double? _parseDouble(String? raw) {
  if (raw == null) return null;
  return double.tryParse(raw);
}

int _parsePage(String? raw) {
  if (raw == null) return 1;
  final parsed = double.tryParse(raw);
  if (parsed == null || parsed < 1) return 1;
  return parsed.floor();
}

String _formatNumber(double value) {
  return value == value.roundToDouble() ? value.toInt().toString() : value.toString();
}
