# vincue_mobile

A Flutter/Dart port of [VincueInventoryChallenge](../VincueInventoryChallenge) — a VINCUE dealer inventory browser (search results grid + vehicle details page) targeting Flutter Web and Android, built for full feature parity with the finished web app: caching, paging, filtering, dark mode, accessibility, and resilience UX.

**Live:** https://flutterinventory.vercel.app

## Status

Core scope (Tasks 1–21 in `docs/superpowers/plans/vincue-mobile-implementation.md`) is complete, plus several above-and-beyond additions (custom branding, a matched display font — Tasks 22–25). Built task-by-task under a strict TDD + confidence-scoring + dual-review loop (see this project's `CLAUDE.md`). See the plan file for the full task-by-task history and status of everything, including what's intentionally still open (below).

## Setup

**Web** (the primary dev loop on this machine — see [Dev environment](#dev-environment--build-architecture) for why):

```bash
flutter pub get
flutter run -d web-server --web-port=8765 --dart-define=API_BASE_URL=<proxy-or-direct-url>
```

Open `http://localhost:8765` manually (see below for why `-d web-server` instead of `-d chrome`). `API_BASE_URL` needs a running proxy behind it for the web build — either `https://flutterinventory.vercel.app/api/inventory` (the deployed one) or a local `vercel dev` instance (see the proxy's own setup below).

**Native Android** — no proxy needed; the native build calls VINCUE directly:

```bash
flutter run -d <device-id> --dart-define=API_BASE_URL=https://pro.vincue.com/api/Inventory/ActiveInventory?dealerID=54222 --dart-define=VINCUE_API_KEY=<real-key>
```

**The proxy itself** (`api/`, only needed if redeploying it or running it locally):

```bash
npm install
cp .env.example .env
# edit .env and set VINCUE_API_KEY to a real key
npm test          # vitest, the proxy's own tests
vercel dev        # serve it locally
npm run deploy    # build the Flutter app + deploy both together to Vercel
```

## Architecture: the CORS bug (and this app's two build targets)

Same root cause as the reference React app: VINCUE's API sends `Access-Control-Allow-Origin: *, *` — the header twice — on both the preflight and the actual `GET`, which browsers reject outright on any cross-origin call, confirmed with `curl` and independent of how the API key is handled. No browser build can call VINCUE directly, full stop.

Flutter's two build targets hit this differently, and the app resolves it with one build-time switch rather than two code paths (`lib/config.dart`):

- **Web** — browser-subject to CORS like any web app, so it needs the same kind of relay the reference app uses: `api/inventory.ts`, a Vercel Node serverless function (handler logic in `api/_inventoryHandler.ts`), with `Access-Control-Allow-Origin: *` added — the one real difference from the reference app's own proxy, which sets no CORS header at all because it's only ever called same-origin by that app. **This had to be this app's own separate deployment**, not a reuse of the reference app's URL — confirmed by `curl` that pointing at the reference app's proxy from a different origin gets rejected. As of Task 21, this app's own compiled Flutter web build is deployed to the *same* Vercel project as the proxy (`public/` alongside `api/`), so in production they're actually same-origin with each other.
- **Native Android** — not a browser, so CORS doesn't apply at all; the native build calls VINCUE directly with the API key attached client-side, no proxy involved.

## Dev environment & build architecture

- **Dev machine:** Windows, tight free RAM — no Android emulator for iterative development. Primary dev/review loop is Flutter web, in a resizable browser window.
- **`-d web-server`, not `-d chrome`:** Flutter's automated Chrome launch (`flutter run -d chrome`) repeatedly failed to connect on this machine — a startup-timing race under RAM pressure between Chrome's multi-process launch and Flutter's debug-port-connect timeout, not a broken install (confirmed: a manually-launched isolated Chrome instance connects to the debug protocol fine). Workaround, adopted as the standing workflow: `flutter run -d web-server --web-port=8765`, then open `http://localhost:8765` manually — no Flutter-managed browser launch, so no race. Hot reload still works normally. CORS applies identically either way, so the proxy is still required regardless of launch method.
- **iOS: not attempted** — explicitly out of scope (`docs/SPEC.md`), and not buildable from this Windows machine regardless (Flutter's iOS toolchain needs Xcode on macOS).
- **Real Android device pass:** planned as a one-time, near-the-end verification step (borrowed physical device, not an emulator) — not yet done as of this note. Everything else (Flutter web, the proxy, both deployed) has been verified live, repeatedly, against real VINCUE data.

## Design notes

- **Caching:** a single Riverpod `FutureProvider` (`inventoryProvider`) fetches once per session; SRP and VDP both read the same cached value — confirmed via code review (not just assumed from the provider's design) that a third, later consumer (the header logo's accessibility label) adds zero additional fetches.
- **Paging & filtering:** both run client-side against the one cached response — VINCUE's API has no server-side paging or filtering to call into, so this is the correct architecture for the API's actual shape, not a simplification of a "real" paginated design. Filters (make, body style, price range — a two-select min/max pair, not a single control) and the current page live in `go_router`'s URL query params, shareable and refresh-survivable, same as the reference app's URL-param approach.
- **Data transform:** `lib/models/transform_vehicle.dart` narrows and normalizes the raw ~48-field VINCUE payload into a clean `Vehicle` type before anything touches the UI (price floor + Porsche-$1 sentinel handling, body-style normalization, mpg gating, description HTML sanitization). One addition beyond the reference app: real Summit Subaru El Cajon listings have a dealer-side authoring-tool bug — a malformed HTML entity pattern (`&ltb>...&lt/b>` instead of `<b>...</b>`) that a spec-compliant parser correctly treats as literal text, not a tag, so it would otherwise survive on-screen as visible `<b>`/`</b>` characters. `_repairMangledEntityTags` fixes this before parsing — a deliberate above-and-beyond deviation from strict parity (the reference app would show the same artifact), documented in `docs/SPEC.md`.
- **Dark mode:** implemented in full (manual toggle, `shared_preferences`-persisted, defaults dark) but **currently force-disabled** — an above-and-beyond branding decision, not a bug: the custom header logo's palette doesn't read well against the dark theme, and no time was budgeted to also tune dark-mode contrast for new branding added late in the build. The entire mechanism (`themeModeProvider`, `ThemeModeNotifier`, persistence, the `ThemeToggleButton` widget) is untouched and fully functional — re-enabling is a one-line change (`lib/main.dart`) back to reading the provider, not a rebuild. Documented as an explicit deviation in `docs/SPEC.md`.
- **Visual design:** a custom "Summit Subaru El Cajon" logo (sunburst-behind-a-mountain emblem — hand-designed for this build, not a stock asset) in the header in place of plain dealer-name text, and a matched bold condensed display font (Anton, Google Fonts/SIL OFL) applied to headline/title text only — not app-wide, since a display font hurts readability in dense areas like the VDP spec table and vehicle descriptions. Both are above-and-beyond additions beyond the reference app's own visual design, documented as deviations in `docs/SPEC.md`.

## Process notes

Built with the same rigor as the reference React app, adapted for a task-loop workflow:

- **Real TDD** for logic-bearing code (the data transform, pagination/filtering math, URL-state sync, the proxy handler, theme configuration) — test written and watched fail for the *expected* reason before any implementation.
- **Confidence scoring after every task**, grounded in what actually happened during implementation (not a pre-estimate), specifically calling out what's uncertain and how it could be verified — several tasks iterated based on their own honest self-assessment before review even started.
- **Two-stage review after every task:** spec compliance against `docs/SPEC.md`, then code quality (idiomatic conventions, no dead code, no unnecessary abstraction) — via an independent reviewer (a fresh subagent or the `/code-review` skill), never self-graded.
- **Live verification over assumption, repeatedly.** This caught real issues that reading the code alone wouldn't have: a `.gitignore` ordering bug that silently re-ignored a tracked file, a missing `AppBar` overflow guard on unbounded dealer-name text, a Riverpod typing gap in `flutter_riverpod`'s public API (documented in `docs/LEARNING.md` so it doesn't get rediscovered from scratch), and — most notably — a fully-implemented header feature (the live dealer name) that turned out to have never actually been visible in the UI, only caught once real API data flowed through the app for the first time and a real developer looked at the running page.
- **Systematic debugging, not guess-fixing**, for real bugs: a "CORS error" on one vehicle photo turned out to be an upstream 500 from VINCUE's own CDN (confirmed via direct `curl`, not assumed); a malformed HTML-entity pattern in real descriptions was root-caused against the actual WHATWG parsing spec before writing a fix, and confirmed systemic (not a one-off) against a second real listing before generalizing the fix.

## Known limitations

- **A real layout bug, found but not yet fixed:** `_PaginationControls`' `Row` (`lib/screens/srp_screen.dart:333`) overflows at narrow real-device widths (confirmed on a real Samsung Galaxy S20 Ultra) — logged with full console evidence in `docs/superpowers/plans/above-and-beyond-candidates.md` (item G3), needs root-cause investigation before a fix, deliberately not guessed at.
- **No retry action on a failed initial fetch** — the error state is a static message; recovering means a full page reload. Logged as G1 in the same backlog file; a small, well-understood fix (`ref.invalidate(inventoryProvider)` behind a visible button), just not built yet.
- **No disk-level image cache** — Flutter's in-memory image cache covers one session; a cold app relaunch re-downloads every vehicle photo. Logged as G2; would need `cached_network_image` or equivalent.
- **A handful of VINCUE photo links are dead** (confirmed via direct `curl` — real upstream 500s, not a bug in this app) — `VehiclePhoto`'s existing placeholder fallback (Task 8) already handles this gracefully.
- **The real Android device verification pass hasn't happened yet** (see [Dev environment](#dev-environment--build-architecture) above) — everything else has been verified live, repeatedly, but native-specific rendering/touch behavior is the one thing only a real device can confirm.

## Development notes

**Git wasn't initialized until partway through the build (Task 8).** My setup process for this project — pulling the spec, plan structure, and reference implementation from a sibling project rather than a from-scratch `flutter create` — was new to me, and version control wasn't part of what got carried over. It went unnoticed until I asked directly whether anything had been committed yet.

Once caught, I initialized the repo and reconstructed history as accurately as I could: a single baseline commit for the work already done (Tasks 1–5, where I no longer had the exact intermediate diffs), then precise per-task commits from Task 6 onward, including separate follow-up commits for confidence-raising test additions and one real bug fix a confidence-ideation pass caught.

I've since updated my global Claude Code instructions (`~/.claude/CLAUDE.md`) to make `git init` the mandatory first step of any new project, with per-task commits pre-authorized in a task-loop workflow, so this doesn't happen again.

## Tech stack

Flutter/Dart · Riverpod · go_router · `http` · `shared_preferences` · `html` (description sanitization) · Vercel (Node serverless proxy + static hosting) · `vitest` (proxy tests) · `flutter_test`/`mocktail` (app tests)
