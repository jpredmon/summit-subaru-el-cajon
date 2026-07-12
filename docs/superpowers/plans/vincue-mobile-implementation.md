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

- [x] **16. README/submission note** — caching/paging/filtering design +
  dev/build-architecture decisions (proxy vs. direct-VINCUE, `-d web-server`
  vs `-d chrome`). No test — documentation only.
  **Status:** DONE. `README.md` rewritten in full, mirroring the reference
  app's README structure/tone per its own precedent: setup (web/native/
  proxy), the CORS-bug architecture section, dev-environment notes,
  design notes (caching/paging/filtering/data-transform/dark-mode-
  deviation/visual-design), process notes (TDD/confidence-scoring/dual-
  review/live-verification/systematic-debugging), an honest "Known
  limitations" section (G1/G2/G3 from the polish backlog, dead photo
  links, real-Android-device pass not yet done), and the existing git-
  init-late development note kept as-is. All factual claims spot-checked
  against `docs/SPEC.md`/the actual codebase before writing, not just
  written from memory (e.g. the exact `Access-Control-Allow-Origin: *, *`
  duplicated-header wording, confirmed `.env.example` exists).

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

- [x] **21. Deploy the Flutter app itself to Vercel** — not required
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
  **Status:** DONE. Config committed `1cba737` (confidence 92). Deployed
  live at **`https://flutterinventory.vercel.app`** — verified both via
  `curl` (app root 200, `/api/inventory` 200 same-origin) and by JP
  directly in a browser: real data, dealer name in header, navigation
  working. One known cosmetic console error persists (the already-
  diagnosed VINCUE broken-photo-link CORS artifact, stock photo
  `1413439848`) — confirmed to reproduce identically from this production
  origin too, proving it's upstream data quality, not environment-
  specific.

- [x] **22. Summit Subaru El Cajon header logo** — above-and-beyond
  branding, not core parity: replaces the plain `Text(dealerName)` AppBar
  title (added last session, commit `f01e873`) with JP's custom-designed
  logo (`assets/images/summit_subaru_logo.png`, 1460×824, transparent
  background, already in place and confirmed via pixel-level alpha
  check). Per the approved design
  (`docs/superpowers/specs/2026-07-12-header-logo-design.md`): the logo
  always shows regardless of the live `dealerName` value (a deliberate
  divergence from `docs/SPEC.md`'s "live dealer name in the header"
  requirement — documented as an intentional deviation, not silently
  overridden). `ref.watch(dealerNameProvider)` in `lib/widgets/
  app_shell.dart` stays exactly as-is (not deleted) and now feeds a
  `Semantics(label: dealerName, ...)` wrapper around the logo image, so
  screen readers still announce the live dealer name even though sighted
  users see the fixed graphic. No new dependency — `Image.asset`, not
  `flutter_svg`. `AppBar`'s `toolbarHeight` increases from Flutter's 56px
  default to roughly 72-80px so "SUMMIT SUBARU"/"El Cajon" stay legible
  rather than squeezed; exact value confirmed visually, same iterative
  process used for the logo's own design. Dark mode is **not** removed
  (explicitly considered and rejected — real regression risk against
  already-shipped, SPEC-required, tested functionality); confirm the
  logo's own colors (navy/gold/red/green) read acceptably against both
  the light and dark AppBar background as-is.
  1. **`pubspec.yaml`** — declare the asset under `flutter: assets:`
     (currently the default commented-out template; this is the first
     real asset this project adds):
     ```yaml
     flutter:
       uses-material-design: true
       assets:
         - assets/images/summit_subaru_logo.png
     ```
  2. **`lib/widgets/app_shell.dart`** — change:
     ```dart
     appBar: AppBar(
       title: Text(dealerName, maxLines: 1, overflow: TextOverflow.ellipsis),
       actions: const [ThemeToggleButton()],
     ),
     ```
     to:
     ```dart
     appBar: AppBar(
       toolbarHeight: 76,
       title: Semantics(
         label: dealerName,
         child: Image.asset('assets/images/summit_subaru_logo.png', fit: BoxFit.contain),
       ),
       actions: const [ThemeToggleButton()],
     ),
     ```
     (`toolbarHeight: 76` is a starting value — adjust visually once
     rendering if the logo looks cramped or the AppBar looks
     disproportionately tall.)
  3. **`docs/SPEC.md`** — short bullet in the "Dealer name" section
     documenting this as an intentional above-and-beyond deviation:
     the header shows a fixed branded logo rather than live dealer-name
     text, with the live value still driving the image's accessibility
     label.
  **Test first:** in `test/widgets/app_shell_test.dart`, using the
  existing `ProviderScope`/`inventoryProvider` override pattern already
  in that file — assert an `Image` widget is present in the `AppBar`
  (`find.byType(Image)` or matching on the asset path via
  `find.byWidgetPredicate`), and assert a `Semantics` node carrying the
  live `dealerName` as its label exists (`find.bySemanticsLabel
  ('Summit Subaru El Cajon')` or equivalent). **Real uncertainty to
  verify, not assume:** `Image.asset` in `flutter_test`'s widget-test
  environment needs the asset actually registered in `pubspec.yaml` *and*
  present on disk to resolve during a test run — confirm this actually
  works (test passes for the right reason, not because the assertion is
  vacuously true) before treating the task as done.
  **Status:** DONE, committed `7820066`. Confidence 93/100. Review clean
  — verified `Image.asset` genuinely resolves in `flutter_test` (RED/
  GREEN confirmed, not assumed), full suite (237 tests) + `flutter
  analyze` clean. The two pre-existing tests asserting the old `Text
  (dealerName)` title were correctly replaced (that widget no longer
  exists after this change; the live-dealerName-reaches-the-UI behavior
  they covered now lives in the new Semantics-label assertion) — a
  necessary consequence of the approved design, not a gap. Remaining
  uncertainty (`toolbarHeight`, logo legibility/contrast in both themes)
  is visual and needs JP's own look at the running app.

- [x] **23. Favicon** — above-and-beyond, config-only, no testable logic
  (same TDD exception as Task 1's scaffolding). JP generated a favicon
  package (favicon.io) from the finished logo. Replaced Flutter's default
  template icons in place — same filenames, so no `index.html`/
  `manifest.json` changes needed: `favicon-96x96.png` → `web/favicon.png`,
  `web-app-manifest-192x192.png` → `web/icons/Icon-192.png`,
  `web-app-manifest-512x512.png` → `web/icons/Icon-512.png` (dimension-
  matched to `manifest.json`'s declared `"sizes"` exactly). Verified
  byte-for-byte against source via `cmp`. The two maskable-icon files
  (`Icon-maskable-192.png`, `Icon-maskable-512.png`) are left as Flutter's
  defaults — the generated package didn't include maskable-safe variants.

- [x] **24. Disable dark mode (force light, keep infrastructure intact)** —
  above-and-beyond decision, not a bugfix: the header logo's palette
  (navy/gold/red/green) doesn't read well against the dark theme, and no
  time budgeted to also tune dark-mode contrast for it. Per JP's explicit
  call: `lib/main.dart`'s `VincueMobileApp` now hardcodes
  `themeMode: ThemeMode.light` instead of `ref.watch(themeModeProvider)`;
  `lib/widgets/app_shell.dart`'s `AppBar` no longer includes
  `ThemeToggleButton` in `actions`. **Deliberately not deleted:**
  `themeModeProvider`/`ThemeModeNotifier`
  (`lib/providers/theme_mode_provider.dart`), its `shared_preferences`
  persistence, and the standalone `ThemeToggleButton` widget — all fully
  intact and still tested in isolation
  (`test/widgets/theme_toggle_button_test.dart`, unaffected since it
  builds the button standalone, not through `AppShell`). Re-enabling later
  is a one-line change back to `ref.watch(themeModeProvider)`, not a
  rebuild. Documented in `docs/SPEC.md`'s "Dark mode" section as an
  explicit deviation. **No new tests** (this removes UI surface rather
  than adding behavior) — instead, updated the tests that broke because
  `ThemeToggleButton` is no longer in `AppShell`'s tree:
  `test/widgets/app_shell_test.dart` (two tests, now check the header
  logo `Image` survives instead of tapping the toggle) and
  `test/router/app_router_test.dart` (the ShellRoute/Tooltip-ancestry
  regression test, now checks the logo renders across SRP↔VDP navigation
  instead of the toggle — the `ShellRoute` wiring it guards is unchanged,
  only which widget exercises it). `test/widget_test.dart`'s
  `themeModeProvider`-toggling regression test is untouched and still
  passes — it exercises the provider directly, not the UI toggle. Full
  suite (242 tests) + `flutter analyze` clean.

- [x] **25. Header/title font matched to the logo (Anton)** —
  above-and-beyond polish, not core parity: JP asked for a font that
  resembles the "SUMMIT SUBARU" lettering in the logo, matched to
  **Anton** (Google Fonts / SIL OFL, free to bundle, no licensing
  concern) after visually inspecting the logo's bold condensed
  all-caps letterforms. Scoped to headline/title `TextTheme` roles only
  (`headlineSmall`, `titleLarge`, `titleMedium`) — not applied app-wide,
  since a display font hurts readability in dense areas (prices,
  descriptions, spec tables); body/label roles keep the default font.
  `assets/fonts/Anton-Regular.ttf` (downloaded from Google Fonts'
  `fonts.gstatic.com`) declared under `pubspec.yaml`'s `fonts:` section.
  `lib/theme/app_theme.dart`'s `_base()` now builds a Material 3 default
  `ThemeData` first, then `.copyWith(textTheme: ...)` overrides only the
  font-family on those three roles, preserving every other
  Material-3-computed property (size, weight, spacing) for each role.
  Applied to both light and dark `ThemeData` (dark is currently
  force-disabled per Task 24, but kept consistent for whenever it's
  re-enabled). **Test first:** `test/theme/app_theme_test.dart` — asserts
  `headlineSmall`/`titleLarge`/`titleMedium`.`fontFamily` is `'Anton'` on
  both `AppTheme.light()` and `AppTheme.dark()`, and that
  `bodyMedium`/`bodySmall`/`bodyLarge` are explicitly NOT `'Anton'`
  (confirms the scope boundary, not just the positive case). Full suite
  (245 tests) + `flutter analyze` clean.
  **Follow-up fix (same day):** JP spotted prices (and other tabular
  numeric displays) looking "scrunched" — `vehicle_card.dart`'s price
  Text bolds an already-Anton `titleMedium` base via `tabularNumsStyle`,
  and Anton's condensed numeral glyphs don't suit `FontFeature
  .tabularFigures()`'s fixed-width digit alignment. Fixed at the single
  shared point every numeric display already routes through:
  `tabularNumsStyle` (`lib/theme/app_theme.dart`) now always forces
  digits back to `_kDefaultFontFamily` ('Roboto'), regardless of the
  base style's own font — fixes prices, mileage, mpg, and page counters
  everywhere at once, no per-call-site changes needed. Test-first
  (3 new cases in `test/theme/app_theme_test.dart`: overrides Anton away,
  still applies tabular figures, preserves the base fontSize). Full suite
  (248 tests) + `flutter analyze` clean.

- [x] **26. "Vehicle Image Not Available" placeholder** — above-and-beyond
  polish, not core parity: replaces `_PlaceholderPhoto`'s generic car icon
  (`lib/widgets/vehicle_photo.dart`) with the branded logo + "Vehicle Image
  Not Available" (Anton font) on a white background, per JP's own design.
  Built as a real Flutter widget composition (`Image.asset` logo + `Text`
  in a `Column`, wrapped in `FittedBox(fit: BoxFit.contain)`), not a baked
  static image — scales cleanly across both contexts this placeholder
  shows in (a small SRP card thumbnail and the larger VDP carousel) from
  one implementation. **Real accessibility bug found and fixed during
  this task, not guessed at:** the child `Text` widget's own
  auto-generated semantics node conflicted with the outer
  `Semantics(image: true, ...)` wrapper, and the compiled semantics tree
  silently dropped the `"No photo available"` label entirely (found via
  direct semantics-tree inspection — `tester.binding.rootPipelineOwner
  .semanticsOwner` — not a guess, and not a caught/thrown error, which is
  what made it non-obvious). Fixed with `ExcludeSemantics` wrapping the
  decorative logo+text content, so only the one meaningful outer label
  reaches screen readers. **Test first:** `test/widgets/vehicle_photo_test
  .dart` — new case asserts both the logo `Image` and the exact placeholder
  text render; two pre-existing tests updated (`find.byType(Image),
  findsNothing` → `find.bySemanticsLabel('Vehicle photo'), findsNothing`)
  since an `Image` now legitimately exists in the placeholder itself.
  Also updated `test/router/app_router_test.dart`'s ShellRoute regression
  test to scope its `Image` finder to the `AppBar` specifically, since an
  unscoped `find.byType(Image)` became ambiguous once the placeholder
  (shown for the test's photo-less fixture vehicle) started using the
  same logo image as the header. Full suite (249 tests) + `flutter
  analyze` clean.
  **Follow-up (same day, approved before implementing this time):** JP
  found the placeholder text too small. Measured the actual logo asset
  directly (`System.Drawing` pixel scan) rather than guessing — the red
  ribbon spans 1308 of the logo's 1460px intrinsic width (~90%). Text
  now sized to 80% of that same 1460px width via `SizedBox` +
  `FittedBox(fit: BoxFit.fitWidth)` (text auto-scales to exactly fill
  that width, no fixed font size), reading as "as wide as the ribbon, a
  little smaller than SUMMIT SUBARU" from real measured geometry rather
  than a guessed number. New test asserts the exact `SizedBox` width
  (`1460 * 0.80`) and `FittedBox.fit`. Full suite (250 tests) + `flutter
  analyze` clean.

## End-to-end verification (once Tasks 1–13 done)

`flutter run -d web-server --web-port=8765`, open `http://localhost:8765`
manually, confirm SRP loads real data through the Vercel proxy, filters/
paging/URL-sync work, VDP reachable with all four states correct.
`flutter test` run in full after every task.

- [x] **27. Retry action on fetch failure (G1)** — above-and-beyond
  polish, not core parity: promoted from the G1 backlog entry in
  `docs/superpowers/plans/above-and-beyond-candidates.md`. Both
  `lib/screens/srp_screen.dart` and `lib/screens/vdp_screen.dart` showed
  a static `Text('Failed to load inventory. Please try again later.')`
  on fetch failure with no recovery besides a full page reload. New
  shared `lib/widgets/inventory_error_view.dart` (`InventoryErrorView`,
  the same message + a "Retry" button) replaces both screens' inline
  error `Center(Padding(Text(...)))`, wired to `onRetry: () =>
  ref.invalidate(inventoryProvider)` in each. **Real Riverpod 3.x
  behavior discovered and worked around, not guessed at:** the framework
  auto-retries a failed `FutureProvider` with its own backoff `Timer` by
  default, and `pumpAndSettle()` waits for that timer too, silently
  racing ahead of a test's own controlled failure/success sequencing —
  found via direct debugging (real attempt counts, real semantics tree),
  confirmed by reading Riverpod's actual source, fixed with
  `ProviderScope(retry: (retryCount, error) => null)` in the two tests
  that need deterministic control over exactly when each fetch attempt
  resolves. Documented in `docs/LEARNING.md`. **Test first:**
  `test/widgets/inventory_error_view_test.dart` (message + button render,
  tapping calls `onRetry`) plus one test per screen confirming the
  button is wired to a real `inventoryProvider` invalidate-and-refetch
  that replaces the error state with loaded content on success (VDP's
  version also confirms it's genuinely the *loaded* state, not the
  separate not-found state, which would also clear the error text). Full
  suite (254 tests) + `flutter analyze` clean.

- [x] **28. SRP grid bottom-gap bug fix** — real bug, not above-and-beyond
  polish: JP reported (with a screenshot) that narrowing the browser
  width left a growing empty gap underneath the price on every SRP card.
  Root cause: `_srpGridDelegate` (`lib/screens/srp_screen.dart`) used a
  fixed `mainAxisExtent: 340`, but `VehicleCard`'s photo scales
  proportionally with column width (`AspectRatio(4/3)`) while its text
  block doesn't — so at narrower widths the card's real content fell
  well short of the fixed 340px cell. **First fix attempt (approved,
  then reverted after it broke other tests):** a single `childAspectRatio
  : 280/340` scales height proportionally with width, but proved
  mathematically wrong — the true needed-height relationship is affine
  (proportional photo + near-fixed text), not proportional, so a single
  ratio through the origin *always* misses at some width (verified: it
  fixed the reported gap but introduced a 7.1px `RenderFlex` overflow at
  a different, narrower width used by three existing tests). **Actual
  fix:** replaced the fixed-cell `GridView` with `flutter_staggered_grid
  _view`'s `MasonryGridView` — each card now sizes to its own real
  content height instead of a predicted one. New dependency, a deliberate
  exception to this project's otherwise-minimal dependency list (see
  bird's-eye architecture review) because a masonry layout is genuinely
  the correct tool here, not an unneeded convenience. `MasonryGridView
  .custom` (not `.builder`) used specifically to preserve the existing
  `findChildIndexCallback` (Task 14c's focus-highlight-state fix — not
  exposed on `.builder`). Skeleton loading grid (`_SkeletonCard`) updated
  to match: its photo placeholder switched from a fixed `height: 200` box
  to the same `AspectRatio(4/3)` the real card uses, so loading and
  loaded states stay visually consistent. **New concept:** masonry grid
  layout — documented in `docs/LEARNING.md`. **Test first:**
  `test/screens/srp_screen_test.dart` — updated the existing delegate
  test for `MasonryGridView`/`SliverSimpleGridDelegateWithMaxCrossAxis
  Extent`, and added a new regression test that renders the grid at a
  360px-wide viewport (forcing the exact narrow column width that wraps
  the default fixture's mileage/body-style line to two lines) and
  compares the grid-rendered card's height against the same card's own
  natural (unconstrained) height at that width — proof the reported gap
  is actually gone, not just that nothing threw. Full suite (255 tests) +
  `flutter analyze` clean.
  **Confidence: 92/100.** Verified rather than assumed that the reported
  failure mode is structurally impossible now, not just untriggered in
  the test I wrote: read `flutter_staggered_grid_view`'s
  `RenderSliverMasonryGrid` source directly (`sliver_masonry_grid.dart`)
  — each child is laid out with a cross-axis-only `BoxConstraints`
  (`parentUsesSize: true`, no forced main-axis extent), meaning every
  card gets exactly its own natural height, never a shared/stretched row
  height. A "gap under the price" requires a taller box than the card's
  own content around that individual card — which this layout cannot
  produce, by construction, unlike the old fixed-cell `GridView`. What's
  still uncertain (visual only, not correctness): the masonry packing
  algorithm (shortest-column-first) means row *edges* can drift slightly
  out of alignment across columns when neighboring card heights genuinely
  differ — not a bug, but a real visual trade-off JP hasn't seen yet.
  What could fail downstream: none of the app's other screens/tests touch
  `_srpGridDelegate` or `GridView` directly (confirmed via grep — no
  other production or test file references either), so this is scoped
  cleanly to the SRP grid. How to verify further: JP checking the running
  app at the same narrow width from the original bug report.
  **Review (8-angle, high effort, 1-vote verify):** 8 findings survived
  verification, 6 fixed directly — `semanticChildCount` wasn't defaulted
  by `MasonryGridView.custom` the way `GridView.builder` defaulted it
  (real accessibility regression, fixed); `SliverSimpleGridDelegateWith
  MaxCrossAxisExtent.getCrossAxisCount` doesn't clamp to at least 1 the
  way the Flutter SDK's own delegate did (a zero-width layout pass could
  divide by zero downstream — fixed with a small clamping subclass,
  `_ClampedMaxCrossAxisExtentDelegate`); grid spacing and the photo
  aspect ratio were duplicated as independent literals instead of shared
  constants (fixed — `_srpGridSpacing`, `kVehiclePhotoAspectRatio`); the
  new regression test only proved "no exception," not that the actual
  reported gap closed, and a `vehicle_card_test.dart` docstring
  contradicted its own still-height-capped fixture (both strengthened).
  Two findings judged no-change-needed: reviewers independently
  identified that a same-file fix (`maxLines: 1` on the mileage/body-
  style line) could have avoided the new dependency entirely — correct
  as far as it goes, but verified during the original design discussion
  that it wouldn't have been a complete fix either (the underlying
  photo-proportional/text-fixed relationship is affine, not
  proportional, so even single-line text leaves real residual overflow
  risk at ~140–150px columns); this exact tradeoff was already presented
  to and decided by JP before implementation, not a gap the review
  surfaced fresh. The second (correctness now leans on a third-party
  package's internal, undocumented layout behavior) is a real, honestly-
  named risk accepted for this project's scope, not fixed. Full suite
  (255 tests) + `flutter analyze` clean after all fixes.

- [x] **29. Pagination controls overflow (G3)** — real bug, not
  above-and-beyond polish: `above-and-beyond-candidates.md`'s G3 entry,
  reproduced again live while JP tested Task 28's grid fix at narrow
  widths. Root-caused via `systematic-debugging` before any fix attempt
  (not guessed): `_PaginationControls`' `Row` (Previous / "Page N of M" /
  Next) has three non-flexible children whose combined natural width
  (measured directly via `tester.getSize`, ~400px) can't shrink to fit
  narrow viewports — a `Row` never shrinks non-flex children, it just
  overflows once their sum exceeds available space. Fix: replaced `Row`
  with `Wrap` (`lib/screens/srp_screen.dart`), the same pattern
  `_FilterBar` and `_EmptyResults` already use elsewhere in this file for
  the identical class of problem. **A code review caught a real
  regression the initial fix shipped:** `Wrap` shrink-wraps to its own
  content width instead of filling its parent the way `Row`'s default
  `mainAxisSize: MainAxisSize.max` did, so on any viewport wide enough
  for the controls to fit on one line, they rendered flush-left instead
  of centered — `WrapAlignment.center` alone only centers within `Wrap`'s
  own already-shrunk box, a no-op when nothing has wrapped. Fixed by
  wrapping in `Center`. **Test first (both the bug and the review's
  catch):** `test/screens/srp_screen_test.dart` — a 320px-viewport
  regression test for the overflow itself (chosen specifically to avoid
  also triggering a separate, unrelated `DropdownButton` overflow found
  during investigation — see below — and verified against the pre-fix
  code: confirmed it fails with a 118px overflow on the old `Row`, passes
  on the new `Wrap`), plus a second test asserting the controls'
  horizontal center matches the page's actual content center at a wide
  viewport (this one first confirmed RED against the `Center`-less
  `Wrap`, at `x=218.975` instead of the expected `x=400`, before the fix).
  Full suite (257 tests) + `flutter analyze` clean.
  **Also found, not fixed, newly documented:** a second, previously
  "not yet identified" overflow noted in the original G3 backlog entry
  is a `DropdownButton` internals issue (Flutter's own code, not app
  code) in `_FilterBar`, triggering below ~300px of available width —
  confirmed independent of this bug (reproduces on the old pagination
  code too), deliberately left out of scope for this task, now recorded
  in `above-and-beyond-candidates.md`'s G3 entry instead of silently
  dropped.
  **Confidence: 90/100.** What was uncertain and how it was closed: my
  first regression test used a 200px viewport (matching the original
  bug report's spirit) but that width also triggered the unrelated
  dropdown bug, conflating two defects in one test — caught by actually
  running the test and reading its failure, not assumed; narrowed to
  320px and verified that width still exercises the real fix (reverted
  the source change via `git stash` and confirmed the old code fails
  there too, rather than trusting a width picked by feel). The
  centering regression itself was NOT something I found — an independent
  code review caught it via direct empirical measurement of the rendered
  widget tree; I verified the finding was real (reproduced the 218.975
  vs 400 discrepancy myself) before fixing it, rather than accepting the
  finding on faith. What could still fail downstream: the wrap-grouping
  asymmetry the same review flagged (at exactly 320px, "Previous" lands
  alone on its own line while "Page N of M"/"Next" share the second) is
  a real but minor cosmetic quirk of `Wrap`'s greedy packing algorithm,
  not fixed — accepted as a minor, honestly-named trade-off, same
  treatment as Task 28's masonry row-alignment note.
