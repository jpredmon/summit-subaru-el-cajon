# VINCUE Inventory — Flutter Mobile Spec

## Context

Take-home follow-up to a completed React web build against VINCUE's live
Inventory API for dealer 54222. Two emails from Brian Kellogg (hiring
contact) scoped this work:

> Hey JP! Cool work on the VIN aggregator. I have a similar challenge. Using
> our AP here: https://pro.vincue.com/api/swagger/index.html and this key:
> [see .env] use the Inventory endpoint to get data for dealerID 54222 and
> create two things using React as the frontend: A listing grid, "SRP"
> (search result page) ... and a "VDP" (vehicle details page) that shows all
> the details you receive about a vehicle. The grid can display simple bits
> of information about the vehicle and the details page can have more rich
> data. If you want to get super fancy, include some sort of caching on the
> API call, paging, or some sort of filtering.

> Do you have any interest in learning mobile development at all? ... What
> would be incredible is if you were to spin up a Flutter app that did the
> same thing you did here with this endpoint. A basic SRP view and a VDP
> view. ... I have our mobile lead lined up ready to review it as well.

**Scope decision (not stated in the emails, decided in planning):** "did the
same thing you did here" is read as full functional parity with the
*finished* web app — caching, paging, and filtering are in scope, not
stretch goals — not a stripped-down MVP of just two screens. "Basic SRP view
and VDP view" names the two screens; it doesn't cap feature depth. Where
reasonable, this build also targets matching or improving on the web app's
design-polish decisions (dark mode, accessibility, resilience UX), using
Flutter-idiomatic approaches rather than porting web-specific implementation
details.

**Cut order under timeline pressure** (unchanged from planning): filtering
first, then design-polish depth, then paging. Caching is structural to the
architecture either way and isn't really optional to cut.

## Deliverables

1. **SRP** (Search Results Page) — grid of active inventory
2. **VDP** (Vehicle Details Page) — full detail view for a single vehicle
3. **Full parity, not stretch goals:**
   - API response caching (single fetch per session)
   - Client-side paging
   - Client-side filtering (small, scoped set)
4. Design-polish parity where Flutter's own idioms make it achievable: dark
   mode, accessibility, resilience UX (see "Design polish" below)

## API

- **Endpoint:** `GET https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222`
- **Auth:** header `x-api-key: <key>`
- **CORS is broken on Vincue's side.** Both the preflight and the actual
  `GET` send `Access-Control-Allow-Origin: *, *` (the header twice) —
  Chromium rejects this outright, so no browser can call this API
  cross-origin at all. This is real and verified (see the web app's SPEC.md
  for the original curl/headless-browser confirmation), not hypothetical.
- **Rate limit:** 5000 requests/hour, surfaced via `x-rate-limit-*` response
  headers — informs the single-fetch-per-session caching design below.
- **Response shape:** `{ result: RawVehicle[] }` — single unpaginated array.
  As observed during the web build: 141 vehicles for this dealer (132
  used/9 new; 34/141 with real photos; 30/141 with an unparseable
  `sellingPrice`) — same endpoint/shape, live counts may have drifted since.
  No server-side paging or filtering; both are implemented client-side
  against the cached response, same as the web app.

### API access strategy (Flutter-specific — this differs from the web app)

- **Flutter Web (dev target):** calls a Vercel-hosted proxy built the same
  way (same `/api/inventory` handler pattern) as the React app's, for the
  identical reason — a browser tab is subject to CORS enforcement regardless
  of how it was launched. This matters here specifically because the
  standing dev workflow (see "Dev environment" below) opens Chrome
  *manually* rather than through `flutter run -d chrome`'s automated launch —
  a manually-opened tab is exactly as CORS-subject as an automated one, so
  the proxy is still required, not optional just because the launch path
  changed.
  - **Must be this app's own deployment, not the React app's URL.**
    Confirmed while pulling forward a quick manual-verification override in
    Task 10: the reference React app's deployed proxy (`api/_inventoryHandler.ts`
    in that repo) sets no CORS headers at all — it doesn't need to, because
    that app calls it *same-origin*. Pointing this Flutter app's web build at
    that same URL is a cross-origin request from a different origin, which
    the browser rejects regardless of environment (verified via `curl`
    showing no `Access-Control-Allow-Origin` on the response). Task 15 needs
    its own Vercel deployment of an equivalent proxy function, not a literal
    reuse of the React app's.
- **Native Android build:** calls VINCUE's endpoint **directly**, no proxy —
  CORS is a browser-enforced mechanism only, and Dio/http-style native
  clients aren't subject to it. This means the API key travels with the
  native binary for this build (unlike the web app's server-only key
  handling). Accepted for this build because it's a one-time internal
  review artifact for the mobile lead, not a distributed/shipped release —
  flagged here explicitly as a real difference from the web app's posture,
  not an oversight.
- **Single build-time switch, not two code paths:** one `InventoryApiClient`
  is constructed with a base URL (from `--dart-define=API_BASE_URL=...`,
  resolved in build config — see Task 15) and a compile-time flag for whether
  to attach the `x-api-key` header client-side. Proxy build: no client-side
  key, base URL = the Vercel proxy. Native build: key supplied via
  `--dart-define=VINCUE_API_KEY=...` at build time — never hardcoded in
  source.
  - **The base URL is the fully-resolved inventory endpoint, GET verbatim.**
    The client does not build paths or append the `dealerID` — the proxy path
    (`/api/inventory`, fixed) and the direct VINCUE path
    (`/Inventory/ActiveInventory?dealerID=54222`) genuinely differ, so there
    is no common suffix to append. The configured value therefore carries the
    whole path+query per build: the proxy URL on web, and
    `https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222` on
    native. This keeps the client a thin fetch/parse layer and keeps the
    `dealerID` in config rather than hardcoded in the client.

## Data model

Same transformed/narrowed shape as the web app — consume `Vehicle`, not the
raw 48-field payload directly.

```dart
class RawVehicle {
  final int inventoryID;
  final String vin;
  final String stock;
  final String newUsed;       // 'N' | 'U'
  final String year;          // numeric string
  final String make;
  final String model;
  final String trim;
  final String body;          // inconsistent — see data quirks
  final String transmission;
  final String engine;
  final String drivetrain;
  final String extColor;
  final String intColor;
  final String miles;         // numeric string
  final String sellingPrice;  // numeric string, sometimes "0.00" or ""
  final String certified;     // 'Y' | 'N'
  final String mpgCity;       // numeric string
  final String mpgHwy;        // numeric string
  final List<String> vehiclePhotos; // frequently empty; matches photoCount
  final int photoCount;
  final List<String> features;      // long, noisy, inconsistent
  final String description;         // raw HTML entities, marketing copy
  final String? vdpUrl;
  final String dealerName;          // consistent across all records
}

enum BodyCategory { sedan, suv, truck, coupe, van, hatchback, convertible, other }

class Vehicle {
  final int id;
  final String vin;
  final String stock;
  final int year;
  final String make;
  final String model;
  final String trim;
  final BodyCategory bodyStyle;
  final String engine;
  final String transmission;
  final String drivetrain;
  final String exteriorColor;
  final String interiorColor;
  final int mileage;
  final double? price;        // null when unparseable/zero -> "Call for price"
  final bool isCertified;
  final double? mpgCity;      // null when unparseable or <= 0
  final double? mpgHwy;       // null when unparseable or <= 0
  final List<String> photos;  // may be empty
  final List<String> features; // deduped, trimmed, empty-after-trim dropped
  final String description;   // sanitized, VDP supplementary text only
  final bool isNew;
}
```

### Known data quirks and business rules (ported verbatim from the web app + corrections)

- `sellingPrice` → `price`: null below a **$500 floor** (not just exactly
  `"0.00"`/`""`) — this floor is what catches the one 2025 Porsche 911 record
  with `sellingPrice: "1.00"` (its `wholesalePrice` of 413035 confirms $1
  isn't real), same "not yet priced" intent as the empty-string records.
  Display as "Call for price" when null.
- `vehiclePhotos` empty on the majority of records — SRP and VDP both need a
  placeholder image state, not a broken image. A non-empty photo URL can
  *still* be a dead link independent of the empty-array case; both SRP cards
  and the VDP carousel fall back to the same placeholder on load failure,
  and the carousel tracks failures **per photo index**, not globally, so
  navigating to a different photo retries independently rather than getting
  stuck on the placeholder.
- `body` is inconsistently populated (real values like "Sedan", "Sport
  Utility", "Coupe", but also drivetrain strings that clearly belong
  elsewhere — `"S-AWC"`, `"SH-AWD"`, `"4dr AWD"` — or empty). Normalize into
  the 8-value `BodyCategory` set, bucketing anything unrecognized into
  `other`, to keep the filter dropdown clean.
- `description` contains literal HTML tags/entities and literal two-character
  `\n` sequences (not real newlines) between marketing sections. Transform:
  strip literal `\n` first, then strip tags and decode entities (Flutter
  equivalent of the web app's `DOMParser`/`textContent` step — e.g. the
  `html` package's document-parse-then-`.text`), then collapse whitespace.
  Never render raw; never treat as a source of truth for spec-table fields.
  **Deviation from strict parity:** real data from Summit Subaru El Cajon
  contains a malformed tag pattern (`&ltb>...&lt/b>`, opening angle-bracket
  entity-encoded without semicolon, closing angle-bracket literal) that a
  spec-compliant parser treats as literal text rather than a tag — this is
  *not* a bug, it's correct per HTML5 tokenization rules, and the reference
  React app exhibits the same artifact. This build adds a deliberate
  text-repair step before parsing to strip these malformed sequences,
  improving submission polish without deviating from core feature parity.
- `features` arrays are long (avg ~95, max ~120) and inconsistently
  formatted. Trim each entry, dedupe (order-preserving), **and drop any
  entry that's empty after trimming** — this last part is easy to miss
  since it only shows up on already-messy records.
- Numeric fields arrive as strings throughout — parse and validate (finite
  check, not just non-null) before math or display formatting.
- **mpg gating:** `mpgCity`/`mpgHwy` are nulled not just when unparseable but
  whenever the parsed value is **≤ 0** — a plain "did it parse" check isn't
  sufficient.
- **year/mileage parse-failure fallback:** unlike price/mpg, a failed parse
  for `year` or `mileage` falls back to **`0`**, not null — consistent with
  them being non-nullable numeric fields on `Vehicle`.
- `isCertified`: true when `certified == 'Y'`. `isNew`: true when
  `newUsed == 'N'` (i.e. "new" inventory, not literally the letter N as
  "no").
- **Price-range filtering is two independent selects (min/max), not a single
  "price range" control** — this is the one correction flagged as
  highest-priority in the flutter-handoff.md audit, since a from-spec
  implementer could otherwise reasonably build a single range slider
  instead. Threshold list, shared by both selects:
  `[10000, 15000, 20000, 25000, 30000, 40000, 50000, 75000, 100000]`. Each
  select's available options are pruned by the other's current value — the
  min list caps at ≤ the current max selection, the max list floors at ≥ the
  current min selection.
- **Price-filter null exclusion:** vehicles with `price == null` ("Call for
  price") are excluded from filtered results whenever *either* price filter
  is active — a real UX rule, not incidental.

## Architecture

- **Stack:** Flutter/Dart. Targets: Flutter Web (primary dev loop) + Android
  (native, single verification pass near project end — see "Dev
  environment" below). No iOS target (not requested).
- **HTTP:** `http` package — no need for `dio`'s interceptor machinery given
  there's exactly one endpoint and one build-time base-URL/key switch (see
  API access strategy above).
- **Data fetching/caching:** **Riverpod** (`AsyncNotifier`/`FutureProvider`
  over a single `InventoryRepository`) fetches once per app session and
  holds `{ vehicles: List<Vehicle>, dealerName: String }` — the same shape
  as the web app's `useInventory()` — exposing loading/error/data states so
  SRP and VDP share one fetch, never two. Chosen over `provider`/
  `ChangeNotifier`: compile-time provider safety and no `BuildContext`
  dependency for reading the cache from non-widget code (e.g. the transform/
  filtering logic), a decision already made earlier in planning, not
  something the "avoid unnecessary weight" instinct should override here —
  Riverpod isn't heavier than `provider` for equivalent functionality.
  `dealerName` is derived once from the response, same as the web app's
  `useDealerName()` convenience wrapper (Flutter equivalent: a derived/
  `select`-style provider, not a separate hook, since Flutter has no hooks —
  same single-derivation intent). Paging and filtering both operate
  client-side against this one cached list, exposed via further Riverpod
  providers derived from the base inventory provider.
- **Shared client logic across builds:** one `InventoryApiClient` class used
  by both the web (proxy-backed) and native (direct-VINCUE) build via the
  base-URL/key switch — mirrors the web app's `api/_inventoryHandler.ts`
  being genuinely shared between the Vercel function and the Vite dev
  middleware, not duplicated per build target.
- **Routing:** `go_router` — chosen specifically because the SRP's
  filter/page state needs to be URL-shareable and refresh-survivable on the
  web target (parity with the web app's `?make=Honda&body=SUV&page=2`
  pattern); `go_router`'s query-parameter support gives this directly. SRP
  at `/`, VDP at `/vehicle/:id`. On native there's no address bar to sync
  to — state simply lives in the router/widget tree for the session, no
  equivalent persistence needed.
- **Testing:** `flutter_test` + `mocktail` for the API client, plus
  Riverpod's `ProviderContainer`/override machinery for testing the
  inventory/paging/filtering providers in isolation. Focused, not
  exhaustive — matching the web app's philosophy: prioritize the
  `RawVehicle -> Vehicle` transform (price floor + Porsche sentinel, body
  normalization, mpg gating, features dedup/trim/empty-drop, year/mileage
  fallback), plus a few key widget/logic tests (price display formatting,
  placeholder fallback, paging math, the two-select price-range pruning
  logic). TDD workflow and task breakdown are the implementation plan's
  concern, not this document's.

## SRP — scope

- Grid layout, one card per vehicle.
- Card shows: photo (or placeholder), year/make/model/trim, mileage, price
  (or "Call for price"), body style.
- Tap through to VDP.
- **Paging:** client-side, over the full cached list. Page size: 12.
  `totalPages = max(1, ceil(count / 12))` (an empty list still reports 1
  page, not 0). Requested page number clamps into `[1, totalPages]` — a
  page below 1 or above the last page silently resolves to the nearest
  valid page rather than erroring or returning an empty slice (undocumented
  in the original spec text, but real behavior in the web app's
  `paginate.ts`, ported unchanged).
- **Filtering:** make, normalized body style, and price range via **two
  selects** (min/max — see Data model above for the threshold list and
  pruning rule). Applied client-side, no additional API calls.
- **URL sync (web target):** filter and page state live in the route's
  query parameters so state is shareable and survives refresh/back — same
  reasoning as the web app: this is what makes paging and filtering compose
  as one coherent feature rather than two independent ones.
- **Page title (web target):** browser tab title is the live `dealerName`
  (same fallback as elsewhere) — matches the web app's
  `useDocumentTitle(dealerName)` on its SRP. Missed in the original SRP task
  (Task 9); folded into Task 12 since that task builds the shared
  page-title mechanism for VDP anyway.

## VDP — scope

- **Photo carousel:** custom-built (no carousel package), current-index
  state, Previous/Next, "X of Y" counter. Boundaries **clamp, not wrap** —
  Next disables at the last photo. Per-photo-index failure tracking (a
  failed photo shows the placeholder; navigating to a different index
  retries independently). Single placeholder (same one used on SRP cards)
  when `photos` is empty.
- Header: year/make/model/trim, price, mileage, stock number.
- Spec table: engine, transmission, drivetrain, mpg city/hwy, exterior/
  interior color, certified status.
- **Features:** bounded/collapsible — first 10, "Show all (N)" to expand,
  "Show less" to collapse. No button shown at ≤10 features. **No Features
  section at all** (not just no button) when `features` is empty — easy to
  miss since the web spec's text only discussed the 10-item boundary.
- Reads from the same `InventoryRepository` cache the SRP populated — a
  local find-by-`id`, never a second fetch.
- **Description:** shown below Features when `description` is non-empty
  (omitted entirely when empty) — matches the web app's supplementary-text
  block; not itself called out in the original VDP scope bullets but implied
  by `Vehicle.description`'s own "VDP supplementary text only" contract and
  the full-parity scope decision.
- **Four distinct states:** loading, error (same message as SRP), not-found
  (loaded but no cached vehicle matches the id — e.g. a stale link — shows a
  message and a link back to SRP), and loaded. Page-title logic (web-target
  browser tab title) has three distinct branches matching these states —
  loaded, not-found, loading each get their own title text, not just the
  loaded case. Error state's title falls through to the same plain-
  `dealerName` text as loading (matches the web app's `getVdpTitle`: only
  three branches are named because error and loading share one).

## Design polish — Flutter-idiomatic parity, not a port

The web app's polish pass is the target *behavior*, not the target
*implementation* — several of its specifics were CSS/DOM workarounds that
don't apply in Flutter and shouldn't be replicated:

- **Dark mode:** manual toggle (not OS-driven), defaults to dark on first
  launch, persisted (`shared_preferences` in place of `localStorage`). The
  web app needed a duplicated inline script to avoid a flash-of-wrong-theme
  because a JS module import can't run early enough — Flutter has no such
  penalty; resolve `ThemeMode` from the persisted value before the first
  frame (no duplicate-logic workaround needed).
  **Deviation (above-and-beyond, not an oversight):** as of the header-logo
  work, this build forces `ThemeMode.light` and no longer exposes the
  toggle in the UI — the header logo's palette doesn't read well against
  the dark theme, and no time was budgeted to also tune dark-mode contrast
  for it. The underlying mechanism (`themeModeProvider`, `ThemeModeNotifier`,
  its `shared_preferences` persistence, and the standalone `ThemeToggleButton`
  widget) is fully intact and untouched — only `main.dart`'s
  `VincueMobileApp` no longer reads it for the app's actual `themeMode`.
  Re-enabling is a one-line change back to `ref.watch(themeModeProvider)`,
  not a rebuild of the feature.
- **Accessibility:** keyboard/focus-traversal parity goal — filters → cards
  → pagination → VDP → carousel → back, all reachable without a pointer
  (Flutter web Tab order; native Android via TalkBack semantics). The web
  app's focus indicator was a border-color swap specifically because CSS
  `outline`/`ring` couldn't cleanly follow the card's border-radius — this
  was a workaround for a CSS limitation Flutter doesn't have. Use Flutter's
  own focus-highlight mechanism (`Focus`/`FocusableActionDetector` with a
  themed decoration matching the actual corner radius) directly instead.
- **Reduced motion:** `MediaQuery.disableAnimations` is the direct Flutter
  equivalent of the web app's `motion-reduce:` variants — apply it to every
  transition/animation (tap/hover feedback, carousel photo transition,
  skeleton pulse).
- **Contrast:** carry over the same *target* palette decisions the web app
  landed on after its axe-core pass (amber-700-equivalent for text-on-light-
  background, a lighter amber acceptable for non-text uses like a focus
  ring) but re-verify against Flutter's actual rendered output — Tailwind's
  token math doesn't carry over automatically.
- **Resilience UX:** skeleton loading states matching the real SRP grid/VDP
  layout shape (respecting `disableAnimations`); a top-level error boundary
  scoped to just the routed content (so a render failure doesn't take the
  header/theme-toggle down with it — Flutter equivalent of the web app's
  class-component `ErrorBoundary` restricted to `<Routes>`, e.g. via
  `ErrorWidget.builder` scoped appropriately or a dedicated boundary widget
  around the router's content); "Clear filters" control on empty filtered
  results. The filter bar itself also shows its own "Clear filters" control
  whenever a filter is active, reflowing alongside the filter dropdowns —
  except while the empty-results panel is showing (filtered results are
  empty), when the filter bar suppresses its copy so only the empty-results
  panel's "Clear filters" control is on screen; placeholder fallback for
  broken/empty photo URLs via
  `Image.network`'s `errorBuilder`, tracked per-index in the carousel.
- **Visual design:** carry over the palette intent (slate neutrals + amber
  accent + emerald "Certified" badge) and the tabular-digit-alignment intent
  for prices/mileage/mpg/counters (Flutter: `FontFeature.tabularFigures()`
  in the relevant `TextStyle`s) and a standardized rounded-corner radius via
  a shared theme constant. **Explicitly not porting:** the custom SVG-
  chevron `<select>` workaround — that existed because a native HTML
  `<select>`'s arrow can't be recolored/repositioned; Flutter's own
  dropdown/menu widgets don't have that limitation, so use them directly
  with normal theming.
- **Dealer name:** header, VDP title branches, and the not-found/loading
  states all read the live `dealerName` from the fetched response, falling
  back to a generic "Vehicle Inventory" string if it's ever empty — VINCUE
  is the platform vendor, not the dealership, so it must never be
  hardcoded as the visible name.
- **Header logo (above-and-beyond deviation):** the header AppBar shows a
  fixed Summit Subaru El Cajon logo image instead of the live `dealerName`
  text described above — a deliberate, documented divergence (see
  `docs/superpowers/specs/2026-07-12-header-logo-design.md`), not an
  oversight. The live `dealerName` value is still read and still drives
  the logo's accessibility label, so screen readers continue to announce
  it even though sighted users see the fixed graphic.

## Dev environment & build architecture

- **Dev machine constraint:** Windows, ~1GB free RAM typically — no Android
  emulator for iterative development (see `dev-environment-notes.md`).
- **Standing dev workflow:** `flutter run -d web-server --web-port=8765`,
  then open `http://localhost:8765` **manually** in a normal Chrome window —
  **not** `flutter run -d chrome` directly. That automated launch path is
  confirmed unreliable on this machine: under RAM pressure, Chrome's
  multi-process startup is slower than Flutter's internal debug-port-connect
  retry timeout, so Flutter's retry spawns a second Chrome into the *same*
  profile directory while the first is still starting — Chrome's own
  single-instance lock merges them, the debug port Flutter is waiting on
  never comes up, and this repeats across all 3 retries until Flutter gives
  up (root-caused and confirmed via manual isolated-Chrome testing in
  `dev-environment-notes.md`; not a broken install). The web-server +
  manually-opened-tab workflow sidesteps the race entirely — Flutter isn't
  managing the browser launch — and hot reload still works because dwds's
  reload client is served inside the page itself, independent of any
  debug-protocol attach.
- **CORS applies the same regardless of launch method:** a manually-opened
  Chrome tab is exactly as subject to CORS enforcement as an automated one,
  so this dev workflow still goes through the Vercel proxy (`/api/inventory`)
  rather than calling VINCUE directly — same reasoning as the web app, see
  "API access strategy" above.
- **Native Android build** calls VINCUE directly (no proxy — CORS is
  browser-only enforcement). Selected via the single build-time base-URL
  switch described above, not a second code path.
- **Android toolchain status:** cmdline-tools, platform-tools, and a single
  build-tools version are installed and all licenses accepted (see
  `dev-environment-notes.md`). An Android `platforms;android-XX` package is
  still needed before the first APK build — a separate, confirm-before-
  install step, not yet done as of this spec.
- **Real-device verification:** once, near the end of the project, on a
  borrowed physical Android phone via USB debugging (not an emulator) — a
  final check for native-build errors, platform-specific rendering, and
  real touch/gesture behavior that the web dev loop can't surface. Not the
  primary dev loop.

## Submission

- Repo access for the mobile lead's review.
- A short note (README or equivalent) covering: the caching/paging/
  filtering design, and the dev/build-architecture decisions (proxy vs.
  direct-VINCUE call, why `-d web-server` instead of `-d chrome`) — mirrors
  the web app's README content, adapted for what's actually different here.

## Explicitly out of scope

- Android emulator-based development.
- The full Android Studio IDE.
- iOS.
- Production-grade native release engineering (signing, store listing,
  crash reporting, etc.) — this native build is a one-time review artifact
  for the mobile lead, not a shipped release.
