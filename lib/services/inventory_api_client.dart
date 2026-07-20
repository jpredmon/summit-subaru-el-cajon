import 'package:http/http.dart' as http;

import 'inventory_response_parser.dart';

/// Fetches and parses the VINCUE inventory response. Historical as of the
/// static-inventory-snapshot switch (see
/// docs/superpowers/specs/2026-07-20-static-inventory-snapshot-design.md):
/// no longer imported by anything the running app uses, but preserved and
/// tested unchanged as documented history of the original live-fetch/
/// proxy/CORS-workaround architecture. One client served both build
/// targets via a fully-resolved [baseUrl] and an [attachApiKeyHeader] flag.
class InventoryApiClient {
  InventoryApiClient({
    required this.baseUrl,
    required this.attachApiKeyHeader,
    this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client() {
    // A real runtime check, not `assert` -- asserts are stripped in
    // release/profile builds, which would let a misconfigured native build
    // silently send unauthenticated requests instead of failing loudly at
    // construction.
    if (attachApiKeyHeader && apiKey == null) {
      throw ArgumentError.value(apiKey, 'apiKey', 'is required when attachApiKeyHeader is true');
    }
  }

  /// Fully-resolved inventory endpoint URL, GET verbatim. Differed per
  /// build (Vercel proxy on web, direct VINCUE URL on native).
  final String baseUrl;

  /// Whether to send the `x-api-key` header client-side (native build
  /// only; the proxy build attached no key).
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
      throw InventoryApiException('Inventory request failed: ${response.statusCode}');
    }

    return parseInventoryResponse(response.body);
  }

  Map<String, String> _headers() {
    final key = apiKey;
    if (attachApiKeyHeader && key != null) {
      return {'x-api-key': key};
    }
    return const {};
  }
}
