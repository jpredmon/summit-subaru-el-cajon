# Summit Subaru El Cajon header logo — design spec

Date: 2026-07-12
Status: approved, pending write-up into the task plan

## Why this exists

JP designed a custom "Summit Subaru El Cajon" logo (sunburst-behind-a-
mountain emblem, red "SUMMIT SUBARU" ribbon, navy "El Cajon" script —
originally inspired by, but independently recomposed from, the general
sunburst-badge style of a real local organization's logo, not a derivative
of that specific mark) and wants it in the app's header, replacing the
plain `Text(dealerName)` title added last session (commit `f01e873`).

This is a deliberate above-and-beyond branding choice, not a bugfix.

## Scope decision: real SPEC tension, resolved explicitly

`docs/SPEC.md`'s "Dealer name" requirement says the header shows the
**live** `dealerName` from the API response (falling back to "Vehicle
Inventory" if empty) — that's about correctness for whatever dealer's
data actually comes back, not fixed branding for one specific dealer.
Swapping in a hardcoded logo image is a genuine divergence from that,
not a restoration of it.

**Decision: the logo always shows**, regardless of what `dealerName`
actually is. `ref.watch(dealerNameProvider)` stays in `AppShell` — not
deleted — and feeds a `Semantics` label wrapping the logo image, so
screen readers still announce the live dealer name for accessibility even
though sighted users see the fixed graphic. This keeps the live-data
mechanism genuinely useful (extensible to a different dealer/logo later)
rather than either deleting it or leaving truly dead code.

A related, larger idea JP raised and explicitly deferred: removing dark
mode and re-theming the whole app's colors/fonts around the logo's
palette. **Rejected for this task** — dark mode is already-shipped,
SPEC-required, tested functionality (Task 13); dropping it would be a
real regression, not a scope trim, and a full app-wide re-theme is a much
larger project than a header logo. If JP wants that later, it becomes its
own separate above-and-beyond item. This task instead just confirms the
logo's own colors (navy/gold/red/green) read acceptably against both the
light and dark AppBar background as-is.

Explicitly out of scope:
- Any theme/palette changes elsewhere in the app.
- Multi-density (1x/2x/3x) asset variants — a single reasonably high-res
  PNG downscales cleanly for one static AppBar-sized use; not worth the
  added asset-management complexity here.
- `flutter_svg` or any new dependency — PNG + `Image.asset` only.

## Implementation

**Asset pipeline:** JP exports one clean PNG from Inkscape (transparent
background, tightly cropped to the emblem, no page margin) — same export
process already used this session (`Export Area: Drawing`, transparency
on). Sized comfortably larger than its final display size so it downscales
cleanly (no upscaling blur).

**File:** `assets/images/summit_subaru_logo.png`, declared under
`pubspec.yaml`'s `flutter: assets:` section (currently the default
commented-out template — this is the first real asset the project adds).

**`lib/widgets/app_shell.dart` changes:**
- `AppBar`'s `title:` changes from `Text(dealerName, maxLines: 1,
  overflow: TextOverflow.ellipsis)` to a `Semantics(label: dealerName,
  child: Image.asset('assets/images/summit_subaru_logo.png', ...))`.
- `dealerNameProvider` watch stays exactly as-is — only what it feeds
  changes, not whether it's read.
- `AppBar`'s implicit height: override via `toolbarHeight` to
  accommodate the logo (target ~72-80px, vs. Flutter's 56px default) so
  "SUMMIT SUBARU"/"El Cajon" stay legible rather than being squeezed.
  Exact value confirmed visually once rendering, same iterative-by-eye
  process used for the logo's own design earlier tonight.

**Docs:** short bullet added to `docs/SPEC.md`'s "Dealer name" section
documenting this as an intentional above-and-beyond deviation (fixed
branded logo instead of live dealer-name text), mirroring Task 20's
entity-repair deviation note.

## Testing

Widget test on `AppShell`: assert an `Image` widget (or `Semantics` node
with the live `dealerName` as its label) is present in the `AppBar`,
using the same `ProviderScope`/`inventoryProvider` override pattern as
the existing dealer-name tests in `test/widgets/app_shell_test.dart`.
`flutter test`'s asset-loading behavior for `Image.asset` in widget tests
needs the asset actually registered in `pubspec.yaml` and present on disk
— confirm this works in the test harness before considering the task
done (a real, checkable uncertainty, not a guess).

## Out of scope

- Favicon generation (separate, JP handles via favicon.io/
  realfavicongenerator.net once a final logo image exists — not part of
  this task).
- The "car photo not shown" placeholder graphic (separate follow-up,
  not scoped here).
- Any app-wide re-theming (see Scope decision above).
