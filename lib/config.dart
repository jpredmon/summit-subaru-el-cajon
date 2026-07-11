import 'services/inventory_api_client.dart';

/// Resolved, build-target-agnostic inputs for constructing the
/// `InventoryApiClient` (Task 4). Kept as a plain value type so
/// [resolveApiBuildConfig] stays a pure function, testable without a
/// compiled build (SPEC "API access strategy").
class ApiBuildConfig {
  const ApiBuildConfig({required this.baseUrl, required this.attachApiKeyHeader, this.apiKey});

  /// The fully-resolved inventory endpoint, GET verbatim -- the Vercel proxy
  /// URL on web, the direct VINCUE URL (with `dealerID`) on native.
  final String baseUrl;

  /// Whether to send the `x-api-key` header client-side. True on native
  /// (direct VINCUE call); false on web (the proxy attaches no client-side
  /// key -- CORS is a browser-only concern, so only the web build needs the
  /// proxy at all).
  final bool attachApiKeyHeader;

  /// Only meaningful when [attachApiKeyHeader] is true.
  final String? apiKey;
}

/// Maps raw `--dart-define` string values (plus the platform they were
/// compiled for) to an [ApiBuildConfig]. `apiBaseUrl` and `apiKey` are
/// exactly what `String.fromEnvironment` returns -- an empty string when the
/// define wasn't supplied, never null -- so an empty [apiKey] is normalized
/// to `null` here rather than leaking `''` into `InventoryApiClient`.
ApiBuildConfig resolveApiBuildConfig({
  required bool isWeb,
  required String apiBaseUrl,
  required String apiKey,
}) {
  return ApiBuildConfig(
    baseUrl: apiBaseUrl,
    attachApiKeyHeader: !isWeb,
    apiKey: apiKey.isEmpty ? null : apiKey,
  );
}

/// Builds the real `InventoryApiClient` from raw `--dart-define` values, or
/// throws if the build is unconfigured -- called from inside
/// `inventoryApiClientProvider`'s override (`Provider.overrideWith`, not
/// `overrideWithValue`) so this only ever runs the first time something
/// actually reads the provider, not eagerly during `main()` before
/// `runApp()`. That laziness matters: a throw here is then caught by
/// `inventoryProvider`'s `FutureProvider` body (which awaits
/// `getInventory()`, itself calling this client) the same way any other
/// inventory-fetch failure is, surfacing as a graceful in-app error state
/// instead of an uncaught exception crashing the app before any UI renders.
///
/// An empty/whitespace-only [apiBaseUrl] means the build is unconfigured
/// (no `API_BASE_URL` define supplied -- e.g. the web proxy isn't deployed
/// yet) and throws [UnimplementedError]. A non-empty [apiBaseUrl] with a
/// missing key on a native build is a genuine misconfiguration, not an
/// unconfigured build -- that case is left to `InventoryApiClient`'s own
/// constructor validation (`ArgumentError`), which already fails loudly and
/// specifically rather than being folded into the generic "unconfigured"
/// message here.
InventoryApiClient buildInventoryApiClient({
  required bool isWeb,
  required String apiBaseUrl,
  required String apiKey,
}) {
  if (apiBaseUrl.trim().isEmpty) {
    throw UnimplementedError(
      'inventoryApiClientProvider must be configured via '
      '--dart-define=API_BASE_URL=... (and --dart-define=VINCUE_API_KEY=... on native).',
    );
  }

  final config = resolveApiBuildConfig(isWeb: isWeb, apiBaseUrl: apiBaseUrl, apiKey: apiKey);
  return InventoryApiClient(
    baseUrl: config.baseUrl,
    attachApiKeyHeader: config.attachApiKeyHeader,
    apiKey: config.apiKey,
  );
}
