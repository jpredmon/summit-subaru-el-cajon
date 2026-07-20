import 'dart:convert';

import '../models/dealer_name.dart';
import '../models/raw_vehicle.dart';

/// Raised for any failure fetching or parsing the inventory response —
/// network error, non-200 status, malformed body, or a missing bundled
/// asset. Callers (the Riverpod provider) surface a single error state
/// regardless of cause.
class InventoryApiException implements Exception {
  const InventoryApiException(this.message);

  final String message;

  @override
  String toString() => 'InventoryApiException: $message';
}

/// The parsed inventory result: untransformed records plus the derived
/// dealer name. The repository maps [records] through `transformVehicle`.
class RawInventory {
  const RawInventory({required this.records, required this.dealerName});

  final List<RawVehicle> records;
  final String dealerName;
}

/// Parses a raw inventory response body (`{ "result": RawVehicle[] }`) into
/// a [RawInventory]. Shared by the historical `InventoryApiClient` (live
/// fetch, unwired as of the static-snapshot switch) and
/// `StaticInventoryDataSource` (the current runtime data source), so the
/// response-shape contract lives in exactly one place.
RawInventory parseInventoryResponse(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (error) {
    throw InventoryApiException('Malformed inventory response: ${error.message}');
  }

  if (decoded is! Map<String, dynamic> || decoded['result'] is! List) {
    throw const InventoryApiException('Inventory response missing "result" array');
  }

  try {
    final records = (decoded['result'] as List<dynamic>)
        .map((e) => RawVehicle.fromJson(e as Map<String, dynamic>))
        .toList();
    return RawInventory(records: records, dealerName: getDealerName(records));
  } catch (error) {
    throw InventoryApiException('Malformed inventory record: $error');
  }
}
