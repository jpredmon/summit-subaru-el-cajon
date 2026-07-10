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

- [ ] **7. Filtering logic** — make / body style / price two-select
  (threshold list `[10000, 15000, 20000, 25000, 30000, 40000, 50000, 75000,
  100000]`, min/max mutual pruning) + price-null-exclusion rule. **Test
  first:** each dimension, pruning boundaries, null-exclusion combined with
  an active price filter.

- [ ] **8. Shared placeholder/broken-image widget** — used by SRP card
  (Task 9) and VDP carousel (Task 11); placeholder on empty list and on
  `Image.network` `errorBuilder`. **Test first:** widget test, both cases.

- [ ] **9. SRP screen** — card grid (photo/placeholder, year/make/model/
  trim, mileage, price/"Call for price", body style), tap-through stub,
  wired to Tasks 5–7; loading/error states; "Clear filters" on empty
  filtered results. **Test first:** card field rendering, "Call for price"
  branch, empty-filtered + Clear-filters flow.

- [ ] **10. Routing (`go_router`) + URL query-param sync** — SRP at `/`
  with filter/page state in query params; VDP route `/vehicle/:id` stub.
  **Test first:** query-param → state restore, state change → URL update.

- [ ] **11. Photo carousel widget** — current-index state, Previous/Next
  clamped (not wrapped), "X of Y" counter, per-index failure tracking
  (reuses Task 8). **Test first:** boundary clamp, counter text, per-index
  independent retry.

- [ ] **12. VDP screen** — header, spec table, features (bounded to 10,
  "Show all (N)"/"Show less", no section when empty), four states (loading/
  error/not-found/loaded) via local find-by-id on Task 5's cache, three-
  branch page title. **Test first:** one test per state, features boundary
  (0/≤10/>10), not-found → link-back flow.

- [ ] **13. Dark mode** — manual toggle, `shared_preferences`-backed,
  defaults dark on first launch, `ThemeMode` resolved pre-first-frame.
  **Test first:** default-dark with no stored pref; persist/restore toggle.

- [ ] **14. Accessibility & reduced motion** — focus-highlight decoration
  matching actual corner radius; `MediaQuery.disableAnimations` applied to
  all Task 9–13 animations. **Test first:** animations skipped when
  `disableAnimations` true. Keyboard/focus-traversal order (filters→cards→
  pagination→VDP→carousel→back) verified as a **documented manual
  checklist**, not an automated test — Flutter's widget-test harness doesn't
  simulate real Tab-key traversal across a full app well.

- [ ] **15. Native/web build-time base-URL wiring** — `main.dart`/`lib/
  config.dart` reads `API_BASE_URL`/`VINCUE_API_KEY` `--dart-define` values,
  constructs Task 4's client. **Test first:** resolver function mapping
  define values → `(baseUrl, attachApiKeyHeader)`, tested directly (no
  compiled build needed).

- [ ] **16. README/submission note** — caching/paging/filtering design +
  dev/build-architecture decisions (proxy vs. direct-VINCUE, `-d web-server`
  vs `-d chrome`). No test — documentation only.

**Not in this loop (per SPEC.md, deliberately deferred):** Android
`platforms;android-XX` package install + the one real-device APK
verification pass — separate, confirm-before-install / near-project-end
step.

## End-to-end verification (once Tasks 1–13 done)

`flutter run -d web-server --web-port=8765`, open `http://localhost:8765`
manually, confirm SRP loads real data through the Vercel proxy, filters/
paging/URL-sync work, VDP reachable with all four states correct.
`flutter test` run in full after every task.
