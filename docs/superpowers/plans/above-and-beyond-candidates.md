# Above-and-beyond candidates (Flutter-flex features)

**Status: NOT approved scope.** These are optional "prove myself" features to
consider *after* the core build (Tasks 14b–16) is done and if time allows.
Each one is chosen because it's notably easier in Flutter than in the React web
version — a concrete "React can't do this cleanly, Flutter does it in a few
lines" story for the hiring submission.

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

### G2. Disk-level image cache

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
**identified during Task 29's investigation (2026-07-12), NOT fixed**:
one of `_FilterBar`'s `DropdownButton`s (`lib/screens/srp_screen.dart`,
the Make/Body/Min price/Max price dropdowns), whose internal
selected-item-plus-arrow `Row` (Flutter's own `DropdownButton`
internals, not app code) overflows below roughly 300px of available
content width. Confirmed independent of `_PaginationControls`'s bug —
reproduces on the *old* `Row`-based pagination code too, and persists
after Task 29's fix. Deliberately left unfixed as out of scope for
Task 29 (a different widget, a different root cause, would need its own
investigation into whether a narrower dropdown item label, a custom
dropdown affordance, or something else is the right fix). **Not yet a
numbered task** — pick up with its own `systematic-debugging` pass
before designing a fix, same discipline as this entry got.

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
