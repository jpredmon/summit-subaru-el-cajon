# Summit Subaru El Cajon

**Live:** https://flutterinventory.vercel.app

A Flutter/Dart port of [VincueInventoryChallenge](../VincueInventoryChallenge) — a VINCUE dealer inventory browser (search results grid + vehicle details page) targeting Flutter Web and Android, built for full feature parity with the finished web app: caching, paging, filtering, dark mode, accessibility, and resilience UX.

## Status

Full core scope (SRP + VDP parity, caching, paging, filtering, dark mode built but disabled, accessibility, resilience UX) plus a long list of extra polish is complete — 42 numbered tasks in `docs/superpowers/plans/vincue-mobile-implementation.md`, including a real-device (Pixel 2) verification pass, a disk-level photo cache, VDP carousel swipe gestures, and a real production bug (a `flutter_staggered_grid_view` layout crash under filtering) found and fixed. Built task-by-task under a strict TDD + confidence-scoring + dual-review loop (see this project's `CLAUDE.md`). Real-device/browser `integration_test` E2E coverage was added for two flows (large-inventory scroll/filter and fetch-failure/retry) once the widget-test suite alone was shown not to catch everything.

See the plan file for the full task-by-task history. Small deferred items and optional extras not yet picked up live in `docs/superpowers/plans/possible-to-dos.md`.

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
- **Real Android device pass:** done, repeatedly — a connected physical Pixel 2 (not an emulator), used both for manual verification (real touch/scroll, several UI-polish rounds) and as the `integration_test` target (see below). Also uncovered a real production bug: a `SliverMasonryGrid` layout crash under filtering that no widget-test fixture reproduced, only real device/browser use.
- **`integration_test` (Task 39):** `flutter test integration_test/<file>.dart -d <device-id>` runs a real, compiled build against a connected device or browser — closes a gap plain `flutter_test` can't (real network/image timing, real scroll physics). Targets the physical Pixel 2 by device id, not an emulator or `-d chrome` (avoids the RAM cost of a local browser on this machine). One gotcha specific to real devices: `SkeletonPulse`'s loading animation repeats forever absent a reduced-motion setting, so `pumpAndSettle()` right after mounting a screen that starts in a loading state hangs until its 10-minute timeout — use a bounded/condition-based pump instead (`integration_test/support/pump_until.dart`). A locked device screen also stalls any `pump()` indefinitely (no VSYNC delivered); `adb shell svc power stayon usb` keeps it awake while connected.

## Design notes

- **Caching:** a single Riverpod `FutureProvider` (`inventoryProvider`) fetches once per session; SRP and VDP both read the same cached value — confirmed via code review (not just assumed from the provider's design) that a third, later consumer (the header logo's accessibility label) adds zero additional fetches.
- **Paging & filtering:** both run client-side against the one cached response — VINCUE's API has no server-side paging or filtering to call into, so this is the correct architecture for the API's actual shape, not a simplification of a "real" paginated design. Filters (make, body style, price range — a two-select min/max pair, not a single control) and the current page live in `go_router`'s URL query params, shareable and refresh-survivable, same as the reference app's URL-param approach.
- **Data transform:** `lib/models/transform_vehicle.dart` narrows and normalizes the raw ~48-field VINCUE payload into a clean `Vehicle` type before anything touches the UI (price floor + Porsche-$1 sentinel handling, body-style normalization, mpg gating, description HTML sanitization). One addition beyond the reference app: real Summit Subaru El Cajon listings have a dealer-side authoring-tool bug — a malformed HTML entity pattern (`&ltb>...&lt/b>` instead of `<b>...</b>`) that a spec-compliant parser correctly treats as literal text, not a tag, so it would otherwise survive on-screen as visible `<b>`/`</b>` characters. `_repairMangledEntityTags` fixes this before parsing — a deliberate deviation from strict parity (the reference app would show the same artifact), documented in `docs/SPEC.md`.
- **Dark mode:** implemented in full (manual toggle, `shared_preferences`-persisted, defaults dark) but **currently force-disabled** — a branding decision, not a bug: the custom header logo's palette doesn't read well against the dark theme, and no time was budgeted to also tune dark-mode contrast for new branding added late in the build. The entire mechanism (`themeModeProvider`, `ThemeModeNotifier`, persistence, the `ThemeToggleButton` widget) is untouched and fully functional — re-enabling is a one-line change (`lib/main.dart`) back to reading the provider, not a rebuild. Documented as an explicit deviation in `docs/SPEC.md`.
- **Visual design:** a custom "Summit Subaru El Cajon" logo (sunburst-behind-a-mountain emblem — designed for this build, not a stock asset) in the header in place of plain dealer-name text, and a matched bold condensed display font (Anton, Google Fonts/SIL OFL) applied to headline/title text only — not app-wide, since a display font hurts readability in dense areas like the VDP spec table and vehicle descriptions. Both go beyond the reference app's own visual design, documented as deviations in `docs/SPEC.md`.
- **Responsive layout:** not part of the original spec — no document ever named a target screen-size range beyond "phone, verified once on a real device" — added mid-project (Tasks 17-19) once it became clear the primary dev/review loop was a resizable browser window, not a fixed phone viewport. `lib/theme/breakpoints.dart`'s `WindowSizeClass` (compact below 600px, medium 600–839px, expanded 840px+) is the one shared breakpoint seam, reused by the SRP filter bar's tiered reflow (Task 34), the SRP's 1200px width cap at expanded, and the header logo's per-size-class scaling (Task 35). VDP tried a two-pane layout at expanded widths first (Tasks 17-19), then reverted it (Task 32) after a live review at real wide-desktop widths found it read worse than a wide single column; replaced with a narrower fix (Task 41) — only the photo shrinks and centers past its own independent 500px breakpoint, everything else in the single-column layout untouched.
  - **Next-steps idea, parked, not scoped:** at medium/expanded, the header, SRP filter bar, and SRP pagination footer are all currently fixed in place at every width (Scaffold `AppBar` plus fixed `Column` siblings around the scrollable grid). The thinking so far — header non-sticky at medium/expanded, filter bar's stickiness still undecided, footer optionally non-sticky too, and an unresolved reveal-on-scroll-up trigger ("any upward scroll" vs. "only at the very top") — is written up in `possible-to-dos.md`'s C6 addendum. Nothing here is scheduled.

## Process notes

Built with the same rigor as the reference React app, adapted for a task-loop workflow:

- **Real TDD** for logic-bearing code (the data transform, pagination/filtering math, URL-state sync, the proxy handler, theme configuration) — test written and watched fail for the *expected* reason before any implementation.
- **Confidence scoring after every task**, grounded in what actually happened during implementation (not a pre-estimate), specifically calling out what's uncertain and how it could be verified — several tasks iterated based on their own honest self-assessment before review even started.
- **Two-stage review after every task:** spec compliance against `docs/SPEC.md`, then code quality (idiomatic conventions, no dead code, no unnecessary abstraction) — via an independent reviewer (a fresh subagent or the `/code-review` skill), never self-graded.
- **Live verification over assumption, repeatedly.** This caught real issues that reading the code alone wouldn't have: a `.gitignore` ordering bug that silently re-ignored a tracked file, a missing `AppBar` overflow guard on unbounded dealer-name text, a Riverpod typing gap in `flutter_riverpod`'s public API (documented in `docs/LEARNING.md` so it doesn't get rediscovered from scratch), and — most notably — a fully-implemented header feature (the live dealer name) that turned out to have never actually been visible in the UI, only caught once real API data flowed through the app for the first time and a real developer looked at the running page.
- **Systematic debugging, not guess-fixing**, for real bugs: a "CORS error" on one vehicle photo turned out to be an upstream 500 from VINCUE's own CDN (confirmed via direct `curl`, not assumed); a malformed HTML-entity pattern in real descriptions was root-caused against the actual WHATWG parsing spec before writing a fix, and confirmed systemic (not a one-off) against a second real listing before generalizing the fix.

## Known limitations

- **A handful of VINCUE photo links are dead** (confirmed via direct `curl` — real upstream 500s, not a bug in this app) — `VehiclePhoto`'s existing placeholder fallback (Task 8) already handles this gracefully.
- **`integration_test` E2E coverage is two flows, not comprehensive** — a large-inventory scroll/filter/clear flow and a fetch-failure/Retry flow, both verified on a real Pixel 2. VDP navigation, the photo carousel, pagination, empty-results, and URL sync have no real-device coverage yet.
- **A handful of optional extra features (Hero transitions, pull-to-refresh, an auto-hiding header, golden tests, platform-native polish, additional `integration_test` flows) were considered and are not being built** — see `docs/superpowers/plans/possible-to-dos.md`'s C1-C7 for what each would have involved.

Everything else — retry-on-failure, disk-level image caching, per-context photo cache sizing, pagination overflow at narrow widths, and the real-Android-device verification pass — was found, fixed, and verified live during the build; see the plan file for specifics (Tasks 27, 29, 36, and the device-pass notes throughout).

## Development notes

**Git wasn't initialized until partway through the build (Task 8).** My setup process for this project — pulling the spec, plan structure, and reference implementation from a sibling project rather than a from-scratch `flutter create` — was new to me, and version control wasn't part of what got carried over. It went unnoticed until I asked directly whether anything had been committed yet.

Once caught, I initialized the repo and reconstructed history as accurately as I could: a single baseline commit for the work already done (Tasks 1–5, where I no longer had the exact intermediate diffs), then precise per-task commits from Task 6 onward, including separate follow-up commits for confidence-raising test additions and one real bug fix a confidence-ideation pass caught.

I've since updated my global Claude Code instructions (`~/.claude/CLAUDE.md`) to make `git init` the mandatory first step of any new project, with per-task commits pre-authorized in a task-loop workflow, so this doesn't happen again.

## Learning

`docs/LEARNING.md` is a running, dated log of new Dart/Flutter concepts introduced task-by-task, plus two whole-project retrospectives written after the numbered task plan wrapped. The most load-bearing lessons out of that log:

**What went right:**

- **Every mistake became a durable process change, not a one-off patch.** The late git init became a standing global rule (`git init` as mandatory step zero); the self-graded-review gap became this project's strict independent-review requirement; every found bug got logged here or in `possible-to-dos.md` rather than silently patched and forgotten.
- **Scope discipline held for the whole build.** Real gaps (no documented screen-size target, a dealer-data HTML-entity bug) were proactively flagged and folded into `docs/SPEC.md` as explicit deviations — never silently done, never silently skipped, and every declined/deferred extra (`possible-to-dos.md`'s C1-C7/G1-G5) is named with a reason instead of just dropped.
- **Verifying against the real source over trusting docs or memory was a consistent habit, not a one-off.** Confirmed independently across unrelated contexts — Riverpod's actual retry internals, the Flutter SDK's own web-specific keyboard-intent handling, a real 1200px-viewport measurement — rather than assuming any of them from documentation.
- **Infra work and logic work were kept cleanly separate.** The Dart-side API-target config was built and tested independent of the actual proxy deployment, so neither blocked the other's own correctness loop.
- **A design that didn't pan out live was reverted outright, then properly re-solved later** — not patched into a permanent compromise. A two-pane detail-page layout was tried, reverted after a live wide-screen look, and the actual underlying problem was solved a different way afterward.

**What went wrong:**

- **Real data/device/browser contact should be front-loaded, not left until integration work.** Three separate bugs — a header feature that was invisible in the UI despite passing every fixture-backed test, a grid-layout crash three synthetic test attempts couldn't reproduce, and a mismatched test assertion — each surfaced only on first real contact, well after the surrounding logic had already been built on unverified assumptions.
- **A safeguard specified in the process isn't the same as one actually exercised.** Per-task review was self-graded for a stretch of early tasks instead of run through an independent pass, caught only by a retroactive review sweep. Now enforced strictly for every task.
- **Correctness bugs and visual/UX judgment calls need different gates.** TDD and code review catch wrong output, crashes, and overflow reliably — they don't catch "this looks worse than expected once you actually see it live," which is what drove more than one shipped decision to get reversed shortly after. Polish-tier work benefits from a live look before treating it as done, not just the same test-and-review pipeline used for logic.
- **Independent review catches a different bug category than tests do, not a redundant check on the same one.** An architecture-level bug (a router silently rebuilding on an unrelated state change) was invisible to any unit test — nothing about the isolated code was wrong — and was only caught by a full-diff review.
- **"My test suite can't reproduce this" means the harness has a gap, not that the bug isn't real.** True every time it came up in this build.

## Tech stack

Flutter/Dart · Riverpod · go_router · `http` · `shared_preferences` · `html` (description sanitization) · `flutter_staggered_grid_view` (SRP masonry grid) · `cached_network_image` (disk-backed photo cache) · Vercel (Node serverless proxy + static hosting) · `vitest` (proxy tests) · `flutter_test`/`mocktail`/`integration_test` (app tests)
