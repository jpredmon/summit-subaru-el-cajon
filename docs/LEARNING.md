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

## 2026-07-11 — Task 13: Dark mode

- **Awaiting a plugin before `runApp` is how Flutter avoids the "flash of
  wrong theme" the web version needed a duplicated inline script to work
  around.** `main()` is `async`, calls `WidgetsFlutterBinding
  .ensureInitialized()`, then `await SharedPreferences.getInstance()` —
  only once that resolves does `runApp` fire, with the loaded prefs handed
  in via `sharedPreferencesProvider.overrideWithValue(prefs)`. Because
  `ThemeModeNotifier.build()` reads that already-resolved value
  synchronously, `ThemeMode` is correct on the very first frame; there's no
  async gap to flash the wrong theme during, unlike a browser's JS module
  timing.
- **A `Provider` that throws `UnimplementedError` unless overridden is this
  codebase's established pattern for "no safe default, must be supplied by
  the caller"** (already used for `inventoryApiClientProvider`, Task 4).
  `sharedPreferencesProvider` follows the same shape: the real app overrides
  it once at the root with the awaited instance, and every test overrides it
  with `SharedPreferences.setMockInitialValues({})` +
  `SharedPreferences.getInstance()`.
- **A `Provider<T>` caches its value across rebuilds of unrelated watchers —
  which matters a lot once more than one provider is watched in the same
  `build()`.** `VincueMobileApp.build()` originally called `buildAppRouter()`
  inline. That was harmless while `themeMode` was a hardcoded literal (the
  widget never rebuilt), but once it started watching `themeModeProvider`
  too, every toggle reran `build()` and — since `buildAppRouter()` allocates
  a brand-new `GoRouter` each call — silently reset navigation back to `/`.
  Moving `buildAppRouter()` behind its own `Provider<GoRouter>`
  (`appRouterProvider`) fixes it: Riverpod computes it once and hands back
  the same instance on every subsequent read, so an unrelated provider
  changing no longer touches routing state at all. Caught by code review,
  not by TDD — worth remembering that "add a second `ref.watch` to an
  existing `build()`" is exactly the kind of change that can silently break
  something several lines away that looks unrelated.
- **`AppBar`'s automatic back arrow is keyed off `Navigator.canPop()`, not
  off whether the screen provides its own way back.** Adding a bare
  `AppBar()` to `VdpScreen` (reached via `context.push`, so `canPop()` is
  true) made Flutter insert a back arrow for free — but this app already had
  an explicit "Back to search results" button with different, intentional
  behavior (resets filters), so the two controls silently disagreed.
  `AppBar(automaticallyImplyLeading: false, ...)` opts out of the automatic
  one, leaving the explicit button as the only way back.

## 2026-07-11 — Task 18: VDP two-pane layout

- **`tester.view.physicalSize`/`.devicePixelRatio` simulate a specific
  viewport in a widget test.** `MediaQuery.sizeOf(context).width` (what
  `windowSizeClassOf` from Task 17 branches on) reads the *logical* size,
  which is `physicalSize / devicePixelRatio`. Setting both explicitly (e.g.
  `Size(1000, 800)` at ratio `1.0` → logical width 1000) is how a test
  forces a specific breakpoint deterministically, instead of depending on
  whatever the default test surface happens to be. `addTearDown(tester.view
  .reset)` restores the real test binding's default afterward so later tests
  in the same file aren't affected.
- **Extract-a-widget refactor to share a subtree across two layout branches,
  without duplicating the state that feeds it.** `_VdpDetails` pulls the
  "title through description" block (previously inline in `_VdpBodyState
  .build()`) into its own `StatelessWidget`, taking `featuresExpanded`/
  `onToggleFeatures` as constructor params. The `_featuresExpanded` bool
  itself stays owned by `_VdpBodyState` — only the *rendering* of it moved,
  not the state — so both the stacked (compact/medium) and side-by-side
  (expanded) arrangements build the identical widget instance from the same
  source of truth instead of two copies that could drift.
- **A `Key` placed purely for test identification is a normal, idiomatic
  Flutter pattern, not a smell.** `Row(key: const Key('vdp-two-pane-row'),
  ...)` exists solely so a widget test can assert "the two-pane layout is
  present" via `find.byKey(...)` without a fragile structural count (e.g.
  counting every `Row`/`Column` in the tree, which would also match
  unrelated internal widgets like `_SpecTable`'s `Wrap`).

## 2026-07-11 — Tasks 17–19 whole-branch review closeout

- **`Center` inside a vertical scroll view is safe — it shrink-wraps.**
  Wrapping the width-capped content in `Center` to horizontally center it
  (matching the web app's `mx-auto`) does *not* throw the usual "unbounded
  height" error, even though a `SingleChildScrollView` gives its child
  unbounded vertical space. `RenderPositionedBox` (behind `Center`/`Align`)
  auto-shrink-wraps whichever axis is unbounded, so it just sizes to the
  child vertically and centers horizontally within the bounded viewport
  width. (Contrast: `Column`/`Expanded` in unbounded height *do* throw — the
  shrink-wrap rule is specific to `Align`/`Center`.)
- **"No behavior change below `expanded`" applies to *where* you wrap.**
  First cut centered the whole VDP `content` (both branches) by wrapping the
  outer scroll child — but that would recenter the sub-expanded `maxWidth:
  800` layout at 801–839px viewports, a change below the `expanded`
  breakpoint the responsive spec forbids. Fix: scope the `Center` to the
  `expanded` branch's `ConstrainedBox` only, leaving compact/medium
  byte-for-byte unchanged. A responsive tweak's *scope* has to match the
  breakpoint it claims to touch.

## 2026-07-11 — Task 14a: Skeleton loading states

- **`FadeTransition` + one repeating `AnimationController` = a cheap group
  pulse.** Instead of animating every skeleton box, wrap the whole skeleton
  subtree in one `FadeTransition` driven by a single controller
  (`SingleTickerProviderStateMixin`, `..repeat(reverse: true)`). The opacity
  change happens in a compositing layer, so the child widget tree isn't
  rebuilt each tick — one ticker for the screen, not one per box. Always
  `dispose()` the controller in `State.dispose()`.
- **A forever-repeating animation makes `pumpAndSettle()` hang.**
  `pumpAndSettle` pumps frames until no animation is scheduled; a
  `..repeat()` animation is *always* scheduled, so it never returns (times
  out after 10 min → test failure). Assert on loading states with `pump()`
  (one frame) or `pump(duration)` instead. This is why the skeleton loading
  tests use `pumpWidget` + `expect` with no settle.
- **Share a `SliverGridDelegate...` via a top-level `const` so a placeholder
  grid can't drift from the real grid.** Extracting `_srpGridDelegate` and
  referencing it from both the real `GridView` and the skeleton `GridView`
  makes "the skeleton matches the real grid's columns" a structural
  guarantee, not a value that has to be kept in sync by hand.
- **`colorScheme.surfaceContainerHighest` is the theme-aware neutral fill.**
  Pulling the skeleton color from `ColorScheme` (same token the "no photo"
  placeholder uses) means it adapts to light/dark automatically — no manual
  grey that would break in dark mode.

## 2026-07-11 — Task 14b: Scoped error boundary

- **Flutter already catches a widget's own build-time exceptions per
  Element** — `ComponentElement.performRebuild` wraps `build()` in a
  try/catch and substitutes `ErrorWidget.builder`'s output for just that
  failing subtree, rather than letting the exception propagate up and take
  down ancestors. This is very different from React, where an uncaught
  render error crashes the whole tree unless you write an explicit
  class-component error boundary. The actual gap versus the web app wasn't
  "catch the exception" (Flutter does that for free) — it was that
  `ErrorWidget.builder`'s default output is an ugly debug red screen, and
  that builder is one process-wide static, so making the *fallback* friendly
  and *scoped* to routed content (not overriding it globally, which SPEC
  explicitly calls out as wrong because it'd also swallow chrome failures)
  needed a dedicated `ErrorBoundary` widget that swaps the static in
  `initState`/restores it in `dispose`.
- **`MaterialApp.router`'s `builder` sits *above* the Router's own
  `Navigator`/`Overlay` — not inside it.** Wiring the shared header there
  first seemed natural (wrap everything the router produces), but a
  `Tooltip` (which `IconButton`'s tooltip uses) needs an `Overlay` ancestor,
  and there wasn't one above the Router. Every widget test using
  `MaterialApp.router(routerConfig: ...)` directly failed with
  `debugCheckHasOverlay`. go_router's `ShellRoute` is the fix: it nests the
  shared shell *inside* the Router's own Navigator (as an ancestor of the
  nested Navigator it creates for switching between the shell's own child
  routes), so `Overlay` is available. Confirmed with a widget test comparing
  `ErrorWidget.builder`'s closure identity before and after navigating
  SRP→VDP — the shell's `State` is the same instance both times, proving
  `ShellRoute` doesn't tear it down per navigation (a version-drift risk in
  a future go_router upgrade, so that comparison is now a permanent
  regression test, not just a one-off check).
- **A regression test has to exercise the real wiring, not just the
  widget in isolation.** The first cut of `app_shell_test.dart` wrapped
  `AppShell` in a bare `MaterialApp(home: ...)`, which supplies its own
  internal `Navigator`/`Overlay` regardless of how the real app wires
  things — so it would have kept passing even if the real router wiring
  regressed back to the broken `MaterialApp.router(builder: ...)` approach.
  Closing that gap needed a second test built on the actual
  `buildAppRouter()` output.

## 2026-07-11 — Task 14c: Accessibility & reduced motion

- **`FocusableActionDetector` vs. `InkWell`'s own built-in focus.**
  `InkWell` is already focusable and already activates on Enter/Space, so
  layering a second focus-managing widget outside it (for a themed focus-ring
  decoration matching the actual corner radius, since Flutter doesn't need
  the web app's CSS-outline-can't-follow-border-radius workaround) risks
  creating *two* tab stops for one card — one on the outer detector, one on
  the inner InkWell. Fix: give the outer `FocusableActionDetector` the real
  `FocusNode`, and the inner `InkWell` `canRequestFocus: false` so it keeps
  handling pointer taps/ripple but drops out of keyboard traversal entirely.
  Taking focus away from `InkWell` also takes its default Enter/Space
  handling with it, so that needed re-wiring explicitly via
  `actions: {ActivateIntent: CallbackAction(...)}`.
- **`onShowFocusHighlight` needs `FocusHighlightMode.traditional` to fire
  true, and the test harness defaults to touch-mode.** `FocusableActionDetector`
  only reports the highlight as "shown" when `FocusManager`'s highlight mode
  is keyboard-style (`traditional`), which it infers from recent input
  history — in a widget test, with no real keyboard/pointer events, that
  history defaults to `touch`. `focusNode.requestFocus()` alone doesn't
  change that. The test has to force it:
  `FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional`
  (and restore it in `addTearDown`, since it's a process-wide static like
  `ErrorWidget.builder` was in Task 14b).
- **`NoSplash.splashFactory` is the direct way to respect
  `MediaQuery.disableAnimations` for an `InkWell`'s ripple** — it swaps the
  animated spreading splash for an instant static one. There's no
  app-wide/theme-level "disable all ink animations" switch; each `InkWell`
  needs its `splashFactory` set conditionally.
- **A `didChangeDependencies` re-check, not just `initState`, is what makes
  `disableAnimations` gating live-reactive.** `SkeletonPulse`'s
  `AnimationController` used to always `..repeat()` from its field
  initializer; gating that decision in `didChangeDependencies` instead means
  toggling the OS/browser's reduced-motion setting while a skeleton is
  already on screen stops (or restarts) the pulse immediately, not just on
  next mount.
- **SPEC deviation, noted rather than silently absorbed:** SPEC's reduced-
  motion bullet mentions gating "carousel photo transition," but `PhotoCarousel`
  never got an animated transition in this build — advancing photos swaps
  the `Image` instantly (confirmed: no `Animation`/`Transition`/`Tween` in
  `photo_carousel.dart` or `vehicle_photo.dart`). There's nothing to gate;
  SPEC's wording assumed a transition that was never added. Everything else
  the bullet lists (skeleton pulse, card ripple/hover) is gated.
- **Keyboard/focus-traversal order is a documented manual checklist, not an
  automated test** (`docs/manual-checklists.md`) — Flutter's widget-test
  harness can drive individual focus/keyboard interactions (as the tests
  above do) but doesn't simulate real Tab-key sequencing across a full
  running app well enough to assert the whole filters→cards→pagination→
  VDP→carousel→back path in one automated pass.

### Two review-caught bugs, both confirmed against the Flutter SDK source directly

Both of these were flagged by the required per-task review, verified against
`/c/dev/flutter/packages/flutter/lib/src/...` (this machine's actual SDK,
3.44.6) rather than taken on trust, and fixed before the task was closed out
— worth logging because both are non-obvious enough to recur.

- **Flutter Web's Enter key fires a different Intent than every other
  platform.** `WidgetsApp._defaultWebShortcuts` (`widgets/app.dart`) maps
  Enter to `ButtonActivateIntent`, not `ActivateIntent` — "on the web, enter
  activates buttons, but not other controls" is the SDK's own comment for
  it. `InkWell` handles both (`ink_well.dart`'s `_actionMap` binds both to
  the same callback) as long as it still owns focus, but once `VehicleCard`
  moved focus to the outer `FocusableActionDetector` (`canRequestFocus:
  false` on InkWell), only whatever intents *that* widget's `actions` map
  binds are reachable — `Actions.invoke` searches upward from the currently
  focused node, and InkWell's own binding sits *below* the now-focused node,
  so it's structurally unreachable regardless of what it handles. Registering
  only `ActivateIntent` meant Enter worked in every test (`flutter test`
  always runs with `kIsWeb == false`, so it never exercises
  `_defaultWebShortcuts`) but would have silently done nothing on the actual
  deployed web build. Fix: bind both intents to the same callback. Because
  `kIsWeb` is a compile-time constant, no widget test can toggle it — the
  only way to test the fix is to invoke `ButtonActivateIntent` directly via
  `Actions.maybeInvoke` and check the side effect, not the return value
  (`CallbackAction.onInvoke` returning `null` by convention makes the return
  value useless as a "was it handled" signal either way).
- **A `key:` on a `GridView.builder`/`ListView.builder` item does nothing by
  itself.** Converting `VehicleCard` to a `StatefulWidget` (for the Task 14c
  focus-highlight state) meant a filter/page change that reindexes the
  vehicle list could silently carry one vehicle's focus state onto a
  different vehicle now occupying the same grid slot — Flutter's
  `SliverChildBuilderDelegate` reconciles builder-based children by
  *position*, not identity, by default. Adding `key: ValueKey(vehicle.id)`
  to the built `VehicleCard` looked like the fix but changed nothing: per
  `scroll_delegate.dart`, `SliverChildBuilderDelegate.findIndexByKey` returns
  `null` — deliberately disabling key-based reconciliation — unless a
  `findChildIndexCallback` is *also* supplied to map a key back to its
  current index. A regression test proving this (comparing `Element`
  identity before/after a filter change via `tester.element(...)`, not just
  checking rendered output) failed even with the key in place, which is what
  surfaced the missing callback. Both pieces are required together.

## 2026-07-11 — Task 15: Native/web build-time base-URL wiring

- **`String.fromEnvironment('X')` reads a `--dart-define=X=...` value at
  *compile* time, not runtime — and returns `''` (empty string), never
  `null`, when the define wasn't supplied.** This is different from reading
  an environment variable at runtime (there's no such thing for a compiled
  Flutter app); the value gets baked into the binary during `flutter build`/
  `flutter run --dart-define=...`. Because it's never `null`, a resolver
  function mapping these raw values to typed config has to explicitly treat
  `''` as "not configured" itself (`apiKey.isEmpty ? null : apiKey` in
  `lib/config.dart`) — nothing does that normalization for you.
- **`kIsWeb` (from `package:flutter/foundation.dart`) is the compile-time web
  check**, used here to decide `attachApiKeyHeader` (SPEC: the proxy build
  attaches no client-side key; the native build does, since CORS is a
  browser-only concern). Keeping the resolver itself as a pure function
  taking `isWeb` as a parameter (rather than reading `kIsWeb` directly
  inside it) is what makes "tested directly, no compiled build needed"
  possible — the test passes `true`/`false` for both branches without
  needing two separate compiled targets.
- **Verified the wiring with a real `flutter build web`, twice — once with
  `--dart-define`s supplied, once without** — not just the isolated unit
  test importing `config.dart` directly. This is the cheap-verification
  habit from Tasks 14b/14c: unit tests prove the pure function's logic, but
  only an actual compile proves `main.dart`'s `String.fromEnvironment` +
  `ProviderScope` override wiring is accepted by the real build pipeline.
  Both builds succeeded.
- **The web build's actual CORS proxy deployment (a new Vercel function,
  per SPEC — not a reuse of the reference React app's) is explicitly out of
  scope for this task**, per JP's call: this task covers only the Dart-side
  resolver + wiring, which works with any `API_BASE_URL` value regardless of
  what serves it. Deploying the proxy is a separate follow-up needing a
  Vercel account/CLI login and the real API key as a secret.
- **`Provider.overrideWithValue` vs. `Provider.overrideWith` — eager vs.
  lazy, and it mattered here.** The first cut built `InventoryApiClient`
  inline in `main()` and installed it via `overrideWithValue`, which
  constructs the value immediately, before `runApp()`/`ProviderScope` even
  exist. `InventoryApiClient`'s constructor deliberately throws
  `ArgumentError` for a misconfigured native build (an existing, intentional
  "fail loudly at construction" design from Task 4) — but doing that
  construction eagerly turned a graceful, in-app failure into an uncaught
  crash before any UI could render at all. `overrideWith((ref) => ...)`
  defers construction to the first actual read, which happens inside
  `inventoryProvider`'s `FutureProvider` body — the same place any other
  inventory-fetch failure is already caught and turned into an `AsyncError`
  the SRP/VDP screens' existing `error:` branches handle. Same fix pattern
  as Task 14b's `ErrorBoundary`/`ShellRoute` lesson: *where* a throw happens
  in the widget/provider tree determines whether something already built to
  catch it actually gets the chance to.
- **Riverpod wraps a provider's creation-time throw in its own
  `ProviderException`** (`package:flutter_riverpod/misc.dart`, not exported
  from the main library) when read via `container.read`/`ref.watch` — the
  original exception is its `.exception` field. A test asserting on the
  thrown type has to account for this wrapping (`isA<ProviderException>()
  .having((e) => e.exception, 'exception', isA<...>())`), not just
  `throwsA(isA<OriginalType>())`.
- **A required per-task review caught this eager-vs-lazy override bug** (two
  finder agents independently, from different angles) before commit — same
  "verify testable things directly" instinct as Tasks 14b/14c: rather than
  just reasoning about whether the fix was safe, a test proving the
  `ProviderContainer` constructs without throwing (only reading it throws),
  plus a second test proving `inventoryProvider` itself resolves to
  `AsyncError` rather than propagating an uncaught exception, verified the
  actual end-to-end behavior.

## 2026-07-11 — Task 15b: Vercel CORS-proxy (Half A)

- **A file under `api/` in a repo deployed to Vercel becomes an HTTP
  endpoint automatically** — no routing config needed, the file path *is*
  the URL path (`api/inventory.ts` → `/api/inventory`). The function runs
  server-side, so it's the right place to hold a secret API key a browser
  should never see: the browser calls the proxy, the proxy calls the real
  API with the key attached server-to-server.
- **CORS (Cross-Origin Resource Sharing) is a browser-only restriction** —
  it blocks a web page from calling an API on a different origin unless
  that API opts in via an `Access-Control-Allow-Origin` response header.
  Native apps (this project's Android build) aren't browsers, so they never
  hit it and call the real API directly; only the Flutter *web* build needs
  this proxy, and only because it runs inside a browser tab. This is why
  the reference React app's own already-deployed proxy couldn't be reused
  here (Task 10/15 notes): it sets no CORS header because it's only ever
  called same-origin by that app, and a browser rejects a cross-origin read
  of a response with no `Access-Control-Allow-Origin` regardless of what's
  actually in the body.

## 2026-07-11 — Bug fix: dealer name missing from the header (found during Task 15b's first live-data test)

- **A browser's "blocked by CORS policy" console error doesn't always mean
  a CORS misconfiguration.** Any failed cross-origin fetch with no
  `Access-Control-Allow-Origin` header gets reported this way — including
  when the *real* cause is a plain server error. One vehicle photo's URL
  turned out to return HTTP 500 (broken link on VINCUE's own image CDN,
  confirmed with a direct `curl -I`), and its error page carried no CORS
  header the way the CDN's successful 200 responses do. The fix wasn't a
  fix at all: `VehiclePhoto`'s existing `errorBuilder` (Task 8) already
  falls back to the placeholder for exactly this case.
- **`AppShell`'s `AppBar` never had a `title:`, so the dealer name was
  invisible in the UI despite being fetched and derived correctly** —
  it only ever reached `setDocumentTitle` (the browser tab title), a
  separate SPEC requirement that was already satisfied. `docs/SPEC.md:379`
  requires the dealer name in the page **header** too, matching the
  reference app's visible header span. This is the kind of gap that's
  invisible in isolated widget tests (they use fixture data, so "no title"
  and "fallback title" and "real title" all look the same at a glance) but
  jumps out immediately the first time real data flows through the app —
  a good argument for testing against a real backend early, not just at
  the very end.
- **Converting a `StatelessWidget` to a `ConsumerWidget` moves any provider
  read outside whatever error boundary wraps only its `child`.** Fixing
  the dealer-name gap meant `AppShell` itself now calls
  `ref.watch(dealerNameProvider)` — but `AppShell`'s own `ErrorBoundary`
  only wraps its `child` parameter (the routed screen), not `AppShell`'s
  own `build()` body. That's currently safe only because
  `dealerNameProvider` is deliberately built to never throw (reads
  `.value`, never `.requireValue`), which is now called out in the class
  doc comment as a documented precondition rather than an invisible one.
- **`.gitignore` patterns use last-match-wins, including across
  negations.** `vercel link` auto-appended a bare `.env*` line *after* an
  existing `!.env.example` negation, silently re-ignoring `.env.example`
  for any future `git add` (confirmed with `git check-ignore -v
  --no-index .env.example`, which is the correct way to test this — the
  default index-aware `check-ignore` masks the problem for files already
  tracked, which is what made it easy to miss). Fix was just reordering:
  any negation needs to be the *last* matching pattern for a path to
  actually win.
- **A multi-angle code review (8 parallel finder agents, each reading the
  diff independently) caught two real, fixable issues that a single review
  pass likely would have missed** — the `.gitignore` ordering bug and the
  missing AppBar overflow guard were each found by only one or two of the
  eight angles. Three separate angles also converged independently on the
  same minor test-duplication observation, which is a useful cross-check
  signal on its own (independent agreement without shared context is worth
  more than one agent stating something with high confidence).

## 2026-07-12 — Task 22: Summit Subaru header logo

- **Flutter's asset system (`pubspec.yaml` assets + `Image.asset`).**
  Flutter doesn't auto-discover files in the project the way a web
  build tool might glob a folder — every image/font/data file bundled
  into the app has to be explicitly listed under `flutter: assets:` in
  `pubspec.yaml` (a plain list of file paths, relative to the project
  root). Once listed, `Image.asset('path/to/file.png')` in widget code
  loads it — the framework packages the declared files into the app
  bundle at build time and looks them up by that exact path string at
  runtime. This project's `pubspec.yaml` shipped with this section
  commented out (part of the default `flutter create` template), so the
  Summit Subaru logo is the first real asset this app has registered.
  Useful side effect: `flutter_test`'s widget tests resolve `Image.asset`
  the same way the real app does, as long as the asset is declared in
  `pubspec.yaml` and present on disk — no special test-only asset
  mocking needed.

## 2026-07-12 — Custom fonts + partial `TextTheme` override

- **Bundling a custom font needs no package** (no `google_fonts`) — just
  the actual `.ttf`/`.otf` file declared under `pubspec.yaml`'s `fonts:`
  section (`family:` name + a list of `fonts:` file paths, optionally
  with `weight`/`style` for other cuts of the same family), same
  mechanism as the `assets:` section used for the logo image. Google
  Fonts' own CSS API (`fonts.googleapis.com/css2?family=<Name>`) points
  at the real static file on `fonts.gstatic.com` — fetching that CSS with
  a plain-text `User-Agent` (rather than a modern browser one) returns a
  `.ttf` link instead of `.woff2`, which is what Flutter's font-bundling
  actually wants.
- **`ThemeData.copyWith` + a base `TextTheme.copyWith` is how to override
  only *some* text styles' font family, not the whole app.** Applying
  Anton (matched to the logo's bold condensed lettering) to every string
  in the app would hurt readability in dense areas (prices, descriptions,
  spec tables) — a display font is meant for short, prominent text.
  Building `ThemeData` once with Material 3's defaults, then
  `.copyWith(textTheme: base.textTheme.copyWith(headlineSmall: ...,
  titleLarge: ..., titleMedium: ...))` overrides only the font-family on
  those three roles while every other property (size, weight, letter
  spacing) Material 3 already computed for that role stays correct —
  much safer than hand-building a whole custom `TextTheme` from scratch.

## 2026-07-12 — `Semantics(image: true)` vs. a semantically-meaningful child

- **A child widget with its own auto-generated semantics (like `Text`)
  can silently override an ancestor `Semantics` node's label, with no
  error thrown.** `Semantics(label: 'No photo available', image: true,
  child: ...)` worked fine when its child was a plain `Icon` (decorative,
  no semantic content of its own). Adding a `Text` widget as a descendant
  broke it — the compiled semantics tree (what `find.bySemanticsLabel`
  actually queries, *not* the widget tree `debugDumpApp()` shows) dropped
  the outer label entirely. No exception, no warning; the only way to see
  it was inspecting the real compiled tree directly
  (`tester.binding.rootPipelineOwner.semanticsOwner
  ?.rootSemanticsNode?.toStringDeep()`), not just reading the widget tree
  or trusting that "the Semantics widget is there" means "the label
  survives." **Fix:** wrap purely decorative content in
  `ExcludeSemantics` so it contributes nothing to the compiled tree, and
  the one meaningful ancestor label is what a screen reader actually
  gets. Lesson for any future composite decorative widget (image + label
  text meant to announce as one unit): decide up front whether the
  children should be excluded, not just assume nesting `Semantics`
  concepts composes safely by default.

## 2026-07-12 — Riverpod 3.x's built-in automatic retry (Task G1, retry button)

- **`FutureProvider`/`AsyncNotifier` retry automatically with a backoff
  `Timer` by default in Riverpod 3.x** — a failed provider doesn't just
  sit in an error state waiting to be manually invalidated; the framework
  itself re-runs the provider's build a number of times with increasing
  delays. While a retry is scheduled, the provider's `AsyncValue` is
  `AsyncLoading(..., retrying: true)` carrying the error, **not**
  `AsyncError` — so `.when()`'s default `loading:`/`error:`/`data:`
  branching routes to `loading:`, not `error:`, until retries are
  exhausted. This is invisible from reading the widget code; it only
  showed up as a real testing problem (see below).
- **`tester.pumpAndSettle()` waits for pending `Timer`s, including that
  retry backoff** — a widget test simulating "fails once, succeeds on
  retry" via a call-counter override raced against Riverpod's own
  automatic retry consuming the "second attempt" before the test's
  manual button tap ever happened, silently corrupting the test's
  intended sequencing (found by direct debugging — printing the actual
  attempt count and the real semantics/widget tree — not guessed).
- **Fix: `ProviderScope`/`ProviderContainer` takes an explicit `retry:
  (int retryCount, Object error) => Duration?` parameter** — returning
  `null` disables automatic retry for that scope entirely. Used in tests
  that need to control exactly when each fetch attempt happens (like
  testing a manual "Retry" button in isolation) without the framework's
  own retry racing ahead. Confirmed by reading Riverpod's actual source
  (`element.dart`'s `origin.retry ?? container.retry ??
  ProviderContainer.defaultRetry`), not assumed from documentation.

## 2026-07-12 — Masonry grid layout (Task 28: SRP grid bottom-gap bug)

- **A `GridView`'s cell height is decided *before* any child is laid
  out** — `SliverGridDelegateWithMaxCrossAxisExtent`'s `mainAxisExtent`/
  `childAspectRatio` fixes every cell in a row to the same height up
  front, then each child is squeezed into that box. That's fine when
  every card's content genuinely scales with its width — it doesn't
  here: `VehicleCard`'s photo scales proportionally (`AspectRatio(4/3)`),
  but its text block doesn't (near-fixed line count, occasionally
  wrapping one extra line at narrow widths). The true needed-height
  relationship is *affine* (`height ≈ 0.75×width + textHeight`), not
  proportional — so no single ratio through the origin can be correct at
  every column width: it under-predicts (overflow) at narrow widths and
  over-predicts (a visible empty gap) at wide ones. Confirmed by directly
  measuring `VehicleCard`'s own natural height at several widths via
  `tester.getSize()` in a throwaway test, not by guessing a constant.
- **`flutter_staggered_grid_view`'s `MasonryGridView`** sidesteps this
  entirely: each item is laid out at its own *natural* height first
  (photo + however many text lines it actually needs), then packed into
  whichever column has the least height so far — a real two-pass
  measure-then-place algorithm, not a predicted one. `MasonryGridView
  .custom` (not `.builder`) is needed to pass a full `SliverChildBuilder
  Delegate` with `findChildIndexCallback` — `.builder` doesn't expose
  that parameter, and it's what keeps a `VehicleCard`'s focus-highlight
  `State` attached to the right vehicle (not the right grid slot) across
  a filter change (Task 14c's fix). `SliverSimpleGridDelegateWithMax
  CrossAxisExtent` mirrors the same column-count math as the `GridView`
  delegate it replaced, so the self-tuning responsive column count is
  unchanged.
- **Trade-off worth naming:** masonry packing means row edges no longer
  align perfectly across columns when card heights genuinely differ
  (e.g. one card's metadata line wraps and a neighbor's doesn't) — a
  deliberate, honest trade for "every card fits its own content exactly,
  every time" over "every card matches a predicted height most of the
  time."
