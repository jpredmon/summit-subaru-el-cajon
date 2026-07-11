# Learning log — vincue_mobile

Running, dated log of new Dart/Flutter concepts introduced task-by-task
during this build. Appended to, never overwritten.

## 2026-07-10 — Task 2: Data models

- **`factory` constructor.** A named constructor prefixed with `factory` doesn't
  have to create a fresh instance directly from an initializer list — it runs a
  body and returns one. That's why `RawVehicle.fromJson(...)` can do parsing
  work before calling the real `const` constructor. A normal (generative)
  constructor can't run statements like that.
- **`as` casts on dynamic JSON.** `jsonDecode` hands back `Map<String, dynamic>`,
  so each field needs a cast to its real type: `json['vin'] as String`. For a
  field that may be JSON `null`, cast to the nullable type instead —
  `json['vdpUrl'] as String?` — otherwise a null value throws at the cast.
- **`.cast<String>()` on a List.** Decoded arrays come back as `List<dynamic>`.
  `(json['features'] as List<dynamic>).cast<String>()` gives a `List<String>`
  view. Casting the list to `List<String>` directly would throw, because the
  runtime list object really is a `List<dynamic>` — `.cast()` wraps it safely.
- **`const` constructors + `final` fields.** All model fields are `final` and
  the constructor is `const`, so instances are immutable. `const` also lets the
  compiler canonicalize identical instances, which matters for widget rebuilds
  later.
- **`enum`.** `BodyCategory` is a plain Dart enum — a fixed set of named values.
  The transform (Task 3) will map messy `body` strings onto these, defaulting
  unknown values to `other`.
- **Fixture-backed tests + `setUpAll`.** `flutter test` runs on the Dart VM, so
  `dart:io`'s `File(...).readAsStringSync()` works and the working directory is
  the package root — a relative `test/fixtures/...` path resolves. `setUpAll`
  runs once before a group's tests (vs. `setUp`, once per test), so the 141-
  record fixture is parsed a single time and shared. This is how the real
  captured API response guards `fromJson` against future contract drift.

## 2026-07-10 — Task 3: RawVehicle → Vehicle transform

- **Top-level functions, no class.** Dart lets functions live at file top level
  (not everything must be in a class, unlike C#/Java). `transformVehicle`,
  `normalizeBodyStyle`, and `stripDescription` are plain library functions —
  the ones the UI/tests need are public, helpers get a `_` prefix (library-
  private).
- **`double.tryParse` vs JS `Number()`.** `double.tryParse('abc')` returns
  `null` instead of `NaN` — no separate finite check needed for the common
  case. Two gotchas: it does **not** trim surrounding whitespace (so trim
  first), and it *can* return `double.infinity` for `'Infinity'`, so a
  `.isFinite` guard is still worth keeping to match the source app exactly.
- **Null-aware chaining `?.toInt() ?? 0`.** `year` is a non-nullable `int` but
  parsing can fail. `_parseNumberOrNull(raw.year)?.toInt() ?? 0` reads: parse
  (nullable double) → if non-null call `.toInt()` → if the whole thing is null
  fall back to `0`. `?.` short-circuits on null; `??` supplies the default.
- **`Set.add` returns a bool.** `seen.add(x)` returns `true` only if `x` wasn't
  already present, so `if (trimmed.isNotEmpty && seen.add(trimmed))` dedupes and
  records in one step — the order-preserving idiom.
- **`html` package for text extraction.** `html.parse(input).body?.text`
  parses an HTML fragment and returns its text content with entities decoded
  (the Flutter equivalent of the web app's `DOMParser` + `.textContent`). The
  `body` getter is nullable, hence `?.text ?? ''`.
- **`RegExp` + `replaceAll`.** `str.replaceAll(RegExp(r'\s+'), ' ')` collapses
  whitespace runs; raw strings (`r'...'`) avoid double-escaping backslashes in
  the pattern. `replaceAll(r'\n', ' ')` with a plain string (not a RegExp)
  replaces the literal two-char backslash-n sequences the API embeds.

## 2026-07-10 — Task 4: InventoryApiClient

- **`Future` / `async` / `await`.** An `async` function returns a `Future<T>`
  immediately and resolves later; `await` suspends until a Future completes.
  Unlike C#, Dart does **not** suffix async methods with `Async` — `flutter
  analyze` would flag it — so it's `fetchInventory()`, not
  `fetchInventoryAsync()`.
- **Constructor initializer list + `assert`.** The `: _http = ..., assert(...)`
  after the constructor signature runs before the body. `assert`s are compiled
  out of release builds, so they're for catching programmer mistakes in dev
  (here: `attachApiKeyHeader` true but no `apiKey`), not for runtime input
  validation.
- **`implements Exception` for a typed error.** `InventoryApiException` is a
  plain class implementing the marker `Exception` interface. Callers catch it
  by type; `throwsA(isA<InventoryApiException>())` is the matching test matcher.
- **`is!` type check with flow promotion.** `if (decoded is! Map<String,
  dynamic> ...)` narrows the type afterward; assigning a nullable field to a
  local (`final key = apiKey; if (key != null) ...`) lets the analyzer promote
  `key` to non-null, avoiding a `!` assertion.
- **mocktail.** `class _MockHttpClient extends Mock implements http.Client {}`
  auto-stubs. `when(() => mock.get(any(), headers: any(named: 'headers')))
  .thenAnswer((_) async => http.Response(body, 200))` stubs a call;
  `.thenThrow(...)` simulates failure. `any()` on a non-primitive type (like
  `Uri`) requires `registerFallbackValue(...)` once in `setUpAll`.
  `verify(() => mock.get(captureAny(), ...)).captured.single` pulls out the
  actual argument passed, which is how the header/URL assertions work.

## 2026-07-10 — Task 5: Riverpod inventory provider

- **Manual (non-codegen) providers.** With `flutter_riverpod` alone (no
  `riverpod_generator`/`build_runner`), providers are top-level `final`s:
  `Provider<T>((ref) => ...)` for sync values, `FutureProvider<T>((ref) async
  => ...)` for async. `ref.watch(otherProvider)` composes them into a graph.
- **`FutureProvider` = the cache.** It runs its body once and caches the
  resulting `AsyncValue`; multiple reads share the one result (verified: the
  client's `fetchInventory` is called exactly once across several reads). This
  is the single-fetch-per-session behavior — no manual memoization needed.
- **Override-only provider for DI.** `inventoryApiClientProvider` throws
  `UnimplementedError` by default because its inputs are build-time. Tests do
  `ProviderContainer(overrides: [inventoryApiClientProvider.overrideWithValue
  (fake)])`; the app root will do the same with the real client (Task 15). This
  is Riverpod's dependency-injection seam.
- **`AsyncValue.value` vs `requireValue` (Riverpod 3).** `.value` returns `T?`
  — null during loading AND on error (no rethrow) — which is what
  `dealerNameProvider` wants (fall back, don't crash). `.requireValue` throws on
  loading/error. (The old `valueOrNull` name is gone in v3.)
- **Testing an error state.** `container.read(futureProvider.future)` does *not*
  reliably complete on error when nothing handles it (it hangs). The robust
  pattern: `container.listen(p, (_, _) {}, onError: (_, _) {})` to keep it alive,
  `await pumpEventQueue()` to drain the async work, then assert on
  `read(p).hasError` / `.error`. Also: use `(_, _)` (wildcards) for unused
  callback params — `(_, __)` trips the `unnecessary_underscores` lint.
- **`ProviderContainer` + `addTearDown`.** Each test builds its own container
  and registers `addTearDown(container.dispose)` so provider state never leaks
  between tests.

## 2026-07-10 — Task 6: Paging logic

- **Generic top-level functions.** `PaginatedResult<T> paginate<T>(List<T>
  items, int page, int pageSize)` — Dart generics on a bare function (no
  class needed) read just like TypeScript's, one of the more directly
  transferable pieces of syntax so far.
- **`num.clamp` returns `num`, not the original type.** `int.clamp(int,
  int)` has a same-type overload so `page.clamp(1, totalPages)` stays an
  `int`, but mixing an `int` with `double.infinity` (as in the `totalPages`
  calc) forces the result to `num`, hence the explicit `.toInt()` — a type a
  TS dev wouldn't think to check for since `Math.min`/`Math.max` don't have
  this split.
- **`List.sublist(start, end)` vs JS `.slice`.** Same semantics (end
  exclusive, clamped) but `sublist` throws `RangeError` if `end` is out of
  bounds instead of silently clamping like JS — hence the explicit
  `.clamp(0, items.length)` on `end` before calling it.

## 2026-07-10 — Task 7: Filtering logic

- **Set comprehensions for dedupe.** `{for (final v in vehicles) v.make}`
  builds a `Set<String>` directly (no intermediate `.map().toSet()` chain) —
  Dart's collection-for works inside set/map literals, not just lists.
  `.toList()..sort()` afterward (the cascade `..` chains a void-returning
  call onto the same list) gives sorted-unique in one expression.
- **Enum declaration order as "canonical order."** `BodyCategory.values` is
  a `List<BodyCategory>` in declaration order, so filtering it by
  `.where(present.contains)` gives "present styles, canonical order" for
  free — no separate ordering array needed (the web app hardcodes a
  parallel `BODY_CATEGORY_ORDER` array to get the same effect from a plain
  TS union type, which has no runtime ordering of its own).
- **Testing logic the reference app never tested.** The min/max price
  pruning exists only as inline JSX filter calls in the web app, with zero
  unit tests. Porting untested logic 1:1 isn't optional — the plan's own
  "Test first" line for this task named pruning boundaries explicitly, so
  the test cases here were derived from the SPEC.md prose rather than an
  existing test file to imitate.

## 2026-07-10 — Task 8: Shared placeholder/broken-image widget

- **`Image.network(url, ...)` vs `Image(image: NetworkImage(url), ...)`.**
  The former is a convenience constructor for the latter — identical
  runtime behavior. Taking the explicit form and making the `ImageProvider`
  itself an injectable parameter is what makes `errorBuilder` testable at
  all: without it, a widget test would need a real dead network URL (slow,
  flaky, actually hits the network from a test).
- **Forcing `errorBuilder` deterministically with `MemoryImage`.** Passing
  `MemoryImage(Uint8List.fromList([1, 2, 3]))` (garbage, not real image
  bytes) makes Flutter's decoder throw synchronously-ish — no `HttpOverrides`
  or network mocking package needed. A real 1x1 PNG's byte sequence (hardcoded
  in the test) proves the success path the opposite way.
- **`errorBuilder`'s error surfaces async.** Flutter resolves the image
  decode over a microtask/frame, so the test needs `await
  tester.pumpAndSettle()` after `pumpWidget` before asserting on which
  branch rendered — a single `pump()` isn't reliably enough.
- **`find.bySemanticsLabel`.** The widget-test equivalent of querying by
  accessible name/alt-text — matches this project's "test the semantics
  tree, not just visuals" approach used already for focus/ring accessibility
  goals in SPEC.md.
- **`Image` needs a `Key` per source to recover from a load error.**
  `_ImageState` memoizes its `ImageStreamListener` (and the error it
  captured) for the widget's lifetime; changing `image` alone re-resolves
  the stream but doesn't reliably clear stale error state on reuse. A
  distinct `key: ValueKey(url)` forces Flutter to discard the old State and
  build fresh — same reason the reference web app keys its carousel `<img>`
  by index. Found via a real test failure (photo recovered from a failed
  URL to a working one but stayed stuck on the placeholder), not by
  inspection — a reminder that "should work by reasoning about the docs"
  and "does work" are different claims for stateful widget internals.

## 2026-07-10 — Task 9: SRP screen

- **`Notifier`/`NotifierProvider` (mutable state) vs. `Provider`/
  `FutureProvider` (read-only/derived).** Every provider through Task 8 just
  computed a value from other providers. The SRP filter/page state is the
  first thing in this app a *user action* changes, so it needs a provider
  backed by a class with methods that reassign `state` — `Notifier<T>`
  (override `build()` to supply the initial value, call `state = ...` in
  methods to update it) paired with `NotifierProvider<MyNotifier, T>`. Riverpod
  rebuilds every widget watching that provider whenever `state` is reassigned.
- **`Override` isn't part of Riverpod 3.x's public API.** Tried to write a
  test helper typed `List<Override>` for provider overrides and it didn't
  compile — `riverpod.dart`'s barrel file exports a curated `show` list that
  leaves `Override` out, even though the class exists internally. The fix
  already used everywhere else in this codebase is the right one: never name
  the type, just pass an inline list literal straight to `ProviderScope`/
  `ProviderContainer`'s `overrides:` parameter and let Dart infer it from
  context.
- **`GridView.builder` only builds *visible* children.** A widget test
  asserting `findsNWidgets(12)` on a 12-item grid failed with "Found 3" —
  not a bug, just `GridView.builder`'s whole reason for existing (it doesn't
  build/lay out off-screen items, for real-world scroll performance). The
  fix is testing *which* items are present (e.g. does vehicle 12 show up
  after paging, does vehicle 0 disappear) rather than raw on-screen counts,
  which sidesteps viewport size entirely instead of fighting it.
- **Re-pumping the same widget shape with a new `ProviderScope` mid-test
  doesn't reliably swap state.** Calling `tester.pumpWidget()` twice in one
  test, each with a different `inventoryProvider` override, kept showing the
  *first* pump's data after the second — Flutter/Riverpod treat the second
  call as an update of the existing element tree rather than a fresh mount,
  and the already-resolved `FutureProvider` value doesn't reliably get
  invalidated by a new override arriving via widget update. Splitting into
  two independent `testWidgets` blocks (one `pumpWidget` each) sidestepped
  the ambiguity entirely, and is arguably the more correct test shape anyway
  (one behavior per test, per the project's TDD convention).
- **Testing a `DropdownButton` interaction.** Tap the button by `Key` to
  open its overlay menu, `pumpAndSettle()`, then tap the option's `Text` (use
  `.last` — the closed button's current-selection label can also match the
  same text), `pumpAndSettle()` again. No special Riverpod- or
  Flutter-version-specific handling needed beyond that sequence.

## 2026-07-10 — Task 10: Routing (`go_router`) + URL query-param sync

- **`Future(() {})` vs. `WidgetsBinding.instance.addPostFrameCallback`.**
  Both defer a call to "right after the current build" — but they're not
  interchangeable for testing. `Future(() {})` schedules a bare Dart
  microtask, invisible to Flutter's frame scheduler. `pumpAndSettle()` loops
  by checking whether a *frame* is still scheduled, not by draining every
  microtask, so a bare `Future` left over from the *last* build in a settle
  loop can go unflushed — the callback silently never runs, no error, no
  warning. `addPostFrameCallback` hooks into the actual frame-completion
  event, which `pump()`/`pumpAndSettle()` do track correctly. Found via a
  test that simulated a second in-app navigation (the same code path a
  browser back/forward-button press exercises) and asserted the restored
  filter state — it silently stayed unrestored with `Future(() {})`, and
  fixing it was a one-line swap once the actual mechanism was identified.
  General lesson: prefer `addPostFrameCallback` over a bare `Future`/
  `Future.microtask` for any "run after this build" deferral in Flutter,
  specifically because of how it interacts with test pumping — not just
  style preference.
- **Riverpod forbids mutating provider state during a widget lifecycle
  method.** `initState`/`build`/`didUpdateWidget` all count — Riverpod
  throws an explicit assertion ("Tried to modify a provider while the widget
  tree was building") rather than silently corrupting state, specifically
  because two widgets watching the same provider could otherwise observe
  different values mid-frame. The fix is always a deferral (see above), per
  the exact fix Riverpod's own error message suggests.
- **Bidirectional state↔URL sync needs a loop-breaker.** Two independent
  reactions — "URL changed → restore state" (`didUpdateWidget`) and "state
  changed → update URL" (`ref.listen`) — feeding into each other will
  infinite-loop without a guard. `_lastSyncedParams` (the last query-param
  map this widget itself produced, either direction) lets each reaction
  check "did I already account for this?" before acting, breaking the cycle
  without needing to special-case which direction triggered first.
- **`Override` (Riverpod's provider-override type) isn't in the public API
  in this version** — same finding as Task 9, confirmed again here: don't
  type a shared test helper's `overrides` parameter explicitly; always build
  `ProviderScope(overrides: [...], child: ...)` inline so Dart infers the
  type at the call site.
- **A stale test can reveal a real gap, not just go stale.** `widget_test.dart`
  (from Task 1) asserted the old stub text and would have failed the moment
  `main.dart` pointed at real screens — updating it to a genuine smoke test
  (renders `SrpScreen` via the real router, with `inventoryProvider`
  overridden) turned a throwaway placeholder into actual regression coverage
  for the app's boot path.
- **CORS is enforced per-origin, not per-deployment.** The reference React
  app's deployed `/api/inventory` Vercel function sets no CORS headers at
  all — it doesn't need to, because the app calling it is served from the
  *same* origin, and same-origin requests are never subject to CORS. Calling
  that same URL from a *different* origin (this Flutter app's own dev
  server) is a cross-origin request the browser will reject regardless of
  environment, confirmed via `curl` showing no `Access-Control-Allow-Origin`
  header on the response. A "it works for the reference app" URL doesn't
  transfer to a different consumer without its own CORS-safe deployment —
  this is exactly why Task 15 is real build/infra work, not just an env var.

## 2026-07-10 — Task 11: Photo carousel widget

- **Reusing Task 8's `VehiclePhoto` eliminated an entire category of new
  bugs.** The plan called out "per-photo-index failure tracking" as if it
  needed new state in the carousel, but `VehiclePhoto` already keys its
  internal `Image` per URL (Task 8's fix), so swapping `photoUrl` as the
  carousel's index changes is *itself* sufficient for a failed photo to
  retry independently when revisited — no extra `Map<int, bool>` or similar
  needed. Confirmed with two tests: navigating to a *different* index after
  a failure, and — added specifically to close a gap noticed while writing
  the confidence score — revisiting the *same* failed index later.
- **`TextButton` with real text labels can overflow a realistic phone
  width.** Mirroring the web app's "Previous photo"/"Next photo" text
  buttons overflowed by 104px even at 400 logical pixels wide (a plausible
  phone width, not just a narrow test fixture) — `TextButton`'s minimum tap
  target plus padding adds up fast for two multi-word labels plus a counter
  in one row. Switched to `IconButton` (chevron icons) with the same text
  as a `tooltip` (which still contributes an accessible name via semantics,
  just not visible chrome) — more compact, arguably more idiomatic for a
  carousel control, and exactly the kind of substitution SPEC.md's "design
  polish" section already sanctions (target *behavior*, not literal
  port). Found by testing at a real width, not by inspection.
- **`find.byTooltip(...)` finds the `Tooltip` widget, not the button inside
  it** — trying to read `.onPressed` off it directly threw a cast error.
  Wrap the lookup: `find.descendant(of: find.byTooltip(...), matching:
  find.byType(IconButton))`. Simpler alternative used here instead:
  `find.widgetWithIcon(IconButton, Icons.chevron_right)` — finds the button
  directly when the icon itself is unique enough to identify it, sidestepping
  the tooltip-vs-button distinction entirely.

## 2026-07-10 — Retroactive review fix pass (Tasks 6–11)

A full `/code-review` pass over everything committed so far (prompted by a
process gap — per-task review had been an inline self-check, not the actual
skill) surfaced 9 real findings, all fixed with a failing test first. Worth
recording as a set, not just individually:

- **`DropdownButton`'s "exactly one matching item" invariant is a live crash
  risk anywhere restored/external state feeds a dropdown's `value`.** Filter
  state restored from a URL (`SrpStateNotifier.restoreFrom`) was applied
  directly to `DropdownButton.value` with no check that the restored make/
  body/price is still one of the currently-offered items. A stale deep link,
  shared URL, or inventory turnover reaching this path crashes the screen.
  The fix is a small, reusable pattern: `_validValue(candidate, validOptions)`
  — display `null` ("no constraint") instead of a value absent from the
  actual `items` list, without touching the underlying stored filter (which
  still participates in real filtering). **General lesson:** any
  `DropdownButton`/`RadioListTile`/similar "value must be one of these
  items" widget fed by state that didn't come from that widget's own
  `onChanged` needs this same guard, not just this one screen.
- **`double.tryParse` accepts `"Infinity"`/`"-Infinity"`/`"NaN"` in Dart** —
  confirmed empirically, not assumed. A parser that only checks `== null`
  lets these through as real (non-finite) doubles. Always pair
  `double.tryParse` with an `.isFinite` check when the input is untrusted
  (URLs, user text, external APIs) — `transform_vehicle.dart`'s parser
  already did this; `srp_query_params.dart`'s didn't, and that was the gap.
- **`assert` is not a validation strategy for anything that must hold in a
  release build.** `InventoryApiClient`'s "apiKey required when
  attachApiKeyHeader is true" was `assert`-only, silently compiled out in
  release/profile mode. Moved to a real `if (...) throw ArgumentError(...)`
  in the constructor body (Dart doesn't allow arbitrary statements in an
  initializer list, so this needs a body, not just an `assert` swapped for
  something else in place). **General lesson:** `assert` is for catching
  programmer errors during development; anything that must be enforced for
  real users in a real build needs an actual runtime check.
- **A "self-correct invalid state" fix needs the same deferred-mutation
  pattern already established for the URL-sync code**, not a new one. A
  restored page number beyond the real total (given the current filters) is
  now corrected via `WidgetsBinding.instance.addPostFrameCallback` +
  `mounted` guard inside `_SrpBody` — the exact pattern `app_router.dart`
  already used for the same underlying Riverpod constraint (can't mutate a
  provider during build). Converting `_SrpBody` from `ConsumerWidget` to
  `ConsumerStatefulWidget` was required to get a `mounted` check at all.
- **Comparing against "what changed" instead of "what I already know about"
  is a common off-by-one in guard conditions.** The router's
  `didUpdateWidget` guard compared `oldWidget.queryParameters` vs
  `widget.queryParameters` (did the URL change at all) instead of
  `widget.queryParameters` vs `_lastSyncedParams` (is this a change I
  haven't already accounted for) — the former can't distinguish a
  self-triggered navigation (which always changes the URL) from a genuine
  external one, causing a redundant parse/restore round trip on every single
  filter change. Fixed with a call-counting `Notifier` subclass in the test
  (`_CountingSrpStateNotifier`) to prove the redundant call disappeared,
  since the wrong END state was never observable — only the wasted
  intermediate work was.
- **Let Riverpod's own caching solve a memoization problem instead of
  hand-rolling one.** `getFilterOptions` was recomputing on every SRP
  rebuild, including page-only changes that can't possibly affect it (it
  only depends on the loaded inventory, never on filters/page). Moving it
  into its own `Provider<FilterOptions>` that watches only `inventoryProvider`
  gets memoization for free — Riverpod skips recomputing a provider's body
  when nothing it watches has changed, no manual "cache + compare inputs"
  code needed. `filterVehicles` has a similar (smaller) inefficiency on
  page-only changes but was left as-is: splitting it out cleanly would need
  restructuring `srpStateProvider` itself, disproportionate effort for what's
  sub-millisecond at realistic dealership inventory sizes.
- **A `ValueKey` scoped to the wrong thing enforces a narrower invariant
  than intended.** `VehiclePhoto`'s per-URL key (Task 8) is correct for its
  own job, but `PhotoCarousel` swapping `photoUrl` alone means two different
  *indices* sharing an identical URL (a plausible dealer-feed duplication)
  would share failure/retry state — "per URL" by accident, not "per index"
  as intended. Giving the `VehiclePhoto` itself an index-based
  `key: ValueKey(_index)` in the carousel restores true per-index
  independence regardless of URL duplication.

## 2026-07-11 — Task 12: VDP screen

- **Conditional imports pick the platform-specific file at compile time, not
  runtime.** `import 'document_title_stub.dart' if (dart.library.html)
  'document_title_web.dart' as impl;` is Dart's built-in mechanism for "use
  this file on web, this other file everywhere else" — the condition
  (`dart.library.html`) is evaluated per compile target, so a native build
  never even sees `document_title_web.dart`'s contents and can't fail to
  compile a web-only import. This is different from a runtime `if (kIsWeb)`
  check, which would still need the web-only import physically present in
  that file for every target.
- **`dart:html` is soft-deprecated; `package:web` + `dart:js_interop` is the
  current idiomatic replacement.** `flutter analyze` flagged `dart:html`
  with two lints (`deprecated_member_use`, `avoid_web_libraries_in_flutter`)
  even though it still compiled and worked. Switching the web-only file to
  `import 'package:web/web.dart' as web; web.document.title = title;`
  cleared both — `package:web` is also the WASM-compatible path forward,
  which `dart:html` explicitly is not.
- **`flutter_riverpod`'s public barrel file doesn't export everything its
  own public API's types reference.** `ProviderScope.overrides` is typed
  `List<Override>`, but `flutter_riverpod.dart` re-exports `riverpod`'s
  internals through an explicit `show` clause that omits `Override` by
  name — so `import 'package:flutter_riverpod/flutter_riverpod.dart';
  List<Override> x = [];` fails to compile with "'Override' isn't a type,"
  even though the class exists and the field it types is public. The fix
  isn't importing it from elsewhere; it's not needing the name at all —
  every existing test in this codebase constructs `ProviderScope(overrides:
  [...], child: ...)` inline instead of declaring a helper with an explicit
  `List<Override>` parameter, sidestepping the gap entirely.
- **`AsyncValue.isLoading`/`.hasValue`/`.value` describe the three
  `FutureProvider` states without needing a manual state machine.** VDP's
  page-title logic needed to know, from one `AsyncValue<Inventory>`,
  whether the fetch is still in flight, has ever produced data, and (if so)
  what that data was — `isLoading`, `hasValue`, and `.value` cover exactly
  that, matching `AsyncValue.when`'s loading/error/data branches without
  re-deriving the same information a second way.
- **Dart's records (`(String, Widget)`) are a lightweight positional tuple,
  useful for "just needs to travel together, not be looked up by key."** A
  `Map<String, Widget>` built only to be immediately `.entries.map()`'d in
  insertion order was buying key-lookup machinery nothing in the code
  actually used; a `List<(String, Widget)>` destructured as `final (label,
  value) = entry;` in the `.map()` callback does the same job with one
  fewer concept and no risk of a duplicate key silently overwriting an
  entry.
