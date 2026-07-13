import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_provider.dart';
import '../theme/breakpoints.dart';
import 'error_boundary.dart';

/// Single rollback point (Task 35): JP decided to keep the logo at every
/// width after seeing it hidden at compact widths rendered. Flip back to
/// `true` to hide it again with no other code changes needed.
const bool kHideLogoAtCompact = false;

/// Header logo/AppBar sizing per window size class -- grows the logo (and
/// the AppBar height around it) on wider screens rather than staying a
/// fixed size regardless of viewport, per the same [WindowSizeClass] tiers
/// already used for VDP's two-pane layout and SRP's width cap. Each tier
/// keeps a consistent 36px gap between logoHeight and toolbarHeight for
/// even vertical padding around the logo.
({double logoHeight, double toolbarHeight}) logoSizingFor(WindowSizeClass sizeClass) {
  switch (sizeClass) {
    case WindowSizeClass.compact:
      return (logoHeight: 68, toolbarHeight: 104);
    case WindowSizeClass.medium:
      return (logoHeight: 80, toolbarHeight: 116);
    case WindowSizeClass.expanded:
      return (logoHeight: 92, toolbarHeight: 128);
  }
}

/// The single persistent chrome (header logo) around every route, wired in
/// via a go_router `ShellRoute` (see `app_router.dart`) rather than
/// `MaterialApp.router`'s `builder` — that `builder` sits *above* the
/// Router's own `Navigator`/`Overlay`, which breaks `Tooltip`-bearing
/// widgets nested under it (the original motivation: `ThemeToggleButton`'s
/// `Tooltip`, back when it lived in this AppBar); `ShellRoute` nests this
/// shell inside that Navigator instead. Still the correct wiring for any
/// future `Tooltip`-bearing widget added here. (SPEC "Resilience UX" — a
/// build failure in [child] must not take the header down with it.)
/// Individual screens no longer own their own `Scaffold`/`AppBar`. Requires
/// a `ProviderScope` ancestor (reads `dealerNameProvider` for the header
/// logo's accessibility label) -- safe from the [child]-only failure
/// guarantee above only because `dealerNameProvider` is designed to never
/// throw (it reads `.value`, never `.requireValue`); it is not itself
/// wrapped in [ErrorBoundary].
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SPEC "Dealer name" -- kept live (falling back to kFallbackDealerName
    // while loading/on error, via dealerNameProvider) even though the header
    // itself now shows a fixed logo (see comment below): this value still
    // drives the logo's Semantics label for accessibility.
    final dealerName = ref.watch(dealerNameProvider);
    final windowSizeClass = windowSizeClassOf(MediaQuery.sizeOf(context).width);
    final sizing = logoSizingFor(windowSizeClass);
    final hideLogo = kHideLogoAtCompact && windowSizeClass == WindowSizeClass.compact;

    return Scaffold(
      appBar: AppBar(
        // Deliberate branding decision (docs/superpowers/specs/2026-07-12-
        // header-logo-design.md): the header shows the fixed Summit
        // Subaru El Cajon logo, a deliberate divergence from SPEC's "live
        // dealer name in the header" text requirement. dealerName is kept
        // (not deleted) and now only feeds this Semantics label, so screen
        // readers still announce the live value even though sighted users
        // see the fixed graphic -- except below 600px (compact), where
        // kHideLogoAtCompact hides the graphic entirely (docs/superpowers/
        // specs/2026-07-12-filter-bar-tiers-and-logo-visibility-design.md)
        // and only the Semantics label survives. centerTitle is explicit
        // because AppBar's default title alignment is platform-dependent
        // (centered on iOS, left-aligned on Android) -- this app wants the
        // logo centered everywhere. Sizing grows with window size class
        // (logoSizingFor above) instead of staying fixed regardless of
        // viewport width.
        toolbarHeight: hideLogo ? kToolbarHeight : sizing.toolbarHeight,
        centerTitle: true,
        title: hideLogo
            ? Semantics(label: dealerName, child: const SizedBox.shrink())
            : Semantics(
                label: dealerName,
                child: Image.asset(
                  'assets/images/summit_subaru_logo.png',
                  height: sizing.logoHeight,
                  fit: BoxFit.contain,
                ),
              ),
      ),
      body: ErrorBoundary(child: child),
    );
  }
}
