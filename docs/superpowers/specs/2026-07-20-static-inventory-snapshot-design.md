# Static inventory snapshot — design

## Context

Access to VINCUE's live Inventory API endpoint is being revoked. The hiring
contact's director gave permission to continue using this project as a
practice/portfolio piece after that happens, on the condition (per the
director's own suggestion, echoed from an equivalent decision already made
on the sibling React project) that the live API call is replaced by a saved
JSON payload rather than left as dead code that silently never runs.

**Is this still worth it as an example project?** Yes. The reviewable
substance — SRP/VDP, caching, paging, filtering, the resilience/dark-mode/
a11y polish, the CORS-workaround story — never depended on the data being
*live*, only on it being *real* (143 actual vehicles with the documented
data quirks: sub-$500 price floor catching the $1 Porsche, malformed HTML
entities, inconsistent `body` values, etc.). A frozen snapshot demonstrates
all of that identically and is arguably better for review, since it's
deterministic. The only capability lost is "hit refresh and see it change,"
which was never a named requirement — the original scope decision (SPEC.md
"Scope decision") is SRP/VDP/caching/paging/filtering, not live-integration
freshness.

## Decision: full switch, both build targets

Static JSON becomes the *only* runtime data source, on both build targets:

- **Web build:** currently calls a Vercel proxy (CORS workaround).
- **Native build:** currently calls VINCUE directly with the API key.

Both are replaced by an in-app asset load. This mirrors the recommendation
already applied to the sibling React project, extended to this app's two
build targets (the React app only had one call path). Reasoning ported
from that decision: once access is gone there's nothing to fall back from,
and leaving the live-fetch code wired in produces dead code that silently
never runs — worse for a review artifact than removing it from the runtime
path while keeping it as documented history.

**Rejected alternative:** keep the live-fetch path behind a build flag,
defaulting to static JSON. Rejected as unnecessary surface area — there is
no plausible future in which this flag flips back to live, and it's a
"maybe someday" code path in an already build-config-heavy area
(`config.dart`).

## What stays, unwired, as documented history

- `InventoryApiClient` (`lib/services/inventory_api_client.dart`) — the
  live-fetch class itself.
- `config.dart`'s `resolveApiBuildConfig`/`buildInventoryApiClient` — the
  build-time proxy-vs-direct-call/API-key resolution logic.
- The Vercel proxy function and its CORS-bug story.
- All existing tests for the above — they still pass, still describe real
  (past) behavior, and cost nothing to leave running.

None of this is imported from `main.dart` or any provider after this
change; it's reachable only by someone reading the repo.

## Data capture

Captured 2026-07-20 via one authenticated `GET` against
`https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222`,
saved verbatim as `assets/data/inventory.json` (~1.08MB, `{ "result": [...]
}` shape, 143 records — SPEC.md's original 141 count had already drifted,
as SPEC.md itself anticipated). No reshaping; `RawVehicle.fromJson` reads
it exactly as it would the live response.

**Photo URLs:** ~34/143 vehicles have real `vehiclePhotos` CDN URLs, which
point at VINCUE's photo CDN — a system independent of the API endpoint
being revoked, but its continued availability isn't guaranteed either.
No action needed: the existing per-index placeholder-fallback UI (SRP
cards and the VDP carousel) already handles a dead photo URL exactly like
a currently-broken one. This is noted, not engineered around.

## Code changes

1. **New shared parser** — `lib/services/inventory_response_parser.dart`:
   extract the JSON-decode + shape-validation + `RawVehicle.fromJson`
   mapping currently inside `InventoryApiClient.fetchInventory()` into a
   pure function `RawInventory parseInventoryResponse(String body)`. The
   `RawInventory` value class moves here too (it's the shared response
   shape, not an API-client-specific concept). `InventoryApiClient` calls
   this function after its HTTP GET, unchanged in behavior.

2. **New `StaticInventoryDataSource`** —
   `lib/services/static_inventory_data_source.dart`: loads
   `assets/data/inventory.json` via `rootBundle.loadString` (an injectable
   `AssetBundle` for testability, mirroring `InventoryApiClient`'s
   injectable `http.Client`), calls `parseInventoryResponse`. Same
   `InventoryApiException`-style error surfacing on a malformed asset
   (defensive only — the asset is repo-controlled — but keeps the
   error-state contract consistent with the class it replaces).

3. **`InventoryRepository`** (`lib/services/inventory_repository.dart`):
   constructor takes `StaticInventoryDataSource` instead of
   `InventoryApiClient`; `getInventory()` calls `loadInventory()` instead
   of `fetchInventory()`. No change to its own public contract — SRP/VDP/
   paging/filtering code downstream is untouched.

4. **`providers/inventory_provider.dart`**: `inventoryApiClientProvider`'s
   throwing placeholder is replaced by a real default
   `staticInventoryDataSourceProvider` (`Provider((ref) =>
   const StaticInventoryDataSource())`) — no app-root override needed
   anymore. `inventoryRepositoryProvider` watches the new provider.

5. **`main.dart`**: delete the `_apiBaseUrl`/`_apiKey`
   `String.fromEnvironment` consts and the
   `inventoryApiClientProvider.overrideWith(...)` override block. Running
   or building the app no longer requires any `--dart-define`.

6. **`pubspec.yaml`**: add `assets/data/inventory.json` under
   `flutter.assets`.

7. **Tests**: existing `InventoryApiClient`/`config.dart` tests are
   untouched (still valid, still passing, still describe the historical
   live-fetch behavior). New tests for `parseInventoryResponse` (moved/
   adapted from `InventoryApiClient`'s existing parsing-focused cases) and
   `StaticInventoryDataSource` (mocktail-faked `AssetBundle`: valid load,
   malformed asset). `InventoryRepository`'s existing tests are updated to
   construct against a faked `StaticInventoryDataSource` instead of a
   faked `InventoryApiClient`.

## Docs

- **`docs/SPEC.md`**: dated deviation note near "API access strategy"
  (same pattern as the existing header-logo deviation) recording: static
  JSON is now the sole runtime data source as of 2026-07-20; the live-fetch/
  proxy/CORS architecture is preserved, unwired, as documented history;
  reason is the API access revocation, continued with Vincue's permission
  as a practice project.
- **`README.md`**: short section covering the same pivot for a repo reader
  — why, what changed, and that caching/paging/filtering/CORS-workaround
  are unaffected by the switch.
- This design doc.

## Explicitly out of scope

- Tearing down (or keeping) the Vercel proxy deployment — an operational
  decision, not a code change; flagged for JP to decide separately.
- Snapshotting vehicle photos themselves — the existing placeholder
  fallback already covers CDN link rot, so no engineering work follows
  from the "photos might also go dark" risk noted above.
