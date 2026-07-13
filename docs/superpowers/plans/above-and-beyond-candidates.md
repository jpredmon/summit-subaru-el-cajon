# Above-and-beyond candidates (Flutter-flex features)

**Status: NOT approved scope — this is JP's "maybe-do-it-later" list
(2026-07-12).** C1-C6 below are optional "prove myself" features to
consider *after* the core build (Tasks 14b–16) is done and if time allows,
not active work. Each one is chosen because it's notably easier in Flutter
than in the React web version — a concrete "React can't do this cleanly,
Flutter does it in a few lines" story for the hiring submission (C6 is the
exception — deferred effort/cost, not a React-parity story).

Per this project's scope discipline: none of these may be silently folded into
the active task loop. To pick one up, first add a matching entry to
`docs/SPEC.md` (this is scope *expansion* beyond the current spec), then promote
the candidate below into a numbered task in
`vincue-mobile-implementation.md`, then run it through the full loop (TDD →
confidence score → dual review → LEARNING note → commit). Each also introduces a
new-to-JP Flutter concept — good `docs/LEARNING.md` material.

Recommended pairing if time is short: **C1 (Hero) + C2 (pull-to-refresh)** —
an afternoon of work, the two most viscerally "native mobile" touches, each a
clean React-can't-do-this story.

---

## C1. Hero shared-element transition (SRP card photo → VDP photo)

**Why Flutter > React:** a `Hero` with a matching `tag` makes the framework
fly the photo from the grid cell into the detail page automatically across the
route change — ~4 lines. React needs Framer Motion `layoutId` or hand-rolled
FLIP and it's still fragile across a router navigation.

**Sketch:** wrap the `VehiclePhoto` in `VehicleCard` and the first image in the
VDP `PhotoCarousel` in `Hero(tag: 'vehicle-photo-${vehicle.id}', child: ...)`.
Tags must be unique per vehicle and match on both screens. Works through the
existing `go_router` push (no router change needed). Watch: Hero + the two-pane
expanded VDP layout (Task 18) — confirm the flight target is the carousel's
image in both layout branches; a mismatched/duplicate tag throws.

**Test first:** widget test navigates SRP→VDP and asserts a `Hero` with the
expected tag is present on both screens (a full flight animation is hard to
assert; presence + matching tag is the testable contract).

**New concept:** `Hero` animations / shared-element transitions.

---

## C2. Pull-to-refresh on the SRP

**Why Flutter > React:** `RefreshIndicator` gives a native drag-to-refresh
gesture + spinner in ~5 lines. On React web this gesture barely exists without
a library and manual touch-event handling.

**Sketch:** wrap the SRP grid's scrollable in
`RefreshIndicator(onRefresh: () => ref.refresh(inventoryProvider.future), ...)`.
Decide refresh semantics vs the existing cache (Task 5): a manual refresh should
bypass/invalidate the cache and re-fetch. Confirm it interacts correctly with
the current filter/page state (refresh data, keep filters).

**Test first:** widget test triggers the refresh callback and asserts the
inventory provider is re-fetched (override the provider, assert the fetch fires
again / new data renders).

**New concept:** `RefreshIndicator`; Riverpod `ref.refresh` for imperative
cache invalidation.

---

## C3. Skeleton → grid crossfade (builds on Task 14a)

**Why Flutter > React:** `AnimatedSwitcher` crossfades between two child
subtrees automatically on child-key change — no transition library.

**Sketch:** wrap the SRP/VDP `.when(...)` result in `AnimatedSwitcher` so the
14a skeleton fades into the loaded content instead of hard-swapping. Give each
branch a distinct `Key` so the switcher detects the change. Must respect
`disableAnimations` (Task 14c) — gate the switch duration to zero when set.

**Test first:** loading→loaded transition renders an `AnimatedSwitcher`; with
`disableAnimations` the switch is instantaneous.

**New concept:** `AnimatedSwitcher`; keyed child transitions.

---

## C4. Golden (screenshot) tests

**Why Flutter > React:** pixel-diff testing is built in
(`matchesGoldenFile`) — no Storybook + Chromatic / jest-image-snapshot stack.
Demonstrates testing maturity, which a mobile lead notices.

**Sketch:** golden tests for `VehicleCard` (with photo / placeholder / call-for-
price) and the skeleton loading state, in light and dark. **Caveat:** goldens
are font-rendering-sensitive across OSes — generate/verify in CI (or a single
pinned environment) and document that, or they'll flake on a different machine.

**Test first:** the golden test *is* the test — write it, generate the baseline
with `--update-goldens`, then confirm it passes clean on re-run.

**New concept:** `matchesGoldenFile`; golden-baseline workflow.

---

## C5. Platform-native polish (React web has no equivalent)

- **Material 3 dynamic color** — add the `dynamic_color` package; on Android 12+
  derive the whole `ColorScheme` from the user's wallpaper, falling back to the
  current seed color elsewhere. Very "native Android," ~a dozen lines around the
  existing theme.
- **Adaptive widgets** — `.adaptive` constructors (switch, dialog, refresh)
  render Cupertino on iOS and Material on Android automatically. A web React app
  has no equivalent.

**Why Flutter > React:** platform-native look/feel per-OS from one codebase; a
web app can't render true platform-native controls at all.

**Test first (dynamic color):** resolver returns the dynamic scheme when a
`CorePalette` is available and the seed-based scheme when it isn't (test the
resolver directly, no device needed — mirrors Task 15's define-resolver pattern).

**New concept:** `dynamic_color` / `CorePalette`; `.adaptive` constructors.

---

## C6. Auto-hiding header on scroll direction — deferred (JP's call, 2026-07-12)

**The ask:** header disappears scrolling down, reappears scrolling up (the
"Quick Return" pattern; Android's native equivalent is `AppBarLayout`'s
`app:layout_scrollFlags="scroll|enterAlways|snap"`). Last of the 4 items in
the approved above-and-beyond polish plan
(`C:\Users\Student\.claude\plans\1-in-vdp-in-the-frolicking-volcano.md`,
Item 4) — the other 3 are done (Items 2/3 → Tasks 37/40; Item 1 superseded
by Task 41's simpler photo-shrink alternative). **JP explicitly does not
want this one done now** — parking it here rather than in the active plan.

Approach already scoped in that plan file if picked up later: the idiomatic
`SliverAppBar(floating: true, snap: true)` was confirmed descoped (would
mean restructuring `AppShell` + both screens around a shared
`NestedScrollView`, a real multi-file architectural change, since
`lib/widgets/app_shell.dart`'s `AppBar` currently sits above each screen's
own separately-scrolling body with no shared scroll view). Chosen
alternative instead: wrap `AppShell.build`'s routed `child` in a
`NotificationListener<UserScrollNotification>` (bubbles up regardless of
how deep the actual scrollable is, no restructuring of `SrpScreen`/
`VdpScreen` needed) and hide/reveal the header on scroll direction.

---

## Real-world gaps (not Flutter-flex, just good practice)

Found during a 2026-07-12 bird's-eye architecture review — distinct from
C1–C5 above: these aren't "Flutter can do this and React can't" stories,
just honest answers to "would this hold up as a real shipped app." Same
scope-discipline rule applies (SPEC.md entry → numbered task → full loop)
before picking either up.

### G1. Retry action on fetch failure — DONE (Task 27, 2026-07-12)

`lib/screens/srp_screen.dart:49` and `lib/screens/vdp_screen.dart:54` both
show a static `Text('Failed to load inventory. Please try again later.')`
with no actual retry affordance — a full page reload is the only way to
recover from a failed initial fetch. Fix: a visible "Retry" button wired
to `ref.invalidate(inventoryProvider)` (or `ref.refresh`).

**Test first:** widget test on the error state asserts a "Retry" button
is present; tapping it (with `inventoryProvider` overridden to succeed on
the second read) asserts the loaded content replaces the error state.

**New concept:** none new — idiomatic Riverpod cache invalidation,
already used elsewhere in this codebase's pattern vocabulary.

### G2. Disk-level image cache — DONE (Task 36, 2026-07-12)

SPEC.md updated (new "Photo disk cache (G2)" bullet under Architecture
decisions) and Task 36 added to `vincue-mobile-implementation.md`, per this
file's own scope-discipline rule. Left a follow-up gap, logged separately
as **G4** below (no per-context image size cap).

`Image.network`/`NetworkImage` gets Flutter's automatic in-memory
`ImageCache` for free (fine within one session), but nothing persists
across app relaunches — a real production app re-downloads every vehicle
photo on every cold start. Likely fix: `cached_network_image` package (or
equivalent), swapped in for `VehiclePhoto`'s `defaultVehiclePhotoProvider`
(`lib/widgets/vehicle_photo.dart`).

**Test first:** TBD once scoped — likely asserts the configured image
provider type/cache behavior rather than real disk I/O in a widget test.

**New concept:** `cached_network_image` / disk-backed `ImageProvider`.

### G3. Pagination controls RenderFlex overflow at narrow widths — DONE (Task 29, 2026-07-12)

Found 2026-07-12 by JP testing on a real Samsung Galaxy S20 Ultra
viewport (via the responsive header-logo work), reproduced again the
same day testing Task 28's grid fix. Root-caused via
`systematic-debugging` (direct widget-size measurement, not assumed) and
fixed in Task 29 — see `vincue-mobile-implementation.md`.

Console evidence, verbatim:

```
A RenderFlex overflowed by 85 pixels on the right.
  creator: Row ← _PaginationControls ← Column ← Padding ← _SrpBody ← SrpScreen ← ...
  constraints: BoxConstraints(0.0<=w<=163.2, 0.0<=h<=Infinity)
  size: Size(163.2, 32.0)
```

Row is at `lib/screens/srp_screen.dart:333`, inside `_PaginationControls`
— its `Row` (Previous / page indicator / Next, per Task 9's original
build) doesn't fit inside the ~163px it's actually given at this width.
Cascades into further errors immediately after (same render pass,
likely knock-on from the failed layout, not independent bugs):

```
Assertion failed: .../flutter/lib/src/rendering/sliver_grid.dart:493:12
Unexpected null value.
Unexpected null value.
A RenderFlex overflowed by 38 pixels on the right.
```

That second, smaller 38px overflow is a separate `Row` somewhere else —
**identified during Task 29's investigation (2026-07-12) and FIXED in
Task 30 (same day)**: one of `_FilterBar`'s `DropdownButton`s
(`lib/screens/srp_screen.dart`, the Make/Body/Min price/Max price
dropdowns) reserves width for its widest possible item across all
options (e.g. "All body styles"), not its current selection, and never
shrinks below that — confirmed overflowing from 280px down through well
below 140px of available width. Fixed with `isExpanded: true` on all
four dropdowns, Flutter's own documented mechanism for this exact case
— see Task 30 in `vincue-mobile-implementation.md`.

**Task 29's fix:** `_PaginationControls`' `Row` (Previous / page
indicator / Next) had three non-flexible children whose combined
natural width (measured ~400px) couldn't shrink to fit narrow
viewports — a `Row` never shrinks non-flex children, it just overflows.
Replaced with a `Wrap` (the same pattern `_FilterBar` and
`_EmptyResults` already use elsewhere in this file for the same class
of problem — this is the third such instance, worth watching for a
fourth before extracting a shared helper), wrapped in `Center` since
`Wrap` shrink-wraps to its content width instead of filling its parent
the way `Row`'s default `mainAxisSize: MainAxisSize.max` did (a real
regression caught by an independent code review, not shipped) — without
`Center`, the controls would render flush-left instead of centered on
any viewport wide enough for them to fit on one line.

### G4. Photo disk cache has no per-context size limit

Found during Task 36's (G2) dual review, 2026-07-12 — **deliberately
deferred** (JP's call). `defaultVehiclePhotoProvider`
(`lib/widgets/vehicle_photo.dart`) calls `CachedNetworkImageProvider(url)`
with no `maxWidth`/`maxHeight`, even though the constructor supports
resize-on-disk via both params. `VehiclePhoto` is shared verbatim between
the SRP grid (`VehicleCard`, small masonry-grid thumbnail) and the VDP
carousel (`PhotoCarousel`, larger display) — one `defaultVehiclePhotoProvider`
function, no way for a call site to say "I'm a thumbnail." So every SRP
thumbnail disk-caches and decodes the CDN's full-resolution original,
multiplying disk/decode cost for the common browsing case with no size cap
taken even though the API was available.

Not a one-line fix: a blanket size cap would also degrade VDP carousel
quality, since both contexts share the same provider function today. Needs
`VehiclePhotoProviderBuilder`'s signature widened with a size hint (or two
separate builders, one per context) before a fix is attempted.

**Test first:** TBD once scoped — likely a widget test asserting
`VehicleCard`'s `VehiclePhoto` receives a smaller `maxWidth` than
`PhotoCarousel`'s, via an injected fake provider capturing its arguments
(same injection pattern already used throughout `vehicle_photo_test.dart`).

**New concept:** none new — same `ImageProvider` construction-parameter
pattern already introduced by Task 36.

### G5. Persistent button styling at compact widths — DONE (Task 37, 2026-07-12)

Found via real Android device testing: every plain-text `TextButton`
("Next"/"Previous," "Clear filters," "Back to search results," etc.) only
fills with the theme's tan/amber-ish tint during the press ripple —
Material 3's default `TextButton` styling, no persistent background. At
real phone widths these read as easy-to-miss plain text, not buttons.

Fixed with `persistentLinkButtonStyle(BuildContext)`
(`lib/theme/app_theme.dart`) — returns `null` above the compact breakpoint
(unchanged plain-link look), and at compact width a `TextButton.styleFrom`
using the theme's own `primaryContainer`/`onPrimaryContainer` roles (no new
hardcoded color) plus the existing `kCardRadius` shape. Applied to all 9
`TextButton` call sites across `lib/screens/srp_screen.dart` and
`lib/screens/vdp_screen.dart`. Deliberately only sets
background/foreground/shape — no padding/size changes — so it carries zero
layout-footprint risk against the existing 320px pagination-overflow
regression test.

**New concept:** none new — `ButtonStyle`/`TextButton.styleFrom`, an
existing Flutter mechanism this codebase hadn't used yet.
