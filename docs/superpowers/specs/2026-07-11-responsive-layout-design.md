# Responsive layout — design spec

Date: 2026-07-11
Status: approved, pending write-up into the task plan

## Why this exists

Nothing in `docs/SPEC.md`, the implementation plan, or the context docs ever
named a target range of screen sizes beyond "phone, verified once on a real
Android device near the end" (`docs/context/original-request.md`). That was a
reasonable default for the original scope, but the primary dev/review loop is
Chrome/`web-server` in a resizable browser window (per
`docs/context/dev-environment-notes.md`), and the mobile lead may well review
via that resizable window before or instead of installing an APK. Right now
there is zero responsive-layout code anywhere in `lib/` — no `MediaQuery`, no
`LayoutBuilder`, no breakpoint concept at all. This spec closes that gap.

## Scope decision

Full responsive breakpoints (not just "don't overflow at phone widths"), but
the smallest version of that idea that actually does something: **one
breakpoint, two layout states.**

This follows Material 3's own adaptive-design guidance directly rather than
inventing a custom scheme: Material 3 defines three window size classes
(`compact` <600dp, `medium` 600–839dp, `expanded` ≥840dp), but the
compact/medium distinction is about *navigation chrome* (bottom nav bar vs.
nav rail) — content itself is documented as staying single-pane through both
compact and medium, only going two-pane ("list-detail" pattern) at
`expanded`. This app has no nav-rail/bottom-nav distinction to make, so the
three-tier classification collapses to two effective content states:

- **Single-pane** (compact + medium, <840px): today's existing layouts,
  essentially unchanged.
- **Two-pane** (expanded, ≥840px): VDP goes side-by-side; SRP/VDP content
  gets a max-width cap so it doesn't stretch edge-to-edge on wide desktop
  windows.

Explicitly rejected: a third-party responsive-layout package
(`responsive_framework` et al.) — overkill for two branch points and a single
breakpoint; a distinct `medium` layout — Material 3's own guidance doesn't
call for one here, and building one anyway would be scope nobody asked for.

## Components

### `lib/theme/breakpoints.dart` (new)

```dart
enum WindowSizeClass { compact, medium, expanded }

const double kMediumBreakpoint = 600;
const double kExpandedBreakpoint = 840;

WindowSizeClass windowSizeClassOf(double width) { ... }
```

A plain function, not a widget — classification is unit-testable directly
(boundary values: 599/600/839/840) with no `pumpWidget` needed. Call sites
read `MediaQuery.sizeOf(context).width` and pass it in.

### VDP (`lib/screens/vdp_screen.dart`)

- **Single-pane** (today's layout, unchanged): `PhotoCarousel` above spec
  table/features/description, in a scrolling column capped at
  `maxWidth: 800` (existing `ConstrainedBox`, unchanged).
- **Two-pane** (`expanded`): `PhotoCarousel` in a left column fixed at
  `440px`, spec table/features/description in a scrolling right column
  filling the remainder, both inside a `Row` whose overall content is capped
  at `maxWidth: 1200` (matching the single-pane cap's ratio: roughly 1.5x,
  enough for two comfortable columns without stretching edge-to-edge on very
  wide windows).

### SRP (`lib/screens/srp_screen.dart`)

- Grid column count already self-tunes via
  `SliverGridDelegateWithMaxCrossAxisExtent` — no change needed there.
- Filter bar already reflows via `Wrap` — no change needed there.
- Only change: cap overall content width at `maxWidth: 1200` at `expanded`
  (same cap VDP's two-pane layout uses, for visual consistency between
  screens), so the grid doesn't stretch absurdly wide on a large desktop
  window.

### Everywhere else

No other screen/widget needs a distinct layout branch. Existing `Wrap`-based
widgets (filter bar, spec table, feature list) already reflow naturally and
need no breakpoint-specific handling.

## Testing

- `windowSizeClassOf`: direct unit tests at the boundary values (599 →
  compact, 600 → medium, 839 → medium, 840 → expanded).
- VDP layout branch: widget tests set `tester.view.physicalSize` to a
  compact-width and an expanded-width size and assert which structural
  layout (stacked `Column` vs. side-by-side `Row`) is present — this is
  automatable, unlike Task 14's keyboard-traversal checklist, because window
  size is a real testable input.
- SRP max-width cap: a widget test at an expanded width asserting the
  content's rendered width is capped rather than filling the full test
  surface.

## Out of scope

- A distinct `medium`-tier layout (see Scope decision above).
- Tablet/desktop-specific navigation chrome (nav rail, bottom nav) — this
  app has no navigation structure that would need one.
- Orientation-specific handling beyond what width-based breakpoints already
  cover.
