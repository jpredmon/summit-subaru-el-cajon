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
