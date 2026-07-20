# Static Inventory Snapshot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the live VINCUE API fetch with the already-captured `assets/data/inventory.json` snapshot as the app's sole runtime data source, on both build targets, while preserving the live-fetch/proxy/CORS-workaround code and story as documented, unwired history.

**Architecture:** Extract the existing JSON-decode/validate/map logic out of `InventoryApiClient` into a shared pure function. Add a small `StaticInventoryDataSource` that loads the bundled asset and calls that same shared function. Repoint `InventoryRepository` and the Riverpod provider graph at the new data source. Leave `InventoryApiClient` and `config.dart` fully intact and tested, just no longer imported by anything the running app actually uses.

**Tech Stack:** Flutter/Dart, Riverpod, `flutter_test` + `mocktail` (existing project stack — no new dependencies).

## Global Constraints

- Per this project's `CLAUDE.md`: TDD, no exceptions — write the failing test first, confirm it fails for the expected reason, then implement.
- After each task's tests pass, write a confidence score (1–100) grounded in what happened during implementation, then run the two-stage review (spec compliance, code quality) before committing. Max 3 iteration passes if confidence is below 90; stop and ask if still below 90 after that.
- One commit per task, message states what the task implemented and its confidence score. A confidence-driven follow-up fix after the initial commit is a separate commit.
- Any task that introduces a concept not yet used in this project (here: `AssetBundle`/`rootBundle` for a bundled *data* asset, as opposed to the images already bundled) gets a "New concept" note appended to `docs/LEARNING.md`.
- Source spec: `docs/superpowers/specs/2026-07-20-static-inventory-snapshot-design.md`.
- The raw snapshot is already captured on disk at `assets/data/inventory.json` (143 records, captured 2026-07-20, verified `{ "result": [...] }` shape) — no task needs to re-fetch it; Task 2 is what commits it.

---

### Task 1: Extract the shared response parser out of `InventoryApiClient`

**Files:**
- Create: `lib/services/inventory_response_parser.dart`
- Create: `test/services/inventory_response_parser_test.dart`
- Modify: `lib/services/inventory_api_client.dart`
- Test (regression, unmodified): `test/services/inventory_api_client_test.dart`

**Interfaces:**
- Produces: `class InventoryApiException implements Exception` (`.message`, `.toString()`), `class RawInventory` (`.records` → `List<RawVehicle>`, `.dealerName` → `String`), `RawInventory parseInventoryResponse(String body)` — all in `lib/services/inventory_response_parser.dart`. Later tasks (2, 3, 4) import `RawInventory`/`InventoryApiException` from this file, not from `inventory_api_client.dart`.

- [ ] **Step 1: Write the failing test**

Create `test/services/inventory_response_parser_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/services/inventory_response_parser.dart';

Map<String, dynamic> _rawJson({String dealerName = 'Summit Subaru El Cajon'}) => {
      'inventoryID': 1,
      'vin': 'V',
      'stock': 'S',
      'newUsed': 'U',
      'year': '2020',
      'make': 'Make',
      'model': 'Model',
      'trim': 'Trim',
      'body': 'Sedan',
      'transmission': 'Automatic',
      'engine': 'V6',
      'drivetrain': 'FWD',
      'extColor': 'Black',
      'intColor': 'Gray',
      'miles': '1000',
      'sellingPrice': '20000.00',
      'certified': 'N',
      'mpgCity': '25',
      'mpgHwy': '30',
      'vehiclePhotos': <String>[],
      'photoCount': 0,
      'features': <String>['A'],
      'description': 'x',
      'vdpUrl': null,
      'dealerName': dealerName,
    };

String _okBody({String dealerName = 'Summit Subaru El Cajon', int count = 1}) => jsonEncode({
      'result': [for (var i = 0; i < count; i++) _rawJson(dealerName: dealerName)],
    });

void main() {
  group('parseInventoryResponse', () {
    test('parses the result array and surfaces the dealer name', () {
      final result = parseInventoryResponse(_okBody(count: 2));
      expect(result.records, hasLength(2));
      expect(result.records.first.make, 'Make');
      expect(result.dealerName, 'Summit Subaru El Cajon');
    });

    test('throws on a body that is not valid JSON', () {
      expect(() => parseInventoryResponse('not json'), throwsA(isA<InventoryApiException>()));
    });

    test('throws when the result key is missing or not a list', () {
      expect(
        () => parseInventoryResponse(jsonEncode({'notResult': 1})),
        throwsA(isA<InventoryApiException>()),
      );
    });

    test('throws when a record is missing a required field', () {
      final malformed = jsonEncode({
        'result': [
          {'inventoryID': 1},
        ],
      });
      expect(() => parseInventoryResponse(malformed), throwsA(isA<InventoryApiException>()));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/inventory_response_parser_test.dart`
Expected: FAIL — compile error, `Target of URI doesn't exist: 'package:vincue_mobile/services/inventory_response_parser.dart'` (the file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `lib/services/inventory_response_parser.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/inventory_response_parser_test.dart`
Expected: PASS (4/4).

- [ ] **Step 5: Refactor `InventoryApiClient` to delegate to the shared parser**

Modify `lib/services/inventory_api_client.dart` — replace the whole file with:

```dart
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
```

- [ ] **Step 6: Run the full existing client test suite to confirm no regression**

Run: `flutter test test/services/inventory_api_client_test.dart test/services/inventory_response_parser_test.dart`
Expected: PASS, all tests (the existing `inventory_api_client_test.dart` file is unmodified — this proves the refactor didn't change `InventoryApiClient`'s observable behavior).

- [ ] **Step 7: Confidence score, dual review (per CLAUDE.md), then commit**

```bash
git add lib/services/inventory_response_parser.dart lib/services/inventory_api_client.dart test/services/inventory_response_parser_test.dart
git commit -m "refactor: extract shared inventory response parser from InventoryApiClient"
```

---

### Task 2: Add `StaticInventoryDataSource` and register the snapshot asset

**Files:**
- Create: `lib/services/static_inventory_data_source.dart`
- Create: `test/services/static_inventory_data_source_test.dart`
- Modify: `pubspec.yaml`
- Commit (already on disk, not yet tracked): `assets/data/inventory.json`

**Interfaces:**
- Consumes: `RawInventory`, `InventoryApiException`, `parseInventoryResponse` from `lib/services/inventory_response_parser.dart` (Task 1).
- Produces: `class StaticInventoryDataSource` with `StaticInventoryDataSource({AssetBundle? bundle})` (not `const` — `rootBundle` is a getter, not a compile-time constant, so it can't appear in a const initializer; matches `InventoryApiClient`'s existing non-const `httpClient ?? http.Client()` pattern), `static const String assetPath`, and `Future<RawInventory> loadInventory()`. Task 3 constructs `InventoryRepository` with an instance of this.

- [ ] **Step 1: Write the failing test**

Create `test/services/static_inventory_data_source_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vincue_mobile/services/inventory_response_parser.dart';
import 'package:vincue_mobile/services/static_inventory_data_source.dart';

class _MockAssetBundle extends Mock implements AssetBundle {}

Map<String, dynamic> _rawJson({String dealerName = 'Summit Subaru El Cajon'}) => {
      'inventoryID': 1,
      'vin': 'V',
      'stock': 'S',
      'newUsed': 'U',
      'year': '2020',
      'make': 'Make',
      'model': 'Model',
      'trim': 'Trim',
      'body': 'Sedan',
      'transmission': 'Automatic',
      'engine': 'V6',
      'drivetrain': 'FWD',
      'extColor': 'Black',
      'intColor': 'Gray',
      'miles': '1000',
      'sellingPrice': '20000.00',
      'certified': 'N',
      'mpgCity': '25',
      'mpgHwy': '30',
      'vehiclePhotos': <String>[],
      'photoCount': 0,
      'features': <String>['A'],
      'description': 'x',
      'vdpUrl': null,
      'dealerName': dealerName,
    };

String _okBody({String dealerName = 'Summit Subaru El Cajon', int count = 1}) => jsonEncode({
      'result': [for (var i = 0; i < count; i++) _rawJson(dealerName: dealerName)],
    });

void main() {
  late _MockAssetBundle bundle;

  setUp(() => bundle = _MockAssetBundle());

  group('loadInventory', () {
    test('loads the configured asset path and parses it via the shared parser', () async {
      when(() => bundle.loadString(any())).thenAnswer((_) async => _okBody(count: 2));

      final result = await StaticInventoryDataSource(bundle: bundle).loadInventory();

      verify(() => bundle.loadString(StaticInventoryDataSource.assetPath)).called(1);
      expect(result.records, hasLength(2));
      expect(result.dealerName, 'Summit Subaru El Cajon');
    });

    test('throws InventoryApiException when the asset fails to load', () {
      when(() => bundle.loadString(any())).thenThrow(Exception('asset not found'));

      expect(
        StaticInventoryDataSource(bundle: bundle).loadInventory(),
        throwsA(isA<InventoryApiException>()),
      );
    });
  });

  group('real bundled asset', () {
    test('loads and parses the actual assets/data/inventory.json', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final result = await StaticInventoryDataSource().loadInventory();

      expect(result.records, isNotEmpty);
      expect(result.dealerName, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/static_inventory_data_source_test.dart`
Expected: FAIL — compile error, `static_inventory_data_source.dart` doesn't exist.

- [ ] **Step 3: Write the implementation**

Create `lib/services/static_inventory_data_source.dart`:

```dart
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
```

- [ ] **Step 4: Run test — expect the two mocked-bundle tests to pass and the real-asset test to fail**

Run: `flutter test test/services/static_inventory_data_source_test.dart`
Expected: 2 PASS (`loadInventory` group), 1 FAIL (`real bundled asset` group) — the asset isn't registered in `pubspec.yaml` yet, so `rootBundle.loadString` throws an asset-not-found error. This confirms the next step is necessary.

- [ ] **Step 5: Register the asset in `pubspec.yaml`**

In `pubspec.yaml`, under the `flutter:` → `assets:` key (currently only listing the logo), add the snapshot:

```yaml
  assets:
    - assets/images/summit_subaru_logo.png
    - assets/data/inventory.json
```

- [ ] **Step 6: Run `flutter pub get`, then re-run the test**

Run: `flutter pub get`
Run: `flutter test test/services/static_inventory_data_source_test.dart`
Expected: PASS (3/3).

- [ ] **Step 7: New concept — `docs/LEARNING.md` entry**

Add a dated entry: bundled *data* assets (not just images) are loaded the same way as images — declared in `pubspec.yaml`'s `flutter.assets` list, read via `AssetBundle`/`rootBundle.loadString()` at runtime. `rootBundle` is the app's real bundle; tests inject a fake `AssetBundle` (mocktail) for unit tests, or call `TestWidgetsFlutterBinding.ensureInitialized()` to exercise the real one against the real packaged file.

- [ ] **Step 8: Confidence score, dual review (per CLAUDE.md), then commit**

```bash
git add lib/services/static_inventory_data_source.dart test/services/static_inventory_data_source_test.dart pubspec.yaml assets/data/inventory.json docs/LEARNING.md
git commit -m "feat: add StaticInventoryDataSource loading the bundled inventory snapshot"
```

---

### Task 3: Repurpose `InventoryRepository` to use `StaticInventoryDataSource`

**Files:**
- Modify: `lib/services/inventory_repository.dart`
- Modify: `test/services/inventory_repository_test.dart`

**Interfaces:**
- Consumes: `StaticInventoryDataSource.loadInventory()` (Task 2), `RawInventory`/`InventoryApiException` (Task 1).
- Produces: `InventoryRepository(StaticInventoryDataSource dataSource)` constructor (was `InventoryRepository(InventoryApiClient client)`), same `Future<Inventory> getInventory()` public contract. Task 4's provider depends on this constructor signature.

- [ ] **Step 1: Rewrite the test to the new constructor (this is the RED step)**

Replace `test/services/inventory_repository_test.dart` entirely with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vincue_mobile/services/inventory_repository.dart';
import 'package:vincue_mobile/services/inventory_response_parser.dart';
import 'package:vincue_mobile/services/static_inventory_data_source.dart';

import '../support/raw_vehicle_factory.dart';

class _MockDataSource extends Mock implements StaticInventoryDataSource {}

void main() {
  late _MockDataSource dataSource;

  setUp(() => dataSource = _MockDataSource());

  test('maps raw records through the transform and passes dealerName', () async {
    when(() => dataSource.loadInventory()).thenAnswer(
      (_) async => RawInventory(
        records: [
          rawVehicle(sellingPrice: '0.00'), // -> price null via transform
          rawVehicle(sellingPrice: '25000.00'),
        ],
        dealerName: 'Summit Subaru El Cajon',
      ),
    );

    final inventory = await InventoryRepository(dataSource).getInventory();

    expect(inventory.vehicles, hasLength(2));
    expect(inventory.vehicles.first.price, isNull);
    expect(inventory.vehicles[1].price, 25000.0);
    expect(inventory.dealerName, 'Summit Subaru El Cajon');
  });

  test('propagates data source errors', () {
    when(() => dataSource.loadInventory()).thenThrow(const InventoryApiException('boom'));

    expect(
      InventoryRepository(dataSource).getInventory(),
      throwsA(isA<InventoryApiException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/inventory_repository_test.dart`
Expected: FAIL — compile error, `InventoryRepository(dataSource)` doesn't match the current constructor's `InventoryApiClient` parameter type.

- [ ] **Step 3: Write the implementation**

Replace `lib/services/inventory_repository.dart` entirely with:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/inventory_repository_test.dart`
Expected: PASS (2/2).

- [ ] **Step 5: Confidence score, dual review (per CLAUDE.md), then commit**

```bash
git add lib/services/inventory_repository.dart test/services/inventory_repository_test.dart
git commit -m "feat: repoint InventoryRepository at StaticInventoryDataSource"
```

---

### Task 4: Rewire providers and `main.dart`; retire the build-time API config wiring

**Files:**
- Modify: `lib/providers/inventory_provider.dart`
- Modify: `lib/main.dart`
- Modify: `test/providers/inventory_provider_test.dart`
- Modify: `test/config_test.dart`

**Interfaces:**
- Consumes: `InventoryRepository(StaticInventoryDataSource)` (Task 3), `StaticInventoryDataSource` (Task 2).
- Produces: `staticInventoryDataSourceProvider` (replaces `inventoryApiClientProvider`, which is deleted — nothing else in the app references it after this task). `inventoryRepositoryProvider`, `inventoryProvider`, `dealerNameProvider`, `filterOptionsProvider` keep their existing names/types unchanged, so no screen/widget code needs to change.

- [ ] **Step 1: Rewrite the provider test to the new provider (RED step)**

Replace `test/providers/inventory_provider_test.dart` entirely with:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vincue_mobile/models/dealer_name.dart';
import 'package:vincue_mobile/providers/inventory_provider.dart';
import 'package:vincue_mobile/services/inventory_response_parser.dart';
import 'package:vincue_mobile/services/static_inventory_data_source.dart';

import '../support/raw_vehicle_factory.dart';

class _MockDataSource extends Mock implements StaticInventoryDataSource {}

void main() {
  late _MockDataSource dataSource;

  setUp(() => dataSource = _MockDataSource());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [staticInventoryDataSourceProvider.overrideWithValue(dataSource)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('fetches once per session even when read multiple times', () async {
    when(() => dataSource.loadInventory()).thenAnswer(
      (_) async => RawInventory(records: [rawVehicle()], dealerName: 'Dealer'),
    );

    final c = container();
    await c.read(inventoryProvider.future);
    await c.read(inventoryProvider.future);
    c.read(inventoryProvider);

    verify(() => dataSource.loadInventory()).called(1);
  });

  test('exposes transformed vehicles and the dealer name', () async {
    when(() => dataSource.loadInventory()).thenAnswer(
      (_) async => RawInventory(
        records: [rawVehicle(sellingPrice: '0.00'), rawVehicle(sellingPrice: '25000.00')],
        dealerName: 'Summit Subaru El Cajon',
      ),
    );

    final inventory = await container().read(inventoryProvider.future);

    expect(inventory.vehicles, hasLength(2));
    expect(inventory.vehicles.first.price, isNull);
    expect(inventory.dealerName, 'Summit Subaru El Cajon');
  });

  test('propagates a data source error through the provider', () async {
    when(() => dataSource.loadInventory())
        .thenAnswer((_) => Future.error(const InventoryApiException('boom')));

    final c = container();
    c.listen(inventoryProvider, (_, _) {}, onError: (_, _) {});
    await pumpEventQueue();

    final state = c.read(inventoryProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<InventoryApiException>());
  });

  group('dealerNameProvider', () {
    test('returns the fallback while inventory is still loading', () {
      final pending = Completer<RawInventory>();
      when(() => dataSource.loadInventory()).thenAnswer((_) => pending.future);

      expect(container().read(dealerNameProvider), kFallbackDealerName);
    });

    test('returns the loaded dealer name once available', () async {
      when(() => dataSource.loadInventory()).thenAnswer(
        (_) async => RawInventory(records: [rawVehicle()], dealerName: 'Summit Subaru El Cajon'),
      );

      final c = container();
      await c.read(inventoryProvider.future);

      expect(c.read(dealerNameProvider), 'Summit Subaru El Cajon');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/inventory_provider_test.dart`
Expected: FAIL — compile error, `staticInventoryDataSourceProvider` is undefined.

- [ ] **Step 3: Write the provider implementation**

Replace `lib/providers/inventory_provider.dart` entirely with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dealer_name.dart';
import '../models/filter_vehicles.dart';
import '../models/inventory.dart';
import '../services/inventory_repository.dart';
import '../services/static_inventory_data_source.dart';

/// The bundled-asset inventory data source. Unlike the historical
/// `inventoryApiClientProvider` it replaces, this has a real default and
/// needs no app-root override — there's no build-time configuration left
/// (see docs/superpowers/specs/2026-07-20-static-inventory-snapshot-design.md).
final staticInventoryDataSourceProvider = Provider<StaticInventoryDataSource>((ref) {
  return StaticInventoryDataSource();
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(staticInventoryDataSourceProvider));
});

/// The single source of inventory for the session. A [FutureProvider] computes
/// its body once and caches the result, so SRP and VDP share one fetch — never
/// two.
final inventoryProvider = FutureProvider<Inventory>((ref) {
  return ref.watch(inventoryRepositoryProvider).getInventory();
});

/// The loaded dealer name, or the generic fallback while loading or on error.
/// Derived once here (mirrors the web app's `useDealerName()`) so callers never
/// re-derive `data?.dealerName ?? fallback` by hand.
final dealerNameProvider = Provider<String>((ref) {
  // AsyncValue.value is null (not a rethrow) during loading and on error, so
  // this yields the fallback until real data arrives. requireValue would throw.
  return ref.watch(inventoryProvider).value?.dealerName ?? kFallbackDealerName;
});

/// The SRP filter dropdowns' option sets, derived once per inventory load.
/// Watching only [inventoryProvider] (not `srpStateProvider`) means Riverpod
/// caches this and skips recomputing `getFilterOptions`'s two O(n) passes on
/// every filter/page change -- it only ever depends on which vehicles are
/// loaded, never on the active filter/page selection.
final filterOptionsProvider = Provider<FilterOptions>((ref) {
  final vehicles = ref.watch(inventoryProvider).value?.vehicles ?? const [];
  return getFilterOptions(vehicles);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/inventory_provider_test.dart`
Expected: PASS (5/5).

- [ ] **Step 5: Simplify `main.dart`**

Replace `lib/main.dart` entirely with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/theme_mode_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

// SharedPreferences is awaited here (once) so themeModeProvider's build()
// runs synchronously off an already-resolved instance -- ThemeMode is
// correct on the very first frame, no flash-of-wrong-theme workaround needed.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VincueMobileApp(),
    ),
  );
}

class VincueMobileApp extends ConsumerWidget {
  const VincueMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'VINCUE Inventory',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Deliberate branding decision (docs/superpowers/specs, dark-mode-
      // disabled note): forced light-only for now -- the header logo's
      // palette doesn't read well against the dark theme yet, and no time
      // budgeted to also tune dark-mode contrast for it. Deliberately NOT
      // ref.watch(themeModeProvider) -- that provider (and ThemeModeNotifier,
      // and its shared_preferences persistence) is kept fully working and
      // untouched, just not wired to this app's actual theme, so re-enabling
      // dark mode later is a one-line change back to
      // ref.watch(themeModeProvider), not a rebuild of the mechanism.
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
```

(This drops the `dart:foundation` `kIsWeb` import, the `config.dart` import, the `_apiBaseUrl`/`_apiKey` consts, and the `inventoryApiClientProvider.overrideWith(...)` override — none are needed anymore.)

- [ ] **Step 6: Fix `test/config_test.dart` — remove the now-invalid provider-integration tests**

`config_test.dart` currently has two tests that override and read `inventoryApiClientProvider` (deleted in Step 3) through `inventoryProvider` to prove the throwing-placeholder pattern degrades gracefully. That pattern no longer exists in the app, so those two tests describe behavior that's gone. The remaining tests (`buildInventoryApiClient` and `resolveApiBuildConfig` groups) test pure functions in `config.dart` that are untouched and still valid as documented history.

Replace `test/config_test.dart` entirely with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vincue_mobile/config.dart';

void main() {
  group('buildInventoryApiClient', () {
    test(
      'throws UnimplementedError when API_BASE_URL is not supplied (unconfigured build) -- '
      'must throw lazily (only when called), not eagerly at app bootstrap, so Riverpod\'s '
      'FutureProvider machinery can catch it and surface a graceful in-app error instead of '
      'crashing before any UI renders',
      () {
        expect(
          () => buildInventoryApiClient(isWeb: true, apiBaseUrl: '', apiKey: ''),
          throwsUnimplementedError,
        );
      },
    );

    test('throws UnimplementedError when API_BASE_URL is whitespace-only', () {
      expect(
        () => buildInventoryApiClient(isWeb: true, apiBaseUrl: '   ', apiKey: ''),
        throwsUnimplementedError,
      );
    });

    test(
      'propagates InventoryApiClient\'s own ArgumentError for a native build missing its key '
      '-- a real misconfiguration, not "unconfigured", so it must fail loudly and specifically '
      'rather than being swallowed into the generic "unconfigured" message',
      () {
        expect(
          () => buildInventoryApiClient(
            isWeb: false,
            apiBaseUrl: 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222',
            apiKey: '',
          ),
          throwsArgumentError,
        );
      },
    );

    test('builds a working web client (no api key header) when configured', () {
      final client = buildInventoryApiClient(
        isWeb: true,
        apiBaseUrl: 'https://vincue-mobile-proxy.example.vercel.app/api/inventory',
        apiKey: '',
      );

      expect(client.baseUrl, 'https://vincue-mobile-proxy.example.vercel.app/api/inventory');
      expect(client.attachApiKeyHeader, isFalse);
    });

    test('builds a working native client (with api key header) when configured', () {
      final client = buildInventoryApiClient(
        isWeb: false,
        apiBaseUrl: 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222',
        apiKey: 'secret-key-123',
      );

      expect(client.baseUrl, 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222');
      expect(client.attachApiKeyHeader, isTrue);
      expect(client.apiKey, 'secret-key-123');
    });
  });

  group('resolveApiBuildConfig', () {
    test('web build: does not attach the api key header, regardless of a supplied key', () {
      final config = resolveApiBuildConfig(
        isWeb: true,
        apiBaseUrl: 'https://vincue-mobile-proxy.example.vercel.app/api/inventory',
        apiKey: '',
      );

      expect(config.baseUrl, 'https://vincue-mobile-proxy.example.vercel.app/api/inventory');
      expect(config.attachApiKeyHeader, isFalse);
      expect(config.apiKey, isNull);
    });

    test('native build: attaches the api key header and carries the supplied key through', () {
      final config = resolveApiBuildConfig(
        isWeb: false,
        apiBaseUrl: 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222',
        apiKey: 'secret-key-123',
      );

      expect(config.baseUrl, 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222');
      expect(config.attachApiKeyHeader, isTrue);
      expect(config.apiKey, 'secret-key-123');
    });

    test('normalizes an empty (unsupplied) api key define to null rather than an empty string', () {
      final config = resolveApiBuildConfig(
        isWeb: false,
        apiBaseUrl: 'https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222',
        apiKey: '',
      );

      expect(config.apiKey, isNull);
    });
  });
}
```

- [ ] **Step 7: Run the full test suite to confirm no leftover references anywhere**

Run: `flutter test`
Expected: PASS, no compile errors, no failures. (This is the cross-cutting regression check — `inventoryApiClientProvider` and `InventoryApiClient` were referenced only in the four files touched across Tasks 1–4, confirmed by an earlier grep across `test/`, but this full run is the actual proof.)

Run: `flutter analyze`
Expected: no issues (confirms no unused imports left behind in `main.dart`/`inventory_provider.dart`).

- [ ] **Step 8: Confidence score, dual review (per CLAUDE.md), then commit**

```bash
git add lib/providers/inventory_provider.dart lib/main.dart test/providers/inventory_provider_test.dart test/config_test.dart
git commit -m "feat: wire providers and main.dart to the static inventory data source"
```

---

### Task 5: Documentation and deploy-script cleanup

**Files:**
- Modify: `docs/SPEC.md`
- Modify: `README.md`
- Modify: `package.json`

No tests — doc/config-only task. Still gets a confidence score (spec-compliance focus: does the doc accurately describe what Tasks 1–4 actually built) and both review stages before commit, per `CLAUDE.md`.

- [ ] **Step 1: Add the deviation note to `docs/SPEC.md`**

In `docs/SPEC.md`, insert a new subsection immediately after the existing "API access strategy" subsection's last bullet (after the paragraph ending `...rather than hardcoded in the client.`, and before the `## Data model` heading):

```markdown

### Data source (deviation, 2026-07-20)

VINCUE revoked live API access for this project. With permission from the
hiring contact's director to continue using this build as a practice/
portfolio project, the live fetch described above was replaced by a
one-time captured snapshot: `assets/data/inventory.json` (143 records,
captured 2026-07-20), loaded via a bundled-asset data source
(`StaticInventoryDataSource`) instead of `InventoryApiClient`'s HTTP GET.
This is the *only* runtime data source on both build targets now.

The live-fetch architecture described above — the Vercel proxy, the
CORS-broken-on-VINCUE's-side story, the native direct-call/API-key path,
the single build-time base-URL/key switch — is preserved unchanged in
`InventoryApiClient` and `config.dart`, fully tested, but no longer wired
into the running app (nothing in `main.dart` or the provider graph imports
either file anymore). It remains as documented history of the original
design, not a currently-exercised code path. See
`docs/superpowers/specs/2026-07-20-static-inventory-snapshot-design.md`
for the full design rationale.
```

- [ ] **Step 2: Update `README.md`'s Setup section**

Replace the block from `## Setup` through the end of the proxy `npm run deploy` code fence (the section ending just before `## Architecture: the CORS bug...`) with:

```markdown
## Setup

Both build targets now read from a bundled inventory snapshot
(`assets/data/inventory.json`) rather than a live API call — no
`--dart-define` configuration needed for either one. See
[Architecture: the CORS bug](#architecture-the-cors-bug-historical-and-this-apps-two-build-targets)
below for why that architecture existed and why it's now historical.

```bash
flutter pub get
flutter run -d web-server --web-port=8765
```

Open `http://localhost:8765` manually (see [Dev environment](#dev-environment--build-architecture) for why `-d web-server` instead of `-d chrome`).

**Native Android:**

```bash
flutter run -d <device-id>
```

**The proxy** (`api/`) is no longer called by the app at runtime, but its code and tests remain in the repo as documented history — see below.
```

- [ ] **Step 3: Update the Architecture section heading and lead-in to mark it historical**

Replace:

```markdown
## Architecture: the CORS bug (and this app's two build targets)

Same root cause as the reference React app: VINCUE's API sends `Access-Control-Allow-Origin: *, *` — the header twice — on both the preflight and the actual `GET`, which browsers reject outright on any cross-origin call, confirmed with `curl` and independent of how the API key is handled. No browser build can call VINCUE directly, full stop.
```

with:

```markdown
## Architecture: the CORS bug (historical) and this app's two build targets

**Historical:** VINCUE revoked live API access for this project; the app now runs entirely off a bundled JSON snapshot (see [Setup](#setup) and `docs/SPEC.md`'s "Data source (deviation)" note). The architecture below is preserved in the code (`InventoryApiClient`, `config.dart`, `api/`) and here in the README as a description of how the app worked while the API was live — none of it is on the runtime path anymore.

Same root cause as the reference React app: VINCUE's API sends `Access-Control-Allow-Origin: *, *` — the header twice — on both the preflight and the actual `GET`, which browsers reject outright on any cross-origin call, confirmed with `curl` and independent of how the API key is handled. No browser build can call VINCUE directly, full stop.
```

- [ ] **Step 4: Simplify the deploy script in `package.json`**

In `package.json`, the `scripts.deploy` entry currently is:

```json
"deploy": "flutter build web --release --dart-define=API_BASE_URL=/api/inventory && rm -rf public && cp -r build/web public && vercel deploy --prod"
```

Replace with:

```json
"deploy": "flutter build web --release && rm -rf public && cp -r build/web public && vercel deploy --prod"
```

(`API_BASE_URL` is no longer read by `main.dart` as of Task 4, so passing it is now a no-op left over from the live-fetch build; removing it keeps the deploy script honest about what the build actually needs.)

- [ ] **Step 5: Confidence score, dual review (per CLAUDE.md), then commit**

```bash
git add docs/SPEC.md README.md package.json
git commit -m "docs: document the static-inventory-snapshot deviation and simplify deploy"
```

---

## Explicitly out of scope for this plan

- Tearing down (or keeping) the Vercel proxy deployment itself — an operational decision for JP, not a code change.
- Snapshotting vehicle photos — the existing placeholder-fallback UI already covers a dead CDN link the same way it covers a currently-broken one; no code follows from this.
