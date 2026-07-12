# SRP filter bar responsive tiers + header logo visibility — design spec

Date: 2026-07-12
Status: approved, pending write-up into the task plan

## Why this exists

Task 30 fixed the filter dropdowns' narrow-width overflow (`isExpanded: true` +
`ConstrainedBox(maxWidth: 300)`), but that fix has a side effect JP found
during the first real-device pass (Task 31, logged as an open bug): every
dropdown always renders at the full 300px cap regardless of its actual
content width, because `isExpanded: true` fills whatever width its `Wrap`
parent gives it up to that cap. Two 300px boxes plus spacing don't fit on a
phone-width screen, so all four stack vertically — wasting most of the
screen's vertical space on a phone.

This spec replaces the flat-cap approach with real per-tier layout behavior
(4 per row → 2 per row → collapsed) and fixes the underlying width mechanism
so each dropdown is only as wide as its own content needs, not a fixed
number. It also adds a new requirement surfaced in the same conversation:
the header logo should disappear at phone widths instead of cramping the
`AppBar`.

## Scope decision

**In scope:** the SRP (search results page) filter bar's responsive layout,
and the header logo's visibility at narrow widths (shared `AppShell` chrome,
so this affects both SRP and VDP's `AppBar`, even though the filter-bar work
itself is SRP-only).

**Explicitly out of scope:** the VDP screen's own layout (already reverted
to always-single-pane, Task 32, in an unrelated prior task this same
session) — no change here.

## Breakpoints (reused, not new)

Same three-tier system already in `lib/theme/breakpoints.dart`, used by the
SRP/VDP width caps (Tasks 17-19):

```dart
enum WindowSizeClass { compact, medium, expanded }
const double kMediumBreakpoint = 600;
const double kExpandedBreakpoint = 840;
```

- **Expanded** (≥840px): all 4 dropdowns in one row.
- **Medium** (600-839px): 2 per row.
- **Compact** (<600px): collapsed by default behind an "Apply filters"
  toggle.

## Filter bar layout per tier

### Expanded

All 4 dropdowns (make, body style, min price, max price) in a single
left-aligned row, each sized to its own natural content width rather than a
shared flat cap — see "Width mechanism" below.

### Medium

Two dropdowns per row: (make, body style) on row one, (min price, max
price) on row two. Same per-field widths as expanded, just re-flowed into
two rows instead of one.

### Compact

Collapsed by default: a single button reading **"Apply filters"** replaces
the dropdown row entirely, so a phone-width screen shows the vehicle grid
immediately without the filter controls eating vertical space. Tapping it
reveals all 4 dropdowns stacked full-width (today's existing narrow-`Wrap`
fallback shape), with a way to fold them back away (the same button, now
reading something like "Hide filters", or an explicit close action --
finalize the exact label during implementation).

**Live filtering, unchanged:** selecting a dropdown value still filters the
grid immediately, the same as today. The button is purely a show/hide
toggle for the panel's visibility -- it does not gate or stage filter
application. This means no new provider/state-management behavior is
needed; only new UI for showing/hiding the existing filter bar.

## Width mechanism (root-cause fix, not another flat cap)

Task 30's real root cause (still present after its own fix): Flutter's
`DropdownButton` normally reserves *closed-state* width for the widest
possible menu item (e.g. "All body styles"), not the current selection.
Task 30 worked around this with `isExpanded: true` + a shared 300px cap --
which stopped the overflow but also means every dropdown always renders at
exactly 300px (or whatever narrower width the `Wrap` line gives it), never
its own true content width.

**Fix:** `DropdownButton.selectedItemBuilder` -- a separate, lean widget
Flutter renders for the *closed* state (just the current selection's text),
completely decoupled from the full menu's widest item. Combined with
`isExpanded: false`, each dropdown's width tracks its actual selected text
instead of the widest possible option. A small per-field max width (reusing
Task 30's own measurements -- make ~234px, body style ~266px, both price
dropdowns ~169px -- as an upper bound, not a forced width) still guards
against a pathologically long value overflowing; `TextOverflow.ellipsis`
(already added in Task 30) remains the last-resort guard.

This is a new Flutter concept for this project (`selectedItemBuilder`) --
gets a LEARNING.md entry.

## Header logo visibility

Below 600px (compact), the header logo (`lib/widgets/app_shell.dart`) is
hidden entirely -- no text fallback, just the toolbar's existing chrome
(theme toggle area, back/nav) remains. The `Semantics(label: dealerName)`
wrapper is unaffected either way since it's about screen-reader output, not
visual layout.

**JP's explicit note, kept in mind for implementation:** this is a
first-pass decision he may revisit after seeing it rendered -- he may want
to keep the logo at all sizes, or shrink it instead of hiding it, rather
than hide it outright. **Implementation should make the hide-vs-keep
decision a single, easily-reversible branch point** (e.g. one conditional
around the `Image.asset`/`SizedBox` in `AppShell`, not scattered logic) so
swapping "hide below 600px" for "shrink below 600px" or "always show" is a
small, localized change, not a re-plan.

## Testing

- Filter bar tier boundaries: widget tests at 599/600/839/840px asserting
  the correct column arrangement (collapsed-behind-button / 2-per-row /
  4-in-a-row).
- Apply-filters toggle: tapping it on a compact-width test reveals the
  dropdowns; tapping again (or the close action) hides them again; a
  dropdown value change while open still updates the filtered grid
  immediately (live-filtering regression check).
- `selectedItemBuilder` width: a widget test asserting a short selection
  (e.g. "Kia") renders narrower than a long one (e.g. "All body styles"),
  proving width now tracks content instead of a flat cap.
- Header logo: existing logo-present assertion (Task 22/26) still holds at
  ≥600px; new test asserts the logo is absent below 600px, on both SRP and
  VDP (shared `AppShell`).

## Out of scope

- Any change to VDP's own layout (Task 32 already settled this,
  unrelated to this spec).
- A true staged/"commit on Apply" filtering model -- selections keep
  filtering live, per JP's explicit call.
- Tablet/desktop nav chrome changes -- not part of this request.
