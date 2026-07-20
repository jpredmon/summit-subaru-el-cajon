import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'inventory_response_parser.dart';

/// Loads and parses the bundled inventory snapshot
/// (`assets/data/inventory.json`) — the app's sole data source now that
/// live VINCUE API access has been revoked (see
/// docs/superpowers/specs/2026-07-20-static-inventory-snapshot-design.md).
/// Same response contract as the historical `InventoryApiClient`
/// (`{ "result": RawVehicle[] }`), parsed via the same shared
/// [parseInventoryResponse] so the shape lives in one place.
class StaticInventoryDataSource {
  StaticInventoryDataSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// The bundled asset path, declared in pubspec.yaml's `flutter.assets`.
  static const String assetPath = 'assets/data/inventory.json';

  final AssetBundle _bundle;

  Future<RawInventory> loadInventory() async {
    final String body;
    try {
      body = await _bundle.loadString(assetPath);
    } catch (error) {
      throw InventoryApiException('Failed to load bundled inventory asset: $error');
    }
    return parseInventoryResponse(body);
  }
}
