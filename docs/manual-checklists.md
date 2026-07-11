# Manual verification checklists

Things the automated suite structurally can't verify, checked by hand
against a running build instead. Each entry: what to run, what to check,
date/result of the last real pass.

## Keyboard/focus-traversal order (Task 14c)

SPEC's accessibility goal: reach everything by keyboard alone, in this order
— **filters → cards → pagination → VDP (on Enter/Space) → carousel controls
→ back-to-results button**. Flutter's widget-test harness doesn't simulate
real Tab-key traversal across a full running app well enough to automate
this, so it's a manual pass instead of a test.

**How to run it:**

1. `flutter run -d web-server --web-port=8765`, open in a real browser.
2. Click once on the page background (not on any control) so focus starts
   at the top, then use only Tab / Shift+Tab / Enter / Space / arrow keys —
   no mouse — for the rest of the pass.
3. Walk the SRP: confirm Tab reaches, in order, the make/body/min-price/
   max-price filter dropdowns, then each vehicle card (one tab stop per
   card — `VehicleCard`'s `InkWell` has `canRequestFocus: false` specifically
   so its `FocusableActionDetector` wrapper is the only stop), then the
   pagination Previous/Next buttons.
4. Confirm a focused card shows the amber focus-ring border (Task 14c) and
   that Enter/Space on a focused card navigates to its VDP (via the
   `ActivateIntent`/`CallbackAction` wired in `VehicleCard`).
5. On the VDP: confirm Tab reaches the carousel's Previous/Next controls,
   then the spec table/features/description content (if any of it is
   focusable), then the "Back to search results" button, and that the
   shared `AppShell` AppBar's theme-toggle button is reachable too — but
   confirm there is **no** separate automatic back-arrow tab stop (SPEC:
   the only supported way back is "Back to search results", which resets
   filters by design).
6. Confirm Shift+Tab reverses the same order.

**Status:** not yet run against a live build — needs a human pass (or a
future session with real browser-driving tools) before this checklist can
be marked verified. Everything above it in the automated suite (focus-ring
rendering, one-tab-stop-per-card, no-auto-back-arrow through the real
`ShellRoute`) is covered by `test/widgets/vehicle_card_test.dart` and
`test/router/app_router_test.dart`; this checklist only covers the parts
those can't reach — actual Tab-key sequencing in a real browser.
