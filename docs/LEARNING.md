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
