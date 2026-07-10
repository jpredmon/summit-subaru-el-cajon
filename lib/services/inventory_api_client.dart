import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/dealer_name.dart';
import '../models/raw_vehicle.dart';

/// Raised for any failure fetching or parsing the inventory response —
/// network error, non-200 status, or a malformed body. Callers (the Riverpod
/// provider) surface a single error state regardless of cause.
class InventoryApiException implements Exception {
  const InventoryApiException(this.message);

  final String message;

  @override
  String toString() => 'InventoryApiException: $message';
}

/// The raw fetch result: untransformed records plus the derived dealer name.
/// The repository (Task 5) maps [records] through `transformVehicle`.
class RawInventory {
  const RawInventory({required this.records, required this.dealerName});

  final List<RawVehicle> records;
  final String dealerName;
}

/// Fetches and parses the VINCUE inventory response. One client serves both
/// build targets via a fully-resolved [baseUrl] and an [attachApiKeyHeader]
/// flag — no `--dart-define` reads or path/dealerID construction happen here
/// (that lives in build config, Task 15).
class InventoryApiClient {
  InventoryApiClient({
    required this.baseUrl,
    required this.attachApiKeyHeader,
    this.apiKey,
    http.Client? httpClient,
  })  : assert(
          !attachApiKeyHeader || apiKey != null,
          'apiKey is required when attachApiKeyHeader is true',
        ),
        _http = httpClient ?? http.Client();

  /// Fully-resolved inventory endpoint URL, GET verbatim. Differs per build
  /// (Vercel proxy on web, direct VINCUE URL on native).
  final String baseUrl;

  /// Whether to send the `x-api-key` header client-side (native build only;
  /// the proxy build attaches no key).
  final bool attachApiKeyHeader;

  final String? apiKey;
  final http.Client _http;

  Future<RawInventory> fetchInventory() async {
    final http.Response response;
    try {
      response = await _http.get(Uri.parse(baseUrl), headers: _headers());
    } catch (error) {
      throw InventoryApiException('Failed to reach inventory API: $error');
    }

    if (response.statusCode != 200) {
      throw InventoryApiException(
        'Inventory request failed: ${response.statusCode}',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      throw InventoryApiException('Malformed inventory response: ${error.message}');
    }

    if (decoded is! Map<String, dynamic> || decoded['result'] is! List) {
      throw const InventoryApiException(
        'Inventory response missing "result" array',
      );
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

  Map<String, String> _headers() {
    final key = apiKey;
    if (attachApiKeyHeader && key != null) {
      return {'x-api-key': key};
    }
    return const {};
  }
}
