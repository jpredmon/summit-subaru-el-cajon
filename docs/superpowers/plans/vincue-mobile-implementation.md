# vincue_mobile — Implementation task list

Source of truth: `docs/SPEC.md`. Workflow: `CLAUDE.md`'s Spec → Plan → Task
Loop → TDD → Dual Review addendum. Each task below is executed in its own
turn: failing test first (Task 1 excepted, see below) → minimal
implementation → passing test → confidence score (written after, not
before; <90 → iterate, max 3 passes, else stop and ask) → two-stage review
(spec compliance, then code quality) → any new-concept note appended to
`docs/LEARNING.md`.

Status legend: `[ ]` not started, `[~]` in progress, `[x]` done.

---

- [x] **1. Project setup** — add `flutter_riverpod`, `go_router`, `http`,
  `shared_preferences`, `html`, `mocktail` (dev) to `pubspec.yaml`; scaffold
  `lib/models/`, `lib/services/`, `lib/providers/`, `lib/screens/`, `lib/
  widgets/`, `lib/theme/`, `lib/router/`; remove counter-app boilerplate
  from `lib/main.dart`/`test/widget_test.dart`; base `ThemeData` (light/
  dark, slate/amber/emerald palette, shared rounded-corner constant).
  **Verify:** `flutter pub get` + `flutter analyze` clean (TDD exception —
  agreed with user: no testable logic in this task).

- [x] **2. Data models** — `RawVehicle` (+ `fromJson`), `Vehicle`,
  `BodyCategory` enum (`lib/models/`). **Test first:** `RawVehicle.fromJson`
  against a representative JSON fixture (empty `sellingPrice`, empty
  `vehiclePhotos` included).

- [x] **3. Vehicle transform (`RawVehicle` → `Vehicle`)** — $500 price floor
  + Porsche-$1 sentinel, body normalization (`"S-AWC"`/`"SH-AWD"`/`"4dr
  AWD"` → `other`), mpg gating (null when unparseable or ≤ 0), year/mileage
  fallback to `0` on parse failure, `isCertified`/`isNew` mapping, features
  trim+dedupe+drop-empty, description sanitization (strip literal `\n` →
  strip tags/decode entities via `html` → collapse whitespace). **Test
  first:** one test per rule above.

- [x] **4. `InventoryApiClient`** — constructor-injected `baseUrl` +
  `attachApiKeyHeader`/key (no internal `--dart-define` reads). Fetches/
  parses `{ result: RawVehicle[] }`, surfaces `dealerName`. **Test first:**
  `mocktail`-mocked `http.Client`, both header configurations, network/
  malformed-body error handling.

- [x] **5. Inventory Riverpod provider** — `AsyncNotifier`/`FutureProvider`
  over `InventoryRepository` (Task 4 client + Task 3 transform), single
  fetch per session, `{ vehicles, dealerName }` + loading/error. **Test
  first:** `ProviderContainer` overrides with a fake client — single-fetch
  semantics, error propagation.

- [x] **6. Paging logic** — full list + page number → 12-item slice. **Test
  first:** exact-multiple, partial-last-page, out-of-range, empty-list.

- [x] **7. Filtering logic** — make / body style / price two-select
  (threshold list `[10000, 15000, 20000, 25000, 30000, 40000, 50000, 75000,
  100000]`, min/max mutual pruning) + price-null-exclusion rule. **Test
  first:** each dimension, pruning boundaries, null-exclusion combined with
  an active price filter.

- [x] **8. Shared placeholder/broken-image widget** — used by SRP card
  (Task 9) and VDP carousel (Task 11); placeholder on empty list and on
  `Image.network` `errorBuilder`. **Test first:** widget test, both cases.

- [x] **9. SRP screen** — card grid (photo/placeholder, year/make/model/
  trim, mileage, price/"Call for price", body style), tap-through stub,
  wired to Tasks 5–7; loading/error states; "Clear filters" on empty
  filtered results. **Test first:** card field rendering, "Call for price"
  branch, empty-filtered + Clear-filters flow. Scope note (discussed and
  approved before starting): also built the filter dropdowns (make/body/
  price) and pagination controls now, backed by local Riverpod state
  (`srpStateProvider`) — Task 10 swaps that state's persistence to
  `go_router` query params without changing the controls themselves.

- [x] **10. Routing (`go_router`) + URL query-param sync** — SRP at `/`
  with filter/page state in query params; VDP route `/vehicle/:id` stub.
  **Test first:** query-param → state restore, state change → URL update.
  `main.dart` now wired to the real router (no more stub `Text` widget) —
  `inventoryApiClientProvider` still has no override, so it throws by design
  until Task 15. A temporary same-origin proxy override was tried and
  reverted: the reference React app's deployed proxy sets no CORS headers,
  so it only works same-origin for that app, not from this app's own dev
  server — real notes in SPEC.md/LEARNING.md for Task 15.

- [x] **11. Photo carousel widget** — current-index state, Previous/Next
  clamped (not wrapped), "X of Y" counter, per-index failure tracking
  (reuses Task 8). **Test first:** boundary clamp, counter text, per-index
  independent retry. Deviation from the web reference: `IconButton`s
  (chevron icons + tooltip) instead of text-label buttons — the text-label
  version overflowed at realistic widths; see LEARNING.md.

- [x] **12. VDP screen** — header, spec table, features (bounded to 10,
  "Show all (N)"/"Show less", no section when empty), four states (loading/
  error/not-found/loaded) via local find-by-id on Task 5's cache, three-
  branch page title. **Test first:** one test per state, features boundary
  (0/≤10/>10), not-found → link-back flow.

- [x] **13. Dark mode** — manual toggle, `shared_preferences`-backed,
  defaults dark on first launch, `ThemeMode` resolved pre-first-frame.
  **Test first:** default-dark with no stored pref; persist/restore toggle.
  Scope note (discussed and approved before starting): the plan's test-first
  line only covers the provider; the toggle also needs a real control to be
  usable, so a `ThemeToggleButton` was added to both SRP and VDP's `AppBar`s
  now rather than deferred to a later shared-header task. Code review (run
  before commit) caught and fixed two regressions this task's own changes
  introduced: `VincueMobileApp` watching `themeModeProvider` made it
  recreate the `GoRouter` (and reset navigation) on every toggle -- fixed by
  caching it behind `appRouterProvider`; and the new `AppBar` gave `VdpScreen`
  an automatic back arrow that bypassed the existing "Back to search
  results" button's filter-reset behavior -- fixed with
  `automaticallyImplyLeading: false`.

<!-- Tasks 14a/14b added 2026-07-11 to close a resilience-UX scope gap: SPEC
     "Design polish → Resilience UX" (skeleton loading + scoped error boundary)
     had no implementing task; the code shipped a CircularProgressIndicator +
     inline per-screen error instead. Approved for full-parity build. Execution
     order is 14a → 14b → 14c (14c's reduced-motion gates 14a's skeleton pulse).
     Tasks 15–19 renumbering avoided by using letter suffixes. -->

- [x] **14a. Skeleton loading states** — replace the `CircularProgressIndicator`
  spinner (SRP `srp_screen.dart:37`, VDP `vdp_screen.dart:52`) with skeleton
  placeholders matching the real layout shape (SPEC "Resilience UX"). A
  reusable `SkeletonBox` (rounded grey rectangle, subtle opacity **pulse**) in
  `lib/widgets/skeleton.dart`; SRP loading renders a grid of skeleton cards
  reusing the existing `SliverGridDelegateWithMaxCrossAxisExtent` dims so the
  skeleton grid matches the real grid; VDP loading renders a skeleton carousel
  block + skeleton spec rows. The pulse animation is left **ungated here** —
  Task 14c wires `disableAnimations` to it. **Test first:** loading state
  renders `SkeletonBox`es (and no `CircularProgressIndicator`) for both SRP
  and VDP; the SRP skeleton grid uses the same max-cross-axis-extent as the
  real grid.

- [x] **14b. Scoped error boundary** — a dedicated boundary widget wrapping the
  router's routed content so a render/build failure in routed content shows a
  fallback **without taking down the header/theme-toggle** (SPEC lines 362–367;
  Flutter equivalent of the web app's `ErrorBoundary` restricted to `<Routes>`).
  Use a **dedicated boundary widget** around the router content, not a global
  `ErrorWidget.builder` override (global is not scoped to routed content and
  would also swallow chrome failures). NOTE — highest-uncertainty task in this
  set: Flutter has no built-in try/catch-around-build; catching a descendant's
  build exception requires a scoped `ErrorWidget.builder` swap or an equivalent
  boundary technique, and this is the part to verify hardest. **Test first:** a
  routed child that throws during build renders the fallback, and a sibling
  chrome control (theme toggle) outside the boundary is still present/tappable.

- [x] **14c. Accessibility & reduced motion** — focus-highlight decoration
  matching actual corner radius (`FocusableActionDetector` + themed decoration,
  SPEC lines 349–351); `MediaQuery.disableAnimations` applied to every existing
  animation — the `VehicleCard` `InkWell` ripple/hover **and** Task 14a's
  skeleton pulse (the carousel swaps instantly and has no transition, so there
  is nothing to gate there — a deviation from SPEC line 354's "carousel photo
  transition" wording, which assumed an animated transition the build never
  added; note it in the reduced-motion writeup). **Test first:** animations
  skipped when `disableAnimations` true (skeleton pulse static; card ripple
  suppressed); focus-highlight decoration present when a card is focused.
  Keyboard/focus-traversal order (filters→cards→pagination→VDP→carousel→back)
  verified as a **documented manual checklist**, not an automated test —
  Flutter's widget-test harness doesn't simulate real Tab-key traversal across
  a full app well.

- [x] **15. Native/web build-time base-URL wiring** — `main.dart`/`lib/
  config.dart` reads `API_BASE_URL`/`VINCUE_API_KEY` `--dart-define` values,
  constructs Task 4's client. **Test first:** resolver function mapping
  define values → `(baseUrl, attachApiKeyHeader)`, tested directly (no
  compiled build needed).

- [x] **15b. Vercel CORS-proxy (web build's real data source)** —
  `api/inventory.ts` (Vercel entry) + `api/_inventoryHandler.ts` (handler),
  mirroring the reference app's `_inventoryHandler.ts` pattern
  (server-to-server fetch to VINCUE with `x-api-key`, relay status/body
  verbatim, 500 on missing key, 502 on upstream failure) plus
  `Access-Control-Allow-Origin: *` on every response — the addition this
  app's own deployment needs since, unlike the reference app, it's called
  cross-origin. Root `package.json` adds `vitest` as the only dev
  dependency; no runtime deps. Per the approved design
  (`docs/superpowers/specs/2026-07-11-vercel-proxy-design.md`). **Test
  first:** three cases against a mocked `fetch` + minimal `res` double —
  missing key → 500 + CORS header present; success → relays upstream
  status/body + CORS header present; upstream throw → 502 + CORS header
  present. **Verification (beyond unit tests):** `vercel dev` locally with a
  real key in `.env` — curl the endpoint directly, then point the Flutter
  web-server build's `API_BASE_URL` dart-define at it and confirm real
  inventory renders at `http://localhost:8765`; then `vercel deploy --prod`
  under the existing team (`team_OQadPvIU6eFYG0SwrLmDwN3t`) and repeat both
  checks against the real URL. Secrets: local `.env` (gitignored,
  `.env.example` committed) for `vercel dev`; JP runs `vercel env add
  VINCUE_API_KEY production` himself for the real deployment — key value
  never passed through the assistant. Record the production URL for Task
  16's write-up.
  **Status:** DONE. Half A (handler, entry point, tests, `package.json`)
  committed `c150ec0`. Half B: `vercel dev` verified locally, then
  deployed to production under team `jp-redmons-projects` — production
  URL **`https://flutterinventory.vercel.app/api/inventory`** (record
  this for Task 16). Verified end-to-end: real inventory renders in the
  Flutter web build pointed at the production URL, not just the raw
  endpoint via `curl`. A follow-up commit (`d356b4d`) added `@types/node`
  + `tsconfig.json` after the first prod deploy succeeded but logged
  non-fatal TypeScript errors (missing Node type declarations) — fixed for
  a clean build log, redeployed, re-verified.

- [ ] **16. README/submission note** — caching/paging/filtering design +
  dev/build-architecture decisions (proxy vs. direct-VINCUE, `-d web-server`
  vs `-d chrome`). No test — documentation only.

- [x] **17. Breakpoint utility** — `lib/theme/breakpoints.dart`:
  `WindowSizeClass` enum (`compact`/`medium`/`expanded`) + `kMediumBreakpoint`
  (600) / `kExpandedBreakpoint` (840) constants + `windowSizeClassOf(double
  width)`, per the approved design
  (`docs/superpowers/specs/2026-07-11-responsive-layout-design.md`). Pure
  function, no widget dependency. **Test first:** boundary values — 599 →
  compact, 600 → medium, 839 → medium, 840 → expanded.

- [x] **18. VDP two-pane layout** — at `expanded` width, `VdpScreen` renders
  `PhotoCarousel` in a `440px`-fixed left column and spec
  table/features/description in a scrolling right column filling the
  remainder, both inside a `Row` capped at `maxWidth: 1200`. Below
  `expanded` (`compact`/`medium`), today's stacked single-column layout is
  unchanged (existing `maxWidth: 800` `ConstrainedBox`). Branch on
  `windowSizeClassOf(MediaQuery.sizeOf(context).width)` from Task 17. **Test
  first:** widget test sets `tester.view.physicalSize` to a compact width
  and an expanded width and asserts which structural layout (stacked
  `Column` vs. side-by-side `Row`) is present at each.

- [x] **19. SRP width cap at wide viewports** — at `expanded` width, wrap
  `SrpScreen`'s existing grid/filter-bar content in a `maxWidth: 1200`
  `ConstrainedBox` (same cap Task 18 uses, for visual consistency between
  screens) so it doesn't stretch edge-to-edge on a large desktop window; no
  change below `expanded`. No change to the grid's own column-count logic
  (`SliverGridDelegateWithMaxCrossAxisExtent` already self-tunes) or the
  filter bar's `Wrap` (already reflows). **Test first:** widget test at an
  expanded width asserting the rendered content width is capped rather than
  filling the full test surface.

**Not in this loop (per SPEC.md, deliberately deferred):** Android
`platforms;android-XX` package install + the one real-device APK
verification pass — separate, confirm-before-install / near-project-end
step.

## Above-and-beyond additions (beyond parity scope — not Tasks 1–19)

- [x] **20. Malformed description entity-tag repair** — real Summit
  Subaru El Cajon listings (confirmed on stock `RH801775` and `PLE17159`)
  have a broken description-authoring template: `&ltb>...&lt/b>` instead
  of `<b>...</b>` (opening `<` entity-encoded without its semicolon,
  closing `>` left literal). `stripDescription`
  (`lib/models/transform_vehicle.dart`) already correctly parses/strips
  genuine tags via `package:html`, but a spec-compliant parser correctly
  treats this malformed sequence as literal text, not a tag — so it
  survives on-screen as visible `<b>`/`</b>` characters. This is not a bug
  (the reference React app's identical `DOMParser`/`textContent` approach
  would show the same artifact); it's a deliberate above-and-beyond
  deviation from strict parity, per the approved design
  (`docs/superpowers/specs/2026-07-11-description-entity-repair-design.md`).
  New private helper `_repairMangledEntityTags(String text)` —
  `text.replaceAll(RegExp(r'&lt(/?[A-Za-z]+)>'), '<\$1>')` — called at the
  top of `stripDescription`, before the existing `\n`-stripping step.
  Deliberately requires no semicolon between `&lt` and the tag name, so
  genuinely well-formed `&lt;` entities are left untouched. General
  letter-only tag-name pattern (not hardcoded to `b`/`i`) since the same
  dealer template bug could recur with a different tag elsewhere in the
  feed — confirmed systemic, not a one-off, since both captured examples
  share the identical broken opening blurb. **Test first:** in
  `test/models/transform_vehicle_test.dart`'s "description sanitization"
  group, using the existing `_raw(description: ...)` override helper:

  ```dart
  test('repairs a mangled entity-encoded tag (dealer authoring-tool bug) before stripping', () {
    final v = transformVehicle(
      _raw(description: r'&ltb>Why BUY from Summit Subaru El Cajon?&lt/b> Great car!'),
    );
    expect(v.description, 'Why BUY from Summit Subaru El Cajon? Great car!');
  });
  ```

  **Docs:** add a short bullet to `docs/SPEC.md`'s description-sanitization
  section documenting this as an intentional, documented deviation from
  strict reference-app parity (not an oversight).
  **Status:** DONE, committed `08dbf6f` (+ formatting follow-up `8ca4182`).
  Confidence 93/100. Review clean (1 Minor line-length nit, fixed via
  `dart format` in the follow-up commit).

- [ ] **21. Deploy the Flutter app itself to Vercel** — not required
  scope (`docs/context/original-request.md`'s submission mechanism is
  repo access + a mobile-lead review call, not a public deployment); JP
  explicitly asked for it as a deliberate above-and-beyond addition (a
  real shareable link, and the only way to view the app on Apple hardware
  since there's no native-iOS build possible on this Windows machine —
  real Android testing goes through a native `.apk` over USB/ADB instead,
  unrelated to this task). Per the approved design
  (`docs/superpowers/specs/2026-07-12-app-deployment-design.md`): same
  Vercel project as the already-deployed proxy (`api/inventory.ts`),
  since Vercel natively serves static files + `api/` functions together
  from one project and its own zero-config default already looks for a
  `public/` directory when no framework is detected (confirmed in the
  proxy's first deploy log). Build locally — Vercel's build container has
  no Flutter SDK and doesn't recognize Flutter as a framework, so
  building inside Vercel was considered and rejected as fragile. New
  `deploy` script in root `package.json`:
  ```json
  "deploy": "flutter build web --release --dart-define=API_BASE_URL=/api/inventory && rm -rf public && cp -r build/web public && vercel deploy --prod"
  ```
  `API_BASE_URL` is deliberately a **relative** path (`/api/inventory`,
  not the full prod URL) — the app and proxy become same-origin once both
  are served from this one project, so a relative path resolves correctly
  and doesn't hardcode the domain into the build. Add `public/` to
  `.gitignore` (generated on every deploy from `build/web`, itself already
  gitignored — never committed). **No TDD in the traditional sense** —
  this is build/deploy configuration, not new Dart logic, same category
  as Task 15b Half A's `package.json`/tooling additions. **Verification
  (functional, not automated):** run `npm run deploy`, then load the real
  production URL in a browser (not just `curl`) and confirm the SRP shows
  real inventory data, filters/paging work, VDP is reachable, the dealer
  name shows in the header (regression check), and the browser's network
  tab shows same-origin `/api/inventory` calls with no CORS
  preflight/error — the concrete proof the relative-URL decision was
  correct.

## End-to-end verification (once Tasks 1–13 done)

`flutter run -d web-server --web-port=8765`, open `http://localhost:8765`
manually, confirm SRP loads real data through the Vercel proxy, filters/
paging/URL-sync work, VDP reachable with all four states correct.
`flutter test` run in full after every task.
